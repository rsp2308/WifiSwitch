Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$wifi = "Wi-Fi"
$usb = "Ethernet 2"
$wifiSSID = "AARAV PG 2F 5G"

# Track state to log only on changes
$lastActive = ""
$firstRun = $true
$lastReconnectTime = [DateTime]::MinValue

function Get-Timestamp {
    return Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}

function Set-Metrics($wifiMetric, $usbMetric) {
    Set-NetIPInterface -InterfaceAlias $wifi -InterfaceMetric $wifiMetric -ErrorAction SilentlyContinue
    Set-NetIPInterface -InterfaceAlias $usb -InterfaceMetric $usbMetric -ErrorAction SilentlyContinue
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
    netsh wlan connect name="$wifiSSID" | Out-Null
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
    $script:logBox.ScrollToCaret()
}

# Create the form
$form = New-Object System.Windows.Forms.Form
$form.Text = "WiFi Failover Monitor"
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
$statusPanel.Location = New-Object System.Drawing.Point(20, 60)
$statusPanel.Size = New-Object System.Drawing.Size(560, 60)
$statusPanel.BorderStyle = "FixedSingle"
$form.Controls.Add($statusPanel)

$wifiStatusLabel = New-Object System.Windows.Forms.Label
$wifiStatusLabel.Location = New-Object System.Drawing.Point(10, 10)
$wifiStatusLabel.Size = New-Object System.Drawing.Size(270, 40)
$wifiStatusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$wifiStatusLabel.Text = "WiFi: Checking..."
$statusPanel.Controls.Add($wifiStatusLabel)

$usbStatusLabel = New-Object System.Windows.Forms.Label
$usbStatusLabel.Location = New-Object System.Drawing.Point(290, 10)
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
$stopButton.Location = New-Object System.Drawing.Point(410, 415)
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
$startButton.Location = New-Object System.Drawing.Point(500, 415)
$startButton.Size = New-Object System.Drawing.Size(80, 30)
$startButton.Text = "Start"
$startButton.Add_Click({
    $script:running = $true
    $stopButton.Enabled = $true
    $startButton.Enabled = $false
    Add-Log "Monitoring started" "Cyan"
})
$form.Controls.Add($startButton)

# Clear Log Button
$clearButton = New-Object System.Windows.Forms.Button
$clearButton.Location = New-Object System.Drawing.Point(20, 415)
$clearButton.Size = New-Object System.Drawing.Size(80, 30)
$clearButton.Text = "Clear Log"
$clearButton.Add_Click({
    $logBox.Clear()
})
$form.Controls.Add($clearButton)

# Timer for monitoring
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 3000  # 3 seconds
$script:running = $false

$timer.Add_Tick({
    if (-not $script:running) { return }
    
    $active = Get-ActiveInterface

    if ($active -eq $wifi) {
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
        elseif ($script:lastActive -ne $wifi -and $script:lastActive -ne "") {
            $timestamp = Get-Timestamp
            Add-Log "[$timestamp] WiFi is back ONLINE" "Green"
        }
        Set-Metrics 1 100
        $script:lastActive = $wifi
    }
    elseif ($active -eq $usb) {
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
        elseif ($script:lastActive -ne $usb) {
            $timestamp = Get-Timestamp
            Add-Log "[$timestamp] WiFi DOWN - Switched to USB Tethering" "Red"
        }
        Set-Metrics 1 100
        $script:lastActive = $usb
        
        # Try to reconnect WiFi
        $now = Get-Date
        if (($now - $script:lastReconnectTime).TotalSeconds -ge 10) {
            TryReconnectWiFi
            $script:lastReconnectTime = $now
        }
        else {
            netsh wlan connect name="$wifiSSID" | Out-Null
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
})

# Initial message
Add-Log "========================================" "Cyan"
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
