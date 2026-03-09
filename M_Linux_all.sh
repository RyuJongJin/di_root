#!/bin/bash


# source "./M_cfg.sh"

# 서비스 정의: "ID|Name|Port|Key|StopID|LogID"
SERVICES=(
    "11|Web Service|80|web|21|81"
    "12|WAS Service|8080|was|22|82"
    "13|Web Agent|18001|webAgent|23|83"
    "14|WAS Agent|18002|wasAgent|24|84"
    "15|Lena Manager|7700|manager|25|85"
    "16|DB Service|3301|db|26|86"
)

# 경로 정의 (연관 배열 사용 - Bash 4.0 이상 필요)
declare -A START_PATHS STOP_PATHS LOG_PATHS
START_PATHS=(
    ["web"]="/engn001/lenaw/1.3/bin/start.sh"
    ["was"]="/engn001/lena/1.3/bin/start.sh"
    ["webAgent"]="/engn001/lenaw/1.3/bin/start_agent.sh"
    ["wasAgent"]="/engn001/lena/1.3/bin/start_agent.sh"
    ["manager"]="/engn001/lenaw/1.3/bin/start_manager.sh"
    ["db"]="echo 'DB Start'"
    ["db"]="echo 'DB Start'"
)

STOP_PATHS=(
    ["web"]="/engn001/lenaw/1.3/bin/stop.sh"
    ["was"]="/engn001/lena/1.3/bin/stop.sh"
    ["webAgent"]="/engn001/lenaw/1.3/bin/stop_agent.sh"
    ["wasAgent"]="/engn001/lena/1.3/bin/stop_agent.sh"
    ["manager"]="/engn001/lenaw/1.3/bin/stop_manager.sh"
    ["db"]="echo 'DB Stop'"
    ["db"]="echo 'DB Stop'"
)

LOG_PATHS=(
    ["web"]="/logs001/lenaw/node/weblog.log"
    ["was"]="/logs001/lena/node/weblog.log"
    ["webAgent"]="/logs001/lenaw/node/weblog.log"
    ["wasAgent"]="/logs001/lena/node/weblog.log"
    ["manager"]="/logs001/lenaw/node/weblog.log"
    ["db"]="/logs001/tomcat/log.log"
    ["db"]="/logs001/tomcat/log.log"
)


# 1. 초기 설정 및 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# 2. 자원 수집 함수
get_system_stats() {
    CPU=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    MEM=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
    SWP=$(free | grep Swap | awk '{if($2>0) print $3/$2 * 100.0; else print 0}')
    
    # GPU (nvidia-smi가 있을 경우만)
    GPU=0
    if command -v nvidia-smi &> /dev/null; then
        GPU=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | head -n 1)
    fi

    HOSTNAME=$(hostname)
    USER=$(whoami)
}

get_stat_color() {
    local val=$1
    if (( $(echo "$val > 90" | bc -l) )); then echo -e "${RED}";
    elif (( $(echo "$val > 80" | bc -l) )); then echo -e "${YELLOW}";
    else echo -e "${GREEN}"; fi
}

# 3. 실시간 대시보드
show_dashboard_live() {
    clear
    tput civis # 커서 숨기기
    
    while true; do
        tput cup 0 0
        get_system_stats
        TIME=$(date "+%Y-%m-%d %H:%M:%S")
        
        echo -e "${GRAY}================================================================${NC}"
        echo -ne "${CYAN} [CMD] ${NC}${HOSTNAME} (${USER})"
        echo -e "${GRAY} | ${TIME}${NC}"
        
        echo -ne "${CYAN} [SYS] ${NC}CPU:$(get_stat_color $CPU)$(printf "%3.0f" $CPU)%${NC}"
        echo -ne " MEM:$(get_stat_color $MEM)$(printf "%3.0f" $MEM)%${NC}"
        echo -ne " SWP:$(get_stat_color $SWP)$(printf "%3.0f" $SWP)%${NC}"
        echo -ne " GPU:$(get_stat_color $GPU)$(printf "%3.0f" $GPU)%${NC}"
        
        echo -ne " | ${CYAN}[DSK] ${NC}"
        df -h --output=target,pcent | grep -E '^/$|^/home' | tr -d '\n' | sed 's/%/% /g'
        
        echo -e "\n${GRAY} [ ESC: 종료 | 아무 키: 제어 메뉴 ]${NC}"
        echo -e "----------------------------------------------------------------"
        
        # 서비스 상태 출력
        for svc in "${SERVICES[@]}"; do
            IFS='|' read -r ID NAME PORT KEY STOPID LOGID <<< "$svc"
            # 포트 리스닝 확인 (netstat 또는 ss 사용)
            COUNT=$(ss -tunlp | grep -c ":$PORT ")
            
            if [ $COUNT -gt 0 ]; then
                STATUS_STR="[ RUNNING ]"
                COLOR=$GREEN
                L_COLOR=$CYAN
            else
                STATUS_STR="[ STOPPED ]"
                COLOR=$RED
                L_COLOR=$RED
            fi
            
            printf " %-12s (Port:%5s)-> " "$NAME" "$PORT"
            echo -ne "${GRAY}(Listen: [${NC}${L_COLOR}${COUNT}${NC}${GRAY}]) ${NC}"
            echo -e "${COLOR}${STATUS_STR}${NC}"
        done
        echo -e "${GRAY}================================================================${NC}"
        
        # 키 입력 대기 (1초)
        read -t 1 -n 1 key
        if [[ $? -eq 0 ]]; then
            if [[ $key == $'\e' ]]; then # ESC
                tput cnorm; clear; exit 0
            else
                tput cnorm; break
            fi
        fi
    done
}

