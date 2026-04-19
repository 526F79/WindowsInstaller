Add-Type -AssemblyName PresentationFramework

# Form layout
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Install Windows"
    WindowStartupLocation="CenterScreen"
    ResizeMode="NoResize"
    SizeToContent="WidthAndHeight"
    Icon="$PSScriptRoot\app.ico">

    <Grid Margin="4">
        <Grid.RowDefinitions>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <TabControl Grid.Row="0" Width="512" Height="384">

            <TabItem Header="Install Settings">
                <StackPanel Margin="10">
                    <TextBlock Text="Select windows image:" Margin="0,0,0,2"/>
                    <ComboBox x:Name="ImgList" HorizontalAlignment="Stretch" Margin="0,0,0,10"/>

                    <TextBlock Text="Select image index:" Margin="0,0,0,2"/>
                    <ComboBox x:Name="ImgIndexList" HorizontalAlignment="Stretch" Margin="0,0,0,10"/>

                    <TextBlock Text="Select target disk:" Margin="0,0,0,2"/>
                    <ComboBox x:Name="DiskList" HorizontalAlignment="Stretch" Margin="0,0,0,10"/>

                    <CheckBox x:Name="AutoRestartCheckBox" Content="Automatically restart after installation" Margin="0,10,0,0" IsChecked="True"/>
                </StackPanel>
            </TabItem>

            <TabItem Header="User Config">
                <StackPanel Margin="10">
                    <TextBlock Text="Username:" Margin="0,0,0,2"/>
                    <TextBox x:Name="UsernameBox" HorizontalAlignment="Stretch" Margin="0,0,0,10" Text="Administrator"/>

                    <TextBlock Text="Password (default 'Password*123'):" Margin="0,0,0,2"/>
                    <PasswordBox x:Name="PasswordBox" HorizontalAlignment="Stretch" Margin="0,0,0,10"/>

                    <TextBlock Text="Language:" Margin="0,0,0,2"/>
                    <ComboBox x:Name="LanguageList" HorizontalAlignment="Stretch" Margin="0,0,0,10"/>

                    <TextBlock Text="Locale:" Margin="0,0,0,2"/>
                    <ComboBox x:Name="LocaleList" HorizontalAlignment="Stretch" Margin="0,0,0,10"/>

                    <TextBlock Text="Keyboard:" Margin="0,0,0,2"/>
                    <ComboBox x:Name="KeyboardList" HorizontalAlignment="Stretch" Margin="0,0,0,10"/>

                    <TextBlock Text="Timezone:" Margin="0,0,0,2"/>
                    <ComboBox x:Name="TimezoneList" HorizontalAlignment="Stretch" Margin="0,0,0,10"/>
                </StackPanel>
            </TabItem>

            <TabItem Header="Network Config">
                <StackPanel Margin="10">
                    <TextBlock Text="Hostname:" Margin="0,0,0,2"/>
                    <TextBox x:Name="HostnameBox" HorizontalAlignment="Stretch" Margin="0,0,0,10" Text="GNT-WIN01"/>

                    <CheckBox x:Name="DhcpCheckBox" Content="Enable DHCP (Automatic IP)" Margin="0,0,0,15" IsChecked="True"/>

                    <StackPanel x:Name="StaticNetworkPanel" IsEnabled="False">
                        <TextBlock Text="IP Address:" Margin="0,0,0,2"/>
                        <TextBox x:Name="IpBox" HorizontalAlignment="Stretch" Margin="0,0,0,10" Text="192.168.100.10"/>

                        <TextBlock Text="Subnet Mask:" Margin="0,0,0,2"/>
                        <TextBox x:Name="NetmaskBox" HorizontalAlignment="Stretch" Margin="0,0,0,10" Text="255.255.255.0"/>

                        <TextBlock Text="Default Gateway:" Margin="0,0,0,2"/>
                        <TextBox x:Name="GatewayBox" HorizontalAlignment="Stretch" Margin="0,0,0,10" Text="192.168.100.254"/>

                        <TextBlock Text="DNS Servers (comma separated):" Margin="0,0,0,2"/>
                        <TextBox x:Name="DnsBox" HorizontalAlignment="Stretch" Margin="0,0,0,10" Text="1.1.1.1, 1.0.0.1"/>
                    </StackPanel>

                    <TextBlock Text="NTP Servers (comma separated):" Margin="0,0,0,2"/>
                    <TextBox x:Name="NtpBox" HorizontalAlignment="Stretch" Margin="0,0,0,10" Text="0.be.pool.ntp.org, 1.be.pool.ntp.org, 2.be.pool.ntp.org, 3.be.pool.ntp.org"/>
                </StackPanel>
            </TabItem>

            <TabItem Header="Apps">
                <StackPanel Margin="10">
                    <TextBlock Text="Coming soon. I will probably use Chocolatey." Margin="0,0,0,10"/>
                </StackPanel>
            </TabItem>

        </TabControl>

        <Button x:Name="InstallBtn" Grid.Row="1" Content="Install" Width="128" HorizontalAlignment="Center" Margin="0,10,0,4" IsDefault="True"/>

        <TextBlock Grid.Row="2" Text="Windows custom installer v0.2 - Kwinten student at HoGent" HorizontalAlignment="Center" Margin="0,10,0,0"/>
    </Grid>
