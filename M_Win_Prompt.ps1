# =================================================================
# LENA & Service Management Tool (Real-time Menu Update)
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

# --- UI 렌더링 함수 (대시보드 + 메뉴 통합) ---
function Render-Full-UI {
    param($stats, $time, $allListen)
    $boxWidth = 70; $line = "─" * ($boxWidth)
    
    goto_xy 0 0
    # 1. 대시보드 영역
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
        Write-Host "│" -NoNewline -ForegroundColor Gray; Write-Host (Pad-Right-Custom $svcInfo $boxWidth) -ForegroundColor $color -NoNewline; Write-Host "│" -ForegroundColor Gray
    }

    Write-Host "├$line┤" -ForegroundColor Gray
    Write-Host "│ " -NoNewline -ForegroundColor Gray
    $msg = if($downCount -gt 0){ "[!] ALERT: $downCount Services Need Check" } else { "[√] ALL SERVICES OPERATIONAL" }
    $msgCol = if($downCount -gt 0){ "Red" } else { "Green" }
    Write-Host (Pad-Right-Custom $msg ($boxWidth-1)) -ForegroundColor $msgCol -NoNewline; Write-Host "│" -ForegroundColor Gray
    Write-Host "└$line┘" -ForegroundColor Gray

    # 2. 제어 메뉴 영역
    $cLine = "─" * ($boxWidth)
    Write-Host "┌$cLine┐" -ForegroundColor Cyan
    Write-Host "│" -NoNewline -ForegroundColor Cyan; Write-Host (Pad-Right-Custom "            LENA SERVICE CONTROL MENU" $boxWidth) -NoNewline -ForegroundColor Cyan; Write-Host "│" -ForegroundColor Cyan
    Write-Host "├$cLine┤" -ForegroundColor Cyan
    $header = " {0,-18} │ {1,-6} │ {2}" -f "SERVICE", "PORT", "CONTROL COMMANDS [ID]"
    Write-Host "│" -NoNewline -ForegroundColor Cyan; Write-Host (Pad-Right-Custom $header $boxWidth) -NoNewline; Write-Host "│" -ForegroundColor Cyan
    Write-Host "├$cLine┤" -ForegroundColor Gray
    
    foreach ($svc in $config.Services) {
        $row = " {0,-18} │ {1,-6} │ Start:{2} Stop:{3} Log:{4}" -f $svc.Name, $svc.Port, $svc.ID, $svc.StopID, $svc.LogID
        Write-Host "│" -NoNewline -ForegroundColor Gray; Write-Host (Pad-Right-Custom $row $boxWidth) -NoNewline; Write-Host "│" -ForegroundColor Gray
    }
    Write-Host "└$cLine┘" -ForegroundColor Gray
    Write-Host "`n [ ESC: EXIT ] | Input ID: " -NoNewline -ForegroundColor White
}

# --- 메인 실행 루프 ---
function main_cmd {
    $userInput = ""
    $menuItems = @{}
    foreach ($svc in $config.Services) {
        $menuItems[$svc.ID] = @{ Key=$svc.Key; Type="Start"; PK="start"; Name=$svc.Name }
        $menuItems[$svc.StopID] = @{ Key=$svc.Key; Type="Stop"; PK="stop"; Name=$svc.Name }
        $menuItems[$svc.LogID] = @{ Key=$svc.Key; Type="Log"; PK="log"; Name=$svc.Name }
    }

    Clear-Host
    [System.Console]::CursorVisible = $true

    while ($true) {
        # 실시간 데이터 수집
        $stats = Get-SystemStats; $time = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        if($isWin){$allListen = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Select-Object -ExpandProperty LocalPort}
        else{$allListen = ss -tuln | Select-String ":(\d+)\s" | ForEach-Object {$_.Matches.Groups[1].Value}}

        # UI 출력 (입력 중인 문자열 표시 포함)
        Render-Full-UI $stats $time $allListen
        Write-Host $userInput -NoNewline

        # 1초 동안 키 입력 대기 (입력 없으면 루프 돌아 화면 갱신)
        if ([Console]::KeyAvailable) {
            $keyInfo = [Console]::ReadKey($true)
            
            if ($keyInfo.Key -eq "Enter") {
                if ($menuItems.ContainsKey($userInput)) {
                    Process-Action $menuItems[$userInput]
                    $userInput = "" # 실행 후 입력값 초기화
                    Clear-Host
                } else {
                    $userInput = "" # 잘못된 입력 초기화
                }
            }
            elseif ($keyInfo.Key -eq "Escape") {
                Clear-Host; exit
            }
            elseif ($keyInfo.Key -eq "BackSpace") {
                if ($userInput.Length -gt 0) { $userInput = $userInput.Substring(0, $userInput.Length - 1) }
            }
            else {
                # 숫자나 문자 입력 추가
                $userInput += $keyInfo.KeyChar
            }
        }
        else {
            Start-Sleep -Milliseconds 500 # 갱신 속도 조절
        }
    }
}

function Process-Action {
    param($item)
    $path = $config.Paths.$targetKey.$($item.Key).$($item.PK)
    
    if ($item.PK -eq "log") {
        Clear-Host; Write-Host ">> LOG MONITORING: $path" -ForegroundColor Yellow
        if(Test-Path $path){ try { Get-Content $path -Wait -Tail 50 } catch { } } 
    } else {
        Write-Host "`n [ TARGET ] $($item.Name) / $($item.Type)" -ForegroundColor Cyan
        Write-Host " [ PATH   ] $path" -ForegroundColor Yellow
        Write-Host " [!] Execute? (y/n): " -NoNewline
        if ((Read-Host) -eq 'y') { 
            try {
                if (-not (Test-Path $cmdPath)) { throw "File not found." }
                Start-Process $path -ErrorAction Stop
                Write-Host "`n [SUCCESS] Command sent." -ForegroundColor Green
            } catch {
                Write-Host "`n [ERROR] $($_.Exception.Message)" -ForegroundColor Red
            }
            Write-Host "`n Press Enter to return..." -ForegroundColor Gray
            Read-Host
        }
    }
}

# 실행
main_cmd
