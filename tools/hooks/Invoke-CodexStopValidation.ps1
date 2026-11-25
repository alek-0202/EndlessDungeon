[CmdletBinding()]
param(
    [ValidateRange(5, 85)]
    [int]$InternalDeadlineSeconds = 80,

    [ValidateRange(1, 80)]
    [int]$ValidatorTimeoutSeconds = 70
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$script:HookDeadlineUtc = [DateTime]::UtcNow.AddSeconds($InternalDeadlineSeconds)

function Write-HookResponse {
    param([Parameter(Mandatory = $true)][hashtable]$Response)

    [Console]::Out.WriteLine(($Response | ConvertTo-Json -Compress -Depth 4))
}

function Complete-Hook {
    param([Parameter(Mandatory = $true)][hashtable]$Response)

    Write-HookResponse -Response $Response
    exit 0
}

function New-InfrastructureResponse {
    param([Parameter(Mandatory = $true)][string]$Message)

    return @{
        continue = $true
        systemMessage = "Stop hook infrastructure failure: $Message Run Quick validation manually and report the failure."
    }
}

function Get-RemainingMilliseconds {
    $remaining = [int][Math]::Floor(($script:HookDeadlineUtc - [DateTime]::UtcNow).TotalMilliseconds)
    if ($remaining -le 0) {
        throw 'The internal hook deadline expired.'
    }
    return $remaining
}

function ConvertTo-NativeArgument {
    param([AllowEmptyString()][string]$Value)

    if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') {
        return $Value
    }

    $builder = New-Object Text.StringBuilder
    [void]$builder.Append('"')
    $backslashes = 0
    foreach ($character in $Value.ToCharArray()) {
        if ($character -eq '\') {
            $backslashes++
            continue
        }
        if ($character -eq '"') {
            [void]$builder.Append(('\' * (($backslashes * 2) + 1)))
            [void]$builder.Append('"')
            $backslashes = 0
            continue
        }
        if ($backslashes -gt 0) {
            [void]$builder.Append(('\' * $backslashes))
            $backslashes = 0
        }
        [void]$builder.Append($character)
    }
    if ($backslashes -gt 0) {
        [void]$builder.Append(('\' * ($backslashes * 2)))
    }
    [void]$builder.Append('"')
    return $builder.ToString()
}

function Stop-StartedProcessTree {
    param([Parameter(Mandatory = $true)][Diagnostics.Process]$Process)

    if ($Process.HasExited) {
        return
    }

    $taskkill = Get-Command taskkill.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $taskkill) {
        $cleanupProcess = New-Object Diagnostics.Process
        try {
            $cleanupInfo = New-Object Diagnostics.ProcessStartInfo
            $cleanupInfo.FileName = $taskkill.Source
            $cleanupInfo.Arguments = "/PID $($Process.Id) /T /F"
            $cleanupInfo.UseShellExecute = $false
            $cleanupInfo.CreateNoWindow = $true
            $cleanupInfo.RedirectStandardOutput = $true
            $cleanupInfo.RedirectStandardError = $true
            $cleanupProcess.StartInfo = $cleanupInfo
            if ($cleanupProcess.Start()) {
                $cleanupOutput = $cleanupProcess.StandardOutput.ReadToEndAsync()
                $cleanupError = $cleanupProcess.StandardError.ReadToEndAsync()
                if ($cleanupProcess.WaitForExit(2000)) {
                    $cleanupProcess.WaitForExit()
                    $null = $cleanupOutput.Result
                    $null = $cleanupError.Result
                }
                elseif (-not $cleanupProcess.HasExited) {
                    $cleanupProcess.Kill()
                    [void]$cleanupProcess.WaitForExit(1000)
                }
            }
            if ($Process.HasExited) {
                return
            }
        }
        catch {
            # Fall back to terminating the exact process started by this adapter.
        }
        finally {
            $cleanupProcess.Dispose()
        }
    }

    if (-not $Process.HasExited) {
        $Process.Kill()
    }
}

function Invoke-BoundedProcess {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$WorkingDirectory,
        [Parameter(Mandatory = $true)][int]$TimeoutMilliseconds
    )

    $effectiveTimeout = [Math]::Min($TimeoutMilliseconds, (Get-RemainingMilliseconds))
    if ($effectiveTimeout -lt 100) {
        throw 'Insufficient time remains to start an external process.'
    }

    $startInfo = New-Object Diagnostics.ProcessStartInfo
    $startInfo.FileName = $FilePath
    $startInfo.Arguments = (($Arguments | ForEach-Object { ConvertTo-NativeArgument -Value $_ }) -join ' ')
    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true

    $process = New-Object Diagnostics.Process
    $processStarted = $false
    $process.StartInfo = $startInfo
    try {
        if (-not $process.Start()) {
            return [pscustomobject]@{ Started = $false; TimedOut = $false; ExitCode = $null; StdOut = ''; StdErr = '' }
        }
        $processStarted = $true

        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($effectiveTimeout)) {
            Stop-StartedProcessTree -Process $process
            [void]$process.WaitForExit(2000)
            return [pscustomobject]@{ Started = $true; TimedOut = $true; ExitCode = $null; StdOut = ''; StdErr = '' }
        }

        $process.WaitForExit()
        $stdout = $stdoutTask.Result
        $stderr = $stderrTask.Result
        if ($stdout.Length -gt 1048576 -or $stderr.Length -gt 1048576) {
            return [pscustomobject]@{ Started = $true; TimedOut = $false; ExitCode = $process.ExitCode; StdOut = ''; StdErr = ''; OutputTooLarge = $true }
        }
        return [pscustomobject]@{
            Started = $true
            TimedOut = $false
            ExitCode = $process.ExitCode
            StdOut = $stdout
            StdErr = $stderr
            OutputTooLarge = $false
        }
    }
    catch {
        return [pscustomobject]@{ Started = $false; TimedOut = $false; ExitCode = $null; StdOut = ''; StdErr = ''; OutputTooLarge = $false }
    }
    finally {
        if ($processStarted -and -not $process.HasExited) {
            Stop-StartedProcessTree -Process $process
        }
        $process.Dispose()
    }
}

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)][string]$GitPath,
        [Parameter(Mandatory = $true)][string]$WorkingDirectory,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    return Invoke-BoundedProcess -FilePath $GitPath -Arguments $Arguments -WorkingDirectory $WorkingDirectory -TimeoutMilliseconds 5000
}

