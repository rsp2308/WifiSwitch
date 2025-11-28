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
        Write-Host "Warning: Could not load settings file, using defaults" -ForegroundColor Yellow
    }
}

# Check if settings are configured
if ($script:wifiSSID -eq "YOUR_WIFI_SSID") {
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "  CONFIGURATION REQUIRED" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please create a settings.json file with your configuration:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host '{' -ForegroundColor Cyan
    Write-Host '  "WiFiSSID": "YourWiFiName",' -ForegroundColor Cyan
    Write-Host '  "WiFiInterface": "Wi-Fi",' -ForegroundColor Cyan
    Write-Host '  "USBInterface": "Ethernet 2"' -ForegroundColor Cyan
    Write-Host '}' -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Or use the GUI version (failover_gui.exe) for easy configuration." -ForegroundColor Green
    Write-Host ""
    pause
    exit
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
    Write-Host "[$timestamp] Attempting to reconnect WiFi..." -ForegroundColor Yellow
    netsh wlan connect name="$($script:wifiSSID)" | Out-Null
}

# Startup message
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  WiFi Failover Monitor Started" -ForegroundColor Cyan
Write-Host "  Monitoring: $($script:wifiSSID)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

while ($true) {

    $active = Get-ActiveInterface

    if ($active -eq $script:wifi) {
        # Log on first run and when switching to WiFi
        if ($firstRun) {
            $timestamp = Get-Timestamp
            Write-Host "[$timestamp] WiFi is ACTIVE - Monitoring started" -ForegroundColor Green
            $firstRun = $false
        }
        elseif ($lastActive -ne $wifi -and $lastActive -ne "") {
            $timestamp = Get-Timestamp
            Write-Host "[$timestamp] WiFi is back ONLINE" -ForegroundColor Green
        }
        Set-Metrics 1 100  # Give WiFi highest priority
        $lastActive = $wifi
    }
    elseif ($active -eq $usb) {
        # Log on first run and when switching to USB
        if ($firstRun) {
            $timestamp = Get-Timestamp
            Write-Host "[$timestamp] USB Tethering is ACTIVE - Monitoring started" -ForegroundColor Yellow
            $firstRun = $false
        }
        elseif ($lastActive -ne $script:usb) {
            $timestamp = Get-Timestamp
            Write-Host "[$timestamp] WiFi DOWN - Switched to USB Tethering" -ForegroundColor Red
        }
        Set-Metrics 1 100
        $lastActive = $script:usb
        
        # Always try to reconnect WiFi, but check if it has internet before considering it ready
        $now = Get-Date
        if (($now - $lastReconnectTime).TotalSeconds -ge 10) {
            TryReconnectWiFi
            $lastReconnectTime = $now
        }
        else {
            # Silently attempt reconnection without logging
            netsh wlan connect name="$($script:wifiSSID)" | Out-Null
        }
    }
    else {
        if ($lastActive -ne "unknown") {
            $timestamp = Get-Timestamp
            Write-Host "[$timestamp] Unknown route detected - Defaulting to WiFi" -ForegroundColor Cyan
        }
        Set-Metrics 1 100  # Prefer WiFi
        $lastActive = "unknown"
    }

    Start-Sleep -Seconds 3
}
