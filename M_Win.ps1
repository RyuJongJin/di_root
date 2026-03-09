
# =================================================================                     
# LENA & Service Integrated Management Tool (Encoding Fixed)
# =================================================================

Add-Type -AssemblyName System.Windows.Forms



# 1. 인코딩 및 버전 호환성 설정 (한글 깨짐 방지)
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

if ($null -eq $IsWindows) { $Global:IsWindows = $env:OS -like "*Windows*" }
$targetKey = "Win"

function goto_xy([int]$x, [int]$y) { [Console]::SetCursorPosition($x, $y) }

# ---------------------------------------------------------
# 설정 데이터
# ---------------------------------------------------------
. ".\M_Win_cfg.ps1"
#$config = @{
#    Services = @(
#        @{ ID="11"; Name="Web Service";   Port=9999;  Key="web";      StopID="21"; LogID="81" }
#        @{ ID="12"; Name="WAS Service";   Port=8888;  Key="was";      StopID="22"; LogID="82" }
#        @{ ID="13"; Name="Web Agent";     Port=18001; Key="webAgent"; StopID="23"; LogID="83" }
#        @{ ID="14"; Name="WAS Agent";     Port=18002; Key="wasAgent"; StopID="24"; LogID="84" }
#        @{ ID="15"; Name="Lena Manager";  Port=7700;  Key="manager";  StopID="25"; LogID="85" }
#        @{ ID="16"; Name="DB Service";    Port=5001;  Key="db";       StopID="26"; LogID="86" }
#    )
#    Paths = @{
#        Win = @{
#            web      = @{ start="d:\engn001\lenaw\1.3\bin\start_service.bat"; stop="d:\engn001\lenaw\1.3\bin\stop_service.bat"; log="d:\logs001\lenaw\node\weblog.log" }
#            was      = @{ start="d:\engn001\lena\1.3\bin\start_service.sh";   stop="d:\engn001\lena\1.3\bin\stop_service.sh";   log="d:\logs001\lena\node\weblog.log" }
#            webAgent = @{ start="d:\engn001\lenaw\1.3\bin\start_agent.sh";   stop="d:\engn001\lenaw\1.3\bin\stop_agent.sh";    log="d:\logs001\lenaw\node\weblog.log" }
#            wasAgent = @{ start="d:\engn001\lena\1.3\bin\start_agent.sh";    stop="d:\engn001\lena\1.3\bin\stop_agent.sh";    log="d:\logs001\lena\node\weblog.log" }
#            manager  = @{ start="d:\engn001\lenaw\1.3\bin\manager.bat";      stop="d:\engn001\lenaw\1.3\bin\stop_manager.bat"; log="d:\logs001\lenaw\node\weblog.log" }
#            db       = @{ start="echo DB Start"; stop="echo DB Stop"; log="d:\logs001\tomcat\log.log" }
#        }
#        Lin = @{
#            web      = @{ start="/engn001/lenaw/1.3/bin/start.sh";        stop="/engn001/lenaw/1.3/bin/stop.sh";        log="/logs001/lenaw/node/weblog.log" }
#            was      = @{ start="/engn001/lena/1.3/bin/start.sh";         stop="/engn001/lena/1.3/bin/stop.sh";         log="/logs001/lena/node/weblog.log" }
#            webAgent = @{ start="/engn001/lenaw/1.3/bin/start_agent.sh";  stop="/engn001/lenaw/1.3/bin/stop_agent.sh";  log="/logs001/lenaw/node/weblog.log" }
#            wasAgent = @{ start="/engn001/lena/1.3/bin/start_agent.sh";   stop="/engn001/lena/1.3/bin/stop_agent.sh";   log="/logs001/lena/node/weblog.log" }
#            manager  = @{ start="/engn001/lenaw/1.3/bin/start_manager.sh"; stop="/engn001/lenaw/1.3/bin/stop_manager.sh"; log="/logs001/lenaw/node/weblog.log" }
#            db       = @{ start="echo DB Start"; stop="echo DB Stop"; log="/logs001/tomcat/log.log" }
#        }
#    }
#}

