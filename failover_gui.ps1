Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Default settings (will be overridden by user config)
$script:wifi = "Wi-Fi"
$script:usb = "Ethernet 2"
$script:wifiSSID = "YOUR_WIFI_SSID"

# Load settings from file if exists
$settingsFile = Join-Path $PSScriptRoot "settings.json"
if (Test-Path $settingsFile) {
    try {
        $settings = Get-Content $settingsFile | ConvertFrom-Json
        $script:wifi = $settings.WiFiInterface
        $script:usb = $settings.USBInterface
        $script:wifiSSID = $settings.WiFiSSID
    } catch {
        # Use defaults if file is corrupted
    }
}

# Track state to log only on changes
$lastActive = ""
$firstRun = $true
$lastReconnectTime = [DateTime]::MinValue

function Get-Timestamp {
    return Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}

function Set-Metrics($wifiMetric, $usbMetric) {
    Set-NetIPInterface -InterfaceAlias $script:wifi -InterfaceMetric $wifiMetric -ErrorAction SilentlyContinue
    Set-NetIPInterface -InterfaceAlias $script:usb -InterfaceMetric $usbMetric -ErrorAction SilentlyContinue
}

function Get-ActiveInterface {
    $route = Get-NetRoute -DestinationPrefix "0.0.0.0/0" |
             Sort-Object RouteMetric |
             Select-Object -First 1

    return $route.InterfaceAlias
}

function Is-WiFiConnected {
    $wifiStatus = netsh wlan show interfaces | Select-String "State"
    if ($wifiStatus -match "connected") {
        return $true
    }
    return $false
}

function Test-WiFiInternet {
    # Check if WiFi is connected AND has internet access
    $wifiConnected = Is-WiFiConnected
    if (-not $wifiConnected) {
        return $false
    }
    
    # Test internet connectivity via ping
    $ping = Test-Connection -ComputerName 8.8.8.8 -Count 1 -Quiet -ErrorAction SilentlyContinue
    return $ping
}

function TryReconnectWiFi {
    $timestamp = Get-Timestamp
    Add-Log "[$timestamp] Attempting to reconnect WiFi..." "Yellow"
    netsh wlan connect name="$($script:wifiSSID)" | Out-Null
}

function Save-Settings {
    $settings = @{
        WiFiInterface = $script:wifi
        USBInterface = $script:usb
        WiFiSSID = $script:wifiSSID
    }
    $settings | ConvertTo-Json | Set-Content $settingsFile
}

