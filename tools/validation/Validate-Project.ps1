[CmdletBinding()]
param(
    [ValidateSet('Full', 'Quick')]
    [string]$Mode = 'Full',

    [switch]$Json,

    [ValidateRange(1, 3600)]
    [int]$GodotTimeoutSeconds = 120,

    [string]$RepositoryRoot
)

Set-StrictMode -Version 2.0

function Invoke-ProjectNativeCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [Parameter(Mandatory = $true)]
        [string]$WorkingDirectory
    )

    $previousLocation = Get-Location
    try {
        Set-Location -LiteralPath $WorkingDirectory
        $output = @(& $FilePath @Arguments 2>&1 | ForEach-Object { $_.ToString() })
        $exitCode = $LASTEXITCODE
        return [pscustomobject]@{
            Started  = $true
            ExitCode = $exitCode
            Output   = $output
            Error    = $null
        }
    }
    catch {
        return [pscustomobject]@{
            Started  = $false
            ExitCode = $null
            Output   = @()
            Error    = $_.Exception.Message
        }
    }
    finally {
        Set-Location -LiteralPath $previousLocation
    }
}

function New-ProjectFinding {
    param(
        [string]$CheckId,
        [ValidateSet('Error', 'Warning', 'Information')]
        [string]$Severity,
        [string]$Category,
        [string]$Message,
        [string]$File,
        [Nullable[int]]$Line
    )

    return [pscustomobject]@{
        CheckId = $CheckId
        Severity = $Severity
        Category = $Category
        File = $File
        Line = $Line
        Message = $Message
    }
}

function New-ProjectCheck {
    param(
        [string]$Id,
        [string]$Description,
        [bool]$Mandatory,
        [ValidateSet('Passed', 'Failed', 'Skipped')]
        [string]$Status,
        [long]$DurationMs,
        [Nullable[int]]$NativeExitCode,
        [object[]]$Findings,
        [object]$Data
    )

    return [pscustomobject]@{
        Id = $Id
        Description = $Description
        Mandatory = $Mandatory
        Status = $Status
        DurationMs = $DurationMs
        NativeExitCode = $NativeExitCode
        Findings = @($Findings)
        Data = $Data
    }
}

function Get-ProjectSha256 {
    param([string]$Path)

    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    try {
        $sha = [Security.Cryptography.SHA256]::Create()
        try {
            return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '').ToLowerInvariant()
        }
        finally {
            $sha.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Get-ProjectSnapshot {
    param(
        [string]$Root,
        [string]$GitPath
    )

    if ([string]::IsNullOrWhiteSpace($GitPath)) {
        return [pscustomobject]@{ Success = $false; Files = @(); SkippedPaths = @(); Message = 'Git is unavailable.' }
    }

    $listResult = Invoke-ProjectNativeCommand -FilePath $GitPath -Arguments @('ls-files', '--cached', '--others', '--exclude-standard') -WorkingDirectory $Root
    if (-not $listResult.Started -or $listResult.ExitCode -ne 0) {
        return [pscustomobject]@{ Success = $false; Files = @(); SkippedPaths = @(); Message = 'Repository-visible files could not be enumerated.' }
    }

    $files = New-Object System.Collections.Generic.List[object]
    $skipped = New-Object System.Collections.Generic.List[string]
    $rootPrefix = $Root.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    $comparison = if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }

    foreach ($relativePath in @($listResult.Output | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)) {
        $normalizedRelative = $relativePath.Replace('/', [IO.Path]::DirectorySeparatorChar)
        $fullPath = [IO.Path]::GetFullPath((Join-Path -Path $Root -ChildPath $normalizedRelative))
        if (-not $fullPath.StartsWith($rootPrefix, $comparison)) {
            [void]$skipped.Add($relativePath)
            continue
        }

        if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf -ErrorAction SilentlyContinue)) {
            [void]$files.Add([pscustomobject]@{ Path = $relativePath; State = 'Missing'; Length = $null; Sha256 = $null })
            continue
        }

        $item = Get-Item -LiteralPath $fullPath -Force
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            [void]$skipped.Add($relativePath)
            continue
        }

        try {
            $hash = Get-ProjectSha256 -Path $fullPath
            [void]$files.Add([pscustomobject]@{ Path = $relativePath; State = 'Present'; Length = $item.Length; Sha256 = $hash })
        }
        catch {
            [void]$skipped.Add($relativePath)
        }
    }

    return [pscustomobject]@{
        Success = $true
        Files = $files.ToArray()
        SkippedPaths = $skipped.ToArray()
        Message = 'Tracked and non-ignored untracked files were fingerprinted.'
    }
}

function Compare-ProjectSnapshots {
    param(
        [object]$Before,
        [object]$After
    )

    $changes = New-Object System.Collections.Generic.List[object]
    $beforeMap = @{}
    $afterMap = @{}
    foreach ($entry in @($Before.Files)) { $beforeMap[$entry.Path] = $entry }
    foreach ($entry in @($After.Files)) { $afterMap[$entry.Path] = $entry }

    $allPaths = @($beforeMap.Keys + $afterMap.Keys | Sort-Object -Unique)
    foreach ($path in $allPaths) {
        if (-not $beforeMap.ContainsKey($path)) {
            [void]$changes.Add([pscustomobject]@{ Path = $path; Change = 'Created' })
            continue
        }
        if (-not $afterMap.ContainsKey($path)) {
            [void]$changes.Add([pscustomobject]@{ Path = $path; Change = 'Deleted' })
            continue
        }

        $old = $beforeMap[$path]
        $new = $afterMap[$path]
        if ($old.State -ne $new.State -or $old.Length -ne $new.Length -or $old.Sha256 -ne $new.Sha256) {
            $change = if ($old.State -eq 'Present' -and $new.State -eq 'Missing') { 'Deleted' } elseif ($old.State -eq 'Missing' -and $new.State -eq 'Present') { 'Created' } else { 'Modified' }
            [void]$changes.Add([pscustomobject]@{ Path = $path; Change = $change })
        }
    }

    return $changes.ToArray()
}