function Test-Property {
    param(
        [Parameter(Mandatory = $true)][object]$Object,
        [Parameter(Mandatory = $true)][string]$Name
    )

    return $null -ne $Object.PSObject.Properties[$Name]
}

function Get-NormalizedPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    return [IO.Path]::GetFullPath($Path).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
}

function Test-EndlessDungeonRoot {
    param([Parameter(Mandatory = $true)][string]$RepositoryRoot)

    $requiredFiles = @(
        'AGENTS.md',
        'project.godot',
        'docs/AI_WORKFLOW.md'
    )
    foreach ($relativePath in $requiredFiles) {
        if (-not (Test-Path -LiteralPath (Join-Path -Path $RepositoryRoot -ChildPath $relativePath) -PathType Leaf)) {
            return $false
        }
    }

    $projectFile = Join-Path -Path $RepositoryRoot -ChildPath 'project.godot'
    $projectName = Select-String -LiteralPath $projectFile -Pattern '^config/name="EndlessDungeon"$' -CaseSensitive -Quiet
    return [bool]$projectName
}

function Get-RepositoryChangeState {
    param(
        [Parameter(Mandatory = $true)][string]$GitPath,
        [Parameter(Mandatory = $true)][string]$RepositoryRoot
    )

    $staged = Invoke-Git -GitPath $GitPath -WorkingDirectory $RepositoryRoot -Arguments @('-C', $RepositoryRoot, 'diff', '--cached', '--quiet', '--')
    if (-not $staged.Started -or $staged.TimedOut -or $staged.ExitCode -notin @(0, 1)) {
        throw 'Git could not inspect staged changes.'
    }

    $unstaged = Invoke-Git -GitPath $GitPath -WorkingDirectory $RepositoryRoot -Arguments @('-C', $RepositoryRoot, 'diff', '--quiet', '--')
    if (-not $unstaged.Started -or $unstaged.TimedOut -or $unstaged.ExitCode -notin @(0, 1)) {
        throw 'Git could not inspect unstaged tracked changes.'
    }

    $untracked = Invoke-Git -GitPath $GitPath -WorkingDirectory $RepositoryRoot -Arguments @('-C', $RepositoryRoot, 'ls-files', '--others', '--exclude-standard', '-z')
    if (-not $untracked.Started -or $untracked.TimedOut -or $untracked.ExitCode -ne 0) {
        throw 'Git could not inspect non-ignored untracked files.'
    }

    return [pscustomobject]@{
        HasStaged = $staged.ExitCode -eq 1
        HasUnstaged = $unstaged.ExitCode -eq 1
        HasUntracked = $untracked.StdOut.Length -gt 0
    }
}

