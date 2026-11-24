#Requires -Version 5.1

<#
.SYNOPSIS
Validates repository-local Endless Dungeon Skills.

.DESCRIPTION
Discovers Skill directories under .agents/skills and validates the six foundational
Skills plus any additional Skills. The validator checks the repository context,
SKILL.md structure, the project's single-line frontmatter subset, repository-relative
references, Git ignore rules, and conservative security patterns.

Supported frontmatter consists of opening and closing --- delimiter lines followed
by single-line key: value metadata. name and description are required. Nested YAML,
lists, multiline scalars, anchors, tags, quoted scalars, and flow collections are
reported as unsupported rather than interpreted.

This is a repository-specific deterministic validator. It is not equivalent to the
official OpenAI Python-based Skill validator and does not claim official format
conformance.

Human-readable output is the default. -Json emits one JSON document. The script
returns exit code 0 when no errors are found and 1 when mandatory validation fails;
warnings alone do not fail validation. Dot-source the file and call
Test-RepositorySkills to reuse the validator without terminating the caller.

.PARAMETER Json
Emits the structured validation result as JSON.

.PARAMETER RepositoryRoot
Overrides the root derived from the script location. Intended for controlled fixtures
and future automation; ordinary project validation should omit this parameter.

.EXAMPLE
.\tools\validation\Validate-Skills.ps1

.EXAMPLE
.\tools\validation\Validate-Skills.ps1 -Json

.EXAMPLE
. .\tools\validation\Validate-Skills.ps1
$result = Test-RepositorySkills
#>
[CmdletBinding()]
param(
    [switch]$Json,

    [string]$RepositoryRoot
)

$script:FoundationalSkillNames = @(
    'project-context',
    'game-design',
    'feature-development',
    'asset-generation',
    'game-validation',
    'code-review'
)

function New-SkillFinding {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Error', 'Warning')]
        [string]$Severity,

        [Parameter(Mandatory = $true)]
        [string]$Category,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Validation', 'PolicyViolation', 'Heuristic')]
        [string]$Classification,

        [AllowNull()]
        [string]$Skill,

        [AllowNull()]
        [string]$File,

        [AllowNull()]
        [object]$Line,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    [pscustomobject]@{
        Severity       = $Severity
        Category       = $Category
        Classification = $Classification
        Skill          = $Skill
        File           = $File
        Line           = $Line
        Message        = $Message
    }
}

function Add-SkillFinding {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$AllFindings,

        [AllowNull()]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$SkillFindings,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Error', 'Warning')]
        [string]$Severity,

        [Parameter(Mandatory = $true)]
        [string]$Category,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Validation', 'PolicyViolation', 'Heuristic')]
        [string]$Classification,

        [AllowNull()]
        [string]$Skill,

        [AllowNull()]
        [string]$File,

        [AllowNull()]
        [object]$Line,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $finding = New-SkillFinding -Severity $Severity -Category $Category -Classification $Classification -Skill $Skill -File $File -Line $Line -Message $Message
    [void]$AllFindings.Add($finding)
    if ($null -ne $SkillFindings) {
        [void]$SkillFindings.Add($finding)
    }
}

function Get-RepositoryRelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $normalizedRoot = [IO.Path]::GetFullPath($Root).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $normalizedPath = [IO.Path]::GetFullPath($Path)
    $prefix = $normalizedRoot + [IO.Path]::DirectorySeparatorChar
    $comparison = if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
        [StringComparison]::OrdinalIgnoreCase
    }
    else {
        [StringComparison]::Ordinal
    }

    if ($normalizedPath.Equals($normalizedRoot, $comparison)) {
        return '.'
    }
    if (-not $normalizedPath.StartsWith($prefix, $comparison)) {
        return $null
    }
    return $normalizedPath.Substring($prefix.Length).Replace([IO.Path]::DirectorySeparatorChar, '/')
}

