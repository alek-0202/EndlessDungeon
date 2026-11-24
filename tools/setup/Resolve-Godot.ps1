#Requires -Version 5.1

<#
.SYNOPSIS
Resolves a compatible Godot 4 executable.

.DESCRIPTION
Searches process GODOT_PATH, Windows User GODOT_PATH, and PATH in that order.
Each candidate must exist, return exit code 0 from --version, and report Godot 4.

Dot-source this file and call Resolve-Godot to reuse the structured result without
terminating the caller. Running the file directly prints a summary and returns exit
code 0 on success or 1 when no compatible executable is found.

.PARAMETER Json
Prints the standalone result as JSON. This parameter does not affect dot-sourced use.

.PARAMETER VersionTimeoutSeconds
Maximum time for each Godot --version probe. The default is 15 seconds.

.EXAMPLE
.\tools\setup\Resolve-Godot.ps1

.EXAMPLE
.\tools\setup\Resolve-Godot.ps1 -Json

.EXAMPLE
. .\tools\setup\Resolve-Godot.ps1
$godot = Resolve-Godot
#>
[CmdletBinding()]
param(
    [switch]$Json,

    [ValidateRange(1, 300)]
    [int]$VersionTimeoutSeconds = 15
)

function Test-WindowsPlatform {
    return [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
}

function New-GodotDiagnostic {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,

        [AllowNull()]
        [string]$Candidate,

        [Parameter(Mandatory = $true)]
        [string]$Status,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    [pscustomobject]@{
        Source    = $Source
        Candidate = $Candidate
        Status    = $Status
        Message   = $Message
    }
}

function Get-GodotCandidateVariants {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Candidate
    )

    $trimmedCandidate = $Candidate.Trim().Trim('"')
    if ([string]::IsNullOrWhiteSpace($trimmedCandidate)) {
        return
    }

    $expandedCandidate = [Environment]::ExpandEnvironmentVariables($trimmedCandidate)
    $variants = New-Object System.Collections.Generic.List[string]

    if (Test-WindowsPlatform) {
        try {
            $directory = [IO.Path]::GetDirectoryName($expandedCandidate)
            $extension = [IO.Path]::GetExtension($expandedCandidate)
            $baseName = [IO.Path]::GetFileNameWithoutExtension($expandedCandidate)
        }
        catch {
            return @($expandedCandidate)
        }

        if (-not [string]::IsNullOrWhiteSpace($baseName) -and $baseName -notmatch '(?i)_console$') {
            $consoleName = $baseName + '_console' + $extension
            $consoleCandidate = if ([string]::IsNullOrWhiteSpace($directory)) {
                $consoleName
            }
            else {
                [IO.Path]::Combine($directory, $consoleName)
            }

            if (Test-Path -LiteralPath $consoleCandidate -PathType Leaf -ErrorAction SilentlyContinue) {
                $variants.Add($consoleCandidate)
            }
        }
    }

    $variants.Add($expandedCandidate)
    return $variants.ToArray()
}

function Get-PathGodotCandidates {
    $isWindows = Test-WindowsPlatform
    $commandNames = if ($isWindows) {
        @('godot4_console.exe', 'godot_console.exe', 'godot4.exe', 'godot.exe', 'godot4', 'godot')
    }
    else {
        @('godot4', 'godot')
    }

    $comparer = if ($isWindows) {
        [StringComparer]::OrdinalIgnoreCase
    }
    else {
        [StringComparer]::Ordinal
    }
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ($comparer)
    $candidates = New-Object System.Collections.Generic.List[string]

    foreach ($commandName in $commandNames) {
        $commands = @(Get-Command -Name $commandName -CommandType Application -ErrorAction SilentlyContinue)
        foreach ($command in $commands) {
            $commandPath = if ($command.Source) { $command.Source } else { $command.Path }
            if ($commandPath -and $seen.Add($commandPath)) {
                $candidates.Add($commandPath)
            }
        }
    }

    if ($isWindows -and -not [string]::IsNullOrWhiteSpace($env:PATH)) {
        foreach ($pathEntry in $env:PATH.Split([IO.Path]::PathSeparator)) {
            $directory = $pathEntry.Trim().Trim('"')
            if ([string]::IsNullOrWhiteSpace($directory) -or -not (Test-Path -LiteralPath $directory -PathType Container -ErrorAction SilentlyContinue)) {
                continue
            }

            try {
                $matches = @(Get-ChildItem -LiteralPath $directory -Filter 'Godot*.exe' -File -ErrorAction Stop |
                    Sort-Object @{ Expression = { if ($_.BaseName -match '(?i)_console$') { 0 } else { 1 } } }, Name)
                foreach ($match in $matches) {
                    if ($seen.Add($match.FullName)) {
                        $candidates.Add($match.FullName)
                    }
                }
            }
            catch {
                continue
            }
        }
    }

    return $candidates.ToArray()
}