</Window>
"@

# Console window helper functions
$code = @"
using System;
using System.Runtime.InteropServices;

public class WindowUtils {
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    public static void Minimize() {
        IntPtr hWnd = GetConsoleWindow();
        ShowWindow(hWnd, 6); // 6 is the command for 'Minimize'
    }

    public static void Restore() {
        IntPtr hWnd = GetConsoleWindow();
        ShowWindow(hWnd, 9); // 9 is the command for 'Restore'
    }
}
"@
if (-not ([System.Management.Automation.PSTypeName]"WindowUtils").Type) {
    Add-Type -TypeDefinition $code
}

# Require admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    try {
        $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        Start-Process powershell.exe -Verb RunAs -ArgumentList $argList -ErrorAction Stop
    } catch {
        Write-Warning "This installer requires Administrator privileges to run."
        Pause
    }
    exit 1
}

Write-Host "Loading form..." -ForegroundColor Cyan

# Load the XAML and display the form
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$form = [System.Windows.Markup.XamlReader]::Load($reader)

# --- Populating UI Controls ---

# Images
$images = Get-ChildItem -Path "$PSScriptRoot\..\sources\" -File | Where-Object { $_.Name -notlike "boot.wim" }
if (-not $images) {
    Write-Error "There are no images detected!"
    exit 1
}

# Cache image metadata to avoid querying DISM repeatedly
$imageCache = @{}
foreach ($i in $images) {
    $imageCache[$i.BaseName] = Get-WindowsImage -ImagePath $i.FullName -ErrorAction Stop | Sort-Object ImageIndex
}

$imgList = $form.FindName("ImgList")
$imgIndexList = $form.FindName("ImgIndexList")

$imgList.Add_SelectionChanged({
    $selectedBaseName = $imgList.SelectedItem.ToString()
    # Wrap in @() to force an array, preventing WPF from parsing a single string as chars
    $imgIndexList.ItemsSource = @(
        $imageCache[$selectedBaseName] | ForEach-Object { "$($_.ImageIndex): $($_.ImageName)" }
    )
    $imgIndexList.SelectedIndex = 0
})

$imgList.ItemsSource = $images.BaseName
$imgList.SelectedIndex = 0

# Disks
$disks = Get-Disk | Where-Object { $_.Size -ge 64GB } | Sort-Object Number
if (-not $disks) {
    Write-Error "There is no disk available greater or equal than 64GB!"
    exit 1
}

$diskList = $form.FindName("DiskList")
$diskList.ItemsSource = @(
    $disks | ForEach-Object { "$($_.Number): $($_.FriendlyName) $($_.Size / 1GB -as [int]) GB" }
)
$diskList.SelectedIndex = 0

# Password
$passwordBox = $form.FindName("PasswordBox")
$passwordBox.Password = "Password*123"

# Localization & Languages
$languages = [System.Globalization.CultureInfo]::GetCultures('SpecificCultures')
if (-not $languages) {
    Write-Error "No languages found!"
    exit 1
}

$languageList = $form.FindName("LanguageList")
$languageList.ItemsSource = $languages
$languageList.DisplayMemberPath = "DisplayName"
$languageList.SelectedValuePath = "Name"
$languageList.SelectedValue = "en-US"

$localeList = $form.FindName("LocaleList")
$localeList.ItemsSource = $languages
$localeList.DisplayMemberPath = "DisplayName"
$localeList.SelectedValuePath = "Name"
$localeList.SelectedValue = "nl-BE"

$keyboardList = $form.FindName("KeyboardList")
$keyboardList.ItemsSource = $languages
$keyboardList.DisplayMemberPath = "Name"
$keyboardList.SelectedValuePath = "Name"
$keyboardList.SelectedValue = "en-US"

# Timezone
$timezones = [System.TimeZoneInfo]::GetSystemTimeZones()
if (-not $timezones) {
    Write-Error "No timezones found!"
    exit 1
}