# 2. 자원 수집 함수
function Get-SystemStats {
    $cpu = (Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction SilentlyContinue).CounterSamples.CookedValue
    $memOS = Get-CimInstance Win32_OperatingSystem
    $memUsage = (($memOS.TotalVisibleMemorySize - $memOS.FreePhysicalMemory) / $memOS.TotalVisibleMemorySize) * 100
    $swapUsage = if ($memOS.SizeStoredInPagingFiles -gt 0) { (($memOS.SizeStoredInPagingFiles - $memOS.FreeSpaceInPagingFiles) / $memOS.SizeStoredInPagingFiles) * 100 } else { 0 }
    $disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
        @{ DeviceID = $_.DeviceID; Usage = (($_.Size - $_.FreeSpace) / $_.Size) * 100 }
    }
    $gpuUsage = 0
    if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
        $gpuInfo = nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits -ErrorAction SilentlyContinue
        if ($gpuInfo) { $gpuUsage = [float]$gpuInfo[0] }
    }
    return @{ 
        CPU=$cpu; MEM=$memUsage; SWAP=$swapUsage; GPU=$gpuUsage; Disks=$disks;
        Hostname = $env:COMPUTERNAME; User = $env:USERNAME
    }
}

function Get-StatColor([float]$value) {
    if ($value -gt 90) { return "Red" }
    if ($value -gt 80) { return "Yellow" }
    return "Green"
}

# 3. 실시간 대시보드
$main_mode ="cmd"
function Show-Dashboard-Live {
    [System.Console]::CursorVisible = $false
   

    while ($true) {
        goto_xy 0 0
        $stats = Get-SystemStats
        $conn = Get-NetTCPConnection -ErrorAction SilentlyContinue
        $allListen = $conn | Where-Object { $_.State -eq 'Listen' }
        $time = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        
        Write-Host "================================================================" -ForegroundColor Gray
        Write-Host " [$main_mode] " -NoNewline -ForegroundColor Cyan
        Write-Host "$($stats.Hostname) ($($stats.User))" -ForegroundColor White -NoNewline
        Write-Host " | $time" -ForegroundColor Gray
        
        Write-Host " [SYS] " -NoNewline -ForegroundColor Cyan
        Write-Host "CPU:" -NoNewline; Write-Host ("{0,3:N0}%" -f $stats.CPU) -ForegroundColor (Get-StatColor $stats.CPU) -NoNewline
        Write-Host " MEM:" -NoNewline; Write-Host ("{0,3:N0}%" -f $stats.MEM) -ForegroundColor (Get-StatColor $stats.MEM) -NoNewline
        Write-Host " SWP:" -NoNewline; Write-Host ("{0,3:N0}%" -f $stats.SWAP) -ForegroundColor (Get-StatColor $stats.SWAP) -NoNewline
        Write-Host " GPU:" -NoNewline; Write-Host ("{0,3:N0}%" -f $stats.GPU) -ForegroundColor (Get-StatColor $stats.GPU) -NoNewline
                
        Write-Host " | [DSK] " -NoNewline -ForegroundColor Cyan
        foreach ($d in $stats.Disks) {
            Write-Host "$($d.DeviceID)" -NoNewline
            Write-Host ("{0,2:N0}% " -f $d.Usage) -ForegroundColor (Get-StatColor $d.Usage) -NoNewline
        }
        Write-Host "`n [ ESC: 종료 | 아무 키: 제어 메뉴 ]" -ForegroundColor DarkGray
        Write-Host "----------------------------------------------------------------"
        
        foreach ($svc in $config.Services) {
            $count = ($allListen | Where-Object { $_.LocalPort -eq $svc.Port }).Count
            
            $statusStr = if ($count -gt 0) { "[ RUNNING ]" } else { "[ STOPPED ]" }
            $colorStr = if ($count -gt 0) { "Green" } else { "Red" }
            $listenColor = if ($count -gt 0) { "Cyan" } else { "Red" }
            
            Write-Host (" {0,-12} (Port:{1,5})-> " -f $svc.Name, $svc.Port) -NoNewline
            Write-Host "(Listen: [" -NoNewline -ForegroundColor Gray
            Write-Host ("{0,1}" -f $count) -ForegroundColor $listenColor -NoNewline
            Write-Host "]) " -NoNewline -ForegroundColor Gray
            Write-Host ("{0,-12}" -f $statusStr) -ForegroundColor $colorStr
        }
        Write-Host "================================================================"
        
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            if ($key.Key -eq "Escape") {  [System.Console]::CursorVisible = $true ; Clear-Host; exit } else {  [System.Console]::CursorVisible = $true ;break } 
        }
        Start-Sleep -Seconds 1	
    }
 
}