function Get-ProjectDocumentationFindings {
    param(
        [string]$Root,
        [string[]]$Files,
        [string]$CheckId
    )

    $findings = New-Object System.Collections.Generic.List[object]
    foreach ($relativeFile in $Files) {
        $fullFile = Join-Path -Path $Root -ChildPath $relativeFile
        if (-not (Test-Path -LiteralPath $fullFile -PathType Leaf)) { continue }

        $lines = [IO.File]::ReadAllLines($fullFile)
        for ($index = 0; $index -lt $lines.Count; $index++) {
            $lineText = $lines[$index]
            foreach ($match in [regex]::Matches($lineText, '`(?<reference>[^`\r\n]+)`')) {
                $reference = $match.Groups['reference'].Value.Trim().TrimEnd('/', '\')
                if ($reference -match '[*?{}<>|]' -or $reference -match '^(?:https?://|res://)') { continue }
                if ($lineText -match '(?i)\b(?:future|futuro|when created|quando (?:for|estiver) criado)\b') { continue }

                $isProjectReference = $reference -match '^(?:AGENTS\.md|project\.godot|docs[/\\]|tools[/\\]|\.agents[/\\])' -or ($reference -match '^(?:AI_WORKFLOW|DECISIONS|ARCHITECTURE|GAME_DESIGN|ROADMAP)\.md$')
                if (-not $isProjectReference) { continue }

                $candidate = if ($reference -match '^(?:AGENTS\.md|project\.godot|docs[/\\]|tools[/\\]|\.agents[/\\])') {
                    Join-Path -Path $Root -ChildPath $reference
                }
                else {
                    Join-Path -Path (Split-Path -Parent $fullFile) -ChildPath $reference
                }

                if (-not (Test-Path -LiteralPath $candidate -ErrorAction SilentlyContinue)) {
                    [void]$findings.Add((New-ProjectFinding -CheckId $CheckId -Severity 'Error' -Category 'MissingDocumentationReference' -File $relativeFile -Line ($index + 1) -Message "Referenced repository path '$reference' does not exist."))
                }
            }
        }
    }
    return $findings.ToArray()
}

function Test-UntrackedWhitespace {
    param(
        [string]$Root,
        [string]$GitPath,
        [string]$CheckId
    )

    $findings = New-Object System.Collections.Generic.List[object]
    $listResult = Invoke-ProjectNativeCommand -FilePath $GitPath -Arguments @('ls-files', '--others', '--exclude-standard') -WorkingDirectory $Root
    if (-not $listResult.Started -or $listResult.ExitCode -ne 0) {
        [void]$findings.Add((New-ProjectFinding -CheckId $CheckId -Severity 'Error' -Category 'UntrackedEnumerationFailed' -File $null -Line $null -Message 'Non-ignored untracked files could not be enumerated.'))
        return [pscustomobject]@{ Success = $false; ExitCode = $listResult.ExitCode; CheckedFiles = @(); Findings = $findings.ToArray() }
    }

    $textExtensions = @('.cfg', '.gd', '.gitignore', '.godot', '.ini', '.json', '.md', '.ps1', '.toml', '.txt', '.yaml', '.yml')
    $checked = New-Object System.Collections.Generic.List[string]
    foreach ($relativeFile in @($listResult.Output | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
        $extension = [IO.Path]::GetExtension($relativeFile).ToLowerInvariant()
        $leafName = [IO.Path]::GetFileName($relativeFile).ToLowerInvariant()
        if ($textExtensions -notcontains $extension -and $leafName -ne '.gitignore') { continue }

        [void]$checked.Add($relativeFile)
        $diffResult = Invoke-ProjectNativeCommand -FilePath $GitPath -Arguments @('diff', '--no-index', '--check', '--no-color', '--', 'NUL', $relativeFile) -WorkingDirectory $Root
        if (-not $diffResult.Started -or $null -eq $diffResult.ExitCode -or $diffResult.ExitCode -gt 1) {
            [void]$findings.Add((New-ProjectFinding -CheckId $CheckId -Severity 'Error' -Category 'UntrackedWhitespaceCheckFailed' -File $relativeFile -Line $null -Message 'Git could not validate whitespace for this untracked text file.'))
            continue
        }

        foreach ($outputLine in @($diffResult.Output)) {
            if ($outputLine -match '(?i)(trailing whitespace|new blank line at EOF|space before tab in indent)') {
                [void]$findings.Add((New-ProjectFinding -CheckId $CheckId -Severity 'Error' -Category 'WhitespaceError' -File $relativeFile -Line $null -Message $outputLine.Trim()))
            }
        }
    }

    return [pscustomobject]@{
        Success = @($findings | Where-Object Severity -eq 'Error').Count -eq 0
        ExitCode = $listResult.ExitCode
        CheckedFiles = $checked.ToArray()
        Findings = $findings.ToArray()
    }
}

function ConvertTo-SafeProjectDiagnostic {
    param([string]$Text)

    $sanitized = [regex]::Replace($Text, '\x1B\[[0-?]*[ -/]*[@-~]', '')
    $sanitized = [regex]::Replace($sanitized, '[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]', '')
    $sanitized = [regex]::Replace($sanitized, '(?i)(?<prefix>\bAuthorization\b\s*[:=]\s*)(?:Bearer\s+)?[^\s,;]+', '${prefix}[REDACTED]')
    $sanitized = [regex]::Replace($sanitized, '(?i)\bBearer\s+[^\s,;]+', 'Bearer [REDACTED]')
    $assignmentPattern = '(?i)(?<prefix>\b(?:api[_-]?(?:key|token)|access[_-]?token|refresh[_-]?token|client[_-]?secret|private[_-]?key|token|password|passwd|secret)\b\s*[:=]\s*)(?:"[^"]*"|''[^'']*''|[^\s,;]+)'
    $sanitized = [regex]::Replace($sanitized, $assignmentPattern, '${prefix}[REDACTED]')
    if ($sanitized.Length -gt 1000) {
        $sanitized = $sanitized.Substring(0, 1000) + '... [truncated]'
    }
    return $sanitized.Trim()
}

function Invoke-GodotProjectImport {
    param(
        [string]$ExecutablePath,
        [string]$Root,
        [int]$TimeoutSeconds
    )

    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    $process = New-Object Diagnostics.Process
    $startInfo = New-Object Diagnostics.ProcessStartInfo
    $startInfo.FileName = $ExecutablePath
    $quotedRoot = '"' + $Root.Replace('"', '\"') + '"'
    $startInfo.Arguments = "--headless --path $quotedRoot --editor --import --quit"
    $startInfo.WorkingDirectory = $Root
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process.StartInfo = $startInfo

    try {
        if (-not $process.Start()) {
            return [pscustomobject]@{ Started = $false; TimedOut = $false; ExitCode = $null; DurationMs = $stopwatch.ElapsedMilliseconds; Output = @('Godot process did not start.'); Error = 'Process start returned false.' }
        }

        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            try { $process.Kill() } catch { }
            try { $process.WaitForExit() } catch { }
            $stopwatch.Stop()
            return [pscustomobject]@{ Started = $true; TimedOut = $true; ExitCode = $null; DurationMs = $stopwatch.ElapsedMilliseconds; Output = @('Godot import exceeded the configured timeout.'); Error = $null }
        }

        [Threading.Tasks.Task]::WaitAll(@($stdoutTask, $stderrTask))
        $stopwatch.Stop()
        $combined = @($stdoutTask.Result, $stderrTask.Result) -join [Environment]::NewLine
        $diagnostics = @([regex]::Split($combined, '\r?\n') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Last 80 | ForEach-Object { ConvertTo-SafeProjectDiagnostic -Text $_ })
        return [pscustomobject]@{ Started = $true; TimedOut = $false; ExitCode = $process.ExitCode; DurationMs = $stopwatch.ElapsedMilliseconds; Output = $diagnostics; Error = $null }
    }
    catch {
        $stopwatch.Stop()
        return [pscustomobject]@{ Started = $false; TimedOut = $false; ExitCode = $null; DurationMs = $stopwatch.ElapsedMilliseconds; Output = @('Godot process could not be started.'); Error = $_.Exception.Message }
    }
    finally {
        $process.Dispose()
    }
}

function Test-EndlessDungeonProject {
    [CmdletBinding()]
    param(
        [ValidateSet('Full', 'Quick')]
        [string]$Mode = 'Full',

        [ValidateRange(1, 3600)]
        [int]$GodotTimeoutSeconds = 120,

        [string]$RepositoryRoot
    )

    $totalStopwatch = [Diagnostics.Stopwatch]::StartNew()
    $root = if ($PSBoundParameters.ContainsKey('RepositoryRoot')) {
        [IO.Path]::GetFullPath($RepositoryRoot)
    }
    else {
        [IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath '..\..'))
    }
    $root = $root.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $checks = New-Object System.Collections.Generic.List[object]
    $allFindings = New-Object System.Collections.Generic.List[object]
    $limitations = New-Object System.Collections.Generic.List[string]
    $gitCommand = Get-Command -Name 'git' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    $gitPath = if ($gitCommand) { if ($gitCommand.Source) { $gitCommand.Source } else { $gitCommand.Path } } else { $null }
    $beforeSnapshot = Get-ProjectSnapshot -Root $root -GitPath $gitPath

    $componentStopwatch = [Diagnostics.Stopwatch]::StartNew()
    $componentFindings = New-Object System.Collections.Generic.List[object]
    $componentAvailability = @{}
    $componentDefinitions = @(
        [pscustomobject]@{ Name = 'Godot resolver'; Path = 'tools/setup/Resolve-Godot.ps1'; Function = 'Resolve-Godot' },
        [pscustomobject]@{ Name = 'environment validator'; Path = 'tools/validation/Validate-Environment.ps1'; Function = 'Test-ProjectEnvironment' },
        [pscustomobject]@{ Name = 'Skill validator'; Path = 'tools/validation/Validate-Skills.ps1'; Function = 'Test-RepositorySkills' }
    )
    foreach ($component in $componentDefinitions) {
        $componentAvailability[$component.Function] = $false
        $componentPath = Join-Path -Path $root -ChildPath $component.Path
        if (-not (Test-Path -LiteralPath $componentPath -PathType Leaf)) {
            [void]$componentFindings.Add((New-ProjectFinding -CheckId 'components' -Severity 'Error' -Category 'MissingValidationComponent' -File $component.Path -Line $null -Message "$($component.Name) is missing."))
            continue
        }
        try {
            $loadOutput = @(. $componentPath)
            if ($null -eq (Get-Command -Name $component.Function -CommandType Function -ErrorAction SilentlyContinue)) {
                [void]$componentFindings.Add((New-ProjectFinding -CheckId 'components' -Severity 'Error' -Category 'InvalidValidationComponent' -File $component.Path -Line $null -Message "$($component.Name) did not define $($component.Function)."))
            }
            else {
                $componentAvailability[$component.Function] = $true
            }
        }
        catch {
            [void]$componentFindings.Add((New-ProjectFinding -CheckId 'components' -Severity 'Error' -Category 'ValidationComponentLoadFailed' -File $component.Path -Line $null -Message "$($component.Name) could not be loaded."))
        }
    }
    $componentStopwatch.Stop()
    foreach ($finding in $componentFindings) { [void]$allFindings.Add($finding) }
    $componentsValid = @($componentFindings | Where-Object Severity -eq 'Error').Count -eq 0
    [void]$checks.Add((New-ProjectCheck -Id 'components' -Description 'Required validation components are present and expose their public functions.' -Mandatory $true -Status $(if ($componentsValid) { 'Passed' } else { 'Failed' }) -DurationMs $componentStopwatch.ElapsedMilliseconds -NativeExitCode $null -Findings $componentFindings.ToArray() -Data $componentDefinitions))

    $environmentResult = $null
    $environmentComponentsValid = $componentAvailability['Resolve-Godot'] -and $componentAvailability['Test-ProjectEnvironment']
    if ($environmentComponentsValid) {
        $checkStopwatch = [Diagnostics.Stopwatch]::StartNew()
        $environmentFindings = New-Object System.Collections.Generic.List[object]
        try {
            $environmentResult = Test-ProjectEnvironment
            if ($null -eq $environmentResult -or $null -eq $environmentResult.PSObject.Properties['Success']) {
                [void]$environmentFindings.Add((New-ProjectFinding -CheckId 'environment' -Severity 'Error' -Category 'InvalidComponentResult' -File 'tools/validation/Validate-Environment.ps1' -Line $null -Message 'Environment validator returned an invalid result.'))
            }
            else {
                foreach ($capability in @($environmentResult.RequiredCapabilities | Where-Object { -not $_.Available })) {
                    [void]$environmentFindings.Add((New-ProjectFinding -CheckId 'environment' -Severity 'Error' -Category 'MissingRequiredCapability' -File $null -Line $null -Message "$($capability.Name): $($capability.Message)"))
                }
                foreach ($capability in @($environmentResult.OptionalCapabilities | Where-Object { -not $_.Available })) {
                    [void]$environmentFindings.Add((New-ProjectFinding -CheckId 'environment' -Severity 'Warning' -Category 'MissingOptionalCapability' -File $null -Line $null -Message "$($capability.Name): $($capability.Message)"))
                }
            }
        }
        catch {
            [void]$environmentFindings.Add((New-ProjectFinding -CheckId 'environment' -Severity 'Error' -Category 'EnvironmentValidationFailed' -File 'tools/validation/Validate-Environment.ps1' -Line $null -Message 'Environment validation raised an exception.'))
        }
        $checkStopwatch.Stop()
        foreach ($finding in $environmentFindings) { [void]$allFindings.Add($finding) }
        $environmentPassed = $null -ne $environmentResult -and $null -ne $environmentResult.PSObject.Properties['Success'] -and [bool]$environmentResult.Success -and @($environmentFindings | Where-Object Severity -eq 'Error').Count -eq 0
        [void]$checks.Add((New-ProjectCheck -Id 'environment' -Description 'Required environment capabilities are available.' -Mandatory $true -Status $(if ($environmentPassed) { 'Passed' } else { 'Failed' }) -DurationMs $checkStopwatch.ElapsedMilliseconds -NativeExitCode $null -Findings $environmentFindings.ToArray() -Data $environmentResult))
    }
    else {
        [void]$checks.Add((New-ProjectCheck -Id 'environment' -Description 'Required environment capabilities are available.' -Mandatory $true -Status 'Skipped' -DurationMs 0 -NativeExitCode $null -Findings @((New-ProjectFinding -CheckId 'environment' -Severity 'Information' -Category 'DependencyFailed' -File $null -Line $null -Message 'Environment validation was skipped because a validation component is unavailable.')) -Data $null))
    }

    $skillsResult = $null
    $skillComponentValid = $componentAvailability['Test-RepositorySkills']
    if ($skillComponentValid) {
        $checkStopwatch = [Diagnostics.Stopwatch]::StartNew()
        $skillFindings = New-Object System.Collections.Generic.List[object]
        try {
            $skillsResult = Test-RepositorySkills -RepositoryRoot $root
            if ($null -eq $skillsResult -or $null -eq $skillsResult.PSObject.Properties['Success']) {
                [void]$skillFindings.Add((New-ProjectFinding -CheckId 'skills' -Severity 'Error' -Category 'InvalidComponentResult' -File 'tools/validation/Validate-Skills.ps1' -Line $null -Message 'Skill validator returned an invalid result.'))
            }
            else {
                foreach ($finding in @($skillsResult.Findings)) {
                    [void]$skillFindings.Add((New-ProjectFinding -CheckId 'skills' -Severity $finding.Severity -Category $finding.Category -File $finding.File -Line $finding.Line -Message $finding.Message))
                }
            }
        }
        catch {
            [void]$skillFindings.Add((New-ProjectFinding -CheckId 'skills' -Severity 'Error' -Category 'SkillValidationFailed' -File 'tools/validation/Validate-Skills.ps1' -Line $null -Message 'Skill validation raised an exception.'))
        }
        $checkStopwatch.Stop()
        foreach ($finding in $skillFindings) { [void]$allFindings.Add($finding) }
        $skillsPassed = $null -ne $skillsResult -and $null -ne $skillsResult.PSObject.Properties['Success'] -and [bool]$skillsResult.Success -and @($skillFindings | Where-Object Severity -eq 'Error').Count -eq 0
        [void]$checks.Add((New-ProjectCheck -Id 'skills' -Description 'Repository-local Skills satisfy the foundational manifest rules.' -Mandatory $true -Status $(if ($skillsPassed) { 'Passed' } else { 'Failed' }) -DurationMs $checkStopwatch.ElapsedMilliseconds -NativeExitCode $null -Findings $skillFindings.ToArray() -Data $skillsResult))
    }
    else {
        [void]$checks.Add((New-ProjectCheck -Id 'skills' -Description 'Repository-local Skills satisfy the foundational manifest rules.' -Mandatory $true -Status 'Skipped' -DurationMs 0 -NativeExitCode $null -Findings @((New-ProjectFinding -CheckId 'skills' -Severity 'Information' -Category 'DependencyFailed' -File $null -Line $null -Message 'Skill validation was skipped because a validation component is unavailable.')) -Data $null))
    }

    $requiredFiles = @('project.godot', 'AGENTS.md', 'docs/AI_WORKFLOW.md', 'docs/DECISIONS.md', 'docs/ARCHITECTURE.md', 'docs/GAME_DESIGN.md', 'docs/ROADMAP.md')
    $checkStopwatch = [Diagnostics.Stopwatch]::StartNew()
    $structureFindings = New-Object System.Collections.Generic.List[object]
    foreach ($requiredFile in $requiredFiles) {
        if (-not (Test-Path -LiteralPath (Join-Path $root $requiredFile) -PathType Leaf)) {
            [void]$structureFindings.Add((New-ProjectFinding -CheckId 'project-structure' -Severity 'Error' -Category 'MissingRequiredProjectFile' -File $requiredFile -Line $null -Message 'Required project file is missing.'))
        }
    }
    $checkStopwatch.Stop()
    foreach ($finding in $structureFindings) { [void]$allFindings.Add($finding) }
    $structurePassed = $structureFindings.Count -eq 0
    [void]$checks.Add((New-ProjectCheck -Id 'project-structure' -Description 'Required Endless Dungeon project files are present.' -Mandatory $true -Status $(if ($structurePassed) { 'Passed' } else { 'Failed' }) -DurationMs $checkStopwatch.ElapsedMilliseconds -NativeExitCode $null -Findings $structureFindings.ToArray() -Data ([pscustomobject]@{ RequiredFiles = $requiredFiles })))

    $checkStopwatch = [Diagnostics.Stopwatch]::StartNew()
    $documentationFiles = @('AGENTS.md', 'docs/AI_WORKFLOW.md', 'docs/DECISIONS.md', 'docs/ARCHITECTURE.md', 'docs/GAME_DESIGN.md', 'docs/ROADMAP.md')
    $documentationFindings = @(Get-ProjectDocumentationFindings -Root $root -Files $documentationFiles -CheckId 'documentation-references')
    $checkStopwatch.Stop()
    foreach ($finding in $documentationFindings) { [void]$allFindings.Add($finding) }
    [void]$checks.Add((New-ProjectCheck -Id 'documentation-references' -Description 'Reliable repository-relative references in core documentation resolve.' -Mandatory $true -Status $(if (@($documentationFindings | Where-Object Severity -eq 'Error').Count -eq 0) { 'Passed' } else { 'Failed' }) -DurationMs $checkStopwatch.ElapsedMilliseconds -NativeExitCode $null -Findings $documentationFindings -Data ([pscustomobject]@{ Files = $documentationFiles })))

    $gitContextValid = $false
    $gitContextResult = $null
    $checkStopwatch = [Diagnostics.Stopwatch]::StartNew()
    $gitFindings = New-Object System.Collections.Generic.List[object]
    if ([string]::IsNullOrWhiteSpace($gitPath)) {
        [void]$gitFindings.Add((New-ProjectFinding -CheckId 'git-context' -Severity 'Error' -Category 'GitUnavailable' -File $null -Line $null -Message 'Git is required for repository validation.'))
    }
    else {
        $gitContextResult = Invoke-ProjectNativeCommand -FilePath $gitPath -Arguments @('rev-parse', '--show-toplevel') -WorkingDirectory $root
        if ($gitContextResult.Started -and $gitContextResult.ExitCode -eq 0 -and $gitContextResult.Output.Count -gt 0) {
            $reportedRoot = [IO.Path]::GetFullPath($gitContextResult.Output[-1].Trim()).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
            $comparison = if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
            $gitContextValid = $reportedRoot.Equals($root, $comparison)
        }
        if (-not $gitContextValid) {
            [void]$gitFindings.Add((New-ProjectFinding -CheckId 'git-context' -Severity 'Error' -Category 'InvalidGitRepositoryContext' -File $null -Line $null -Message 'Validation root is not the active Git repository root.'))
        }
    }
    $gitStatusData = $null
    if ($gitContextValid) {
        $statusResult = Invoke-ProjectNativeCommand -FilePath $gitPath -Arguments @('status', '--porcelain=v1', '--untracked-files=all') -WorkingDirectory $root
        $branchResult = Invoke-ProjectNativeCommand -FilePath $gitPath -Arguments @('rev-parse', '--abbrev-ref', 'HEAD') -WorkingDirectory $root
        $gitStatusData = [pscustomobject]@{
            Branch = if ($branchResult.ExitCode -eq 0) { $branchResult.Output[-1] } else { $null }
            Dirty = $statusResult.ExitCode -ne 0 -or $statusResult.Output.Count -gt 0
            Entries = @($statusResult.Output)
        }
    }
    $checkStopwatch.Stop()
    foreach ($finding in $gitFindings) { [void]$allFindings.Add($finding) }
    [void]$checks.Add((New-ProjectCheck -Id 'git-context' -Description 'Git is available and the validation root matches the active repository.' -Mandatory $true -Status $(if ($gitContextValid) { 'Passed' } else { 'Failed' }) -DurationMs $checkStopwatch.ElapsedMilliseconds -NativeExitCode $(if ($null -ne $gitContextResult) { $gitContextResult.ExitCode } else { $null }) -Findings $gitFindings.ToArray() -Data $gitStatusData))

    foreach ($whitespaceCheck in @(
        [pscustomobject]@{ Id = 'whitespace-unstaged'; Description = 'Tracked unstaged changes pass Git whitespace validation.'; Arguments = @('diff', '--check') },
        [pscustomobject]@{ Id = 'whitespace-staged'; Description = 'Staged changes pass Git whitespace validation.'; Arguments = @('diff', '--cached', '--check') }
    )) {
        if (-not $gitContextValid) {
            [void]$checks.Add((New-ProjectCheck -Id $whitespaceCheck.Id -Description $whitespaceCheck.Description -Mandatory $true -Status 'Skipped' -DurationMs 0 -NativeExitCode $null -Findings @((New-ProjectFinding -CheckId $whitespaceCheck.Id -Severity 'Information' -Category 'DependencyFailed' -File $null -Line $null -Message 'Whitespace validation was skipped because Git context validation failed.')) -Data $null))
            continue
        }
        $checkStopwatch = [Diagnostics.Stopwatch]::StartNew()
        $diffResult = Invoke-ProjectNativeCommand -FilePath $gitPath -Arguments $whitespaceCheck.Arguments -WorkingDirectory $root
        $diffFindings = New-Object System.Collections.Generic.List[object]
        if (-not $diffResult.Started -or $diffResult.ExitCode -ne 0) {
            $diagnosticLines = @($diffResult.Output | Where-Object { $_ -match '(?i)(trailing whitespace|new blank line at EOF|space before tab in indent)' })
            $message = if ($diagnosticLines.Count -gt 0) { $diagnosticLines -join [Environment]::NewLine } else { 'Git whitespace validation failed.' }
            [void]$diffFindings.Add((New-ProjectFinding -CheckId $whitespaceCheck.Id -Severity 'Error' -Category 'WhitespaceError' -File $null -Line $null -Message $message))
        }
        $checkStopwatch.Stop()
        foreach ($finding in $diffFindings) { [void]$allFindings.Add($finding) }
        [void]$checks.Add((New-ProjectCheck -Id $whitespaceCheck.Id -Description $whitespaceCheck.Description -Mandatory $true -Status $(if ($diffFindings.Count -eq 0) { 'Passed' } else { 'Failed' }) -DurationMs $checkStopwatch.ElapsedMilliseconds -NativeExitCode $diffResult.ExitCode -Findings $diffFindings.ToArray() -Data $null))
    }

    if ($gitContextValid) {
        $checkStopwatch = [Diagnostics.Stopwatch]::StartNew()
        $untrackedWhitespace = Test-UntrackedWhitespace -Root $root -GitPath $gitPath -CheckId 'whitespace-untracked'
        $checkStopwatch.Stop()
        foreach ($finding in $untrackedWhitespace.Findings) { [void]$allFindings.Add($finding) }
        [void]$checks.Add((New-ProjectCheck -Id 'whitespace-untracked' -Description 'Relevant non-ignored untracked text files pass Git whitespace validation.' -Mandatory $true -Status $(if ($untrackedWhitespace.Success) { 'Passed' } else { 'Failed' }) -DurationMs $checkStopwatch.ElapsedMilliseconds -NativeExitCode $untrackedWhitespace.ExitCode -Findings $untrackedWhitespace.Findings -Data ([pscustomobject]@{ CheckedFiles = $untrackedWhitespace.CheckedFiles })))
    }
    else {
        [void]$checks.Add((New-ProjectCheck -Id 'whitespace-untracked' -Description 'Relevant non-ignored untracked text files pass Git whitespace validation.' -Mandatory $true -Status 'Skipped' -DurationMs 0 -NativeExitCode $null -Findings @((New-ProjectFinding -CheckId 'whitespace-untracked' -Severity 'Information' -Category 'DependencyFailed' -File $null -Line $null -Message 'Untracked whitespace validation was skipped because Git context validation failed.')) -Data $null))
    }

    if ($Mode -eq 'Quick') {
        [void]$checks.Add((New-ProjectCheck -Id 'godot-import' -Description 'Godot imports the project headlessly within the configured timeout.' -Mandatory $false -Status 'Skipped' -DurationMs 0 -NativeExitCode $null -Findings @((New-ProjectFinding -CheckId 'godot-import' -Severity 'Information' -Category 'QuickMode' -File $null -Line $null -Message 'Quick mode intentionally skips the Godot headless import.')) -Data ([pscustomobject]@{ TimeoutSeconds = $GodotTimeoutSeconds })))
    }
    else {
        $godotCapability = $null
        if ($null -ne $environmentResult -and $null -ne $environmentResult.PSObject.Properties['RequiredCapabilities']) {
            $godotCapability = $environmentResult.RequiredCapabilities | Where-Object Name -eq 'Godot' | Select-Object -First 1
        }
        $godotExecutable = if ($null -ne $godotCapability -and $godotCapability.Available) { $godotCapability.ExecutablePath } else { $null }
        if (-not $structurePassed -or [string]::IsNullOrWhiteSpace($godotExecutable) -or -not (Test-Path -LiteralPath $godotExecutable -PathType Leaf)) {
            [void]$checks.Add((New-ProjectCheck -Id 'godot-import' -Description 'Godot imports the project headlessly within the configured timeout.' -Mandatory $true -Status 'Skipped' -DurationMs 0 -NativeExitCode $null -Findings @((New-ProjectFinding -CheckId 'godot-import' -Severity 'Information' -Category 'DependencyFailed' -File $null -Line $null -Message 'Godot import was skipped because its validated executable or project structure prerequisite failed.')) -Data ([pscustomobject]@{ TimeoutSeconds = $GodotTimeoutSeconds })))
        }
        else {
            $importResult = Invoke-GodotProjectImport -ExecutablePath $godotExecutable -Root $root -TimeoutSeconds $GodotTimeoutSeconds
            $importFindings = New-Object System.Collections.Generic.List[object]
            if (-not $importResult.Started) {
                [void]$importFindings.Add((New-ProjectFinding -CheckId 'godot-import' -Severity 'Error' -Category 'GodotProcessStartFailed' -File $null -Line $null -Message 'Godot import process could not be started.'))
            }
            elseif ($importResult.TimedOut) {
                [void]$importFindings.Add((New-ProjectFinding -CheckId 'godot-import' -Severity 'Error' -Category 'GodotImportTimeout' -File $null -Line $null -Message "Godot import exceeded $GodotTimeoutSeconds second(s)."))
            }
            elseif ($importResult.ExitCode -ne 0) {
                [void]$importFindings.Add((New-ProjectFinding -CheckId 'godot-import' -Severity 'Error' -Category 'GodotImportFailed' -File $null -Line $null -Message "Godot import returned exit code $($importResult.ExitCode)."))
            }
            foreach ($finding in $importFindings) { [void]$allFindings.Add($finding) }
            [void]$checks.Add((New-ProjectCheck -Id 'godot-import' -Description 'Godot imports the project headlessly within the configured timeout.' -Mandatory $true -Status $(if ($importFindings.Count -eq 0) { 'Passed' } else { 'Failed' }) -DurationMs $importResult.DurationMs -NativeExitCode $importResult.ExitCode -Findings $importFindings.ToArray() -Data ([pscustomobject]@{ TimeoutSeconds = $GodotTimeoutSeconds; TimedOut = $importResult.TimedOut; Diagnostics = $importResult.Output })))
        }
    }

    [void]$limitations.Add('Headless import validates project loading and resource import, not gameplay or runtime behavior.')
    [void]$limitations.Add('Automated gameplay tests are not available in this project yet.')
    [void]$limitations.Add('Side-effect detection fingerprints tracked and non-ignored untracked files; ignored caches, ignored local artifacts, Git index-only changes, directories, and skipped reparse-point files are outside its scope.')
    [void]$limitations.Add('A detected repository change is reported without attributing it to the validator or to a concurrent process.')
    [void]$checks.Add((New-ProjectCheck -Id 'gameplay-tests' -Description 'Automated gameplay and runtime behavior tests execute.' -Mandatory $false -Status 'Skipped' -DurationMs 0 -NativeExitCode $null -Findings @((New-ProjectFinding -CheckId 'gameplay-tests' -Severity 'Information' -Category 'UnavailableValidation' -File $null -Line $null -Message 'Automated gameplay tests are not available.')) -Data $null))

    $sideEffectStopwatch = [Diagnostics.Stopwatch]::StartNew()
    $afterSnapshot = Get-ProjectSnapshot -Root $root -GitPath $gitPath
    $sideEffectFindings = New-Object System.Collections.Generic.List[object]
    $sideEffectStatus = 'Passed'
    $changes = @()
    if (-not $beforeSnapshot.Success -or -not $afterSnapshot.Success) {
        $sideEffectStatus = 'Skipped'
        [void]$sideEffectFindings.Add((New-ProjectFinding -CheckId 'repository-side-effects' -Severity 'Information' -Category 'SnapshotUnavailable' -File $null -Line $null -Message 'Repository side effects could not be compared because a snapshot was unavailable.'))
    }
    else {
        $changes = @(Compare-ProjectSnapshots -Before $beforeSnapshot -After $afterSnapshot)
        foreach ($change in $changes) {
            [void]$sideEffectFindings.Add((New-ProjectFinding -CheckId 'repository-side-effects' -Severity 'Error' -Category 'RepositoryStateChanged' -File $change.Path -Line $null -Message "Repository-visible file was $($change.Change.ToLowerInvariant()) during validation; the cause was not determined."))
        }
        if ($changes.Count -gt 0) { $sideEffectStatus = 'Failed' }
    }
    foreach ($path in @($beforeSnapshot.SkippedPaths + $afterSnapshot.SkippedPaths | Sort-Object -Unique)) {
        [void]$sideEffectFindings.Add((New-ProjectFinding -CheckId 'repository-side-effects' -Severity 'Warning' -Category 'FingerprintSkipped' -File $path -Line $null -Message 'File fingerprint was skipped because it could not be read safely.'))
    }
    $sideEffectStopwatch.Stop()
    foreach ($finding in $sideEffectFindings) { [void]$allFindings.Add($finding) }
    [void]$checks.Add((New-ProjectCheck -Id 'repository-side-effects' -Description 'Repository-visible file content is unchanged by the validation run.' -Mandatory $true -Status $sideEffectStatus -DurationMs $sideEffectStopwatch.ElapsedMilliseconds -NativeExitCode $null -Findings $sideEffectFindings.ToArray() -Data ([pscustomobject]@{ Changes = $changes; BeforeFileCount = @($beforeSnapshot.Files).Count; AfterFileCount = @($afterSnapshot.Files).Count; ExcludedByGitIgnore = $true })))

    $totalStopwatch.Stop()
    $checkArray = $checks.ToArray()
    $failedMandatory = @($checkArray | Where-Object { $_.Mandatory -and $_.Status -eq 'Failed' })
    $failedDependencies = @($checkArray | Where-Object { $_.Mandatory -and $_.Status -eq 'Skipped' })
    $success = $failedMandatory.Count -eq 0 -and $failedDependencies.Count -eq 0
    $findingArray = @($checkArray | ForEach-Object { @($_.Findings) })

    return [pscustomobject]@{
        SchemaVersion = 1
        Success = $success
        Mode = $Mode
        RepositoryRoot = $root
        DurationMs = $totalStopwatch.ElapsedMilliseconds
        Counts = [pscustomobject]@{
            Passed = @($checkArray | Where-Object Status -eq 'Passed').Count
            Failed = @($checkArray | Where-Object Status -eq 'Failed').Count
            Skipped = @($checkArray | Where-Object Status -eq 'Skipped').Count
            Warnings = @($findingArray | Where-Object Severity -eq 'Warning').Count
        }
        Checks = $checkArray
        Findings = $findingArray
        SideEffects = [pscustomobject]@{
            Status = $sideEffectStatus
            Changes = $changes
            BeforeFileCount = @($beforeSnapshot.Files).Count
            AfterFileCount = @($afterSnapshot.Files).Count
            SkippedPaths = @($beforeSnapshot.SkippedPaths + $afterSnapshot.SkippedPaths | Sort-Object -Unique)
        }
        Limitations = $limitations.ToArray()
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $parameters = @{
        Mode = $Mode
        GodotTimeoutSeconds = $GodotTimeoutSeconds
    }
    if ($PSBoundParameters.ContainsKey('RepositoryRoot')) {
        $parameters.RepositoryRoot = $RepositoryRoot
    }
    try {
        $result = Test-EndlessDungeonProject @parameters
    }
    catch {
        $failureFinding = New-ProjectFinding -CheckId 'validator-internal' -Severity 'Error' -Category 'UnexpectedValidatorFailure' -File 'tools/validation/Validate-Project.ps1' -Line $null -Message 'Project validation stopped because of an unexpected internal error.'
        $failureCheck = New-ProjectCheck -Id 'validator-internal' -Description 'The project validator completes its orchestration.' -Mandatory $true -Status 'Failed' -DurationMs 0 -NativeExitCode $null -Findings @($failureFinding) -Data $null
        $result = [pscustomobject]@{
            SchemaVersion = 1
            Success = $false
            Mode = $Mode
            RepositoryRoot = if ($PSBoundParameters.ContainsKey('RepositoryRoot')) { [IO.Path]::GetFullPath($RepositoryRoot) } else { [IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath '..\..')) }
            DurationMs = 0
            Counts = [pscustomobject]@{ Passed = 0; Failed = 1; Skipped = 0; Warnings = 0 }
            Checks = @($failureCheck)
            Findings = @($failureFinding)
            SideEffects = [pscustomobject]@{ Status = 'Skipped'; Changes = @(); BeforeFileCount = 0; AfterFileCount = 0; SkippedPaths = @() }
            Limitations = @('Validation did not complete, so repository side effects could not be compared.')
        }
    }

    if ($Json) {
        $result | ConvertTo-Json -Depth 15
    }
    else {
        Write-Output "Endless Dungeon project validation ($($result.Mode))"
        Write-Output "Repository: $($result.RepositoryRoot)"
        Write-Output "Duration: $($result.DurationMs) ms"
        Write-Output ''
        foreach ($check in $result.Checks) {
            $nativeExit = if ($null -ne $check.NativeExitCode) { "; native exit $($check.NativeExitCode)" } else { '' }
            Write-Output "[$($check.Status.ToUpperInvariant())] $($check.Id) - $($check.Description) ($($check.DurationMs) ms$nativeExit)"
        }
        if ($result.Findings.Count -gt 0) {
            Write-Output ''
            Write-Output 'Findings:'
            foreach ($finding in $result.Findings) {
                $location = if ($finding.File) { if ($finding.Line) { "$($finding.File):$($finding.Line)" } else { $finding.File } } else { 'repository' }
                Write-Output "[$($finding.Severity.ToUpperInvariant())][$($finding.Category)] $location - $($finding.Message)"
            }
        }
        Write-Output ''
        Write-Output "Checks: $($result.Counts.Passed) passed, $($result.Counts.Failed) failed, $($result.Counts.Skipped) skipped; $($result.Counts.Warnings) warning(s)."
        if ($result.Success) { Write-Output '[PASS] Mandatory project validation checks passed.' } else { Write-Output '[FAIL] One or more mandatory project validation checks did not pass.' }
    }

    if ($result.Success) { exit 0 }
    exit 1
}
