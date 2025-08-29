#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Configures Claude Code settings to use the todo hook tracker
.DESCRIPTION
    This script configures the Claude Code settings.json file to add the todo hook.
    It will check for existing settings and merge them properly using Newtonsoft.Json.
    By default runs in Dry Run mode (no changes made) and Interactive mode (asks for confirmation).
.PARAMETER Live
    Actually make changes to the settings file (disable Dry Run mode)
.PARAMETER Auto
    Skip interactive prompts and proceed automatically (requires -Live for actual changes)
.PARAMETER UseLocalSettings
    Use local .claude/settings.json instead of global settings
.PARAMETER Help
    Show help information
.EXAMPLE
    .\configure_claude_hook.ps1
    Runs in Dry Run mode with interactive prompts (default, safe mode)
.EXAMPLE
    .\configure_claude_hook.ps1 -Live
    Makes actual changes with interactive confirmation
.EXAMPLE
    .\configure_claude_hook.ps1 -Live -Auto
    Makes actual changes automatically without prompts
.EXAMPLE
    .\configure_claude_hook.ps1 -Auto
    Dry Run in automatic mode (shows what would happen)
#>

param(
    [switch]$Live,
    [switch]$Auto,
    [switch]$UseLocalSettings,
    [switch]$Help
)

# Show help if requested
if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path -Detailed
    exit 0
}

# Check if Newtonsoft.Json is available
$newtonsoftModule = Get-Module -ListAvailable -Name Newtonsoft.Json
if (-not $newtonsoftModule) {
    Write-Host "Newtonsoft.Json not found. Installing..." -ForegroundColor Yellow
    try {
        Install-Module -Name Newtonsoft.Json -Force -Scope CurrentUser -AllowClobber
        Import-Module Newtonsoft.Json
        Write-Host "Newtonsoft.Json installed successfully." -ForegroundColor Green
    } catch {
        Write-Host "Failed to install Newtonsoft.Json. Trying with NuGet package..." -ForegroundColor Yellow
        
        # Alternative: Install via NuGet
        if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
            Install-PackageProvider -Name NuGet -Force -Scope CurrentUser
        }
        Install-Package -Name Newtonsoft.Json -Force -Scope CurrentUser -SkipDependencies
        
        # Load the assembly
        $newtonsoftPath = (Get-Package Newtonsoft.Json).Source
        if ($newtonsoftPath) {
            $dllPath = Join-Path (Split-Path $newtonsoftPath) "lib\netstandard2.0\Newtonsoft.Json.dll"
            if (Test-Path $dllPath) {
                Add-Type -Path $dllPath
            } else {
                Write-Host "Could not find Newtonsoft.Json.dll" -ForegroundColor Red
                exit 1
            }
        }
    }
} else {
    Import-Module Newtonsoft.Json
}

# Determine settings file location
$settingsPath = if ($UseLocalSettings) {
    $localPath = Join-Path $PWD ".claude\settings.json"
    Write-Host "Using local settings: $localPath" -ForegroundColor Cyan
    
    # Create .claude directory if it doesn't exist
    $claudeDir = Join-Path $PWD ".claude"
    if (-not (Test-Path $claudeDir)) {
        New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
        Write-Host "Created .claude directory" -ForegroundColor Green
    }
    $localPath
} else {
    $globalPath = Join-Path $env:USERPROFILE ".claude\settings.json"
    Write-Host "Using global settings: $globalPath" -ForegroundColor Cyan
    
    # Create .claude directory if it doesn't exist
    $claudeDir = Join-Path $env:USERPROFILE ".claude"
    if (-not (Test-Path $claudeDir)) {
        New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
        Write-Host "Created .claude directory" -ForegroundColor Green
    }
    $globalPath
}

# Get the hook script path
$hookScriptPath = Join-Path $PSScriptRoot "todo_hook_post_tool.ps1"
if (-not (Test-Path $hookScriptPath)) {
    Write-Host "Error: Hook script not found at $hookScriptPath" -ForegroundColor Red
    exit 1
}

