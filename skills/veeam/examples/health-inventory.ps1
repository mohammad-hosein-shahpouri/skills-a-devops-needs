# Veeam health inventory — jobs, repositories, restore points, last runs.
# Run on the backup server (or a host with the Veeam PowerShell module loaded).
# Output: JSON payload suitable for NOC monitoring ingestion.
# No credentials in the file; the module uses the existing authenticated session.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Connect if not already in a session (service account, least privilege).
# Connect-VBRServer -Server 'backup.example.internal' -Credential (Get-Secret veeam-api)

$result = [ordered]@{}
$now = Get-Date
$result.generatedAt = $now.ToString('o')

# ─── 1. Job status and staleness ────────────────────────────────────────────
$jobs = @()
foreach ($job in Get-VBRJob) {
    if ($job.IsScheduleEnabled -eq $false) { continue }
    $session = $job.FindLastSession()
    $lastRun = if ($session) { $session.CreationTime } else { $null }
    $jobs += [ordered]@{
        name       = $job.Name
        lastResult = "$($job.GetLastResult())"
        lastRun    = if ($lastRun) { $lastRun.ToString('o') } else { $null }
        ageHours   = if ($lastRun) { [math]::Round(($now - $lastRun).TotalHours, 1) } else { $null }
        state      = if ($session) { "$($session.State)" } else { 'NeverRun' }
    }
}
$result.jobs = $jobs

# ─── 2. Repository capacity ─────────────────────────────────────────────────
$repos = @()
foreach ($repo in Get-VBRBackupRepository) {
    if ($repo.Type -eq 'SanSnapshotOnly') { continue }
    $repos += [ordered]@{
        name     = $repo.Name
        usedGB   = [math]::Round($repo.GetContainerSizeInBytes().Used / 1GB, 1)
        freeGB   = [math]::Round($repo.GetContainerSizeInBytes().Free / 1GB, 1)
    }
}
$result.repositories = $repos

# ─── 3. Restore-point count per backup (retention drift) ───────────────────
$points = @()
foreach ($backup in Get-VBRBackup) {
    $points += [ordered]@{
        backup    = $backup.Name
        points    = ($backup | Get-VBRRestorePoint | Measure-Object).Count
    }
}
$result.restorePoints = $points

# ─── 4. Summary for alert rules (monitor reads this section) ────────────────
$failed = @($jobs | Where-Object { $_.lastResult -eq 'Failed' })
$stale  = @($jobs | Where-Object { $_.ageHours -ne $null -and $_.ageHours -gt 30 })
$full   = @($repos | Where-Object { $_.freeGB -lt 200 })   # GB floor per repo

$result.alerts = [ordered]@{
    failedJobs   = $failed.name
    staleJobs    = $stale.name
    lowSpaceRepos = $full.name
}

$result | ConvertTo-Json -Depth 5

# Notes:
# * Schedule every 10-15 min via scheduled task; POST the JSON to the NOC
#   collector (Zabbix trapper / HTTP API).
# * Alert rules live in the monitor: failed/stale jobs, repo floors, point
#   counts below retention policy.
# * Service account: Veeam PowerShell needs appropriate RBAC role; do not use
#   the built-in administrator interactively in scripts.
