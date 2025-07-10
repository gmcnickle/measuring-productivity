# Measuring What We Can’t See
**A Data-Driven Look at the Invisible Work of Developers**

<img src="https://raw.githubusercontent.com/gmcnickle/gittools/main/assets/gitTools-dk-small.png" alt="logo" style="float: right;">

Modern development work is full of invisible effort—decisions made, bugs avoided, knowledge shared—but most of that doesn’t show up in dashboards or status updates.  
This article explores how we can responsibly measure what traditional metrics miss, using version control data as a starting point.

Included in this repo is a lightweight PowerShell script that generates a daily activity summary for your development team. It pulls insights from Git and GitHub to highlight:

- ✅ Commit frequency and impact  
- ✅ Pull request activity  
- ✅ Unreviewed or uncommented PRs  
- ✅ Last commit timestamps by team member

It’s designed to be simple, cross-platform, and transparent—something you can start using immediately and extend as your team’s needs grow.

## 🚀 Usage

### 1. Clone the repo and update the script settings

Edit the `$settings` object in the script to include:

- Your SMTP server details  
- Your GitHub Personal Access Token (PAT)  
- A mapping of team member email addresses to GitHub usernames

### 2. Run the script manually or via scheduled task

```bash
pwsh ./New-DailyTeamSummary.ps1 -RepoPath "/path/to/your/repo" -LeaderEmail "you@example.com"
```

- `RepoPath` is optional and defaults to the current working directory  
- `LeaderEmail` is required and specifies where to send the daily summary

### 3. What You’ll Receive

The script sends a styled HTML email to the designated team lead with:
- Commit counts  
- Adjusted impact (lines added/removed)  
- PRs opened  
- PRs assigned but not yet reviewed or commented on  
- Last commit timestamp per developer

<br>

<img src="https://raw.githubusercontent.com/gmcnickle/measuring-productivity/main/assets/screenshot.png">

