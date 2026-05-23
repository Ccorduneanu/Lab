param(
  [string]$action,
  [string]$value,
  [string]$value2
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

function Call-Api($method, $url) {
  $token = Get-Token
  try {
    return Invoke-RestMethod -Uri $url -Headers @{ Authorization = "Bearer $token"; Accept = 'application/json' } -Method $method -ErrorAction Stop
  } catch {
    Write-Error "API request failed: $($_.Exception.Message)"
    if ($_.Exception.Response -ne $null) {
      try { $stream = $_.Exception.Response.GetResponseStream(); $sr = New-Object System.IO.StreamReader($stream); Write-Output "Response body:"; Write-Output $sr.ReadToEnd() } catch { }
    }
    exit 2
  }
}

switch ($action) {
  'store-token' {
    if (-not $value) { Write-Error 'Usage: .\scripts\testiny-skill.ps1 store-token <token>'; exit 1 }
    Save-Token $value
    break
  }
  'list-projects' {
    $page = 1; $all = @()
    while ($true) {
      $url = "https://api.testiny.io/v1/projects?page=$page&per_page=100"
      $resp = Call-Api -method 'GET' -url $url
      if ($resp -is [System.Array]) { $items = $resp } elseif ($resp.PSObject.Properties.Name -contains 'data') { $items = $resp.data } else { $items = @($resp) }
      if ($items.Count -eq 0) { break }
      $all += $items
      if ($items.Count -lt 100) { break }
      $page++
    }
    $all | ConvertTo-Json -Depth 5
    break
  }
  'list-testcases' {
    # Usage: list-testcases [projectId] [testplanId]
    $projectId = $value
    $testplanId = $value2
    $outputs = @()
    if (-not $projectId) {
      # fetch all projects
      $projects = & $MyInvocation.MyCommand.Path -split '\\' | Out-Null
      $projectsJson = & $MyInvocation.MyCommand.Path | Out-Null
      $projects = & $PSScriptRoot\testiny-skill.ps1 list-projects
      # The above will not work when invoked this way; instead call API directly
      $page = 1; $projects = @()
      while ($true) {
        $url = "https://api.testiny.io/v1/projects?page=$page&per_page=100"
        $resp = Call-Api -method 'GET' -url $url
        if ($resp -is [System.Array]) { $items = $resp } elseif ($resp.PSObject.Properties.Name -contains 'data') { $items = $resp.data } else { $items = @($resp) }
        if ($items.Count -eq 0) { break }
        $projects += $items
        if ($items.Count -lt 100) { break }
        $page++
      }
    } else {
      $projects = @(@{ id = [int]$projectId })
    }

    foreach ($p in $projects) {
      $pid = $p.id
      if ($testplanId) {
        $page = 1; $acc = @()
        while ($true) {
          $url = "https://api.testiny.io/v1/projects/$pid/testplans/$testplanId/testcases?page=$page&per_page=100"
          $resp = Call-Api -method 'GET' -url $url
          if ($resp -is [System.Array]) { $items = $resp } elseif ($resp.PSObject.Properties.Name -contains 'data') { $items = $resp.data } else { $items = @($resp) }
          if ($items.Count -eq 0) { break }
          $acc += $items
          if ($items.Count -lt 100) { break }
          $page++
        }
        $outputs += @{ projectId = $pid; testplanId = $testplanId; testcases = $acc }
      } else {
        # Try project-level endpoint
        $page = 1; $acc = @()
        while ($true) {
          $url1 = "https://api.testiny.io/v1/projects/$pid/testcases?page=$page&per_page=100"
          $url2 = "https://api.testiny.io/v1/projects/$pid/testplans?page=$page&per_page=100"
          $resp = Call-Api -method 'GET' -url $url1
          if ($resp -eq $null) { break }
          if ($resp -is [System.Array]) { $items = $resp } elseif ($resp.PSObject.Properties.Name -contains 'data') { $items = $resp.data } else { $items = @($resp) }
          if ($items.Count -gt 0) { $acc += $items } else {
            # fallback: enumerate testplans and their testcases
            $tp_page = 1; $tps = @()
            while ($true) {
              $tpurl = "https://api.testiny.io/v1/projects/$pid/testplans?page=$tp_page&per_page=100"
              $tpr = Call-Api -method 'GET' -url $tpurl
              if ($tpr -is [System.Array]) { $tpitems = $tpr } elseif ($tpr.PSObject.Properties.Name -contains 'data') { $tpitems = $tpr.data } else { $tpitems = @($tpr) }
              if ($tpitems.Count -eq 0) { break }
              foreach ($tp in $tpitems) {
                $tp_id = $tp.id
                $tc_page = 1
                while ($true) {
                  $tcurl = "https://api.testiny.io/v1/projects/$pid/testplans/$tp_id/testcases?page=$tc_page&per_page=100"
                  $tcr = Call-Api -method 'GET' -url $tcurl
                  if ($tcr -is [System.Array]) { $tcitems = $tcr } elseif ($tcr.PSObject.Properties.Name -contains 'data') { $tcitems = $tcr.data } else { $tcitems = @($tcr) }
                  if ($tcitems.Count -eq 0) { break }
                  $acc += $tcitems
                  if ($tcitems.Count -lt 100) { break }
                  $tc_page++
                }
              }
              if ($tpitems.Count -lt 100) { break }
              $tp_page++
            }
            break
          }
          if ($items.Count -lt 100) { break }
          $page++
        }
        $outputs += @{ projectId = $pid; testcases = $acc }
      }
    }
    $outputs | ConvertTo-Json -Depth 6
    break
  }
  'print-curl' {
    Write-Output "curl -s -H \"Authorization: Bearer <TOKEN>\" -H \"Accept: application/json\" \"https://api.testiny.io/v1/projects?per_page=100\" | jq ."
    break
  }
  default {
    Write-Output "Usage: .\scripts\testiny-skill.ps1 <store-token|list-projects|list-testcases|print-curl> [projectId] [testplanId]"
  }
}
