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

    Primary Author: Gary McNickle (gmcnickle@outlook.com)
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
    Smtp = @{
        Server   = "smtp-relay.brevo.com"
        Port     = 587
        Username = "7f5cbf001@smtp-brevo.com"
        Password = "8TNCEHw1MQbLWIjx"
        From     = "gmcnickle@outlook.com"
    }
    GitHub = @{
        PAT = "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"
    }
    TeamMembers = @{
        "robert.roaten@jci.com" = "jroater_jcplc"
        "riley.deal@jci.com" = "jdealr_jcplc"
        "christopher.bucker@jci.com" = "jbuckec_jcplc"
        "michael.kistler@jci.com" = "jkistlm_jcplc"
        "anastacio.s.meza@jci.com" = "jmezaan_jcplc"
        "vinod.kumar.reddem.reddy-ext@jci.com" = "jreddev_jcplc"
        "jtailor@jci.com" = "jtailor_jcplc"
        "ciaran.mccormick@jci.com" = "jmccorci_jcplc"
        "brianmark.cunningham@jci.com" = "jcunnib1_jcplc"
        "adam.henderson@jci.com" = "jhende7_jcplc"
        "sairam.adunuri@jci.com" = "jadunus_jcplc"
    }
}

$global:CachedPRs = $null

function Get-PullRequests {
    if ($global:CachedPRs) { return $global:CachedPRs }

    $repo = (git -C $RepoPath remote get-url origin) -replace '.*[/:](.+?)/(.+?)(\.git)?$', '$1/$2'
    $headers = @{ Authorization = "token $($settings.GitHub.PAT)" }
    $url = "https://api.github.com/repos/$repo/pulls?state=all&per_page=100"

    $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
    $global:CachedPRs = $response | Where-Object { $_.state -eq 'open' }
    return $global:CachedPRs
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

    $commits = git -C  $RepoPath log --remotes --since="24 hours ago" --author="$Author" --pretty=format:"%H"
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
    $repo = (git -C $RepoPath remote get-url origin) -replace '.*[/:](.+?)/(.+?)(\.git)?$', '$1/$2'
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
    param ($report)

    $emailBody = @"
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; }
        h2 { color: #2F4F4F; }
        .header {
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .logo {
            height: 80px;
            margin-left: 20px;
        }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ccc; padding: 6px 10px; text-align: left; }
        th { background-color: #f4f4f4; }
        tr:nth-child(even) { background-color: #f9f9f9; }
    </style>
</head>
<body>
<div class="header">
    <h2>Daily Team Summary - $(Get-Date -Format "dddd, MMMM dd, yyyy")</h2>
    <img class="logo" src="https://raw.githubusercontent.com/gmcnickle/gittools/main/assets/gitTools-dk.png" alt="Logo">
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
$authors = $settings.TeamMembers.Keys

foreach ($author in $authors) {
    $commits = Get-Commits -Author $author
    $impact = Get-AdjustedImpact -Author $author
    $prsOpened = Get-PRsOpened -Author $settings.TeamMembers[$author]
    $prsPending = Get-UnreviewedAssignedPRs -Author $settings.TeamMembers[$author]
    $lastCommit = Get-LastCommitDate -Author $author

    $report += "<tr><td>$author</td><td>$commits</td><td>+$($impact.Added)/-$($impact.Deleted)</td><td>$prsOpened</td><td>$prsPending</td><td>$lastCommit</td></tr>"
}

$emailBody = Get-EmailBody -report $report

Send-MailMessage -To $LeaderEmail -From $settings.Smtp.From -Subject "Daily Developer Activity Report" -BodyAsHtml -Body $emailBody -SmtpServer $settings.Smtp.Server -Port $settings.Smtp.Port -UseSsl -Credential (New-Object PSCredential($settings.Smtp.Username, (ConvertTo-SecureString $settings.Smtp.Password -AsPlainText -Force)))