function Invoke-SkillGit {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GitPath,

        [Parameter(Mandatory = $true)]
        [string]$Root,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $callerErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& $GitPath -C $Root @Arguments 2>&1 | ForEach-Object { $_.ToString() })
        $exitCode = $LASTEXITCODE
    }
    catch {
        return [pscustomobject]@{
            ExitCode = $null
            Output   = @()
            Executed = $false
        }
    }
    finally {
        $ErrorActionPreference = $callerErrorActionPreference
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Output   = $output
        Executed = $true
    }
}

function Test-PlaceholderCredentialValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    $normalized = $Value.Trim().Trim('"').Trim("'")
    if ([string]::IsNullOrWhiteSpace($normalized)) {
        return $true
    }
    return $normalized -match '(?i)^(?:\$\{[^}]+\}|\$env:[A-Z0-9_]+|<[^>]+>|YOUR[_-].+|REPLACE[_-].+|(?:EXAMPLE|SAMPLE|DUMMY|FAKE|TEST)[_-].+|.+[_-](?:PLACEHOLDER|EXAMPLE)|EXAMPLE|PLACEHOLDER|REDACTED|NONE|NULL|\*+|X+)$'
}

function Test-SkillSecurity {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Lines,

        [Parameter(Mandatory = $true)]
        [string]$Skill,

        [Parameter(Mandatory = $true)]
        [string]$RelativeFile,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$AllFindings,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$SkillFindings
    )

    $absolutePathPattern = '(?i)(?:[A-Z]:[\\/](?:Users|Documents and Settings)[\\/][^\s`]+|\\\\[A-Za-z0-9._-]+\\[A-Za-z0-9$._-]+\\|/(?:home|Users)/[^/\s`]+/)'
    $credentialAssignmentPattern = '(?i)\b(?:api[_-]?key|access[_-]?token|auth[_-]?token|password|client[_-]?secret|private[_-]?token)\b\s*[:=]\s*(?<value>[^\s#]+)'
    $tokenPatterns = @(
        '(?i)\bghp_[A-Za-z0-9]{20,}\b',
        '(?i)\bgithub_pat_[A-Za-z0-9_]{20,}\b',
        '(?i)\bsk-[A-Za-z0-9_-]{20,}\b',
        '(?i)\bBearer\s+[A-Za-z0-9._~-]{20,}\b',
        '\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b'
    )

    for ($index = 0; $index -lt $Lines.Count; $index++) {
        $line = $Lines[$index]
        $lineNumber = $index + 1

        if ($line -match $absolutePathPattern) {
            Add-SkillFinding -AllFindings $AllFindings -SkillFindings $SkillFindings -Severity 'Error' -Category 'MachineSpecificPath' -Classification 'PolicyViolation' -Skill $Skill -File $RelativeFile -Line $lineNumber -Message 'Machine-specific absolute filesystem path detected.'
        }
        if ($line -match '-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----') {
            Add-SkillFinding -AllFindings $AllFindings -SkillFindings $SkillFindings -Severity 'Error' -Category 'PrivateKeyMarker' -Classification 'PolicyViolation' -Skill $Skill -File $RelativeFile -Line $lineNumber -Message 'Private key marker detected.'
        }

        $assignmentMatches = [regex]::Matches($line, $credentialAssignmentPattern)
        foreach ($assignmentMatch in $assignmentMatches) {
            $value = $assignmentMatch.Groups['value'].Value
            if (-not (Test-PlaceholderCredentialValue -Value $value)) {
                Add-SkillFinding -AllFindings $AllFindings -SkillFindings $SkillFindings -Severity 'Error' -Category 'CredentialAssignment' -Classification 'PolicyViolation' -Skill $Skill -File $RelativeFile -Line $lineNumber -Message 'Credential-like assignment detected; value redacted.'
            }
        }

        foreach ($tokenPattern in $tokenPatterns) {
            $tokenMatch = [regex]::Match($line, $tokenPattern)
            if ($tokenMatch.Success -and $tokenMatch.Value -notmatch '(?i)(?:X{8,}|PLACEHOLDER|EXAMPLE|REDACTED)') {
                Add-SkillFinding -AllFindings $AllFindings -SkillFindings $SkillFindings -Severity 'Warning' -Category 'AuthenticationTokenPattern' -Classification 'Heuristic' -Skill $Skill -File $RelativeFile -Line $lineNumber -Message 'Authentication token pattern detected; value redacted.'
                break
            }
        }
    }
}

