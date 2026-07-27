param(
    [string]$ExtensionDir = "$env:USERPROFILE\.vscode\extensions",
    [string]$LogPath = "$PSScriptRoot\extension_watcher.log"
)
$ExtensionDir = Resolve-Path -Path $ExtensionDir
$LogPath = Resolve-Path -Path $LogPath -ErrorAction SilentlyContinue
if (-not $LogPath) { $LogPath = Join-Path $PSScriptRoot 'extension_watcher.log' }
$LogPath = [System.IO.Path]::GetFullPath($LogPath)
"Watching: $ExtensionDir`nLogging: $LogPath" | Out-File -FilePath $LogPath -Encoding utf8
$fsw = New-Object System.IO.FileSystemWatcher $ExtensionDir -Property @{ IncludeSubdirectories = $true; NotifyFilter = [IO.NotifyFilters]'FileName, LastWrite, Size, DirectoryName' }
$action = {
    $time = (Get-Date).ToString('s')
    $args = $Event.SourceEventArgs
    $changeType = $args.ChangeType
    $fullPath = $args.FullPath
    $line = "$time`t$changeType`t$fullPath"
    Add-Content -Path $using:LogPath -Value $line
}
Register-ObjectEvent $fsw 'Created' -Action $action | Out-Null
Register-ObjectEvent $fsw 'Changed' -Action $action | Out-Null
Register-ObjectEvent $fsw 'Deleted' -Action $action | Out-Null
Register-ObjectEvent $fsw 'Renamed' -Action $action | Out-Null
Write-Host "Started watcher for $ExtensionDir. Logging to $LogPath"
while ($true) { Start-Sleep -Seconds 60 }
