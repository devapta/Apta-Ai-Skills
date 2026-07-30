<#
.SYNOPSIS
  Install the portable Agent Skills in ./skills into the AI agent(s) on this machine.

.DESCRIPTION
  Skills follow the open Agent Skills standard (https://agentskills.io): the SKILL.md
  content is identical for every tool; only the destination directory differs. This
  script places each skills/<name>/ folder into each detected agent's skill directory.
  Verified paths: claude-code. Others (cursor, gemini-cli, codex, copilot, windsurf)
  are best-effort — edit the registry tables below or use -Target.

.PARAMETER Scope
  user (default) or project.

.PARAMETER Copy
  Copy instead of link (frozen snapshot).

.PARAMETER Uninstall
  Remove skills this script installed (use -Force for copies).

.PARAMETER Force
  Overwrite/remove existing entries.

.PARAMETER Target
  Install into an arbitrary directory (skips agent detection).

.PARAMETER Agent
  Restrict to one agent from the registry (e.g. cursor).

.EXAMPLE
  .\install.ps1
  .\install.ps1 -Scope project
  .\install.ps1 -Copy -Target D:\my-skills
#>
[CmdletBinding()]
param(
  [ValidateSet('user','project')][string]$Scope = 'user',
  [switch]$Copy,
  [switch]$Uninstall,
  [switch]$Force,
  [string]$Target = '',
  [string]$Agent = ''
)

$ErrorActionPreference = 'Stop'
$RepoRoot  = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillsSrc = Join-Path $RepoRoot 'skills'
$HomeDir   = $env:USERPROFILE
$Project   = (Get-Location).Path

if (-not (Test-Path $SkillsSrc)) { throw "No skills/ directory found at $SkillsSrc" }

# --- agent registry ----------------------------------------------------------
$Agents = 'claude-code','cursor','gemini-cli','codex','copilot','windsurf'

function Get-UserDir($a) {
  switch ($a) {
    'claude-code' { Join-Path $HomeDir '.claude\skills' }
    'cursor'      { Join-Path $HomeDir '.cursor\skills' }
    'gemini-cli'  { Join-Path $HomeDir '.gemini\skills' }
    'codex'       { Join-Path $HomeDir '.codex\skills' }
    'copilot'     { Join-Path $HomeDir '.copilot\skills' }
    'windsurf'    { Join-Path $HomeDir '.codeium\windsurf\skills' }
  }
}
function Get-ProjectDir($a) {
  switch ($a) {
    'claude-code' { Join-Path $Project '.claude\skills' }
    'cursor'      { Join-Path $Project '.cursor\skills' }
    'gemini-cli'  { Join-Path $Project '.gemini\skills' }
    'codex'       { Join-Path $Project '.codex\skills' }
    'copilot'     { Join-Path $Project '.github\copilot\skills' }
    'windsurf'    { Join-Path $Project '.codeium\windsurf\skills' }
  }
}
function Get-Detect($a) {
  switch ($a) {
    'claude-code' { Join-Path $HomeDir '.claude' }
    'cursor'      { Join-Path $HomeDir '.cursor' }
    'gemini-cli'  { Join-Path $HomeDir '.gemini' }
    'codex'       { Join-Path $HomeDir '.codex' }
    'copilot'     { '' }
    'windsurf'    { Join-Path $HomeDir '.codeium' }
  }
}
function Get-DestDir($a) {
  if ($Scope -eq 'user') { Get-UserDir $a } else { Get-ProjectDir $a }
}

# --- collect skills ----------------------------------------------------------
$Skills = Get-ChildItem -Path $SkillsSrc -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'SKILL.md') }
if (-not $Skills) { throw "No skills found in $SkillsSrc (each needs a SKILL.md)" }

# --- resolve destinations ----------------------------------------------------
$Labels = [System.Collections.Generic.List[string]]::new()
$Dirs   = [System.Collections.Generic.List[string]]::new()
if ($Target) { $Labels.Add('target'); $Dirs.Add($Target) }
else {
  foreach ($a in $Agents) {
    if ($Agent -and $a -ne $Agent) { continue }
    if ($Uninstall) { $Labels.Add($a); $Dirs.Add((Get-DestDir $a)) }
    else {
      $marker = Get-Detect $a
      if (-not $marker -or (Test-Path $marker)) { $Labels.Add($a); $Dirs.Add((Get-DestDir $a)) }
    }
  }
  if ($Labels.Count -eq 0) { throw "No agents from the registry appear to be installed. Use -Target." }
}

$mode = if ($Copy) { 'copy' } else { 'link' }
Write-Host "== apta-skills: $(if($Uninstall){'uninstall'}else{'install'}) $($Skills.Count) skill(s) -> $($Labels.Count) destination(s) [$mode, scope=$Scope] =="

for ($i = 0; $i -lt $Labels.Count; $i++) {
  $label = $Labels[$i]; $destDir = $Dirs[$i]
  Write-Host "[$label] -> $destDir"
  foreach ($s in $Skills) {
    $src = $s.FullName; $dest = Join-Path $destDir $s.Name
    if ($Uninstall) {
      if (Test-Path $dest) {
        if ($Force) { Remove-Item -Recurse -Force $dest; Write-Host "  - $label`:$($s.Name) (removed)" }
        elseif ((Get-Item $dest -Force).LinkType) { Remove-Item -Force $dest; Write-Host "  - $label`:$($s.Name) (removed link)" }
        else { Write-Host "  ! $label`:$($s.Name) is a copy (-Force to remove)" }
      } else { Write-Host "  . $label`:$($s.Name) (not present)" }
    }
    else {
      $null = New-Item -ItemType Directory -Force -Path $destDir
      if (Test-Path $dest) {
        $item = Get-Item $dest -Force
        if (-not $Copy -and $item.LinkType -and $item.Target -and ($item.Target -join ';') -eq $src) {
          Write-Host "  = $label`:$($s.Name) (already linked)"; continue
        }
        if ($Force) { Remove-Item -Recurse -Force $dest } else { Write-Host "  ! $label`:$($s.Name) exists (-Force to overwrite)"; continue }
      }
      if (-not $Copy) {
        try { $null = New-Item -ItemType SymbolicLink -Path $dest -Target $src; Write-Host "  + $label`:$($s.Name) (linked)" }
        catch { Copy-Item -Recurse -Force $src $dest; Write-Host "  + $label`:$($s.Name) (copied - symlink needs admin/dev mode)" }
      } else { Copy-Item -Recurse -Force $src $dest; Write-Host "  + $label`:$($s.Name) (copied)" }
    }
  }
}
