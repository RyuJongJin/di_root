# =================================================================
# LENA & Service Management Tool (Consistent & Stable Edition)
# =================================================================

$OutputEncoding = [System.Text.Encoding]::UTF8
if ($null -eq $IsWindows) { $Global:IsWindows = $env:OS -like "*Windows*" }
$isWin = $IsWindows

if ($isWin) {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::InputEncoding = [System.Text.Encoding]::UTF8
    $targetKey = "Win"
} else {
    $targetKey = "Lin"
}

if (Test-Path ".\M_Win_cfg.ps1") { . ".\M_Win_cfg.ps1" }

# --- 헬퍼 함수 ---
function Get-DisplayWidth ([string]$str) {
    $width = 0
    foreach ($char in $str.ToCharArray()) {
        if ([int]$char -gt 127) { $width += 2 } 
        else { $width += 1 } 
    }
    return $width
}

function Pad-Right-Custom ([string]$str, [int]$totalWidth) {
    $currentWidth = Get-DisplayWidth $str
    $paddingNeeded = $totalWidth - $currentWidth
    if ($paddingNeeded -lt 0) { return $str }
    return $str + (" " * $paddingNeeded)
}

function goto_xy([int]$x, [int]$y) {
    if ($isWin) { [Console]::SetCursorPosition($x, $y) }
    else { Write-Host -NoNewline "$([char]27)[$($y+1);$($x+1)H" }
}

function Get-SystemStats {
    $stats = @{ CPU=0; MEM=0; SWAP=0; GPU=0; Disks=@(); Hostname=$env:COMPUTERNAME; User=$env:USERNAME }
    try {
        if ($isWin) {
            $cpuSample = (Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction SilentlyContinue).CounterSamples.CookedValue
            $memOS = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
            $stats.CPU = if ($cpuSample) { $cpuSample } else { 0 }
            $stats.MEM = if ($memOS) { (($memOS.TotalVisibleMemorySize - $memOS.FreePhysicalMemory) / $memOS.TotalVisibleMemorySize) * 100 } else { 0 }
            $stats.Disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object { @{ DeviceID = $_.DeviceID; Usage = (($_.Size - $_.FreeSpace) / $_.Size) * 100 } }
        }
    } catch { }
    return $stats
}

# --- 공통 렌더링 박스 (너비 70 고정) ---
function Render-Dashboard-Box {
    param($stats, $time, $allListen)
    $boxWidth = 70
    $line = "─" * ($boxWidth)

    Write-Host "┌$line┐" -ForegroundColor Gray
    $left = " HOST: $($stats.Hostname) ($($stats.User))"; $right = "$time "
    $midSpace = $boxWidth - (Get-DisplayWidth $left) - (Get-DisplayWidth $right)
    Write-Host "│" -NoNewline -ForegroundColor Gray; Write-Host $left -ForegroundColor Cyan -NoNewline
    Write-Host (" " * $midSpace) -NoNewline; Write-Host $right -ForegroundColor Gray -NoNewline; Write-Host "│" -ForegroundColor Gray

    Write-Host "│ " -NoNewline -ForegroundColor Gray
    $resPart = "CPU: {0,3:N0}%  MEM: {1,3:N0}%  DSK: " -f $stats.CPU, $stats.MEM
    Write-Host $resPart -NoNewline
    $dskStr = ""; foreach ($d in $stats.Disks) { $dskStr += "$($d.DeviceID){0,2:N0}% " -f $d.Usage }
    Write-Host (Pad-Right-Custom $dskStr ($boxWidth - (Get-DisplayWidth $resPart) - 1)) -NoNewline
    Write-Host "│" -ForegroundColor Gray

    Write-Host "├$line┤" -ForegroundColor Gray
    $downCount = 0
    foreach ($svc in $config.Services) {
        $isAlive = if($isWin){ $allListen -contains $svc.Port } else { $allListen -contains $svc.Port.ToString() }
        $icon = if($isAlive){ "●" } else { "○" }; $statusText = if($isAlive){ "RUNNING" } else { "STOPPED" }
        $color = if($isAlive){ "Green" } else { "Red" }
        if (-not $isAlive) { $downCount++ }
        $svcInfo = " $icon {0,-18} (Port:{1,5}) -> [{2,-7}]" -f $svc.Name, $svc.Port, $statusText
		$boxWidth = 71
        Write-Host "│" -NoNewline -ForegroundColor Gray; Write-Host (Pad-Right-Custom $svcInfo $boxWidth) -ForegroundColor $color -NoNewline; Write-Host "│" -ForegroundColor Gray
    }
    $boxWidth = 70
    Write-Host "├$line┤" -ForegroundColor Gray
    Write-Host "│ " -NoNewline -ForegroundColor Gray
	
    $msg = if($downCount -gt 0){ "[!] ALERT: $downCount Services Need Check" } else { "[√] ALL SERVICES OPERATIONAL" }
    $msgCol = if($downCount -gt 0){ "Red" } else { "Green" }
    Write-Host (Pad-Right-Custom $msg ($boxWidth-1)) -ForegroundColor $msgCol -NoNewline; Write-Host "│" -ForegroundColor Gray
    Write-Host "└$line┘" -ForegroundColor Gray
}

