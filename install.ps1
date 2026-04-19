param (
    [Parameter(Mandatory)][String]$ImagePath,
    [Parameter(Mandatory)][UInt32]$WimIndex
)

try {
    Write-Host "Installing Windows..." -ForegroundColor Cyan
    dism /Apply-Image /ImageFile:"$ImagePath" /Index:$($WimIndex) /ApplyDir:C:\
    if($LASTEXITCODE -ne 0) {
        throw "Dism failed with exit code $LASTEXITCODE!"
    }
    Write-Host "Windows installed." -ForegroundColor Green
} catch {
    Write-Error "Failed to install Windows: $($_.Exception.Message)"
    exit 1
}

try {
    Write-Host "Creating boot files..." -ForegroundColor Cyan
    bcdboot C:\Windows
    Write-Host "Boot files created" -ForegroundColor Green
} catch {
    Write-Error "Failed to create boot files: $($_.Exception.Message)"
    exit 1
}

exit 0