function Test-SkillReferences {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Lines,

        [Parameter(Mandatory = $true)]
        [string]$Root,

        [Parameter(Mandatory = $true)]
        [string]$Skill,

        [Parameter(Mandatory = $true)]
        [string]$RelativeFile,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$AllFindings,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$SkillFindings
    )

    $knownRootPattern = '^(?:\.agents|docs|tools|assets|data|scenes|scripts)(?:[\\/].+)?[\\/]?$'
    $knownRootFiles = @('AGENTS.md', 'project.godot')
    $rootFullPath = [IO.Path]::GetFullPath($Root).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $rootPrefix = $rootFullPath + [IO.Path]::DirectorySeparatorChar
    $comparison = if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }

    for ($index = 0; $index -lt $Lines.Count; $index++) {
        $line = $Lines[$index]
        $matches = [regex]::Matches($line, '`(?<reference>[^`\r\n]+)`')
        foreach ($match in $matches) {
            $reference = $match.Groups['reference'].Value.Trim()
            if ([string]::IsNullOrWhiteSpace($reference) -or $reference -match '^[A-Za-z][A-Za-z0-9+.-]*://' -or $reference.StartsWith('-')) {
                continue
            }

            $isKnownFile = $knownRootFiles -contains $reference
            $isKnownPath = $reference -match $knownRootPattern
            if (-not $isKnownFile -and -not $isKnownPath) {
                continue
            }

            if ($reference -match '[*?{}<>\[\]]' -or $reference -match '(^|[\\/])\.\.([\\/]|$)') {
                Add-SkillFinding -AllFindings $AllFindings -SkillFindings $SkillFindings -Severity 'Warning' -Category 'AmbiguousRepositoryReference' -Classification 'Heuristic' -Skill $Skill -File $RelativeFile -Line ($index + 1) -Message 'Repository-like reference is ambiguous and was not required to exist.'
                continue
            }

            $conditionalReference = $line -match '(?i)\b(?:future|futuro|if it exists|when it exists|quando existir)\b'
            $platformReference = $reference.Replace('/', [IO.Path]::DirectorySeparatorChar).Replace('\', [IO.Path]::DirectorySeparatorChar).TrimEnd([IO.Path]::DirectorySeparatorChar)
            try {
                $candidatePath = [IO.Path]::GetFullPath((Join-Path -Path $rootFullPath -ChildPath $platformReference))
            }
            catch {
                Add-SkillFinding -AllFindings $AllFindings -SkillFindings $SkillFindings -Severity 'Warning' -Category 'AmbiguousRepositoryReference' -Classification 'Heuristic' -Skill $Skill -File $RelativeFile -Line ($index + 1) -Message 'Repository-like reference could not be resolved reliably.'
                continue
            }

            if (-not ($candidatePath.Equals($rootFullPath, $comparison) -or $candidatePath.StartsWith($rootPrefix, $comparison))) {
                Add-SkillFinding -AllFindings $AllFindings -SkillFindings $SkillFindings -Severity 'Error' -Category 'RepositoryReferenceOutsideRoot' -Classification 'PolicyViolation' -Skill $Skill -File $RelativeFile -Line ($index + 1) -Message 'Repository-relative reference resolves outside the repository root.'
                continue
            }

            if (-not (Test-Path -LiteralPath $candidatePath -ErrorAction SilentlyContinue) -and -not $conditionalReference) {
                Add-SkillFinding -AllFindings $AllFindings -SkillFindings $SkillFindings -Severity 'Error' -Category 'MissingRepositoryReference' -Classification 'Validation' -Skill $Skill -File $RelativeFile -Line ($index + 1) -Message 'Referenced repository path does not exist.'
            }
        }
    }
}

