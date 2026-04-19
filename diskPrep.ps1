param (
    [Parameter(Mandatory)][UInt32]$DiskNumber
)

# Disk helper functions 
function New-FormattedPartition {
    param (
        [Parameter(Mandatory)][UInt32]$DiskNumber,
        [Parameter(Mandatory)][string]$Label,
        [string]$FileSystem,
        [UInt64]$Size,
        [UInt64]$Offset,
        [string]$GptType,
        [char]$DriveLetter
    )

    # Partition
    try {
        $params = @{
            DiskNumber = $DiskNumber
            ErrorAction = 'Stop'
        }

        if ($Size) { $params.Size = $Size } else { $params.UseMaximumSize = $true }
        if ($Offset) { $params.Offset = $Offset }
        if ($GptType) { $params.GptType = $GptType }
        if ($DriveLetter) { $params.DriveLetter = $DriveLetter }

        Write-Host "Partitioning '$Label'..." -ForegroundColor Cyan
        $partition = New-Partition @params
        Write-Host "Created partition '$label'." -ForegroundColor Green
    } catch {
        Write-Error "Failed to partition ${Label}: $($_.Exception.Message)"
        exit 1
    }

    # Format
    if ($FileSystem) {
        try {
            $params = @{
                Partition = $partition
                FileSystem = $FileSystem
                NewFileSystemLabel = $Label
                Confirm = $false
                ErrorAction = 'Stop'
            }

            Write-Host "Formating '$Label'..." -ForegroundColor Cyan
            Format-Volume @params
            Write-Host "Created filesystem '$label'." -ForegroundColor Green
        } catch {
            Write-Error "Failed to format ${Label}: $($_.Exception.Message)"
            exit 1
        }
    }
}

function Move-DriveLetter {
    param (
        [Parameter(Mandatory)][char]$Letter
    )

    Write-Host "Free drive letter $Letter if in use..." -ForegroundColor Cyan

    # get drive
    $drive = Get-CimInstance -ClassName Win32_Volume -Filter "DriveLetter = '${Letter}:'"
    if (-not $drive) {
        Write-Host "Source drive '${Letter}:' was not found!" -ForegroundColor Yellow
        return
    }

    # get free letter
    try {
        Write-Host "Searching for new drive letter..." -ForegroundColor Cyan
        $usedLetters = (Get-Volume).DriveLetter
        $alphabet = 68..90 | ForEach-Object { [char]$_ }

        foreach ($l in $alphabet) {
            if ($l -notin $usedLetters) {
                $new = $l
                break
            } elseif ($l -eq 'Z') {
                throw "There are no free drive letters!"
            }
        }

        Write-Host "Found free letter: ${new}:" -ForegroundColor Green
    } catch {
        Write-Error "Failed to find a new drive letter: $($_.Exception.Message)"
        exit 1
    }

    # Switch letters
    try {
        Write-Host "Changing drive letter from ${Letter}: to ${new}:..." -ForegroundColor Cyan
        $drive | Set-CimInstance -Property @{ DriveLetter = "${new}:" } -ErrorAction Stop
        Write-Host "Successfully changed drive letter." -ForegroundColor Green
    } 
    catch {
        Write-Error "Failed to update drive letter: $($_.Exception.Message)"
        exit 1
    }
}

# -- Clear disk --
$disk = get-Disk -Number $DiskNumber
Write-Host "Clearing disk..." -ForegroundColor Cyan
if ($disk.PartitionStyle -ne 'RAW') {
    try {
        Clear-Disk -Number $DiskNumber -RemoveData -RemoveOEM -Confirm:$false -ErrorAction Stop
        Write-Host "Disk '$($DiskNumber)' was cleared" -ForegroundColor Green
    } catch {
        Write-Host "Disk '$($DiskNumber)' was not cleared!" -ForegroundColor Yellow
    }
}

# Free drive letter C
Move-DriveLetter -Letter 'C'

# Initialize system disk
try {
    Write-Host "Initializing disk..." -ForegroundColor Cyan
    if (-not $disk) {
        throw "No disk selected!"
    }
    Initialize-Disk -Number $DiskNumber -PartitionStyle GPT -ErrorAction Stop
    Write-Host "Disk '$($DiskNumber)' is initialized." -ForegroundColor Green
} catch {
    Write-Error "Failed to initialize drive: $($_.Exception.Message)"
    exit 1
}

# EFI
New-FormattedPartition -DiskNumber $disk.Number -Label "System" -FileSystem FAT32 -Size 500MB -GptType "{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}"

# MSR
New-FormattedPartition -DiskNumber $disk.Number -Label "MSR" -Size 128MB -GptType "{e3c9e316-0b5c-4db8-817d-f92df00215ae}"

# Windows
New-FormattedPartition -DiskNumber $disk.Number -Label "Windows" -FileSystem NTFS -DriveLetter 'C'

exit 0