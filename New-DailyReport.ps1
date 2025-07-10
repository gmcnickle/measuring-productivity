
<#
.SYNOPSIS
    Sends a daily activity summary email for a development team.

.DESCRIPTION
    This script collects Git and GitHub data for a configured list of developers, analyzing their contributions
    over the last 24 hours. It compiles metrics such as commit counts, adjusted line impact, PR activity, and
    the date of last commit. The results are emailed to a team lead.

.PARAMETER RepoPath
    Path to the Git repository to analyze. Defaults to the current directory if not specified.

.PARAMETER LeaderEmail
    Email address of the team lead who should receive the summary report.

.NOTES
    Requires PowerShell 7.0 or later.
    Uses Git CLI and GitHub REST API (via a personal access token).
    Team member identities (email-to-GitHub-username) are configured in the $settings object.

    Author: Gary McNickle (gmcnickle@outlook.com)
    Co-Author & Assistant: ChatGPT (OpenAI)

    This script was collaboratively designed and developed through interactive sessions with ChatGPT, combining human experience and AI-driven support to solve real-world development challenges.

.EXAMPLE
    .\New-DailyReport.ps1 -RepoPath "C:\Repos\ProjectX" -LeaderEmail "lead@example.com"
#>

param (
    [string]$RepoPath = (Get-Location),
    [Parameter(Mandatory = $true)][string]$LeaderEmail
)

#Requires -Version 7.0

$settings = [PSCustomObject]@{
    Smtp = [PSCustomObject]@{
        Server   = "<smtp server address>"
        Port     = 587  # e.g., 587
        Username = "<smtp username>"
        Password = "<smtp password>"
        From     = "<from email address>"
    }
    GitHub = [PSCustomObject]@{
        PAT = "https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens"
    }
    TeamMembers = @(
        [PSCustomObject]@{ Email = "<developer1@example.com>"; GitHubId = "<github_username1>" }
        [PSCustomObject]@{ Email = "<developer2@example.com>"; GitHubId = "<github_username2>" }
        [PSCustomObject]@{ Email = "<developer3@example.com>"; GitHubId = "<github_username3>" }
    )
}

$global:CachedPRs = $null

function Get-PullRequests {
    if ($global:CachedPRs) { return $global:CachedPRs }

    $repo = Get-Repo -RepoPath $RepoPath

    $headers = @{ Authorization = "token $($settings.GitHub.PAT)" }
    $url = "https://api.github.com/repos/$repo/pulls?state=all&per_page=100"

    $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
    $global:CachedPRs = $response | Where-Object { $_.state -eq 'open' }
    return $global:CachedPRs
}

function Get-Repo {
    param (
        [string]$RepoPath
    )

    if (-not (Test-Path $RepoPath)) {
        Write-Error "Repository path '$RepoPath' does not exist."
        return $null
    }

    $repo = (git -C $RepoPath remote get-url origin) -replace '.*[/:](.+?)/(.+?)(\.git)?$', '$1/$2'

    return $repo
}

function Get-Commits {
    param (
        [string]$Author
    )

    git -C $RepoPath log --remotes --since="24 hours ago" --author="$Author" --pretty=tformat:"%H" | Measure-Object | Select-Object -ExpandProperty Count
}

function Get-AdjustedImpact {
    param (
        [string]$Author,
        [int]$MaxLinesThreshold = 500
    )

    $commits = git -C $RepoPath log --remotes --since="24 hours ago" --author="$Author" --pretty=format:"%H"
    $added = 0; $deleted = 0

    foreach ($commit in $commits) {
        $statLines = git -C $RepoPath show --shortstat --oneline $commit
        $shortStat = $statLines | Where-Object { $_ -match "files changed" }
        $commitAdded = 0; $commitDeleted = 0

        if ($shortStat -match "(\d+) insertions.*?(\d+) deletions") {
            $commitAdded = [int]$matches[1]
            $commitDeleted = [int]$matches[2]
        }
        elseif ($shortStat -match "(\d+) insertions") {
            $commitAdded = [int]$matches[1]
        }
        elseif ($shortStat -match "(\d+) deletions") {
            $commitDeleted = [int]$matches[1]
        }
        else {
            Write-Debug "No insert/delete stats found for commit $commit"
        }

        if (($commitAdded + $commitDeleted) -le $MaxLinesThreshold) {
            $added += $commitAdded
            $deleted += $commitDeleted
        }
    }

    return @{ Added = $added; Deleted = $deleted }
}