function Test-GodotExecutableCandidate {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Candidate,

        [ValidateRange(1, 300)]
        [int]$VersionTimeoutSeconds = 15
    )

    if (-not (Test-Path -LiteralPath $Candidate -PathType Leaf -ErrorAction SilentlyContinue)) {
        return [pscustomobject]@{
            Valid          = $false
            ExecutablePath = $null
            Version        = $null
            ExitCode       = $null
            Message        = 'Candidate path does not exist or is not a file.'
        }
    }

    $process = New-Object Diagnostics.Process
    $startInfo = New-Object Diagnostics.ProcessStartInfo
    try {
        $resolvedPath = (Resolve-Path -LiteralPath $Candidate -ErrorAction Stop).Path
        $startInfo.FileName = $resolvedPath
        $startInfo.Arguments = '--version'
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $process.StartInfo = $startInfo
        if (-not $process.Start()) { throw 'Process start returned false.' }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($VersionTimeoutSeconds * 1000)) {
            try { $process.Kill() } catch { }
            try { $process.WaitForExit() } catch { }
            return [pscustomobject]@{
                Valid          = $false
                ExecutablePath = $resolvedPath
                Version        = $null
                ExitCode       = $null
                Message        = "Candidate timed out after $VersionTimeoutSeconds second(s) while running --version."
            }
        }
        [Threading.Tasks.Task]::WaitAll(@($stdoutTask, $stderrTask))
        $versionOutput = @($stdoutTask.Result, $stderrTask.Result)
        $exitCode = $process.ExitCode
    }
    catch {
        return [pscustomobject]@{
            Valid          = $false
            ExecutablePath = $Candidate
            Version        = $null
            ExitCode       = $null
            Message        = 'Candidate could not be executed with --version.'
        }
    }
    finally {
        $process.Dispose()
    }

    if ($exitCode -ne 0) {
        return [pscustomobject]@{
            Valid          = $false
            ExecutablePath = $resolvedPath
            Version        = $null
            ExitCode       = $exitCode
            Message        = "Candidate returned exit code $exitCode from --version."
        }
    }

    $versionText = ($versionOutput -join [Environment]::NewLine).Trim()
    $versionMatch = [regex]::Match($versionText, '(?m)^\s*(?<version>\d+\.\d+(?:\.\d+)?(?:[^\s]*)?)\s*$')
    if (-not $versionMatch.Success) {
        return [pscustomobject]@{
            Valid          = $false
            ExecutablePath = $resolvedPath
            Version        = $null
            ExitCode       = $exitCode
            Message        = 'Candidate did not report a recognizable Godot version.'
        }
    }

    $version = $versionMatch.Groups['version'].Value
    $majorVersion = [int]($version.Split('.')[0])
    if ($majorVersion -ne 4) {
        return [pscustomobject]@{
            Valid          = $false
            ExecutablePath = $resolvedPath
            Version        = $version
            ExitCode       = $exitCode
            Message        = "Candidate reports Godot $version; this project requires Godot 4."
        }
    }

    return [pscustomobject]@{
        Valid          = $true
        ExecutablePath = $resolvedPath
        Version        = $version
        ExitCode       = $exitCode
        Message        = 'Compatible Godot 4 executable verified.'
    }
}

