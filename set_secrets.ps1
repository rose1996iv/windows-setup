$GH_TOKEN = "vcp_8Z3k9bQsScR00hhy8ovo6Q5AnGsisMD7dKCbQLLaHM"
$REPO = "rose1996iv/windows-setup"
$headers = @{
    Authorization = "token $GH_TOKEN"
    Accept = "application/vnd.github.v3+json"
    "User-Agent" = "PowerShell"
}

Write-Host "Step 1: Fetching repo public key..." -ForegroundColor Cyan
$pubKeyResp = Invoke-RestMethod -Uri "https://api.github.com/repos/$REPO/actions/secrets/public-key" -Method GET -Headers $headers
Write-Host "Key ID: $($pubKeyResp.key_id)" -ForegroundColor Green

Write-Host "Step 2: Installing PyNaCl..." -ForegroundColor Cyan
python -m pip install PyNaCl --quiet 2>&1 | Out-Null

Write-Host "Step 3: Setting secrets..." -ForegroundColor Cyan
$encPy = @"
import base64, sys
from nacl.public import PublicKey, SealedBox
pub_key = base64.b64decode(sys.argv[1])
box = SealedBox(PublicKey(pub_key))
enc = box.encrypt(sys.argv[2].encode('utf-8'))
print(base64.b64encode(enc).decode('utf-8'))
"@

$secrets = @{
    "VERCEL_TOKEN"      = "vcp_8Z3k9bQsScR00hhy8ovo6Q5AnGsisMD7dKCbQLLaHM"
    "VERCEL_ORG_ID"     = "rose1996iv"
    "VERCEL_PROJECT_ID" = "prj_LjHgQ2SeMMeUz1yWmkTGOfmrv228"
}

foreach ($name in $secrets.Keys) {
    $val = $secrets[$name]
    $enc = python -c $encPy $pubKeyResp.key $val
    $body = "{`"encrypted_value`":`"$enc`",`"key_id`":`"$($pubKeyResp.key_id)`"}"
    Invoke-RestMethod -Uri "https://api.github.com/repos/$REPO/actions/secrets/$name" -Method PUT -Headers $headers -Body $body -ContentType "application/json" | Out-Null
    Write-Host "  $name set OK" -ForegroundColor Green
}

Write-Host ""
Write-Host "Verifying..." -ForegroundColor Cyan
$list = Invoke-RestMethod -Uri "https://api.github.com/repos/$REPO/actions/secrets" -Method GET -Headers $headers
$list.secrets | ForEach-Object { Write-Host "  OK: $($_.name)" -ForegroundColor Green }
Write-Host "Done!" -ForegroundColor Green