function Get-PRsOpened {
    param ([string]$Author)
    $prs = Get-PullRequests | Where-Object { $_.user.login -eq $Author }
    return ($prs | Measure-Object).Count
}

function Get-UnreviewedAssignedPRs {
    param ([string]$Author)

    $headers = @{ Authorization = "token $($settings.GitHub.PAT)" }
    $repo = Get-Repo -RepoPath $RepoPath

    $prs = Get-PullRequests | Where-Object {
        ($_.assignee.login -eq $Author -or $_.requested_reviewers.login -contains $Author) -and (-not $_.comments -or $_.comments -eq 0)
    }

    $unreviewedCount = 0

    foreach ($pr in $prs) {
        $reviewUrl = "https://api.github.com/repos/$repo/pulls/$($pr.number)/reviews"
        $reviews = Invoke-RestMethod -Uri $reviewUrl -Headers $headers -Method Get

        $hasReviewed = $reviews | Where-Object { $_.user.login -eq $Author }
        if (-not $hasReviewed) {
            $unreviewedCount++
        }
    }

    return $unreviewedCount
}

function Get-LastCommitDate {
    param ([string]$Author)

    git -C $RepoPath log --remotes --author="$Author" -1 --pretty=format:"%ci"
}

function Get-EmailBody {
    param (
        $report,
        [string]$Repo
    )

    $emailBody = @"
<html>
<head>
<style>
    body {
        font-family: Arial, sans-serif;
        background-color: #ffffff;
        margin: 20px;
        color: #333;
    }
    h2 {
        color: #1E3A5F;
        margin-bottom: 10px;
    }
    .header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        border-bottom: 2px solid #1E3A5F;
        margin-bottom: 20px;
        padding-bottom: 10px;
    }
    .logo {
        height: 60px;
        margin-left: 20px;
    }
    table {
        border-collapse: collapse;
        width: 100%;
        font-size: 14px;
    }
    th {
        background-color: #1E3A5F;
        color: #ffffff;
        padding: 8px 12px;
        border: 1px solid #ccc;
        text-align: left;
    }
    td {
        border: 1px solid #ddd;
        padding: 6px 10px;
    }
    tr:nth-child(even) {
        background-color: #f2f6fa;
    }
</style>
</head>
<body>
<div class="header">
    <div>
        <h2>Daily Team Summary - $(Get-Date -Format "dddd, MMMM dd, yyyy")</h2>
        <p>Repository: <strong>$Repo</strong></p>
    </div>
    <a href="https://github.com/gmcnickle/measuring-productivity#">
        <img class="logo" src="https://raw.githubusercontent.com/gmcnickle/gittools/main/assets/gitTools-dk.png" alt="Logo">
    </a>
</div>
<table>
    <tr>
        <th>Developer</th>
        <th>Commits</th>
        <th>Impact (+/-)</th>
        <th>PRs Opened</th>
        <th>Unreviewed PRs</th>
        <th>Last Commit</th>
    </tr>
$($report -join "`n")
</table>
</body>
</html>
"@

    return $emailBody
}

$report = @()
$authors = $settings.TeamMembers.Email
$repo = Get-Repo -RepoPath $RepoPath

foreach ($author in $authors) {
    $githubId = ($settings.TeamMembers | Where-Object { $_.Email -eq $author }).GitHubId
    $commits = Get-Commits -Author $author
    $impact = Get-AdjustedImpact -Author $author
    $prsOpened = Get-PRsOpened -Author $githubId
    $prsPending = Get-UnreviewedAssignedPRs -Author $githubId
    $lastCommit = Get-LastCommitDate -Author $author

    $report += "<tr><td>$author</td><td>$commits</td><td>+$($impact.Added)/-$($impact.Deleted)</td><td>$prsOpened</td><td>$prsPending</td><td>$lastCommit</td></tr>"
}

$emailBody = Get-EmailBody -report $report -Repo $repo

Send-MailMessage -To $LeaderEmail -From $settings.Smtp.From -Subject "Daily Developer Activity Report" -BodyAsHtml -Body $emailBody -SmtpServer $settings.Smtp.Server -Port $settings.Smtp.Port -UseSsl -Credential (New-Object PSCredential($settings.Smtp.Username, (ConvertTo-SecureString $settings.Smtp.Password -AsPlainText -Force)))
