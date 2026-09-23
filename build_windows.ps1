$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
if ($env:OS -ne 'Windows_NT') { throw 'Run this script on Windows.' }
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'Install Flutter 3.29.0 and add flutter/bin to PATH. See README_WINDOWS.md.'
}
function Invoke-Flutter {
  & flutter @args
  if ($LASTEXITCODE -ne 0) { throw "Flutter failed: $args" }
}
Invoke-Flutter config --enable-windows-desktop
Invoke-Flutter pub get --enforce-lockfile
Invoke-Flutter analyze --no-fatal-infos --no-fatal-warnings
Invoke-Flutter test test/guided
Invoke-Flutter build windows --release
$release = Join-Path $PSScriptRoot 'build\windows\x64\runner\Release'
if (-not (Test-Path "$release\Ls_BLE_Guided.exe")) { throw 'Executable was not produced.' }
New-Item -ItemType Directory -Force 'dist' | Out-Null
Compress-Archive -Path "$release\*" -DestinationPath 'dist\Ls_BLE_Guided_Windows_x64.zip' -Force
Write-Host 'Ready: dist\Ls_BLE_Guided_Windows_x64.zip'
Write-Host 'Extract the entire ZIP before opening Ls_BLE_Guided.exe. Keep DLLs and data beside it.'