function Test-SkillManifest {
    param(
        [Parameter(Mandatory = $true)]
        [IO.DirectoryInfo]$Directory,

        [Parameter(Mandatory = $true)]
        [string]$Root,

        [Parameter(Mandatory = $true)]
        [bool]$Foundational,

        [AllowNull()]
        [string]$GitPath,

        [Parameter(Mandatory = $true)]
        [bool]$GitContextValid,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$AllFindings
    )

    $directoryName = $Directory.Name
    $manifestPath = Join-Path -Path $Directory.FullName -ChildPath 'SKILL.md'
    $relativeManifest = Get-RepositoryRelativePath -Root $Root -Path $manifestPath
    $skillFindings = New-Object System.Collections.Generic.List[object]
    $result = [pscustomobject]@{
        DirectoryName   = $directoryName
        Name            = $null
        Foundational    = $Foundational
        ManifestPath    = $relativeManifest
        ManifestPresent = $false
        IgnoredByGit    = $false
        Valid           = $false
        ErrorCount      = 0
        WarningCount    = 0
        Findings        = $skillFindings
    }

    if ($directoryName -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') {
        Add-SkillFinding -AllFindings $AllFindings -SkillFindings $skillFindings -Severity 'Error' -Category 'InvalidSkillDirectoryName' -Classification 'Validation' -Skill $directoryName -File (Get-RepositoryRelativePath -Root $Root -Path $Directory.FullName) -Line $null -Message 'Skill directory name does not follow lowercase kebab-case.'
    }

    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf -ErrorAction SilentlyContinue)) {
        Add-SkillFinding -AllFindings $AllFindings -SkillFindings $skillFindings -Severity 'Error' -Category 'MissingSkillManifest' -Classification 'Validation' -Skill $directoryName -File $relativeManifest -Line $null -Message 'Skill directory does not contain SKILL.md.'
        return $result
    }

    $manifestItem = Get-Item -LiteralPath $manifestPath -Force -ErrorAction SilentlyContinue
    if ($manifestItem -and ($manifestItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        Add-SkillFinding -AllFindings $AllFindings -SkillFindings $skillFindings -Severity 'Error' -Category 'ReparseManifestRejected' -Classification 'PolicyViolation' -Skill $directoryName -File $relativeManifest -Line $null -Message 'SKILL.md is a reparse point and was not read.'
        return $result
    }

    $result.ManifestPresent = $true
    if ($GitContextValid -and $GitPath) {
        $ignoreResult = Invoke-SkillGit -GitPath $GitPath -Root $Root -Arguments @('check-ignore', '-q', '--no-index', '--', $relativeManifest)
        if ($ignoreResult.Executed -and $ignoreResult.ExitCode -eq 0) {
            $result.IgnoredByGit = $true
            $severity = if ($Foundational) { 'Error' } else { 'Warning' }
            $classification = if ($Foundational) { 'PolicyViolation' } else { 'Heuristic' }
            $message = if ($Foundational) { 'Foundational Skill manifest is ignored by Git.' } else { 'Additional Skill manifest is ignored by Git.' }
            Add-SkillFinding -AllFindings $AllFindings -SkillFindings $skillFindings -Severity $severity -Category 'SkillManifestIgnored' -Classification $classification -Skill $directoryName -File $relativeManifest -Line $null -Message $message
        }
        elseif (-not $ignoreResult.Executed -or $ignoreResult.ExitCode -gt 1) {
            Add-SkillFinding -AllFindings $AllFindings -SkillFindings $skillFindings -Severity 'Error' -Category 'GitIgnoreCheckFailed' -Classification 'Validation' -Skill $directoryName -File $relativeManifest -Line $null -Message 'Git ignore status could not be determined.'
        }
    }

    try {
        $utf8 = New-Object System.Text.UTF8Encoding($false, $true)
        $content = [IO.File]::ReadAllText($manifestItem.FullName, $utf8)
    }
    catch {
        Add-SkillFinding -AllFindings $AllFindings -SkillFindings $skillFindings -Severity 'Error' -Category 'UnreadableSkillManifest' -Classification 'Validation' -Skill $directoryName -File $relativeManifest -Line $null -Message 'SKILL.md could not be read as UTF-8 text.'
        return $result
    }

    if ([string]::IsNullOrWhiteSpace($content)) {
        Add-SkillFinding -AllFindings $AllFindings -SkillFindings $skillFindings -Severity 'Error' -Category 'EmptySkillManifest' -Classification 'Validation' -Skill $directoryName -File $relativeManifest -Line 1 -Message 'SKILL.md is empty.'
        return $result
    }

    $lines = [regex]::Split($content.TrimStart([char]0xFEFF), '\r?\n')
    Test-SkillSecurity -Lines $lines -Skill $directoryName -RelativeFile $relativeManifest -AllFindings $AllFindings -SkillFindings $skillFindings
    Test-SkillReferences -Lines $lines -Root $Root -Skill $directoryName -RelativeFile $relativeManifest -AllFindings $AllFindings -SkillFindings $skillFindings

    if ($lines.Count -eq 0 -or $lines[0].Trim() -ne '---') {
        Add-SkillFinding -AllFindings $AllFindings -SkillFindings $skillFindings -Severity 'Error' -Category 'MissingFrontmatter' -Classification 'Validation' -Skill $directoryName -File $relativeManifest -Line 1 -Message 'SKILL.md must begin with a --- frontmatter delimiter.'
        return $result
    }

    $closingIndex = -1
    for ($index = 1; $index -lt $lines.Count; $index++) {
        if ($lines[$index].Trim() -eq '---') {
            $closingIndex = $index
            break
        }
    }
    if ($closingIndex -lt 0) {
        Add-SkillFinding -AllFindings $AllFindings -SkillFindings $skillFindings -Severity 'Error' -Category 'UnclosedFrontmatter' -Classification 'Validation' -Skill $directoryName -File $relativeManifest -Line 1 -Message 'Frontmatter does not have a closing --- delimiter.'
        return $result
    }

    $requiredMetadata = @{}
    for ($index = 1; $index -lt $closingIndex; $index++) {
        $frontmatterLine = $lines[$index]
        if ([string]::IsNullOrWhiteSpace($frontmatterLine)) {
            continue
        }

        $metadataMatch = [regex]::Match($frontmatterLine, '^(?<key>[A-Za-z][A-Za-z0-9_-]*)\s*:\s*(?<value>.*)$')
        if (-not $metadataMatch.Success) {
            Add-SkillFinding -AllFindings $AllFindings -SkillFindings $skillFindings -Severity 'Error' -Category 'UnsupportedFrontmatterSyntax' -Classification 'Validation' -Skill $directoryName -File $relativeManifest -Line ($index + 1) -Message 'Frontmatter line is outside the supported single-line key: value subset.'
            continue
        }

        $key = $metadataMatch.Groups['key'].Value
        $normalizedKey = $key.ToLowerInvariant()
        $value = $metadataMatch.Groups['value'].Value.Trim()
        if ($normalizedKey -notin @('name', 'description')) {
            Add-SkillFinding -AllFindings $AllFindings -SkillFindings $skillFindings -Severity 'Warning' -Category 'UnsupportedMetadataKey' -Classification 'Heuristic' -Skill $directoryName -File $relativeManifest -Line ($index + 1) -Message 'Metadata key is preserved but not interpreted by this repository validator.'
            continue
        }

        if ($requiredMetadata.ContainsKey($normalizedKey)) {
            Add-SkillFinding -AllFindings $AllFindings -SkillFindings $skillFindings -Severity 'Error' -Category 'DuplicateRequiredMetadata' -Classification 'Validation' -Skill $directoryName -File $relativeManifest -Line ($index + 1) -Message "Required metadata key '$normalizedKey' is duplicated."
            continue
        }

        if ($key -cne $normalizedKey) {
            Add-SkillFinding -AllFindings $AllFindings -SkillFindings $skillFindings -Severity 'Error' -Category 'UnsupportedRequiredMetadataCase' -Classification 'Validation' -Skill $directoryName -File $relativeManifest -Line ($index + 1) -Message "Required metadata key '$normalizedKey' must be lowercase."
        }
        if ([string]::IsNullOrWhiteSpace($value)) {
            Add-SkillFinding -AllFindings $AllFindings -SkillFindings $skillFindings -Severity 'Error' -Category 'EmptyRequiredMetadata' -Classification 'Validation' -Skill $directoryName -File $relativeManifest -Line ($index + 1) -Message "Required metadata '$normalizedKey' is empty."
        }
        elseif ($value -match '^(?:[|>\[\]{}`''"&*!]|!!|~$|null$)' -or $value -match '\s+#') {
            Add-SkillFinding -AllFindings $AllFindings -SkillFindings $skillFindings -Severity 'Error' -Category 'UnsupportedFrontmatterSyntax' -Classification 'Validation' -Skill $directoryName -File $relativeManifest -Line ($index + 1) -Message 'Required metadata value uses unsupported YAML syntax.'
        }

        $requiredMetadata[$normalizedKey] = [pscustomobject]@{
            Value = $value
            Line  = $index + 1
        }
    }

    foreach ($requiredKey in @('name', 'description')) {
        if (-not $requiredMetadata.ContainsKey($requiredKey)) {
            Add-SkillFinding -AllFindings $AllFindings -SkillFindings $skillFindings -Severity 'Error' -Category 'MissingRequiredMetadata' -Classification 'Validation' -Skill $directoryName -File $relativeManifest -Line 1 -Message "Required metadata '$requiredKey' is missing."
        }
    }

    if ($requiredMetadata.ContainsKey('name')) {
        $skillName = $requiredMetadata['name'].Value
        $result.Name = $skillName
        if (-not [string]::IsNullOrWhiteSpace($skillName)) {
            if ($skillName -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') {
                Add-SkillFinding -AllFindings $AllFindings -SkillFindings $skillFindings -Severity 'Error' -Category 'InvalidSkillName' -Classification 'Validation' -Skill $directoryName -File $relativeManifest -Line $requiredMetadata['name'].Line -Message 'Skill name does not follow lowercase kebab-case.'
            }
            if ($skillName -cne $directoryName) {
                Add-SkillFinding -AllFindings $AllFindings -SkillFindings $skillFindings -Severity 'Error' -Category 'SkillNameDirectoryMismatch' -Classification 'Validation' -Skill $directoryName -File $relativeManifest -Line $requiredMetadata['name'].Line -Message 'Skill name does not match its directory name.'
            }
        }
    }

    $instructionContent = if ($closingIndex + 1 -lt $lines.Count) {
        ($lines[($closingIndex + 1)..($lines.Count - 1)] -join [Environment]::NewLine).Trim()
    }
    else {
        ''
    }
    if ([string]::IsNullOrWhiteSpace($instructionContent)) {
        Add-SkillFinding -AllFindings $AllFindings -SkillFindings $skillFindings -Severity 'Error' -Category 'MissingInstructionContent' -Classification 'Validation' -Skill $directoryName -File $relativeManifest -Line ($closingIndex + 2) -Message 'SKILL.md has no instructional content after frontmatter.'
    }

    return $result
}