function Resolve-Godot {
    <#
    .SYNOPSIS
    Returns structured Godot resolution data without terminating the caller.

    .PARAMETER ProcessGodotPath
    Overrides process GODOT_PATH for controlled tests. Omit to read the process environment.

    .PARAMETER UserGodotPath
    Overrides Windows User GODOT_PATH for controlled tests. Omit to read the User environment.

    .PARAMETER PathCandidates
    Overrides PATH discovery with an explicit candidate list for controlled tests.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$ProcessGodotPath,

        [AllowNull()]
        [AllowEmptyString()]
        [string]$UserGodotPath,

        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]$PathCandidates,

        [ValidateRange(1, 300)]
        [int]$VersionTimeoutSeconds = 15
    )

    $diagnostics = New-Object System.Collections.Generic.List[object]
    $processValue = if ($PSBoundParameters.ContainsKey('ProcessGodotPath')) {
        $ProcessGodotPath
    }
    else {
        $env:GODOT_PATH
    }

    $sourceGroups = New-Object System.Collections.Generic.List[object]
    $sourceGroups.Add([pscustomobject]@{
        Source     = 'ProcessEnvironment'
        Candidates = if ([string]::IsNullOrWhiteSpace($processValue)) { @() } else { @($processValue) }
        EmptyMessage = 'Process GODOT_PATH is missing or empty.'
    })

    if (Test-WindowsPlatform) {
        $userValue = if ($PSBoundParameters.ContainsKey('UserGodotPath')) {
            $UserGodotPath
        }
        else {
            [Environment]::GetEnvironmentVariable('GODOT_PATH', 'User')
        }
        $sourceGroups.Add([pscustomobject]@{
            Source       = 'UserEnvironment'
            Candidates   = if ([string]::IsNullOrWhiteSpace($userValue)) { @() } else { @($userValue) }
            EmptyMessage = 'Windows User GODOT_PATH is missing or empty.'
        })
    }
    else {
        $diagnostics.Add((New-GodotDiagnostic -Source 'UserEnvironment' -Candidate $null -Status 'Skipped' -Message 'Windows User environment lookup is not supported on this platform.'))
    }

    $pathValues = if ($PSBoundParameters.ContainsKey('PathCandidates')) {
        @($PathCandidates)
    }
    else {
        @(Get-PathGodotCandidates)
    }
    $sourceGroups.Add([pscustomobject]@{
        Source       = 'Path'
        Candidates   = $pathValues
        EmptyMessage = 'No Godot executable candidate was discovered through PATH.'
    })

    foreach ($group in $sourceGroups) {
        if (@($group.Candidates).Count -eq 0) {
            $diagnostics.Add((New-GodotDiagnostic -Source $group.Source -Candidate $null -Status 'Skipped' -Message $group.EmptyMessage))
            continue
        }

        foreach ($sourceCandidate in @($group.Candidates)) {
            $variants = @(Get-GodotCandidateVariants -Candidate $sourceCandidate)
            foreach ($candidate in $variants) {
                $test = Test-GodotExecutableCandidate -Candidate $candidate -VersionTimeoutSeconds $VersionTimeoutSeconds
                $status = if ($test.Valid) { 'Accepted' } else { 'Rejected' }
                $diagnostics.Add((New-GodotDiagnostic -Source $group.Source -Candidate $candidate -Status $status -Message $test.Message))

                if ($test.Valid) {
                    return [pscustomobject]@{
                        Success        = $true
                        ExecutablePath = $test.ExecutablePath
                        Source         = $group.Source
                        Version        = $test.Version
                        ExitCode       = $test.ExitCode
                        Diagnostics    = $diagnostics.ToArray()
                    }
                }
            }
        }
    }

    return [pscustomobject]@{
        Success        = $false
        ExecutablePath = $null
        Source         = $null
        Version        = $null
        ExitCode       = $null
        Diagnostics    = $diagnostics.ToArray()
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $result = Resolve-Godot -VersionTimeoutSeconds $VersionTimeoutSeconds
    if ($Json) {
        $result | ConvertTo-Json -Depth 6
    }
    elseif ($result.Success) {
        Write-Output "[PASS] Godot $($result.Version) resolved from $($result.Source)."
        Write-Output "Executable: $($result.ExecutablePath)"
    }
    else {
        Write-Output '[FAIL] No compatible Godot 4 executable could be resolved.'
        foreach ($diagnostic in $result.Diagnostics) {
            $candidateText = if ($diagnostic.Candidate) { " ($($diagnostic.Candidate))" } else { '' }
            Write-Output "[$($diagnostic.Status)] $($diagnostic.Source)$candidateText`: $($diagnostic.Message)"
        }
    }

    if ($result.Success) {
        exit 0
    }
    exit 1
}