$timezoneList = $form.FindName("TimezoneList")
$timezoneList.ItemsSource = $timezones.Id
$timezoneList.SelectedItem = ($timezones | Where-Object { $_.Id -match "Romance Standard Time" } | Select-Object -First 1).Id

# DHCP/static toggle
$dhcpCheckBox = $form.FindName("DhcpCheckBox")
$staticNetworkPanel = $form.FindName("StaticNetworkPanel")

$dhcpCheckBox.Add_Click({
    $staticNetworkPanel.IsEnabled = -not $dhcpCheckBox.IsChecked
})

# Setup run configuration variables
$runConfig = @{}

# Install Button Event
$installBtn = $form.FindName("InstallBtn")
$installBtn.Add_Click({
# --- Install Settings ---
    $runConfig.DiskNumber = $diskList.SelectedItem.ToString().Split(':')[0]
    $runConfig.ImagePath = $images[$imgList.SelectedIndex].FullName
    $runConfig.WimIndex = $imgIndexList.SelectedIndex + 1
    $runConfig.AutoRestart = [bool]$form.FindName("AutoRestartCheckBox").IsChecked

    # --- User Config ---
    $runConfig.Username = $form.FindName("UsernameBox").Text
    $runConfig.Password = $passwordBox.Password
    $runConfig.Language = $languageList.SelectedValue
    $runConfig.Locale = $localeList.SelectedValue
    $runConfig.Keyboard = $keyboardList.SelectedValue
    $runConfig.Timezone = $timezoneList.SelectedItem.ToString()
    
    # --- Network Config ---
    $runConfig.Hostname = $form.FindName("HostnameBox").Text
    $runConfig.IsDHCP = [bool]$dhcpCheckBox.IsChecked
    $runConfig.IP = $form.FindName("IpBox").Text
    $runConfig.Netmask = $form.FindName("NetmaskBox").Text
    $runConfig.Gateway = $form.FindName("GatewayBox").Text
    $runConfig.DNS = $form.FindName("DnsBox").Text
    $runConfig.NTP = $form.FindName("NtpBox").Text
    
    $form.DialogResult = $true
    $form.Close()
})

# Show the window
[WindowUtils]::Minimize()
$result = $form.ShowDialog()
[WindowUtils]::Restore()

# Execute Post-Form Actions
if ($result -eq $true) {
    Write-Host "Proceeding with installation..." -ForegroundColor Cyan

    # Prep disk
    Write-Host "Disk number: $($runConfig.DiskNumber)" -ForegroundColor White
    & "$PSScriptRoot\diskPrep.ps1" -DiskNumber $runConfig.DiskNumber
    if ($LASTEXITCODE -ne 0) {
        exit 1
    }

    # Install system
    Write-Host "Image: $($runConfig.ImagePath), Index: $($runConfig.WimIndex)" -ForegroundColor White
    & "$PSScriptRoot\install.ps1" -ImagePath $runConfig.ImagePath -WimIndex $runConfig.WimIndex
    if ($LASTEXITCODE -ne 0) {
        exit 1
    }

    # Provision autounattend.xml
    $provisionParams = @{
        Username = $runConfig.Username
        Password = $runConfig.Password
        Language = $runConfig.Language
        Locale = $runConfig.Locale
        Keyboard = $runConfig.Keyboard
        Timezone = $runConfig.Timezone
        IsDHCP = $runConfig.IsDHCP
        NTP = $runConfig.NTP
    }

    $provisionParams.Hostname = $runConfig.Hostname
    if (-not $runConfig.IsDHCP) {
        $provisionParams.IP = $runConfig.IP
        $provisionParams.Netmask = $runConfig.Netmask
        $provisionParams.Gateway = $runConfig.Gateway
        $provisionParams.DNS = $runConfig.DNS
    }
    Write-Host "Provision config:" -ForegroundColor White
    $provisionParams | Out-String | Write-Host -ForegroundColor White
    & "$PSScriptRoot\provision.ps1" @provisionParams
    if ($LASTEXITCODE -ne 0) {
        exit 1
    }

    if ($runConfig.AutoRestart) {
        Write-Host "Rebooting system in 5 seconds..." -ForegroundColor Cyan
        Start-Sleep -Seconds 5
        wpeutil.exe reboot
    }
} else {
    Write-Host "Installation canceled by user." -ForegroundColor Yellow
    Write-Host "Use 'wpeutil.exe reboot' to reboot the system." -ForegroundColor white
    Write-Host "Use 'wpeutil.exe shutdown' to poweroff the system." -ForegroundColor white
    Write-Host "Use 'powershell.exe -ExecutionPolicy Bypass -File D:\Scripts\installForm.ps1' to start Windows installation (D: should be the mounted ISO's drive letter)." -ForegroundColor white
}
Read-Host