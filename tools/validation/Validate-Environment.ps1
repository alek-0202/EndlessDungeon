#Requires -Version 5.1

<#
.SYNOPSIS
Validates the required and optional Endless Dungeon development environment.

.DESCRIPTION
Finds the repository relative to this script, verifies repository markers, and
reports PowerShell, Git, Godot, Node.js, npm, npx, Python, and standalone Codex CLI.
PowerShell, Git, a compatible Godot 4 executable, project.godot, and AGENTS.md are
required. Optional tools produce warnings only.

Human-readable output is the default. -Json emits one valid JSON document without
additional console messages. The script exits 0 when all required checks pass and
1 when any required check fails. Dot-source the file and call
Test-ProjectEnvironment to obtain the result without terminating the caller.

.PARAMETER Json
Emits the structured result as JSON.

.EXAMPLE
.\tools\validation\Validate-Environment.ps1

.EXAMPLE
.\tools\validation\Validate-Environment.ps1 -Json
#>
[CmdletBinding()]
param(
    [switch]$Json
)

function New-CapabilityResult {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [bool]$Required,

        [Parameter(Mandatory = $true)]
        [bool]$Available,

        [AllowNull()]
        [string]$Version,

        [AllowNull()]
        [string]$ExecutablePath,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    [pscustomobject]@{
        Name           = $Name
        Required       = $Required
        Available      = $Available
        Version        = $Version
        ExecutablePath = $ExecutablePath
        Message        = $Message
    }
}

function Get-ApplicationCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Names
    )

    foreach ($name in $Names) {
        $command = Get-Command -Name $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command) {
            return $command
        }
    }
    return $null
}

function Invoke-NativeVersionProbe {
    param(
        [string]$CommandPath,
        [string[]]$Arguments,
        [ValidateRange(1, 300)]
        [int]$TimeoutSeconds = 15
    )

    $process = New-Object Diagnostics.Process
    $startInfo = New-Object Diagnostics.ProcessStartInfo
    $argumentText = @($Arguments | ForEach-Object {
        if ($_ -match '[\s"]') { '"' + $_.Replace('"', '\"') + '"' } else { $_ }
    }) -join ' '
    $isWindowsCommandScript = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT -and [IO.Path]::GetExtension($CommandPath) -match '^(?i)\.(?:cmd|bat)$'

    if ($isWindowsCommandScript) {
        $startInfo.FileName = $env:ComSpec
        $startInfo.Arguments = '/d /s /c ""' + $CommandPath + '" ' + $argumentText + '"'
    }
    else {
        $startInfo.FileName = $CommandPath
        $startInfo.Arguments = $argumentText
    }
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process.StartInfo = $startInfo

    try {
        if (-not $process.Start()) { throw 'Process start returned false.' }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            try { $process.Kill() } catch { }
            try { $process.WaitForExit() } catch { }
            return [pscustomobject]@{ Started = $true; TimedOut = $true; ExitCode = $null; Output = @() }
        }
        [Threading.Tasks.Task]::WaitAll(@($stdoutTask, $stderrTask))
        return [pscustomobject]@{
            Started = $true
            TimedOut = $false
            ExitCode = $process.ExitCode
            Output = @($stdoutTask.Result, $stderrTask.Result)
        }
    }
    catch {
        return [pscustomobject]@{ Started = $false; TimedOut = $false; ExitCode = $null; Output = @() }
    }
    finally {
        $process.Dispose()
    }
}

