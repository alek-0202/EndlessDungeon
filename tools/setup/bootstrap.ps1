<#
.SYNOPSIS
Diagnoses the Endless Dungeon development environment and delegates project validation.

.DESCRIPTION
Resolves the repository relative to this script, loads the canonical project validator,
and runs Quick validation by default. Full mode delegates to the same validator with
Godot headless import enabled. The bootstrap is diagnostic and advisory: it does not
install software or change persistent environment, editor, MCP, Godot, or Git settings.

.PARAMETER Mode
Quick skips Godot headless import. Full includes it. The default is Quick.

.PARAMETER Json
Emits one JSON document instead of human-readable output.

.PARAMETER GodotTimeoutSeconds
Timeout forwarded to Full project validation. The default is 120 seconds.

.EXAMPLE
.\tools\setup\bootstrap.ps1

.EXAMPLE
.\tools\setup\bootstrap.ps1 -Mode Full -Json

.EXAMPLE
. .\tools\setup\bootstrap.ps1
$result = Invoke-EndlessDungeonBootstrap -Mode Quick
#>
[CmdletBinding()]
param(
    [ValidateSet('Quick', 'Full')]
    [string]$Mode = 'Quick',

    [switch]$Json,

    [ValidateRange(1, 3600)]
    [int]$GodotTimeoutSeconds = 120
)

Set-StrictMode -Version 2.0

function New-BootstrapFinding {
    param(
        [ValidateSet('Error', 'Warning', 'Information')]
        [string]$Severity,
        [string]$Category,
        [string]$Message,
        [string]$File
    )

    return [pscustomobject]@{
        Severity = $Severity
        Category = $Category
        File = $File
        Message = $Message
    }
}

function New-BootstrapRemediation {
    param(
        [string]$Id,
        [ValidateSet('Required', 'Optional', 'Integration')]
        [string]$Priority,
        [string]$AppliesTo,
        [string]$Summary,
        [string[]]$Instructions
    )

    return [pscustomobject]@{
        Id = $Id
        Priority = $Priority
        AppliesTo = $AppliesTo
        Summary = $Summary
        Instructions = @($Instructions)
    }
}

function ConvertTo-BootstrapCapability {
    param([object]$Capability)

    return [pscustomobject]@{
        Name = $Capability.Name
        Required = [bool]$Capability.Required
        Available = [bool]$Capability.Available
        Version = $Capability.Version
        Message = $Capability.Message
    }
}

function Get-CapabilityRemediation {
    param([object]$Capability)

    switch ($Capability.Name) {
        'RepositoryLayout' {
            return New-BootstrapRemediation -Id 'restore-repository-layout' -Priority 'Required' -AppliesTo 'RepositoryLayout' -Summary 'Restore the required repository files.' -Instructions @(
                'Run the bootstrap from a complete Endless Dungeon checkout.',
                'Confirm that project.godot and AGENTS.md exist at the repository root.'
            )
        }
        'PowerShell' {
            return New-BootstrapRemediation -Id 'provide-powershell' -Priority 'Required' -AppliesTo 'PowerShell' -Summary 'Use a compatible PowerShell host.' -Instructions @(
                'Open the repository with Windows PowerShell 5.1 or another version that has been verified for these scripts.',
                'Do not change the execution policy through this bootstrap.'
            )
        }
        'Git' {
            return New-BootstrapRemediation -Id 'provide-git' -Priority 'Required' -AppliesTo 'Git' -Summary 'Make Git available to the current shell.' -Instructions @(
                'Install Git manually from a trusted source if it is not installed.',
                'Open a new shell after installation and confirm that git --version succeeds.'
            )
        }
        'Godot' {
            return New-BootstrapRemediation -Id 'configure-godot' -Priority 'Required' -AppliesTo 'Godot' -Summary 'Make a compatible Godot 4 executable available.' -Instructions @(
                'Install Godot 4 manually from a trusted source if needed.',
                "For the current shell only, set `$env:GODOT_PATH to '<path-to-Godot-4-executable>'.",
                'For a persistent manual setup on Windows, create a User environment variable named GODOT_PATH that points to the executable.',
                'Godot CLI availability does not verify Godot MCP connectivity.'
            )
        }
        'Node.js' {
            return New-BootstrapRemediation -Id 'optional-nodejs' -Priority 'Optional' -AppliesTo 'Node.js' -Summary 'Install Node.js only when a task requires it.' -Instructions @(
                'Install a supported Node.js release manually from a trusted source.',
                'Confirm that node --version succeeds in a new shell.'
            )
        }
        'npm' {
            return New-BootstrapRemediation -Id 'optional-npm' -Priority 'Optional' -AppliesTo 'npm' -Summary 'Provide npm only for workflows that require it.' -Instructions @(
                'Use the npm installation supplied with a supported Node.js distribution.',
                'Confirm that npm --version succeeds in a new shell.'
            )
        }
        'npx' {
            return New-BootstrapRemediation -Id 'optional-npx' -Priority 'Optional' -AppliesTo 'npx' -Summary 'Provide npx only for workflows that require it.' -Instructions @(
                'Use the npx installation supplied with a supported Node.js distribution.',
                'Confirm that npx --version succeeds in a new shell.'
            )
        }
        'Python' {
            return New-BootstrapRemediation -Id 'optional-python' -Priority 'Optional' -AppliesTo 'Python' -Summary 'Install Python only for validation or tooling that requires it.' -Instructions @(
                'Install a supported Python release manually from a trusted source.',
                'Disable or bypass unusable command aliases and confirm that python --version returns a real version.',
                'Python is optional for the current deterministic repository validators.'
            )
        }
        'CodexCLI' {
            return New-BootstrapRemediation -Id 'optional-codex-cli' -Priority 'Optional' -AppliesTo 'CodexCLI' -Summary 'Configure the standalone Codex CLI only when a CLI workflow requires it.' -Instructions @(
                'Follow the official Codex CLI setup instructions outside this bootstrap.',
                'Standalone Codex CLI availability is independent from the Codex integration in VS Code.'
            )
        }
        default {
            $priority = if ($Capability.Required) { 'Required' } else { 'Optional' }
            return New-BootstrapRemediation -Id ('review-' + $Capability.Name.ToLowerInvariant()) -Priority $priority -AppliesTo $Capability.Name -Summary 'Review the unavailable capability.' -Instructions @(
                'Use the capability diagnostic message to complete the setup manually.',
                'Re-run the bootstrap after the environment is updated.'
            )
        }
    }
}