function Get-SanitizedCheckIds {
    param([Parameter(Mandatory = $true)][object[]]$Checks)

    $ids = New-Object Collections.Generic.List[string]
    foreach ($check in $Checks) {
        if (-not (Test-Property -Object $check -Name 'Id') -or
            -not (Test-Property -Object $check -Name 'Mandatory') -or
            -not (Test-Property -Object $check -Name 'Status')) {
            continue
        }
        if (-not [bool]$check.Mandatory -or [string]$check.Status -notin @('Failed', 'Skipped')) {
            continue
        }
        $id = [string]$check.Id
        if ($id -match '^[A-Za-z0-9._-]{1,64}$') {
            [void]$ids.Add($id)
        }
        if ($ids.Count -ge 5) {
            break
        }
    }
    return $ids.ToArray()
}

function Test-ValidatorResult {
    param(
        [Parameter(Mandatory = $true)][object]$Result,
        [Parameter(Mandatory = $true)][string]$RepositoryRoot,
        [Parameter(Mandatory = $true)][int]$ExitCode
    )

    foreach ($property in @('SchemaVersion', 'Success', 'Mode', 'RepositoryRoot', 'Checks')) {
        if (-not (Test-Property -Object $Result -Name $property)) {
            throw 'Validator JSON is missing a required allowlisted field.'
        }
    }
    if ([int]$Result.SchemaVersion -ne 1 -or [string]$Result.Mode -ne 'Quick') {
        throw 'Validator JSON uses an unexpected schema or mode.'
    }
    if ($Result.Success -isnot [bool]) {
        throw 'Validator JSON has an invalid success value.'
    }
    if ((Get-NormalizedPath -Path ([string]$Result.RepositoryRoot)) -ne (Get-NormalizedPath -Path $RepositoryRoot)) {
        throw 'Validator JSON identifies a different repository root.'
    }
    if (($Result.Success -and $ExitCode -ne 0) -or (-not $Result.Success -and $ExitCode -ne 1)) {
        throw "Validator success state is inconsistent with process exit code $ExitCode."
    }
}

