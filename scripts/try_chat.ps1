# Talks to the deployed chat function from the terminal, as a new anonymous user.
# Uses the Supabase URL and key from config/dev.json.
#
#   .\scripts\try_chat.ps1                                  # a short sample conversation
#   .\scripts\try_chat.ps1 "habari" "nina stress" "ndio"    # your own messages, in order
#
# Each run creates a new anonymous user in Supabase (Authentication > Users).

param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Messages)

if (-not $Messages) {
    $Messages = @("hi", "my name is Joy", "I feel joy today", "I'm so stressed about exams", "yes", "thank you")
}

$cfg = Get-Content (Join-Path $PSScriptRoot "..\config\dev.json") -Raw | ConvertFrom-Json
$url = $cfg.SUPABASE_URL
$key = $cfg.SUPABASE_ANON_KEY

$auth = Invoke-RestMethod -Method Post "$url/auth/v1/signup" -Headers @{ apikey = $key } `
    -ContentType "application/json" -Body "{}"
$headers = @{ apikey = $key; Authorization = "Bearer $($auth.access_token)" }

$session = $null
foreach ($m in $Messages) {
    $body = @{ text = $m; session_id = $session } | ConvertTo-Json
    $r = Invoke-RestMethod -Method Post "$url/functions/v1/chat" -Headers $headers `
        -ContentType "application/json; charset=utf-8" -Body ([Text.Encoding]::UTF8.GetBytes($body))
    $session = $r.session_id
    Write-Host "You: $m" -ForegroundColor Cyan
    Write-Host "Bot: $($r.reply)"
    Write-Host "     [intent: $($r.intent), confidence: $($r.confidence)]" -ForegroundColor DarkGray
    if ($r.crisis) { $r.helplines | ForEach-Object { Write-Host "     $($_.name): $($_.phone)" -ForegroundColor Yellow } }
}