function Get-NativeVersionCapability {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [bool]$Required,

        [Parameter(Mandatory = $true)]
        [string[]]$CommandNames,

        [string[]]$Arguments = @('--version'),

        [Parameter(Mandatory = $true)]
        [string]$VersionPattern,

        [string]$UnavailableMessage = 'Executable was not found or did not return a usable version.',

        [ValidateRange(1, 300)]
        [int]$TimeoutSeconds = 15
    )

    $attemptMessages = New-Object System.Collections.Generic.List[string]
    foreach ($commandName in $CommandNames) {
        $command = Get-ApplicationCommand -Names @($commandName)
        if (-not $command) {
            continue
        }

        $commandPath = if ($command.Source) { $command.Source } else { $command.Path }
        $probe = Invoke-NativeVersionProbe -CommandPath $commandPath -Arguments $Arguments -TimeoutSeconds $TimeoutSeconds
        if (-not $probe.Started) {
            $attemptMessages.Add("$commandName could not be executed.")
            continue
        }
        if ($probe.TimedOut) {
            $attemptMessages.Add("$commandName timed out after $TimeoutSeconds second(s).")
            continue
        }

        $exitCode = $probe.ExitCode
        $outputText = ($probe.Output -join [Environment]::NewLine).Trim()
        $match = [regex]::Match($outputText, $VersionPattern)
        if ($exitCode -eq 0 -and $match.Success) {
            $version = if ($match.Groups['version'].Success) {
                $match.Groups['version'].Value
            }
            else {
                $match.Value.Trim()
            }
            return New-CapabilityResult -Name $Name -Required $Required -Available $true -Version $version -ExecutablePath $commandPath -Message 'Usable executable verified.'
        }

        $attemptMessages.Add("$commandName returned an unusable version response with exit code $exitCode.")
    }

    $message = $UnavailableMessage
    if ($attemptMessages.Count -gt 0) {
        $message += ' ' + ($attemptMessages -join ' ')
    }
    return New-CapabilityResult -Name $Name -Required $Required -Available $false -Version $null -ExecutablePath $null -Message $message
}

