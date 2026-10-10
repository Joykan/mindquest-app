# Starts the trained Rasa model as a server on http://localhost:5005.
# The chat Edge Function calls POST /model/parse?token=... on it.
#
# The token is read from .rasa-token in this folder (git-ignored). Create it once:
#   -join ((48..57) + (97..122) | Get-Random -Count 32 | % {[char]$_}) | Set-Content .rasa-token
# and save the same value as the RASA_TOKEN secret in Supabase.

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Test-Path .rasa-token)) {
    Write-Error "No .rasa-token file. See the comment at the top of serve.ps1."
}
$token = (Get-Content .rasa-token -Raw).Trim()

# Use the Rasa venv in this folder even if another venv is active.
$rasa = Join-Path $PSScriptRoot ".venv\Scripts\rasa.exe"
if (-not (Test-Path $rasa)) { $rasa = "rasa" }

& $rasa run --enable-api --auth-token $token --model models --port 5005