#
# cmd 
#
function main_cmd {
    Clear-Host
    while ($true) {
        # 1. 실시간 대시보드 표시 (여기서 ESC를 누르면 종료, 다른 키를 누르면 break로 빠져나옴)
        
        Show-Dashboard-Live 
        Clear-Host
        Write-Host "================================================================" -ForegroundColor Gray
        Write-Host "   LENA MANAGEMENT MENU (ID 입력 후 Enter)                      " -ForegroundColor Cyan
        Write-Host "================================================================"
        
        $menuItems = @{}
        $activePorts = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Select-Object -ExpandProperty LocalPort
        
        foreach ($svc in $config.Services) {
            $isAlive = $activePorts -contains $svc.Port
            $mStatus = if ($isAlive) { "RUN" } else { "STOP" }
            $mColor  = if ($isAlive) { "Green" } else { "Red" }

            #Write-Host (" {0,-11} " -f $($svc.Name) )  -NoNewline
			Write-Host (" {0,-12} (Port:{1,5})-> " -f $svc.Name, $svc.Port) -NoNewline
			
            Write-Host (" {0,-4} "-f $mStatus)  -ForegroundColor $mColor -NoNewline
            Write-Host " > [" -NoNewline; Write-Host "$($svc.ID)" -ForegroundColor Green -NoNewline; Write-Host "]Start [" -NoNewline
            Write-Host "$($svc.StopID)" -ForegroundColor Red -NoNewline; Write-Host "]Stop [" -NoNewline
            Write-Host "$($svc.LogID)" -ForegroundColor Yellow -NoNewline; Write-Host "]Log"
            
            $menuItems[$svc.ID]     = @{ Key=$svc.Key; Type="기동(Start)";    PathKey="start" }
            $menuItems[$svc.StopID] = @{ Key=$svc.Key; Type="중지(Stop)";     PathKey="stop"  }
            $menuItems[$svc.LogID]  = @{ Key=$svc.Key; Type="로그 확인(Tail)"; PathKey="log"   }
        }
        Write-Host "================================================================"
        $selection = Read-Host "선택"

        if ([string]::IsNullOrWhiteSpace($selection)) { Clear-Host; continue }

        if ($menuItems.ContainsKey($selection)) {
            $item = $menuItems[$selection]
            $cmdPath = $config.Paths.Win.$($item.Key).$($item.PathKey)
            
            if ($item.PathKey -eq "log") {
                Clear-Host
                Write-Host ">> 로그 확인 시작: $cmdPath`n>> 종료: Ctrl + C" -ForegroundColor Yellow
                if (Test-Path $cmdPath) { Get-Content $cmdPath -Wait -Tail 50 } 
                else { Write-Host "파일 없음"; Start-Sleep -Seconds 2 }
            } else {
                Write-Host "`n작업: $($item.Type) | 경로: $cmdPath" -ForegroundColor Cyan
                if ((Read-Host "실행하시겠습니까? (y/n)") -eq 'y') {
                    if ($cmdPath -like "echo*") { Invoke-Expression $cmdPath } 
                    else { Start-Process $cmdPath }
                    Start-Sleep -Seconds 1
                }
            }
        }
        Clear-Host
    }
}

#
# grid
#