function Test-ProjectEnvironment {
    [CmdletBinding()]
    param(
        [ValidateRange(1, 300)]
        [int]$NativeCommandTimeoutSeconds = 15
    )

    $repositoryRoot = [IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath '..\..'))
    $resolverPath = Join-Path -Path $repositoryRoot -ChildPath 'tools\setup\Resolve-Godot.ps1'
    $projectFile = Join-Path -Path $repositoryRoot -ChildPath 'project.godot'
    $agentsFile = Join-Path -Path $repositoryRoot -ChildPath 'AGENTS.md'

    $resolverLoaded = $false
    $resolverLoadMessage = 'Godot resolver was not found.'
    if (Test-Path -LiteralPath $resolverPath -PathType Leaf) {
        $callerErrorActionPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Stop'
            $resolverOutput = @(. $resolverPath)
            $resolverLoaded = $null -ne (Get-Command -Name 'Resolve-Godot' -CommandType Function -ErrorAction SilentlyContinue)
            if ($resolverLoaded) {
                $resolverLoadMessage = 'Godot resolver loaded.'
            }
            else {
                $resolverLoadMessage = 'Godot resolver did not define Resolve-Godot.'
            }
        }
        catch {
            $resolverLoadMessage = 'Godot resolver could not be loaded.'
        }
        finally {
            $ErrorActionPreference = $callerErrorActionPreference
        }
    }

    $required = New-Object System.Collections.Generic.List[object]
    $optional = New-Object System.Collections.Generic.List[object]

    $repositoryAvailable = (Test-Path -LiteralPath $projectFile -PathType Leaf) -and (Test-Path -LiteralPath $agentsFile -PathType Leaf)
    $repositoryMessage = if ($repositoryAvailable) {
        'project.godot and AGENTS.md were found relative to the validation script.'
    }
    else {
        'Expected project.godot and AGENTS.md were not both found relative to the validation script.'
    }
    $required.Add((New-CapabilityResult -Name 'RepositoryLayout' -Required $true -Available $repositoryAvailable -Version $null -ExecutablePath $repositoryRoot -Message $repositoryMessage))

    $required.Add((New-CapabilityResult -Name 'PowerShell' -Required $true -Available $true -Version $PSVersionTable.PSVersion.ToString() -ExecutablePath $null -Message "PowerShell $($PSVersionTable.PSEdition) edition is running."))

    $git = Get-NativeVersionCapability -Name 'Git' -Required $true -CommandNames @('git') -VersionPattern '(?im)^git version\s+(?<version>\S+)' -TimeoutSeconds $NativeCommandTimeoutSeconds
    $required.Add($git)

    $godot = if ($resolverLoaded) {
        Resolve-Godot -VersionTimeoutSeconds $NativeCommandTimeoutSeconds
    }
    else {
        [pscustomobject]@{
            Success        = $false
            ExecutablePath = $null
            Source         = $null
            Version        = $null
            ExitCode       = $null
            Diagnostics    = @(
                [pscustomobject]@{
                    Source    = 'Resolver'
                    Candidate = $resolverPath
                    Status    = 'Rejected'
                    Message   = $resolverLoadMessage
                }
            )
        }
    }
    $godotMessage = if ($godot.Success) {
        "Compatible Godot 4 executable resolved from $($godot.Source)."
    }
    elseif (-not $resolverLoaded) {
        $resolverLoadMessage
    }
    else {
        'No compatible Godot 4 executable could be resolved.'
    }
    $required.Add((New-CapabilityResult -Name 'Godot' -Required $true -Available $godot.Success -Version $godot.Version -ExecutablePath $godot.ExecutablePath -Message $godotMessage))

    $optional.Add((Get-NativeVersionCapability -Name 'Node.js' -Required $false -CommandNames @('node') -VersionPattern '(?im)^v?(?<version>\d+\.\d+\.\d+)' -TimeoutSeconds $NativeCommandTimeoutSeconds))
    $optional.Add((Get-NativeVersionCapability -Name 'npm' -Required $false -CommandNames @('npm') -VersionPattern '(?im)^(?<version>\d+\.\d+\.\d+)' -TimeoutSeconds $NativeCommandTimeoutSeconds))
    $optional.Add((Get-NativeVersionCapability -Name 'npx' -Required $false -CommandNames @('npx') -VersionPattern '(?im)^(?<version>\d+\.\d+\.\d+)' -TimeoutSeconds $NativeCommandTimeoutSeconds))
    $optional.Add((Get-NativeVersionCapability -Name 'Python' -Required $false -CommandNames @('python', 'python3', 'py') -VersionPattern '(?im)^Python\s+(?<version>\d+\.\d+(?:\.\d+)?)' -UnavailableMessage 'No usable Python runtime was found; Windows Store aliases that cannot return a version are not accepted.' -TimeoutSeconds $NativeCommandTimeoutSeconds))
    $optional.Add((Get-NativeVersionCapability -Name 'CodexCLI' -Required $false -CommandNames @('codex') -VersionPattern '(?im)(?:codex(?:-cli)?\s+)?(?<version>\d+\.\d+(?:\.\d+)?)' -UnavailableMessage 'Standalone Codex CLI was not found; this does not assess the VS Code Codex integration.' -TimeoutSeconds $NativeCommandTimeoutSeconds))

    $requiredFailures = @($required | Where-Object { -not $_.Available })
    $optionalMissing = @($optional | Where-Object { -not $_.Available })

    return [pscustomobject]@{
        Success              = $requiredFailures.Count -eq 0
        RepositoryRoot       = $repositoryRoot
        PowerShellVersion    = $PSVersionTable.PSVersion.ToString()
        PowerShellEdition    = $PSVersionTable.PSEdition
        RequiredCapabilities = $required.ToArray()
        OptionalCapabilities = $optional.ToArray()
        RequiredFailureCount = $requiredFailures.Count
        OptionalMissingCount = $optionalMissing.Count
        GodotSource          = $godot.Source
        GodotVersionExitCode = $godot.ExitCode
        GodotDiagnostics     = $godot.Diagnostics
        Limitations          = @(
            'Executable discovery does not validate MCP connectivity.',
            'Godot executable validation does not validate gameplay or runtime behavior.',
            'Cross-platform behavior has not been verified.'
        )
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $result = Test-ProjectEnvironment
    if ($Json) {
        $result | ConvertTo-Json -Depth 8
    }
    else {
        Write-Output 'Endless Dungeon environment validation'
        Write-Output "Repository: $($result.RepositoryRoot)"
        Write-Output ''
        Write-Output 'Required capabilities:'
        foreach ($capability in $result.RequiredCapabilities) {
            $status = if ($capability.Available) { 'PASS' } else { 'FAIL' }
            $versionText = if ($capability.Version) { " $($capability.Version)" } else { '' }
            Write-Output "[$status] $($capability.Name)$versionText - $($capability.Message)"
        }
        Write-Output ''
        Write-Output 'Optional capabilities:'
        foreach ($capability in $result.OptionalCapabilities) {
            $status = if ($capability.Available) { 'PASS' } else { 'WARN' }
            $versionText = if ($capability.Version) { " $($capability.Version)" } else { '' }
            Write-Output "[$status] $($capability.Name)$versionText - $($capability.Message)"
        }
        Write-Output ''
        if ($result.Success) {
            Write-Output '[PASS] All required environment checks passed.'
        }
        else {
            Write-Output "[FAIL] $($result.RequiredFailureCount) required environment check(s) failed."
        }
    }

    if ($result.Success) {
        exit 0
    }
    exit 1
}
