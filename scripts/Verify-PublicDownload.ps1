param(
  [string]$ManifestPath = "downloads/OuroborosChatGPT.manifest.json",
  [string]$ExpectedSignerSubject = $env:EXPECTED_SIGNER_SUBJECT
)

$ErrorActionPreference = "Stop"

function Fail([string]$Message) {
  Write-Error "public download verification failed: $Message"
  exit 1
}

function Is-PlaceholderSigner([AllowNull()][string]$Value) {
  if ([string]::IsNullOrWhiteSpace($Value)) {
    return $true
  }

  return $Value.Trim() -match "^(0+|n/a|na|none|null|unknown|unsigned|todo|tbd|placeholder|changeme|change-me|cn\s*=\s*(todo|unknown|placeholder|changeme))$"
}

if (-not (Test-Path -LiteralPath $ManifestPath)) {
  Fail "manifest not found at $ManifestPath"
}

$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json

if ($manifest.availability -eq 'disabled') {
  $executables = @(Get-ChildItem -LiteralPath (Split-Path -Parent $ManifestPath) -Filter '*.exe' -File)
  if ($manifest.production -ne $false -or $null -ne $manifest.file -or $null -ne $manifest.sha256 -or $null -ne $manifest.expectedSignerSubject) {
    Fail "disabled downloads require production=false and null file, hash, and signer"
  }
  if ($executables.Count -ne 0) {
    Fail "disabled downloads must contain no executable files"
  }
  Write-Host 'public download verification ok: Windows download is safely disabled'
  exit 0
}

if ($manifest.availability -ne 'enabled') {
  Fail "manifest availability must be enabled or disabled"
}

if ($manifest.production -ne $true) {
  Fail "manifest production must be true before this download can be released"
}

if ([string]::IsNullOrWhiteSpace($ExpectedSignerSubject)) {
  $ExpectedSignerSubject = $manifest.expectedSignerSubject
}

if (Is-PlaceholderSigner $ExpectedSignerSubject) {
  Fail "expected signer subject is missing or a placeholder"
}

$downloadPath = Join-Path (Split-Path -Parent $ManifestPath) $manifest.file
if (-not (Test-Path -LiteralPath $downloadPath)) {
  Fail "download file not found at $downloadPath"
}

$actualSha256 = (Get-FileHash -LiteralPath $downloadPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualSha256 -ne $manifest.sha256) {
  Fail "manifest sha256 $($manifest.sha256) does not match $downloadPath $actualSha256"
}

$signature = Get-AuthenticodeSignature -LiteralPath $downloadPath
if ($signature.Status -ne "Valid") {
  Fail "Authenticode status is $($signature.Status), expected Valid"
}

if ($null -eq $signature.SignerCertificate) {
  Fail "signer certificate is missing"
}

$actualSignerSubject = $signature.SignerCertificate.Subject
if (Is-PlaceholderSigner $actualSignerSubject) {
  Fail "signer subject is empty, zero, or a placeholder"
}

if ($actualSignerSubject -cne $ExpectedSignerSubject) {
  Fail "signer subject '$actualSignerSubject' does not match expected '$ExpectedSignerSubject'"
}

if ($null -eq $signature.TimeStamperCertificate) {
  Fail "timestamp certificate is missing"
}

if (Is-PlaceholderSigner $signature.TimeStamperCertificate.Subject) {
  Fail "timestamp certificate subject is empty, zero, or a placeholder"
}

Write-Host "public download verification ok: $downloadPath"
Write-Host "sha256: $actualSha256"
Write-Host "signer: $actualSignerSubject"
Write-Host "timestamp: $($signature.TimeStamperCertificate.Subject)"
