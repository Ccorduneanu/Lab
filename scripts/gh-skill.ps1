Param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "gh CLI not found"
    exit 1
}

Write-Output "Running: gh $($Args -join ' ')"

gh @Args