# Escape path for JSON
$hookCommand = "pwsh -File `"$($hookScriptPath.Replace('\', '\\'))`""

# Load existing settings or create new
$settings = @{}
if (Test-Path $settingsPath) {
    Write-Host "`nExisting settings.json found. Current content:" -ForegroundColor Yellow
    $existingContent = Get-Content $settingsPath -Raw
    Write-Host $existingContent -ForegroundColor DarkGray
    
    try {
        $settings = [Newtonsoft.Json.JsonConvert]::DeserializeObject($existingContent, [System.Collections.Hashtable])
        if ($null -eq $settings) {
            $settings = @{}
        }
    } catch {
        Write-Host "Warning: Could not parse existing settings. Creating new settings file." -ForegroundColor Yellow
        $settings = @{}
    }
} else {
    Write-Host "`nNo existing settings.json found. Creating new file." -ForegroundColor Yellow
}

# Check if hook already exists
$existingHook = $null
if ($settings.ContainsKey("hooks") -and $settings["hooks"].ContainsKey("post_tool_use")) {
    $existingHook = $settings["hooks"]["post_tool_use"]
    Write-Host "`nExisting post_tool_use hook found:" -ForegroundColor Yellow
    Write-Host "  $($existingHook.ToString())" -ForegroundColor DarkGray
}

# Display mode information
Write-Host "`n==================================================================" -ForegroundColor Cyan
Write-Host "                    CLAUDE CODE HOOK CONFIGURATION" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# Show current mode
if (-not $Live) {
    Write-Host "`n[DRY RUN MODE] No changes will be made" -ForegroundColor Yellow -BackgroundColor DarkGray
} else {
    Write-Host "`n[LIVE MODE] Changes will be applied" -ForegroundColor White -BackgroundColor DarkRed
}

if ($Auto) {
    Write-Host "[AUTOMATIC MODE] Running without prompts" -ForegroundColor Cyan
} else {
    Write-Host "[INTERACTIVE MODE] User confirmation required" -ForegroundColor Cyan
}

Write-Host "`nConfiguration Details:" -ForegroundColor White
Write-Host "  Settings File: $settingsPath" -ForegroundColor Gray
Write-Host "  Hook Type: post_tool_use" -ForegroundColor Gray
Write-Host "  Command: $hookCommand" -ForegroundColor Gray
Write-Host ""

if ($null -ne $existingHook) {
    Write-Host "WARNING: This will replace the existing hook!" -ForegroundColor Yellow
    Write-Host ""
}

# Interactive confirmation (skip if Auto mode)
if (-not $Auto) {
    $promptMessage = if ($Live) {
        "Do you want to proceed with the configuration? (Y/N)"
    } else {
        "Do you want to see what would be changed? (Y/N)"
    }
    
    $response = Read-Host $promptMessage
    if ($response -ne 'Y' -and $response -ne 'y') {
        Write-Host "Configuration cancelled." -ForegroundColor Yellow
        exit 0
    }
} else {
    Write-Host "Proceeding automatically..." -ForegroundColor Cyan
}

# Update settings (in memory)
# Clone settings to avoid modifying JObject directly
$newSettings = @{}
foreach ($key in $settings.Keys) {
    if ($key -eq "hooks") {
        $newSettings[$key] = @{
            "post_tool_use" = $hookCommand
        }
    } else {
        $newSettings[$key] = $settings[$key]
    }
}

# If hooks didn't exist, add it
if (-not $newSettings.ContainsKey("hooks")) {
    $newSettings["hooks"] = @{
        "post_tool_use" = $hookCommand
    }
}

# Convert to JSON with proper formatting
$jsonSettings = [Newtonsoft.Json.JsonConvert]::SerializeObject($newSettings, [Newtonsoft.Json.Formatting]::Indented)

# Show what would be changed
Write-Host "`n==================================================================" -ForegroundColor Cyan
if ($Live) {
    Write-Host "                    APPLYING CONFIGURATION" -ForegroundColor Green
} else {
    Write-Host "                    DRY RUN RESULTS" -ForegroundColor Yellow
}
Write-Host "==================================================================" -ForegroundColor Cyan

Write-Host "`nSettings that would be written to: $settingsPath" -ForegroundColor White
Write-Host "`nNew settings content:" -ForegroundColor Cyan
Write-Host $jsonSettings -ForegroundColor DarkGray

# Write to file only in Live mode
if ($Live) {
    try {
        Set-Content -Path $settingsPath -Value $jsonSettings -Encoding UTF8
        Write-Host "`n==================================================================" -ForegroundColor Green
        Write-Host "✓ Settings updated successfully!" -ForegroundColor Green
        Write-Host "Hook configured! The todo tracker will now work with Claude Code." -ForegroundColor Green
        Write-Host "`nRun the monitor script to see todos in real-time:" -ForegroundColor Green
        Write-Host "  pwsh -File `"$(Join-Path $PSScriptRoot 'todo_live_monitor.ps1')`"" -ForegroundColor White
        Write-Host "==================================================================" -ForegroundColor Green
    } catch {
        Write-Host "`nError writing settings file: $_" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "`n==================================================================" -ForegroundColor Yellow
    Write-Host "⚠ DRY RUN COMPLETE - No changes were made" -ForegroundColor Yellow
    Write-Host "`nTo apply these changes, run with -Live flag:" -ForegroundColor White
    Write-Host "  pwsh -File `"$($MyInvocation.MyCommand.Path)`" -Live" -ForegroundColor Cyan
    if ($Auto) {
        Write-Host "  pwsh -File `"$($MyInvocation.MyCommand.Path)`" -Live -Auto" -ForegroundColor Cyan
    }
    Write-Host "==================================================================" -ForegroundColor Yellow
}