function Show-SettingsDialog {
    $settingsForm = New-Object System.Windows.Forms.Form
    $settingsForm.Text = "Settings"
    $settingsForm.Size = New-Object System.Drawing.Size(450, 280)
    $settingsForm.StartPosition = "CenterParent"
    $settingsForm.FormBorderStyle = "FixedDialog"
    $settingsForm.MaximizeBox = $false
# Create the form
$form = New-Object System.Windows.Forms.Form
$form.Text = "WiFi Failover Monitor"
$form.Size = New-Object System.Drawing.Size(600, 500)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

# Menu Strip
$menuStrip = New-Object System.Windows.Forms.MenuStrip
$fileMenu = New-Object System.Windows.Forms.ToolStripMenuItem
$fileMenu.Text = "File"

$settingsMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$settingsMenuItem.Text = "Settings"
$settingsMenuItem.Add_Click({ Show-SettingsDialog })
$fileMenu.DropDownItems.Add($settingsMenuItem)

$exitMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$exitMenuItem.Text = "Exit"
$exitMenuItem.Add_Click({ $form.Close() })
$fileMenu.DropDownItems.Add($exitMenuItem)

$menuStrip.Items.Add($fileMenu)
$form.Controls.Add($menuStrip)
$form.MainMenuStrip = $menuStrip

# Status Label
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(20, 35)
$statusLabel.Size = New-Object System.Drawing.Size(560, 30)
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$statusLabel.Text = "Status: Initializing..."
$form.Controls.Add($statusLabel)
    # WiFi Interface
    $lblWiFi = New-Object System.Windows.Forms.Label
    $lblWiFi.Location = New-Object System.Drawing.Point(20, 60)
    $lblWiFi.Size = New-Object System.Drawing.Size(150, 20)
    $lblWiFi.Text = "WiFi Interface Name:"
    $settingsForm.Controls.Add($lblWiFi)
    
    $txtWiFi = New-Object System.Windows.Forms.TextBox
    $txtWiFi.Location = New-Object System.Drawing.Point(180, 60)
    $txtWiFi.Size = New-Object System.Drawing.Size(240, 20)
    $txtWiFi.Text = $script:wifi
    $settingsForm.Controls.Add($txtWiFi)
    
    # USB Interface
    $lblUSB = New-Object System.Windows.Forms.Label
    $lblUSB.Location = New-Object System.Drawing.Point(20, 100)
    $lblUSB.Size = New-Object System.Drawing.Size(150, 20)
    $lblUSB.Text = "USB Interface Name:"
    $settingsForm.Controls.Add($lblUSB)
    
    $txtUSB = New-Object System.Windows.Forms.TextBox
    $txtUSB.Location = New-Object System.Drawing.Point(180, 100)
    $txtUSB.Size = New-Object System.Drawing.Size(240, 20)
    $txtUSB.Text = $script:usb
    $settingsForm.Controls.Add($txtUSB)
    
    # Help text
    $helpLabel = New-Object System.Windows.Forms.Label
    $helpLabel.Location = New-Object System.Drawing.Point(20, 140)
    $helpLabel.Size = New-Object System.Drawing.Size(400, 40)
    $helpLabel.Text = "Tip: Run 'Get-NetAdapter' in PowerShell to find interface names.`nRun 'netsh wlan show interfaces' to find your WiFi SSID."
    $helpLabel.ForeColor = [System.Drawing.Color]::Gray
    $settingsForm.Controls.Add($helpLabel)
    
    # Buttons
    $btnSave = New-Object System.Windows.Forms.Button
    $btnSave.Location = New-Object System.Drawing.Point(260, 200)
    $btnSave.Size = New-Object System.Drawing.Size(75, 30)
    $btnSave.Text = "Save"
    $btnSave.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $btnSave.Add_Click({
        $script:wifiSSID = $txtSSID.Text
        $script:wifi = $txtWiFi.Text
        $script:usb = $txtUSB.Text
        Save-Settings
        Add-Log "Settings saved successfully" "Green"
        $statusLabel.Text = "Status: Settings Updated - Restart monitoring"
        $settingsForm.Close()
    })
    $settingsForm.Controls.Add($btnSave)
    
    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Location = New-Object System.Drawing.Point(345, 200)
    $btnCancel.Size = New-Object System.Drawing.Size(75, 30)
    $btnCancel.Text = "Cancel"
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $settingsForm.Controls.Add($btnCancel)
    
    $settingsForm.AcceptButton = $btnSave
    $settingsForm.CancelButton = $btnCancel
    
    [void]$settingsForm.ShowDialog()
}

