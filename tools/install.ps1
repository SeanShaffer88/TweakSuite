param(
    [Parameter(Mandatory=$true)][string]$ClientPath,
    [switch]$Install
)
$ErrorActionPreference = 'Stop'
$client = (Resolve-Path -LiteralPath $ClientPath).Path
$flavor = Split-Path -Leaf $client
if ($flavor -notin @('_classic_beta_', '_forever_')) { throw 'Select a Forever beta or launch client folder.' }
$executable = Join-Path $client $(if ($flavor -eq '_classic_beta_') { 'WowB.exe' } else { 'Wow.exe' })
if (-not (Test-Path -LiteralPath $executable)) { throw 'Client executable not found.' }
$version = (Get-Item -LiteralPath $executable).VersionInfo.FileVersion
if ($version -notmatch '^1\.60\.1\.') { throw "Unverified client version: $version. Recheck the TOC and APIs before installing." }
$source = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../ForeverSuite')).Path
$destination = [IO.Path]::GetFullPath((Join-Path $client 'Interface/AddOns/ForeverSuite'))
if (-not $destination.StartsWith($client + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid destination.' }
Write-Output "Client: $flavor $version"
Write-Output "Addon destination: $destination"
if (-not $Install) { Write-Output 'Check complete. Use -Install to copy this preview.'; return }
if (Get-Process -Name Wow,WowB -ErrorAction SilentlyContinue) { throw 'Close WoW before installing.' }
if (Test-Path -LiteralPath $destination) { throw 'ForeverSuite already exists. This installer never overwrites an existing version.' }
New-Item -ItemType Directory -Path $destination | Out-Null
Get-ChildItem -LiteralPath $source | Copy-Item -Destination $destination -Recurse
foreach ($name in @('LICENSE','README.md','ROADMAP.md','FEATURE-BACKLOG.md','SOURCES.md','VALIDATION.md')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "../$name") -Destination (Join-Path $destination $name)
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../docs') -Destination $destination -Recurse
Write-Output 'Installed ForeverSuite. All features start off. Restart WoW and type /fs.'
