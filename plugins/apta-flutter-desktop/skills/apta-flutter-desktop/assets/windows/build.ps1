# Windows release build: Flutter release binary + Inno Setup installer.
# Copy to the project root next to installer.iss and set the values in the Configuration block.

param(
    [switch]$Clean,
    [string]$Version = "",
    [string]$OutputRoot = "",
    [switch]$Help
)

# Configuration
$ProjectRoot = $PSScriptRoot
$AppSlug = "<app-slug>"                      # must equal MyAppSlug in installer.iss
$IssFile = "installer.iss"
$InnoCompilerPath = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
$BuildsRoot = if ([string]::IsNullOrWhiteSpace($OutputRoot)) { Join-Path $PSScriptRoot "build\installer_output" } else { $OutputRoot }
$OutputBaseDir = ""
$ResolvedVersion = ""

# Output helpers (named to avoid shadowing the built-in Write-Error / Write-Warning cmdlets)
function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Fail {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Show-Usage {
    Write-Host "Usage: .\build.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "OPTIONS:"
    Write-Host "  -Clean               Clean the Flutter project before building"
    Write-Host "  -Version x.y.z       Override the version (defaults to the pubspec.yaml version)"
    Write-Host "  -OutputRoot <path>   Folder that receives v<version>\ (defaults to build\installer_output)"
    Write-Host "  -Help                Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\build.ps1                    # build the installer"
    Write-Host "  .\build.ps1 -Clean             # clean, then build"
    Write-Host "  .\build.ps1 -Version 0.2.0     # build as version 0.2.0"
}

function Test-Prerequisites {
    Write-Status "Checking prerequisites..."

    try {
        $null = & fvm --version 2>$null
    }
    catch {
        Write-Fail "FVM is not installed or not in PATH"
        exit 1
    }

    if (-not (Test-Path $InnoCompilerPath)) {
        Write-Fail "Inno Setup compiler not found at: $InnoCompilerPath"
        Write-Fail "Install Inno Setup 6 or update `$InnoCompilerPath in this script"
        exit 1
    }

    if (-not (Test-Path $IssFile)) {
        Write-Fail "Inno Setup script $IssFile not found"
        exit 1
    }

    if (-not (Test-Path ".env")) {
        Write-Fail ".env file not found in the project root"
        exit 1
    }

    Write-Success "All prerequisites checked."
}

function Resolve-BuildContext {
    Write-Status "Resolving version and updating installer configuration..."

    if ([string]::IsNullOrWhiteSpace($Version)) {
        if (-not (Test-Path "pubspec.yaml")) {
            Write-Fail "pubspec.yaml not found and -Version not provided"
            exit 1
        }
        $pubspec = Get-Content "pubspec.yaml" -Raw
        $m = [regex]::Match($pubspec, "(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)")
        if (-not $m.Success) {
            Write-Fail "Could not determine the version from pubspec.yaml"
            exit 1
        }
        $script:ResolvedVersion = $m.Groups[1].Value
    } else {
        $script:ResolvedVersion = $Version
        # Write the version into pubspec.yaml; cider is optional, the regex is the fallback
        Write-Status "Updating version in pubspec.yaml to $Version using cider..."
        & fvm dart pub global run cider version $Version
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "cider update failed, updating pubspec.yaml directly..."
            $pubspecContent = Get-Content "pubspec.yaml" -Raw
            $updatedPubspec = [regex]::Replace($pubspecContent, '(?m)^version:\s*.*', "version: $Version")
            Set-Content "pubspec.yaml" $updatedPubspec -NoNewline
        }
        Write-Status "Updated version in pubspec.yaml to $script:ResolvedVersion"
    }

    $script:OutputBaseDir = Join-Path $BuildsRoot ("v" + $script:ResolvedVersion)

    Write-Status "Version: $script:ResolvedVersion"
    Write-Status "Output directory: $script:OutputBaseDir"

    # Keep the installer's version in step with pubspec.yaml
    $issContent = Get-Content $IssFile -Raw
    $updatedIss = [regex]::Replace($issContent, '(?m)^#define MyAppVersion ".*?"', "#define MyAppVersion `"$script:ResolvedVersion`"")
    Set-Content $IssFile $updatedIss -NoNewline
    Write-Status "Updated version in $IssFile to $script:ResolvedVersion"
}

function New-OutputDirectories {
    Write-Status "Creating output directory..."
    if (-not (Test-Path $script:OutputBaseDir)) {
        New-Item -ItemType Directory -Path $script:OutputBaseDir -Force | Out-Null
    }
    Write-Success "Output directory ready."
}

function Invoke-CleanProject {
    Write-Status "Cleaning Flutter project..."
    & fvm flutter clean
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "Failed to clean the project"
        exit 1
    }
    Write-Success "Project cleaned."
}

function Invoke-BuildFlutter {
    Write-Status "Building Flutter Windows release binary..."
    & fvm flutter build windows --release
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "Flutter build failed"
        exit 1
    }
    Write-Success "Flutter build completed."
}

function Invoke-CompileInstaller {
    Write-Status "Compiling the Inno Setup installer..."
    $outputName = "$AppSlug-v$script:ResolvedVersion"

    $maxAttempts = 3
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        & $InnoCompilerPath $IssFile /O"$script:OutputBaseDir" /F"$outputName"
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Installer compiled successfully!"
            return $true
        }

        if ($attempt -lt $maxAttempts) {
            Write-Warn "Inno Setup attempt $attempt failed (possibly a transient file lock by antivirus). Retrying in 2 seconds..."
            Start-Sleep -Seconds 2
        }
    }

    Write-Fail "Failed to compile the installer after $maxAttempts attempts."
    return $false
}

# Main
if ($Help) {
    Show-Usage
    exit 0
}

Set-Location $ProjectRoot
Test-Prerequisites
Resolve-BuildContext
New-OutputDirectories

if ($Clean) {
    Invoke-CleanProject
}

Invoke-BuildFlutter

if (Invoke-CompileInstaller) {
    Write-Host ""
    Write-Success "Build process completed successfully!"
    Write-Status "Installer file: $(Join-Path $script:OutputBaseDir "$AppSlug-v$script:ResolvedVersion.exe")"
} else {
    Write-Fail "Build process failed."
    exit 1
}