function Add-Log($message, $color = "Black") {
    $script:logBox.SelectionStart = $script:logBox.TextLength
    $script:logBox.SelectionLength = 0
    
    switch($color) {
        "Green" { $script:logBox.SelectionColor = [System.Drawing.Color]::Green }
        "Red" { $script:logBox.SelectionColor = [System.Drawing.Color]::Red }
        "Yellow" { $script:logBox.SelectionColor = [System.Drawing.Color]::DarkOrange }
        "Cyan" { $script:logBox.SelectionColor = [System.Drawing.Color]::DarkCyan }
        default { $script:logBox.SelectionColor = [System.Drawing.Color]::Black }
    }
    
    $script:logBox.AppendText("$message`r`n")
# Connection Status Panel
$statusPanel = New-Object System.Windows.Forms.Panel
$statusPanel.Location = New-Object System.Drawing.Point(20, 75)
$statusPanel.Size = New-Object System.Drawing.Size(560, 60)
$statusPanel.BorderStyle = "FixedSingle"
$form.Controls.Add($statusPanel)tor"
$form.Size = New-Object System.Drawing.Size(600, 500)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

# Status Label
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(20, 20)
$statusLabel.Size = New-Object System.Drawing.Size(560, 30)
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$statusLabel.Text = "Status: Initializing..."
$form.Controls.Add($statusLabel)

# Connection Status Panel
$statusPanel = New-Object System.Windows.Forms.Panel
# Log Box
$logLabel = New-Object System.Windows.Forms.Label
$logLabel.Location = New-Object System.Drawing.Point(20, 145)
$logLabel.Size = New-Object System.Drawing.Size(100, 20)
$logLabel.Text = "Activity Log:"
$form.Controls.Add($logLabel)

$logBox = New-Object System.Windows.Forms.RichTextBox
$logBox.Location = New-Object System.Drawing.Point(20, 170)
$logBox.Size = New-Object System.Drawing.Size(560, 250)
$logBox.ReadOnly = $true
$logBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$logBox.BackColor = [System.Drawing.Color]::White
$form.Controls.Add($logBox)New-Object System.Drawing.Point(290, 10)
$usbStatusLabel.Size = New-Object System.Drawing.Size(260, 40)
$usbStatusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$usbStatusLabel.Text = "USB: Checking..."
$statusPanel.Controls.Add($usbStatusLabel)

# Log Box
$logLabel = New-Object System.Windows.Forms.Label
$logLabel.Location = New-Object System.Drawing.Point(20, 130)
$logLabel.Size = New-Object System.Drawing.Size(100, 20)
$logLabel.Text = "Activity Log:"
$form.Controls.Add($logLabel)

$logBox = New-Object System.Windows.Forms.RichTextBox
$logBox.Location = New-Object System.Drawing.Point(20, 155)
$logBox.Size = New-Object System.Drawing.Size(560, 250)
$logBox.ReadOnly = $true
$logBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$logBox.BackColor = [System.Drawing.Color]::White
$form.Controls.Add($logBox)

# Buttons
$stopButton = New-Object System.Windows.Forms.Button
$stopButton.Location = New-Object System.Drawing.Point(410, 430)
$stopButton.Size = New-Object System.Drawing.Size(80, 30)
$stopButton.Text = "Stop"
$stopButton.Enabled = $false
$stopButton.Add_Click({
    $script:running = $false
    $stopButton.Enabled = $false
    $startButton.Enabled = $true
    Add-Log "Monitoring stopped by user" "Cyan"
})
$form.Controls.Add($stopButton)

$startButton = New-Object System.Windows.Forms.Button
$startButton.Location = New-Object System.Drawing.Point(500, 430)
$startButton.Size = New-Object System.Drawing.Size(80, 30)
$startButton.Text = "Start"
$startButton.Add_Click({
    if ($script:wifiSSID -eq "YOUR_WIFI_SSID") {
        [System.Windows.Forms.MessageBox]::Show("Please configure settings first (File -> Settings)", "Settings Required", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        Show-SettingsDialog
        return
    }
    $script:running = $true
    $stopButton.Enabled = $true
    $startButton.Enabled = $false
    Add-Log "Monitoring started" "Cyan"
})
$form.Controls.Add($startButton)

# Clear Log Button
$clearButton = New-Object System.Windows.Forms.Button
$clearButton.Location = New-Object System.Drawing.Point(20, 430)
$clearButton.Size = New-Object System.Drawing.Size(80, 30)
$clearButton.Text = "Clear Log"
$clearButton.Add_Click({
    $logBox.Clear()
})
$form.Controls.Add($clearButton)

$timer.Add_Tick({
    if (-not $script:running) { return }
    
    $active = Get-ActiveInterface

    if ($active -eq $script:wifi) {
        $statusLabel.Text = "Status: WiFi Active"
        $statusLabel.ForeColor = [System.Drawing.Color]::Green
        $wifiStatusLabel.Text = "WiFi: ✓ Connected`nStatus: Active"
        $wifiStatusLabel.ForeColor = [System.Drawing.Color]::Green
        $usbStatusLabel.Text = "USB: Standby"
        $usbStatusLabel.ForeColor = [System.Drawing.Color]::Gray
        
        if ($script:firstRun) {
            $timestamp = Get-Timestamp
            Add-Log "[$timestamp] WiFi is ACTIVE - Monitoring started" "Green"
            $script:firstRun = $false
        }
        elseif ($script:lastActive -ne $script:wifi -and $script:lastActive -ne "") {
            $timestamp = Get-Timestamp
            Add-Log "[$timestamp] WiFi is back ONLINE" "Green"
        }
        Set-Metrics 1 100
        $script:lastActive = $script:wifi
    }
    elseif ($active -eq $script:usb) {
        $statusLabel.Text = "Status: USB Tethering Active (WiFi Down)"
        $statusLabel.ForeColor = [System.Drawing.Color]::Red
        $wifiStatusLabel.Text = "WiFi: ✗ Disconnected`nStatus: Reconnecting..."
        $wifiStatusLabel.ForeColor = [System.Drawing.Color]::Red
        $usbStatusLabel.Text = "USB: ✓ Connected`nStatus: Active"
        $usbStatusLabel.ForeColor = [System.Drawing.Color]::DarkOrange
        
        if ($script:firstRun) {
            $timestamp = Get-Timestamp
            Add-Log "[$timestamp] USB Tethering is ACTIVE - Monitoring started" "Yellow"
            $script:firstRun = $false
        }
        elseif ($script:lastActive -ne $script:usb) {
            $timestamp = Get-Timestamp
            Add-Log "[$timestamp] WiFi DOWN - Switched to USB Tethering" "Red"
        }
        Set-Metrics 1 100
        $script:lastActive = $script:usb
        
        # Try to reconnect WiFi
        $now = Get-Date
        if (($now - $script:lastReconnectTime).TotalSeconds -ge 10) {
            TryReconnectWiFi
            $script:lastReconnectTime = $now
        }
        else {
            netsh wlan connect name="$($script:wifiSSID)" | Out-Null
        }
    }
    else {
        $statusLabel.Text = "Status: Unknown Route"
        $statusLabel.ForeColor = [System.Drawing.Color]::Orange
        
        if ($script:lastActive -ne "unknown") {
            $timestamp = Get-Timestamp
            Add-Log "[$timestamp] Unknown route detected - Defaulting to WiFi" "Cyan"
        }
        Set-Metrics 1 100
        $script:lastActive = "unknown"
    }
})          Add-Log "[$timestamp] Unknown route detected - Defaulting to WiFi" "Cyan"
        }
# Initial message
Add-Log "========================================" "Cyan"
Add-Log "  WiFi Failover Monitor" "Cyan"
if ($script:wifiSSID -eq "YOUR_WIFI_SSID") {
    Add-Log "  Please configure settings (File -> Settings)" "Yellow"
} else {
    Add-Log "  Monitoring: $($script:wifiSSID)" "Cyan"
}
Add-Log "========================================" "Cyan"
Add-Log ""
Add-Log "Click 'Start' to begin monitoring" "Cyan" "Cyan"
Add-Log "  WiFi Failover Monitor" "Cyan"
Add-Log "  Monitoring: $wifiSSID" "Cyan"
Add-Log "========================================" "Cyan"
Add-Log ""
Add-Log "Click 'Start' to begin monitoring" "Cyan"

$form.Add_Shown({
    $timer.Start()
})

$form.Add_FormClosing({
    $timer.Stop()
    $timer.Dispose()
})

[void]$form.ShowDialog()
