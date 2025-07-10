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

To get started, [read the full article →](https://github.com/gmcnickle/measuring-productivity/blob/main/MeasuringWhatWeCantSee.md)  
It explains the motivation, metrics, and philosophy behind the script.

### Clone the repo and update the script settings

Edit the `$settings` object in the script to include:

- Your SMTP server details  
- Your GitHub Personal Access Token (PAT)  
- A mapping of team member email addresses to GitHub usernames

> 📝 **NOTE**  Git-related data is usually most reliable when queried using an email address. While the --author flag accepts either a name or email, email matching tends to produce better results.
>
>GitHub, on the other hand, works best when identifying users by their GitHub username, not email or full name.
>
>For this reason, the TeamMembers mapping is structured such as to store both the git email address, and the githubId

> 🛠️ **Pro Tip** 
> The $settings object might feel a bit verbose with all its nested PSCustomObject declarations, but that structure is intentional. It ensures the object can be easily exported to or imported from a JSON file.
>
> We've hard-coded it directly into the script to minimize external dependencies and make the script usable out of the box—but you’re free to load it from a file in your own workflow.


### Run the script manually or via scheduled task

```bash
pwsh ./New-DailyTeamSummary.ps1 -RepoPath "/path/to/your/repo" -LeaderEmail "you@example.com"
```

- `RepoPath` is optional and defaults to the current working directory  
- `LeaderEmail` is required and specifies where to send the daily summary

### What You’ll Receive

The script sends a styled HTML email to the designated team lead with:
- Commit counts  
- Adjusted impact (lines added/removed)  
- PRs opened  
- PRs assigned but not yet reviewed or commented on  
- Last commit timestamp per developer

<br>

<img src="https://raw.githubusercontent.com/gmcnickle/measuring-productivity/main/assets/screenshot.png">

### Closing Thoughts

I hope this article gets you thinking about ways you might measure developer productitivy by leveraging the rich data at our fingertips, and I hope that it starts you on a journey of discovering what questions your team needs answers to.

The provided script was meant to be illustrative of the concept, and not a framework itself.  Build on it, consider adding caching, robust error handling and logging and support for reading configuration from a file and I think you'll find you have everything you need to build out your own automated analytics platform.

Above all, talk with your team and share your work!

Best of luck. Reach out if you have questions.

[**Gary**](https://github.com/gmcnickle)  

[![GitHub](https://img.shields.io/badge/GitHub-%40gmcnickle-181717?logo=github&style=flat-square)](https://github.com/gmcnickle)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-blue?logo=linkedin&style=flat-square)](https://www.linkedin.com/in/gmcnickle)
![Made with PowerShell](https://img.shields.io/badge/Made%20with-PowerShell-5391FE?logo=powershell&logoColor=white&style=flat-square)