function Get-ExternalIntegrationGuidance {
    return @(
        [pscustomobject]@{
            Name = 'GodotMCP'
            Status = 'NotChecked'
            Verified = $false
            Guidance = @(
                'Configure Godot MCP separately through the supported Codex or editor integration.',
                'Verify connectivity with a relevant Godot MCP inspection call before relying on it.',
                'A working Godot CLI executable does not prove Godot MCP connectivity.'
            )
        },
        [pscustomobject]@{
            Name = 'PixelLabMCP'
            Status = 'NotChecked'
            Verified = $false
            Guidance = @(
                'Configure PixelLab MCP separately through the supported connection flow.',
                'Use the host secure connection mechanism for credentials; this bootstrap never requests, reads, stores, or prints them.',
                'Verify connectivity with a free read-only operation before approved asset generation.'
            )
        },
        [pscustomobject]@{
            Name = 'CodexVSCodeIntegration'
            Status = 'NotChecked'
            Verified = $false
            Guidance = @(
                'Configure and verify the VS Code integration separately.',
                'The environment check only detects the standalone Codex CLI and does not assess the VS Code integration.'
            )
        }
    )
}

function Invoke-EndlessDungeonBootstrap {
    [CmdletBinding()]
    param(
        [ValidateSet('Quick', 'Full')]
        [string]$Mode = 'Quick',

        [ValidateRange(1, 3600)]
        [int]$GodotTimeoutSeconds = 120
    )

    $requestedMode = $Mode
    $requestedGodotTimeoutSeconds = $GodotTimeoutSeconds
    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    $root = [IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath '..\..')).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $projectValidatorPath = Join-Path -Path $root -ChildPath 'tools\validation\Validate-Project.ps1'
    $findings = New-Object System.Collections.Generic.List[object]
    $remediation = New-Object System.Collections.Generic.List[object]
    $requiredCapabilities = @()
    $optionalCapabilities = @()
    $projectValidation = $null

    if (-not (Test-Path -LiteralPath $projectValidatorPath -PathType Leaf)) {
        [void]$findings.Add((New-BootstrapFinding -Severity 'Error' -Category 'MissingProjectValidator' -File 'tools/validation/Validate-Project.ps1' -Message 'The canonical project validation component is missing.'))
        [void]$remediation.Add((New-BootstrapRemediation -Id 'restore-project-validator' -Priority 'Required' -AppliesTo 'Validate-Project.ps1' -Summary 'Restore the canonical project validation component.' -Instructions @(
            'Restore tools/validation/Validate-Project.ps1 from the authorized repository revision.',
            'Re-run the bootstrap after the component is restored.'
        )))
    }
    else {
        try {
            $loadOutput = @(. $projectValidatorPath)
            if ($null -eq (Get-Command -Name 'Test-EndlessDungeonProject' -CommandType Function -ErrorAction SilentlyContinue)) {
                [void]$findings.Add((New-BootstrapFinding -Severity 'Error' -Category 'InvalidProjectValidator' -File 'tools/validation/Validate-Project.ps1' -Message 'The project validation component did not define Test-EndlessDungeonProject.'))
            }
            else {
                $projectValidation = Test-EndlessDungeonProject -Mode $requestedMode -GodotTimeoutSeconds $requestedGodotTimeoutSeconds
                if ($null -eq $projectValidation -or $null -eq $projectValidation.PSObject.Properties['Success'] -or $null -eq $projectValidation.PSObject.Properties['Checks']) {
                    [void]$findings.Add((New-BootstrapFinding -Severity 'Error' -Category 'InvalidProjectValidationResult' -File 'tools/validation/Validate-Project.ps1' -Message 'The project validator returned an invalid structured result.'))
                    $projectValidation = $null
                }
            }
        }
        catch {
            [void]$findings.Add((New-BootstrapFinding -Severity 'Error' -Category 'ProjectValidationInvocationFailed' -File 'tools/validation/Validate-Project.ps1' -Message 'The canonical project validator could not be loaded or invoked.'))
            $projectValidation = $null
        }
    }

    if ($null -ne $projectValidation) {
        $environmentCheck = $projectValidation.Checks | Where-Object Id -eq 'environment' | Select-Object -First 1
        if ($null -ne $environmentCheck -and $null -ne $environmentCheck.Data) {
            $requiredCapabilities = @($environmentCheck.Data.RequiredCapabilities | ForEach-Object { ConvertTo-BootstrapCapability -Capability $_ })
            $optionalCapabilities = @($environmentCheck.Data.OptionalCapabilities | ForEach-Object { ConvertTo-BootstrapCapability -Capability $_ })

            foreach ($capability in @($requiredCapabilities + $optionalCapabilities | Where-Object { -not $_.Available })) {
                [void]$remediation.Add((Get-CapabilityRemediation -Capability $capability))
            }
        }

        foreach ($componentFinding in @($projectValidation.Findings | Where-Object Category -in @('MissingValidationComponent', 'InvalidValidationComponent', 'ValidationComponentLoadFailed'))) {
            $remediationId = 'restore-' + (($componentFinding.File -replace '[^A-Za-z0-9]+', '-').Trim('-').ToLowerInvariant())
            if (@($remediation | Where-Object Id -eq $remediationId).Count -eq 0) {
                [void]$remediation.Add((New-BootstrapRemediation -Id $remediationId -Priority 'Required' -AppliesTo $componentFinding.File -Summary 'Restore the required validation component.' -Instructions @(
                    "Restore $($componentFinding.File) from the authorized repository revision.",
                    'Re-run the bootstrap after the component is restored.'
                )))
            }
        }

        if (-not $projectValidation.Success -and @($remediation | Where-Object Priority -eq 'Required').Count -eq 0) {
            [void]$remediation.Add((New-BootstrapRemediation -Id 'review-project-validation' -Priority 'Required' -AppliesTo 'ProjectValidation' -Summary 'Resolve the failed mandatory project checks.' -Instructions @(
                'Review failed and skipped mandatory checks in ProjectValidation.Checks.',
                'Correct the reported issue without discarding unrelated work, then re-run the same bootstrap mode.'
            )))
        }
    }

    $externalIntegrations = @(Get-ExternalIntegrationGuidance)
    $stopwatch.Stop()
    $success = $null -ne $projectValidation -and [bool]$projectValidation.Success -and @($findings | Where-Object Severity -eq 'Error').Count -eq 0
    $limitations = @(
        'Bootstrap is diagnostic and advisory; it does not install software or modify persistent settings.',
        'Godot MCP, PixelLab MCP, and the Codex VS Code integration are not tested by this script.',
        'Optional capabilities are reported but do not fail bootstrap.',
        'Successful Godot import does not prove runtime or gameplay behavior.'
    )
    if ($null -ne $projectValidation) {
        $limitations += @($projectValidation.Limitations)
    }

    return [pscustomobject]@{
        SchemaVersion = 1
        Success = $success
        Mode = $requestedMode
        RepositoryRoot = $root
        DurationMs = $stopwatch.ElapsedMilliseconds
        RequiredCapabilities = $requiredCapabilities
        OptionalCapabilities = $optionalCapabilities
        ProjectValidation = $projectValidation
        RemediationSteps = $remediation.ToArray()
        ExternalIntegrations = $externalIntegrations
        Findings = $findings.ToArray()
        Limitations = @($limitations | Select-Object -Unique)
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $result = Invoke-EndlessDungeonBootstrap -Mode $Mode -GodotTimeoutSeconds $GodotTimeoutSeconds
    }
    catch {
        $root = [IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath '..\..'))
        $failureFinding = New-BootstrapFinding -Severity 'Error' -Category 'UnexpectedBootstrapFailure' -File 'tools/setup/bootstrap.ps1' -Message 'Bootstrap stopped because of an unexpected internal error.'
        $result = [pscustomobject]@{
            SchemaVersion = 1
            Success = $false
            Mode = $Mode
            RepositoryRoot = $root
            DurationMs = 0
            RequiredCapabilities = @()
            OptionalCapabilities = @()
            ProjectValidation = $null
            RemediationSteps = @((New-BootstrapRemediation -Id 'review-bootstrap-failure' -Priority 'Required' -AppliesTo 'bootstrap.ps1' -Summary 'Review the bootstrap implementation and repository state.' -Instructions @('Restore the authorized bootstrap and validation scripts, then re-run the command.')))
            ExternalIntegrations = @(Get-ExternalIntegrationGuidance)
            Findings = @($failureFinding)
            Limitations = @('Bootstrap did not complete, so environment and project validation results are unavailable.')
        }
    }

    if ($Json) {
        $result | ConvertTo-Json -Depth 18
    }
    else {
        Write-Output "Endless Dungeon development bootstrap ($($result.Mode))"
        Write-Output "Repository: $($result.RepositoryRoot)"
        Write-Output "Duration: $($result.DurationMs) ms"
        Write-Output ''
        Write-Output 'Required capabilities:'
        if ($result.RequiredCapabilities.Count -eq 0) { Write-Output '[UNKNOWN] Environment capability results are unavailable.' }
        foreach ($capability in $result.RequiredCapabilities) {
            $status = if ($capability.Available) { 'PASS' } else { 'FAIL' }
            $version = if ($capability.Version) { " ($($capability.Version))" } else { '' }
            Write-Output "[$status] $($capability.Name)$version - $($capability.Message)"
        }
        Write-Output ''
        Write-Output 'Optional capabilities:'
        foreach ($capability in $result.OptionalCapabilities) {
            $status = if ($capability.Available) { 'PASS' } else { 'WARN' }
            $version = if ($capability.Version) { " ($($capability.Version))" } else { '' }
            Write-Output "[$status] $($capability.Name)$version - $($capability.Message)"
        }
        Write-Output ''
        if ($null -ne $result.ProjectValidation) {
            $projectStatus = if ($result.ProjectValidation.Success) { 'PASS' } else { 'FAIL' }
            Write-Output "[$projectStatus] Project validation - $($result.ProjectValidation.Counts.Passed) passed, $($result.ProjectValidation.Counts.Failed) failed, $($result.ProjectValidation.Counts.Skipped) skipped, $($result.ProjectValidation.Counts.Warnings) warning(s)."
        }
        else {
            Write-Output '[FAIL] Project validation result is unavailable.'
        }
        if ($result.RemediationSteps.Count -gt 0) {
            Write-Output ''
            Write-Output 'Remediation:'
            foreach ($step in $result.RemediationSteps) {
                Write-Output "[$($step.Priority.ToUpperInvariant())] $($step.AppliesTo) - $($step.Summary)"
                foreach ($instruction in $step.Instructions) { Write-Output "  - $instruction" }
            }
        }
        Write-Output ''
        Write-Output 'External integrations:'
        foreach ($integration in $result.ExternalIntegrations) {
            Write-Output "[$($integration.Status.ToUpperInvariant())] $($integration.Name)"
            foreach ($guidance in $integration.Guidance) { Write-Output "  - $guidance" }
        }
        Write-Output ''
        if ($result.Success) { Write-Output '[PASS] Mandatory bootstrap requirements passed.' } else { Write-Output '[FAIL] One or more mandatory bootstrap requirements did not pass.' }
    }

    if ($result.Success) { exit 0 }
    exit 1
}