# 4. 메인 메뉴 (기존 main_cmd 역할)
main_menu() {
    while true; do
        show_dashboard_live
        
        echo -e "${GRAY}================================================================${NC}"
        echo -e "${CYAN}   LENA MANAGEMENT MENU (ID 입력 후 Enter)                      ${NC}"
        echo -e "${GRAY}================================================================${NC}"
        
        for svc in "${SERVICES[@]}"; do
            IFS='|' read -r ID NAME PORT KEY STOPID LOGID <<< "$svc"
            COUNT=$(ss -tunlp | grep -c ":$PORT ")
            
            [ $COUNT -gt 0 ] && M_STATUS="RUN " && M_COLOR=$GREEN || M_STATUS="STOP" && M_COLOR=$RED
            
            printf " %-12s (Port:%5s)-> " "$NAME" "$PORT"
            echo -ne "${M_COLOR}${M_STATUS}${NC} > "
            echo -ne "[${GREEN}${ID}${NC}]Start [${RED}${STOPID}${NC}]Stop [${YELLOW}${LOGID}${NC}]Log\n"
        done
        echo -e "${GRAY}================================================================${NC}"
        
        read -p "선택: " SELECTION
        [ -z "$SELECTION" ] && continue

        # 로직 처리
        FOUND=false
        for svc in "${SERVICES[@]}"; do
            IFS='|' read -r ID NAME PORT KEY STOPID LOGID <<< "$svc"
            
            if [ "$SELECTION" == "$ID" ]; then
                CMD_PATH=${START_PATHS[$KEY]}; TYPE="기동(Start)"; FOUND=true
            elif [ "$SELECTION" == "$STOPID" ]; then
                CMD_PATH=${STOP_PATHS[$KEY]}; TYPE="중지(Stop)"; FOUND=true
            elif [ "$SELECTION" == "$LOGID" ]; then
                CMD_PATH=${LOG_PATHS[$KEY]}; TYPE="로그 확인(Tail)"; FOUND=true
            fi

            if [ "$FOUND" == true ]; then
                if [[ "$TYPE" == "로그 확인(Tail)" ]]; then
                    clear
                    echo -e "${YELLOW}>> 로그 확인 시작: $CMD_PATH${NC}"
                    echo -e "${YELLOW}>> 종료: Ctrl + C${NC}"
                    [ -f "$CMD_PATH" ] && tail -f -n 50 "$CMD_PATH" || echo "파일 없음"
                    sleep 2
                else
                    echo -e "\n작업: $TYPE | 경로: $CMD_PATH"
                    read -p "실행하시겠습니까? (y/n): " CONFIRM
                    if [ "$CONFIRM" == "y" ]; then
                        if [[ "$CMD_PATH" == echo* ]]; then
                            eval "$CMD_PATH"
                        else
                            sh "$CMD_PATH" &
                        fi
                        sleep 1
                    fi
                fi
                break
            fi
        done
        [ "$FOUND" == false ] && echo "잘못된 ID입니다." && sleep 1
        clear
    done
}

# 시작
clear
echo -e "${GREEN}LENA 관리 도구를 시작합니다...${NC}"
sleep 1
main_menu
