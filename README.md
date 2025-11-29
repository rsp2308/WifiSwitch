# WiFi Failover Monitor

Automatic WiFi failover system that switches to USB tethering when WiFi is down and automatically reconnects to WiFi when available.

## Features

- 🔄 Automatic failover from WiFi to USB tethering
- 🔌 Automatic reconnection to WiFi when available
- 📊 Real-time monitoring and status updates
- 📝 Event-based logging (no spam, only important events)
- ⏰ Timestamped logs for easy tracking
- 🎨 Color-coded console output
- 🖥️ GUI version with visual status indicators

## Versions

### Console Version (`failover.exe`)
- ✅ Runs with visible console window
- ✅ Shows timestamped logs for all events
- ✅ Minimal, clean logging (only shows changes)
- ✅ Perfect for background monitoring
- ✅ **Fully working and tested**

### GUI Version (`failover_gui.ps1`)
- Run directly with: `powershell -ExecutionPolicy Bypass -File failover_gui.ps1`
- Modern Windows Forms interface
- Visual status indicators for WiFi and USB
- Real-time activity log with color coding
- Start/Stop controls
- Clear log functionality
- **Note:** Run the .ps1 file directly for best compatibility

## How It Works

1. Continuously monitors active network interface (every 3 seconds)
2. When WiFi goes down:
   - Automatically switches to USB tethering
   - Attempts to reconnect WiFi in background
   - Logs reconnection attempts (every 10 seconds)
3. When WiFi comes back:
   - Verifies internet connectivity via ping to 8.8.8.8
   - Automatically switches back to WiFi
   - Logs successful reconnection

## Configuration

Edit these variables in the `.ps1` files to match your setup:

```powershell
$wifi = "Wi-Fi"              # Your WiFi interface name
$usb = "Ethernet 2"          # Your USB tethering interface name
$wifiSSID = "LPU Wireless" # Your WiFi network name
```

## Requirements

- Windows 10/11
- Administrator privileges (required for network metric changes)
- PowerShell 5.1 or later

## Installation

1. Download the appropriate executable:
   - `failover.exe` for console version
   - `failover_gui.exe` for GUI version

2. Run as Administrator (required)

3. For auto-start on Windows boot:
   - Press `Win + R`
   - Type `shell:startup`
   - Create a shortcut to the exe in this folder
   - Set shortcut to run as administrator

## Network Priority

The script uses Windows network interface metrics:
- WiFi metric: 1 (highest priority)
- USB metric: 100 (lowest priority)

This ensures automatic failback to WiFi when it becomes available.

## Logs

### Console Version
Logs are displayed in the console window with color coding:
- 🟢 Green: WiFi online/active
- 🔴 Red: WiFi down, switched to USB
- 🟡 Yellow: Reconnection attempts
- 🔵 Cyan: System messages

### GUI Version
Logs are shown in the activity log panel with:
- Visual status indicators (✓/✗)
- Color-coded messages
- Scrollable history
- Clear log button

## Troubleshooting

### Finding Interface Names
Run in PowerShell:
```powershell
Get-NetAdapter | Select-Object Name, InterfaceDescription, Status
```

### Finding WiFi SSID
Run in PowerShell:
```powershell
netsh wlan show interfaces
```

### Exe Not Starting
- Make sure to run as Administrator
- Check Windows Defender/Antivirus isn't blocking it
- Verify interface names match your system

## Development

### Source Files
- `failover.ps1` - Console version source
- `failover_gui.ps1` - GUI version source

### Building from Source
Requires PS2EXE module:
```powershell
Install-Module -Name ps2exe
Invoke-PS2EXE -inputFile "failover.ps1" -outputFile "failover.exe" -requireAdmin
Invoke-PS2EXE -inputFile "failover_gui.ps1" -outputFile "failover_gui.exe" -requireAdmin -noConsole
```

## Git Checkpoints

Current checkpoint includes:
- ✅ Working console version with smart logging
- ✅ GUI version with visual interface
- ✅ Automatic WiFi reconnection with ping verification
- ✅ Priority-based network switching
- ✅ Event-based logging (no spam)

## License

Free to use and modify.

## Author

Created for reliable WiFi failover management on Windows systems.
