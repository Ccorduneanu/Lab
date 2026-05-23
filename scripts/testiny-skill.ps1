param(
  [string]$action,
  [string]$value
)

function Save-Token($plain) {
  $dir = Join-Path $env:USERPROFILE '.testiny'
  if (-Not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $secure = ConvertTo-SecureString $plain -AsPlainText -Force
  $enc = $secure | ConvertFrom-SecureString
  Set-Content -Path (Join-Path $dir 'token.txt') -Value $enc -NoNewline
  Write-Output "Token stored encrypted for user: $env:USERNAME"
}

function Get-Token() {
  $path = Join-Path $env:USERPROFILE '.testiny\token.txt'
  if (-Not (Test-Path $path)) { Write-Error "Token not found. Run 'store-token' with your token."; exit 1 }
  $enc = Get-Content -Path $path -Raw
  $secure = $enc | ConvertTo-SecureString
  $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try { $tok = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) } finally { [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
  return $tok
}

switch ($action) {
  'store-token' {
    if (-not $value) { Write-Error 'Usage: .\scripts\testiny-skill.ps1 store-token <token>'; exit 1 }
    Save-Token $value
    break
  }
  'list-projects' {
    $token = Get-Token
    $page = 1
    $all = @()
    while ($true) {
      $url = "https://api.testiny.io/v1/projects?page=$page&per_page=100"
      try {
        $resp = Invoke-RestMethod -Uri $url -Headers @{ Authorization = "Bearer $token"; Accept = 'application/json' } -Method Get -ErrorAction Stop
      } catch {
        Write-Error "API request failed: $($_.Exception.Message)"
        exit 2
      }
      if ($null -eq $resp) { break }
      if ($resp -is [System.Array]) { $items = $resp } elseif ($resp.PSObject.Properties.Name -contains 'data') { $items = $resp.data } else { $items = @($resp) }
      if ($items.Count -eq 0) { break }
      $all += $items
      if ($items.Count -lt 100) { break }
      $page++
    }
    $all | ConvertTo-Json -Depth 5
    break
  }
  'print-curl' {
    Write-Output "curl -s -H \"Authorization: Bearer <TOKEN>\" -H \"Accept: application/json\" \"https://api.testiny.io/v1/projects?per_page=100\" | jq ."
    break
  }
  default {
    Write-Output "Usage: .\scripts\testiny-skill.ps1 <store-token|list-projects|print-curl> [value]"
  }
}