function main_grid
{
try {
    while ($true) {
        # 1. 실시간 대시보드 표시 (여기서 ESC를 누르면 종료, 다른 키를 누르면 break로 빠져나옴)
        Show-Dashboard-Live 

        # 2. 그리드 메뉴 구성
        $ports = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Select-Object -ExpandProperty LocalPort
        $menuData = New-Object System.Collections.Generic.List[PSCustomObject]
        foreach ($svc in $config.Services) {
            $isAlive = $ports -contains $svc.Port
            $statusStr = if ($isAlive) { "● RUNNING" } else { "○ STOPPED" }
            $menuData.Add([PSCustomObject]@{ID=$svc.ID;     Status=$statusStr; Action="$($svc.Name) Start"; Category="1.Start"; 실행="[ START ]"})
            $menuData.Add([PSCustomObject]@{ID=$svc.StopID; Status=$statusStr; Action="$($svc.Name) Stop";  Category="2.Stop";  실행="[ STOP ]"})
            $menuData.Add([PSCustomObject]@{ID=$svc.LogID;  Status="LOG";      Action="$($svc.Name) Tail Log"; Category="3.Log";   실행="[ VIEW ]"})
        }

        # 3. GridView 메뉴 호출
        $selection = $menuData | Sort-Object ID | Out-GridView -Title "LENA Action Menu (창을 닫으면 대시보드로 복귀)" -OutputMode Single

        # 사용자가 아무것도 선택하지 않고 그리드 창을 닫으면 다시 대시보드로 돌아감
        if ($null -eq $selection) {
            Clear-Host 
            continue 
        }

        # 4. 선택된 항목 실행 로직
        $currentPaths = $config.Paths.$targetKey
        $selID = $selection.ID
        $cmdPath = ""; $execType = ""

        # ID 기반 매칭 (기존 로직 유지)
        if ($selID -match "^1[1-6]$") { 
            $svcKey = ($config.Services | Where-Object ID -eq $selID).Key
            $cmdPath = $currentPaths.$svcKey.start; $execType = "기동(Start)"
        }
        elseif ($selID -match "^2[1-6]$") {
            $svcKey = ($config.Services | Where-Object StopID -eq $selID).Key
            $cmdPath = $currentPaths.$svcKey.stop; $execType = "중지(Stop)"
        }
        elseif ($selID -match "^8[1-6]$") {
            $svcKey = ($config.Services | Where-Object LogID -eq $selID).Key
            $cmdPath = $currentPaths.$svcKey.log; $execType = "로그 확인(Tail)"
        }

        # 실행 확인창
        $confirm = [System.Windows.Forms.MessageBox]::Show("작업: $execType`n경로: $cmdPath`n`n실행하시겠습니까?", "LENA 확인", "YesNo", "Question")

        if ($confirm -eq "Yes") {
            if ($execType -eq "로그 확인(Tail)") {
                Clear-Host
                Write-Host ">> 로그 확인 시작: $cmdPath`n>> 종료: Ctrl + C" -ForegroundColor Yellow
                if ($targetKey -eq "Lin") { & tail -f $cmdPath } 
                else { Get-Content $cmdPath -Wait -Tail 50 }
            } else {
                Write-Host "`n>> 실행 중: $cmdPath" -ForegroundColor Green
                Start-Process $cmdPath
                Start-Sleep -Seconds 2 # 실행 후 상태 반영을 위해 약간 대기
            }
        }
        Clear-Host 
    }
} finally {
    Write-Host "`n프로그램 종료." -ForegroundColor Gray
}
}
#
# Start 
#


# 입력 인자에 따른 모드 결정
$modeInput = $args[0]
$main_mode = $modeInput

Clear-Host

if ($modeInput -eq "grid") { 
    $main_mode = "grid"
    
    # 반복문을 사용하여 깔끔하게 출력
    1..1 | ForEach-Object { 
        Write-Host "그리드 모드를 시작합니다..." -ForegroundColor Cyan 
    }
    Start-Sleep -Seconds 2 # 상태 반영 대기
    # 그리드 메인 함수 호출
    main_grid 
} 
else { 
    $main_mode = "cmd"

    1..1 | ForEach-Object { 
        Write-Host "커맨드 모드를 시작합니다..." -ForegroundColor green
    }
    Start-Sleep -Seconds 2 # 상태 반영 대기
    # 커맨드 메인 함수 호출
    main_cmd 
}
