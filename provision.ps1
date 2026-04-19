param(
    [Parameter(Mandatory)][string]$Hostname,
    [Parameter(Mandatory)][string]$Username,
    [Parameter(Mandatory)][string]$Password,
    [Parameter(Mandatory)][string]$Language,
    [Parameter(Mandatory)][string]$Locale,
    [Parameter(Mandatory)][string]$Keyboard,
    [Parameter(Mandatory)][string]$Timezone,
    [Parameter(Mandatory)][bool]$IsDHCP,
    [string]$IP,
    [string]$Netmask,
    [string]$Gateway,
    [string]$DNS,
    [Parameter(Mandatory)][string]$NTP
)

Write-Host "Generate autounatend.xml..." -ForegroundColor Cyan

# Prepare Network/NTP Commands to run during the 'specialize' pass
$networkCommands = ""
$order = 1

# Add NTP Configuration
if (-not [string]::IsNullOrWhiteSpace($NTP)) {
    $networkCommands += @"
<RunSynchronousCommand wcm:action="add">
    <Order>$order</Order>
    <Path>cmd.exe /c w32tm /config /syncfromflags:manual /manualpeerlist:"$NTP" /update &amp; w32tm /resync</Path>
</RunSynchronousCommand>
"@
    $order++
}

# Add Static IP Configuration if DHCP is false
if (-not $IsDHCP) {
    $networkCommands += @"
<RunSynchronousCommand wcm:action="add">
    <Order>$order</Order>
    <Path>cmd.exe /c for /f "skip=1 tokens=3*" %A in ('netsh interface show interface') do netsh interface ip set address name="%B" static $IP $Netmask $Gateway</Path>
</RunSynchronousCommand>
"@
    $order++
    if (-not [string]::IsNullOrWhiteSpace($DNS)) {
        $dnsServers = $DNS.Split(',')
        $dnsIndex = 1
        foreach ($server in $dnsServers) {
            $cleanDns = $server.Trim()
            if (-not [string]::IsNullOrWhiteSpace($cleanDns)) {
                $networkCommands += @"
<RunSynchronousCommand wcm:action="add">
    <Order>$order</Order>
    <Path>cmd.exe /c for /f "skip=1 tokens=3*" %A in ('netsh interface show interface') do netsh interface ip add dns name="%B" $cleanDns index=$dnsIndex</Path>
</RunSynchronousCommand>
"@
                $order++
                $dnsIndex++
            }
        }
    }
}

# The Dynamic XML Template
$xmlContent = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="specialize">
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <InputLocale>$Keyboard</InputLocale>
            <SystemLocale>$Locale</SystemLocale>
            <UILanguage>$Language</UILanguage>
            <UILanguageFallback>en-US</UILanguageFallback>
            <UserLocale>$Locale</UserLocale>
        </component>
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="NonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <TimeZone>$Timezone</TimeZone>
            <ComputerName>$Hostname</ComputerName>
        </component>
        <component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <RunSynchronous>
                $networkCommands
            </RunSynchronous>
        </component>
    </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <InputLocale>$Keyboard</InputLocale>
            <SystemLocale>$Locale</SystemLocale>
            <UILanguage>$Language</UILanguage>
            <UILanguageFallback>en-US</UILanguageFallback>
            <UserLocale>$Locale</UserLocale>
        </component>
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="NonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <TimeZone>$Timezone</TimeZone>
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideLocalAccountScreen>false</HideLocalAccountScreen>
                <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <ProtectYourPC>3</ProtectYourPC>
            </OOBE>
            <AutoLogon>
                <Password>
                    <Value>$Password</Value>
                    <PlainText>true</PlainText>
                </Password>
                <Enabled>true</Enabled>
                <LogonCount>999</LogonCount>
                <Username>$Username</Username>
            </AutoLogon>
            <UserAccounts>
                <AdministratorPassword>
                    <Value>$Password</Value>
                    <PlainText>true</PlainText>
                </AdministratorPassword>
                <LocalAccounts>
                    <LocalAccount wcm:action="add">
                        <Password>
                            <Value>$Password</Value>
                            <PlainText>true</PlainText>
                        </Password>
                        <Description>Local Admin</Description>
                        <DisplayName>$Username</DisplayName>
                        <Group>Administrators</Group>
                        <Name>$Username</Name>
                    </LocalAccount>
                </LocalAccounts>
            </UserAccounts>
        </component>
    </settings>
</unattend>
"@

# Ensure the Panther directory exists on the target drive
$pantherDir = "C:\Windows\Panther"
if (-not (Test-Path $pantherDir)) {
    New-Item -Path $pantherDir -ItemType Directory -Force | Out-Null
}

# Write the XML to the target system
$unattendPath = Join-Path $pantherDir "unattend.xml"
$xmlContent | Out-File -FilePath $unattendPath -Encoding utf8 -Force

Write-Host "Successfully provisioned answer file at $unattendPath" -ForegroundColor Green
exit 0