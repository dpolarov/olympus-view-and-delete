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

if (-not (Test-ByteSequence -Haystack $bytes -Needle $commitBytes)) {
    throw "Dart AOT metadata does not contain current Git commit '$ExpectedCommit'. A stale libapp.so may have been packaged."
}
if (-not (Test-ByteSequence -Haystack $bytes -Needle $timeBytes)) {
    throw "Dart AOT metadata does not contain current build time '$ExpectedBuildTime'. A stale libapp.so may have been packaged."
}

Write-Host "[verify] Dart AOT metadata matches commit $ExpectedCommit and build time $ExpectedBuildTime"