try {
    $rawInput = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($rawInput)) {
        Complete-Hook -Response (New-InfrastructureResponse -Message 'Stop event input was empty.')
    }

    try {
        $event = $rawInput | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Complete-Hook -Response (New-InfrastructureResponse -Message 'Stop event input was not valid JSON.')
    }

    foreach ($property in @('hook_event_name', 'cwd', 'stop_hook_active')) {
        if (-not (Test-Property -Object $event -Name $property)) {
            Complete-Hook -Response (New-InfrastructureResponse -Message "Stop event input omitted $property.")
        }
    }
    if ([string]$event.hook_event_name -ne 'Stop') {
        Complete-Hook -Response (New-InfrastructureResponse -Message 'The received event was not Stop.')
    }
    if ($event.stop_hook_active -isnot [bool]) {
        Complete-Hook -Response (New-InfrastructureResponse -Message 'stop_hook_active was not a Boolean value.')
    }
    if ([string]::IsNullOrWhiteSpace([string]$event.cwd) -or -not (Test-Path -LiteralPath ([string]$event.cwd) -PathType Container)) {
        Complete-Hook -Response (New-InfrastructureResponse -Message 'The event working directory was invalid.')
    }

    $git = Get-Command git.exe, git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $git) {
        Complete-Hook -Response (New-InfrastructureResponse -Message 'Git was unavailable.')
    }

    $eventWorkingDirectory = Get-NormalizedPath -Path ([string]$event.cwd)
    $rootResult = Invoke-Git -GitPath $git.Source -WorkingDirectory $eventWorkingDirectory -Arguments @('-C', $eventWorkingDirectory, 'rev-parse', '--show-toplevel')
    if (-not $rootResult.Started -or $rootResult.TimedOut -or $rootResult.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($rootResult.StdOut)) {
        Complete-Hook -Response (New-InfrastructureResponse -Message 'Git could not resolve the repository root.')
    }
    $rootLines = @($rootResult.StdOut -split '[\r\n]+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($rootLines.Count -ne 1) {
        Complete-Hook -Response (New-InfrastructureResponse -Message 'Git returned an ambiguous repository root.')
    }
    $repositoryRoot = Get-NormalizedPath -Path $rootLines[0]
    if (-not (Test-EndlessDungeonRoot -RepositoryRoot $repositoryRoot)) {
        Complete-Hook -Response (New-InfrastructureResponse -Message 'The resolved repository was not the expected Endless Dungeon project.')
    }

    $validatorPath = Join-Path -Path $repositoryRoot -ChildPath 'tools/validation/Validate-Project.ps1'
    if (-not (Test-Path -LiteralPath $validatorPath -PathType Leaf)) {
        Complete-Hook -Response (New-InfrastructureResponse -Message 'The project validator was unavailable.')
    }

    $changeState = Get-RepositoryChangeState -GitPath $git.Source -RepositoryRoot $repositoryRoot
    if (-not $changeState.HasStaged -and -not $changeState.HasUnstaged -and -not $changeState.HasUntracked) {
        Complete-Hook -Response @{ continue = $true }
    }

    $powerShellPath = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    $remaining = Get-RemainingMilliseconds
    $validatorTimeout = [Math]::Min(($ValidatorTimeoutSeconds * 1000), ($remaining - 2000))
    if ($validatorTimeout -lt 100) {
        Complete-Hook -Response (New-InfrastructureResponse -Message 'Insufficient time remained to run Quick validation.')
    }

    $validator = Invoke-BoundedProcess -FilePath $powerShellPath -Arguments @(
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy', 'Bypass',
        '-File', $validatorPath,
        '-Mode', 'Quick',
        '-Json',
        '-RepositoryRoot', $repositoryRoot
    ) -WorkingDirectory $repositoryRoot -TimeoutMilliseconds $validatorTimeout

    if (-not $validator.Started) {
        Complete-Hook -Response (New-InfrastructureResponse -Message 'The project validator process could not start.')
    }
    if ($validator.TimedOut) {
        Complete-Hook -Response (New-InfrastructureResponse -Message 'Quick validation exceeded the internal timeout.')
    }
    if ((Test-Property -Object $validator -Name 'OutputTooLarge') -and $validator.OutputTooLarge) {
        Complete-Hook -Response (New-InfrastructureResponse -Message 'Quick validation output exceeded the safe size limit.')
    }

    try {
        $validatorResult = $validator.StdOut | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Complete-Hook -Response (New-InfrastructureResponse -Message 'Quick validation returned invalid JSON.')
    }

    try {
        Test-ValidatorResult -Result $validatorResult -RepositoryRoot $repositoryRoot -ExitCode $validator.ExitCode
    }
    catch {
        $safeExitCode = if ($null -eq $validator.ExitCode) { 'unknown' } else { [string]$validator.ExitCode }
        Complete-Hook -Response (New-InfrastructureResponse -Message "Quick validation result was inconsistent (exit code $safeExitCode).")
    }

    if ([bool]$validatorResult.Success) {
        Complete-Hook -Response @{ continue = $true }
    }

    $failedCheckIds = @(Get-SanitizedCheckIds -Checks @($validatorResult.Checks))
    $checkSummary = if ($failedCheckIds.Count -gt 0) { $failedCheckIds -join ', ' } else { 'unidentified mandatory check' }
    $feedback = "Quick validation failed (exit code $($validator.ExitCode)); mandatory checks: $checkSummary. Inspect Validate-Project.ps1 -Mode Quick -Json, correct only within the original authorized task scope, and report unresolved failures without expanding scope."
    if ([bool]$event.stop_hook_active) {
        Complete-Hook -Response @{ continue = $true; systemMessage = $feedback }
    }
    Complete-Hook -Response @{ decision = 'block'; reason = $feedback }
}
catch {
    Complete-Hook -Response (New-InfrastructureResponse -Message 'An unexpected internal error occurred.')
}