# --- 1. 실시간 모니터링 ---
function Show-Dashboard-Live {
    [System.Console]::CursorVisible = $false
    while ($true) {
        goto_xy 0 0
        $stats = Get-SystemStats; $time = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        if($isWin){$allListen = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Select-Object -ExpandProperty LocalPort}
        else{$allListen = ss -tuln | Select-String ":(\d+)\s" | ForEach-Object {$_.Matches.Groups[1].Value}}

        Render-Dashboard-Box $stats $time $allListen
        Write-Host " [ ESC: EXIT | ANY KEY: CONTROL MENU ] " -ForegroundColor DarkGray
        
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            if ($key.Key -eq "Escape") { [System.Console]::CursorVisible = $true; Clear-Host; exit } 
            else { [System.Console]::CursorVisible = $true; break } 
        }
        Start-Sleep -Seconds 1	
    }
}

# --- 2. 제어 메뉴 및 복귀 로직 ---
function main_cmd {
    while ($true) {
        Clear-Host
        Show-Dashboard-Live; Clear-Host # 대시보드에서 키 입력 시 메뉴 진입
        
        $stats = Get-SystemStats; $time = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        if($isWin){$allListen = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Select-Object -ExpandProperty LocalPort}
        else{$allListen = ss -tuln | Select-String ":(\d+)\s" | ForEach-Object {$_.Matches.Groups[1].Value}}
        
        Render-Dashboard-Box $stats $time $allListen

        $boxWidth = 70; $line = "─" * ($boxWidth)
        Write-Host "┌$line┐" -ForegroundColor Cyan
        Write-Host "│" -NoNewline -ForegroundColor Cyan; Write-Host (Pad-Right-Custom "            LENA SERVICE CONTROL MENU" $boxWidth) -NoNewline -ForegroundColor Cyan; Write-Host "│" -ForegroundColor Cyan
        Write-Host "├$line┤" -ForegroundColor Cyan
        $header = " {0,-18} │ {1,-6} │ {2}" -f "SERVICE", "PORT", "CONTROL COMMANDS [ID]"
		$boxWidth = 72
        Write-Host "│" -NoNewline -ForegroundColor Cyan; Write-Host (Pad-Right-Custom $header $boxWidth) -NoNewline; Write-Host "│" -ForegroundColor Cyan
        Write-Host "├$line┤" -ForegroundColor Gray
        
        $menuItems = @{}
		
        foreach ($svc in $config.Services) {
            $menuItems[$svc.ID] = @{ Key=$svc.Key; Type="Start"; PK="start"; Name=$svc.Name }
            $menuItems[$svc.StopID] = @{ Key=$svc.Key; Type="Stop"; PK="stop"; Name=$svc.Name }
            $menuItems[$svc.LogID] = @{ Key=$svc.Key; Type="Log"; PK="log"; Name=$svc.Name }
            $row = " {0,-18} │ {1,-6} │ Start:{2} Stop:{3} Log:{4}" -f $svc.Name, $svc.Port, $svc.ID, $svc.StopID, $svc.LogID
            Write-Host "│" -NoNewline -ForegroundColor Gray; Write-Host (Pad-Right-Custom $row $boxWidth) -NoNewline; Write-Host "│" -ForegroundColor Gray
        }
        Write-Host "└$line┘" -ForegroundColor Gray
        
        Write-Host "`n [?] Input ID: " -NoNewline -ForegroundColor White
        $sel = Read-Host; if ([string]::IsNullOrWhiteSpace($sel)) { continue }
        
        if ($menuItems.ContainsKey($sel)) {
            $item = $menuItems[$sel]; $path = $config.Paths.$targetKey.$($item.Key).$($item.PK)
            if ($item.PK -eq "log") {
                Clear-Host; Write-Host ">> LOG MONITORING: $path" -ForegroundColor Yellow
                if(Test-Path $path){ try { Get-Content $path -Wait -Tail 50 } catch { } } 
            } else {
                Write-Host "`n [ TARGET ] $($item.Name) / $($item.Type)" -ForegroundColor Cyan
                Write-Host " [ PATH   ] $path" -ForegroundColor Yellow
                Write-Host " [!] Execute? (y/n): " -NoNewline
                if ((Read-Host) -eq 'y') { 
                    Invoke-LenaAction $path $item.Type 
                }
            }
        }
    }
}

function Invoke-LenaAction {
    param($cmdPath, $type)
    try {
        if (-not (Test-Path $cmdPath)) { throw "File not found: $cmdPath" }
        Start-Process $cmdPath -ErrorAction Stop
        Write-Host "`n [SUCCESS] Command sent." -ForegroundColor Green
    } catch {
        Write-Host "`n [ERROR] $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host "`n Press Enter to return to Dashboard..." -ForegroundColor Gray
    Read-Host 
    Clear-Host
}

# --- 실행 ---
Clear-Host
main_cmd