function Test-RepositorySkills {
    <#
    .SYNOPSIS
    Returns structured repository-specific Skill validation without exiting.

    .PARAMETER RepositoryRoot
    Repository to validate. Omit to derive it from this script's location.
    #>
    [CmdletBinding()]
    param(
        [string]$RepositoryRoot
    )

    $root = if ($PSBoundParameters.ContainsKey('RepositoryRoot')) {
        [IO.Path]::GetFullPath($RepositoryRoot)
    }
    else {
        [IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath '..\..'))
    }
    $root = $root.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $skillsRoot = Join-Path -Path $root -ChildPath '.agents\skills'
    $allFindings = New-Object System.Collections.Generic.List[object]
    $skillResults = New-Object System.Collections.Generic.List[object]

    $gitCommand = Get-Command -Name 'git' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    $gitPath = if ($gitCommand) { if ($gitCommand.Source) { $gitCommand.Source } else { $gitCommand.Path } } else { $null }
    $gitContextValid = $false
    if (-not $gitPath) {
        Add-SkillFinding -AllFindings $allFindings -SkillFindings $null -Severity 'Error' -Category 'GitUnavailable' -Classification 'Validation' -Skill $null -File $null -Line $null -Message 'Git is required for repository and ignore validation.'
    }
    else {
        $gitRootResult = Invoke-SkillGit -GitPath $gitPath -Root $root -Arguments @('rev-parse', '--show-toplevel')
        if ($gitRootResult.Executed -and $gitRootResult.ExitCode -eq 0 -and $gitRootResult.Output.Count -gt 0) {
            $reportedRoot = [IO.Path]::GetFullPath($gitRootResult.Output[-1].Trim()).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
            $comparison = if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
            $gitContextValid = $reportedRoot.Equals($root, $comparison)
        }
        if (-not $gitContextValid) {
            Add-SkillFinding -AllFindings $allFindings -SkillFindings $null -Severity 'Error' -Category 'InvalidGitRepositoryContext' -Classification 'Validation' -Skill $null -File $null -Line $null -Message 'Validation root is not the active Git repository root.'
        }
    }

    foreach ($marker in @('AGENTS.md', 'project.godot')) {
        if (-not (Test-Path -LiteralPath (Join-Path $root $marker) -PathType Leaf -ErrorAction SilentlyContinue)) {
            Add-SkillFinding -AllFindings $allFindings -SkillFindings $null -Severity 'Error' -Category 'MissingRepositoryMarker' -Classification 'Validation' -Skill $null -File $marker -Line $null -Message 'Required Endless Dungeon repository marker is missing.'
        }
    }

    $directories = @()
    if (-not (Test-Path -LiteralPath $skillsRoot -PathType Container -ErrorAction SilentlyContinue)) {
        Add-SkillFinding -AllFindings $allFindings -SkillFindings $null -Severity 'Error' -Category 'MissingSkillsDirectory' -Classification 'Validation' -Skill $null -File '.agents/skills' -Line $null -Message 'Repository-local Skills directory does not exist.'
    }
    else {
        $skillsRootItem = Get-Item -LiteralPath $skillsRoot -Force
        if ($skillsRootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            Add-SkillFinding -AllFindings $allFindings -SkillFindings $null -Severity 'Error' -Category 'ReparseSkillsRootRejected' -Classification 'PolicyViolation' -Skill $null -File '.agents/skills' -Line $null -Message 'Skills root is a reparse point and was not traversed.'
        }
        else {
            foreach ($directory in @(Get-ChildItem -LiteralPath $skillsRoot -Directory -Force -ErrorAction SilentlyContinue | Sort-Object Name)) {
                if ($directory.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                    Add-SkillFinding -AllFindings $allFindings -SkillFindings $null -Severity 'Warning' -Category 'ReparseSkillDirectorySkipped' -Classification 'Heuristic' -Skill $directory.Name -File (Get-RepositoryRelativePath -Root $root -Path $directory.FullName) -Line $null -Message 'Reparse-point Skill directory was skipped to preserve repository scope.'
                    continue
                }
                $directories += $directory
            }
        }
    }

    $directoryMap = @{}
    foreach ($directory in $directories) {
        $directoryMap[$directory.Name.ToLowerInvariant()] = $directory
    }

    $missingFoundational = New-Object System.Collections.Generic.List[string]
    foreach ($foundationalName in $script:FoundationalSkillNames) {
        $found = $directoryMap.ContainsKey($foundationalName) -and (Test-Path -LiteralPath (Join-Path $directoryMap[$foundationalName].FullName 'SKILL.md') -PathType Leaf -ErrorAction SilentlyContinue)
        if (-not $found) {
            [void]$missingFoundational.Add($foundationalName)
            Add-SkillFinding -AllFindings $allFindings -SkillFindings $null -Severity 'Error' -Category 'MissingFoundationalSkill' -Classification 'Validation' -Skill $foundationalName -File ".agents/skills/$foundationalName/SKILL.md" -Line $null -Message 'Required foundational Skill is missing.'
        }
    }

    foreach ($directory in $directories) {
        $foundational = $script:FoundationalSkillNames -contains $directory.Name
        $skillResult = Test-SkillManifest -Directory $directory -Root $root -Foundational $foundational -GitPath $gitPath -GitContextValid $gitContextValid -AllFindings $allFindings
        [void]$skillResults.Add($skillResult)
    }

    $namedResults = @($skillResults | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Name) })
    foreach ($group in @($namedResults | Group-Object -Property { $_.Name.ToLowerInvariant() } | Where-Object { $_.Count -gt 1 })) {
        foreach ($skillResult in $group.Group) {
            Add-SkillFinding -AllFindings $allFindings -SkillFindings $skillResult.Findings -Severity 'Error' -Category 'DuplicateSkillName' -Classification 'Validation' -Skill $skillResult.DirectoryName -File $skillResult.ManifestPath -Line $null -Message 'Skill name is duplicated by another repository-local Skill.'
        }
    }

    foreach ($skillResult in $skillResults) {
        $skillErrors = @($skillResult.Findings | Where-Object Severity -eq 'Error')
        $skillWarnings = @($skillResult.Findings | Where-Object Severity -eq 'Warning')
        $skillResult.ErrorCount = $skillErrors.Count
        $skillResult.WarningCount = $skillWarnings.Count
        $skillResult.Valid = $skillErrors.Count -eq 0
        $skillResult.Findings = $skillResult.Findings.ToArray()
    }

    $errors = @($allFindings | Where-Object Severity -eq 'Error')
    $warnings = @($allFindings | Where-Object Severity -eq 'Warning')
    $validatedCount = @($skillResults | Where-Object ManifestPresent).Count

    return [pscustomobject]@{
        Success                        = $errors.Count -eq 0
        RepositoryRoot                 = $root
        SkillsRoot                     = $skillsRoot
        DiscoveredSkillCount           = $directories.Count
        ValidatedSkillCount            = $validatedCount
        RequiredFoundationalSkillCount = $script:FoundationalSkillNames.Count
        MissingFoundationalSkills      = $missingFoundational.ToArray()
        Skills                         = $skillResults.ToArray()
        ErrorCount                     = $errors.Count
        WarningCount                   = $warnings.Count
        Findings                       = $allFindings.ToArray()
        Limitations                    = @(
            'This repository-specific validator is not equivalent to the official OpenAI Skill validator.',
            'Only single-line key: value frontmatter is interpreted; general YAML is unsupported.',
            'Repository references are validated only when identified reliably in inline code spans.',
            'Security checks are conservative heuristics and do not guarantee the absence of secrets.',
            'PowerShell 7 and cross-platform behavior have not been verified.'
        )
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $parameters = @{}
    if ($PSBoundParameters.ContainsKey('RepositoryRoot')) {
        $parameters.RepositoryRoot = $RepositoryRoot
    }
    $result = Test-RepositorySkills @parameters

    if ($Json) {
        $result | ConvertTo-Json -Depth 10
    }
    else {
        Write-Output 'Endless Dungeon Skill validation'
        Write-Output "Repository: $($result.RepositoryRoot)"
        Write-Output "Discovered: $($result.DiscoveredSkillCount); validated: $($result.ValidatedSkillCount); foundational required: $($result.RequiredFoundationalSkillCount)"
        Write-Output ''
        foreach ($skill in $result.Skills) {
            $status = if (-not $skill.Valid) { 'FAIL' } elseif ($skill.WarningCount -gt 0) { 'WARN' } else { 'PASS' }
            $displayName = if ($skill.Name) { $skill.Name } else { $skill.DirectoryName }
            Write-Output "[$status] $displayName - $($skill.ErrorCount) error(s), $($skill.WarningCount) warning(s)"
        }

        if ($result.Findings.Count -gt 0) {
            Write-Output ''
            Write-Output 'Findings:'
            foreach ($finding in $result.Findings) {
                $location = if ($finding.File) {
                    if ($finding.Line) { "$($finding.File):$($finding.Line)" } else { $finding.File }
                }
                else {
                    'repository'
                }
                Write-Output "[$($finding.Severity.ToUpperInvariant())][$($finding.Category)] $location - $($finding.Message)"
            }
        }

        Write-Output ''
        if ($result.Success) {
            Write-Output "[PASS] Skill validation completed with $($result.WarningCount) warning(s)."
        }
        else {
            Write-Output "[FAIL] Skill validation found $($result.ErrorCount) error(s) and $($result.WarningCount) warning(s)."
        }
    }

    if ($result.Success) {
        exit 0
    }
    exit 1
}
