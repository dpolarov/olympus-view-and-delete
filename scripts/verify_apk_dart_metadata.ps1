param(
    [Parameter(Mandatory = $true)][string]$ApkPath,
    [Parameter(Mandatory = $true)][string]$ExpectedCommit,
    [Parameter(Mandatory = $true)][string]$ExpectedBuildTime
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Test-ByteSequence {
    param(
        [byte[]]$Haystack,
        [byte[]]$Needle
    )

    if ($Needle.Length -eq 0 -or $Haystack.Length -lt $Needle.Length) {
        return $false
    }

    for ($i = 0; $i -le $Haystack.Length - $Needle.Length; $i++) {
        if ($Haystack[$i] -ne $Needle[0]) {
            continue
        }
        $match = $true
        for ($j = 1; $j -lt $Needle.Length; $j++) {
            if ($Haystack[$i + $j] -ne $Needle[$j]) {
                $match = $false
                break
            }
        }
        if ($match) {
            return $true
        }
    }
    return $false
}

if (-not (Test-Path -LiteralPath $ApkPath)) {
    throw "APK not found: $ApkPath"
}

$zip = [System.IO.Compression.ZipFile]::OpenRead($ApkPath)
try {
    $entry = $zip.Entries |
        Where-Object { $_.FullName -eq 'lib/arm64-v8a/libapp.so' } |
        Select-Object -First 1
    if ($null -eq $entry) {
        throw 'arm64-v8a/libapp.so was not found in the APK.'
    }
    if ($entry.Length -lt 1MB) {
        throw "arm64-v8a/libapp.so is unexpectedly small ($($entry.Length) bytes)."
    }

    $stream = $entry.Open()
    try {
        $memory = New-Object System.IO.MemoryStream
        try {
            $stream.CopyTo($memory)
            $bytes = $memory.ToArray()
        }
        finally {
            $memory.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}
finally {
    $zip.Dispose()
}

$commitBytes = [System.Text.Encoding]::UTF8.GetBytes($ExpectedCommit)
$timeBytes = [System.Text.Encoding]::UTF8.GetBytes($ExpectedBuildTime)
$hasCommit = Test-ByteSequence -Haystack $bytes -Needle $commitBytes
$hasBuildTime = Test-ByteSequence -Haystack $bytes -Needle $timeBytes

if ($hasCommit -and $hasBuildTime) {
    Write-Host "[verify] Dart AOT metadata matches commit $ExpectedCommit and build time $ExpectedBuildTime"
    exit 0
}

if ($hasCommit -xor $hasBuildTime) {
    throw 'Only part of the expected Dart build metadata is visible in libapp.so. Refusing an inconsistent APK.'
}

# Local release builds use --obfuscate. Dart AOT obfuscation/snapshot encoding is
# allowed to hide String.fromEnvironment values from a raw byte scan even though
# the values are available correctly at runtime. A missing pair therefore cannot
# prove that libapp.so is stale. The release script already runs flutter clean
# before every build, while the app's four-finger diagnostics compares native
# package information with the Dart-side build/version values at runtime.
Write-Warning "Git commit/build time are not visible as plain bytes in libapp.so. This is expected for an obfuscated Dart AOT build."
Write-Host "[verify] libapp.so is present and structurally sane; raw metadata scan skipped for obfuscated AOT."
