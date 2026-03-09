#!/bin/bash

# 서비스 정의: "ID|Name|Port|Key|StopID|LogID"
SERVICES=(
    "10|All Service|00|all|30|80"
    "11|Web Service|80|web|31|81"
    "12|WAS Service|8080|was|32|82"
    "13|DB Service|3306|db|33|83"
    "14|Web Agent|18001|webAgent|23|83"
    "15|WAS Agent|18002|wasAgent|24|84"
    "16|Lena Manager|7700|manager|25|85"
)

# 경로 정의 (연관 배열)
declare -A START_PATHS STOP_PATHS LOG_PATHS
START_PATHS=( ["all"]="/di_root/10.start_all.sh" 
              ["web"]="/di_root/11.start_apache.sh" 
			  ["was"]="/di_root/12.start_tomcat.sh" 
			  ["db"]="/di_root/13.start_db.sh" 
			  ["webAgent"]="/engn001/lenaw/1.3/bin/start_agent.sh" 
			  ["wasAgent"]="/engn001/lena/1.3/bin/start_agent.sh" 
			  ["manager"]="/engn001/lenaw/1.3/bin/start_manager.sh" )
STOP_PATHS=( ["all"]="/di_root/30.stop_all.sh" 
             ["web"]="/di_root/31.stop_apache.sh" 
			 ["was"]="/di_root/32.stop_tomcat.sh" 
			 ["db"]="/di_root/33.stop_db.sh" 
			 ["webAgent"]="/engn001/lenaw/1.3/bin/stop_agent.sh" 
			 ["wasAgent"]="/engn001/lena/1.3/bin/stop_agent.sh" 
			 ["manager"]="/engn001/lenaw/1.3/bin/stop_manager.sh" )
LOG_PATHS=( ["web"]="/var/log/apache2/access.log" 
            ["was"]="/opt/tomcat/latest/logs/localhost.$(date '+%Y-%m-%d').log" 
			["db"]="/logs001/tomcat/log.log" 
			["webAgent"]="/logs001/lenaw/node/weblog.log" 
			["wasAgent"]="/logs001/lena/node/weblog.log" 
			["manager"]="/logs001/lenaw/node/weblog.log" )

# 색상 정의
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; GRAY='\033[0;90m'; NC='\033[0m'

# 자원 수집 함수
get_system_stats() {
    CPU=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    MEM=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
    SWP=$(free | grep Swap | awk '{if($2>0) print $3/$2 * 100.0; else print 0}')
    GPU=0
    command -v nvidia-smi &> /dev/null && GPU=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | head -n 1)
    HOSTNAME=$(hostname); USER=$(whoami)
}

get_stat_color() {
    local val=$1
    if (( $(echo "$val > 90" | bc -l) )); then echo -ne "${RED}";
    elif (( $(echo "$val > 80" | bc -l) )); then echo -ne "${YELLOW}";
    else echo -ne "${GREEN}"; fi
}

# 1. 상단 실시간 대시보드 (ID 10 체크 제외)
show_dashboard() {
    clear
    get_system_stats
    TIME=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "${GRAY}================================================================${NC}"
    echo -e "${CYAN} [CMD] ${NC}${HOSTNAME} (${USER}) | ${TIME}"
    echo -ne "${CYAN} [SYS] ${NC}CPU:$(get_stat_color $CPU)$(printf "%3.0f" $CPU)%${NC} "
    echo -ne "MEM:$(get_stat_color $MEM)$(printf "%3.0f" $MEM)%${NC} "
    echo -ne "SWP:$(get_stat_color $SWP)$(printf "%3.0f" $SWP)%${NC} "
    echo -ne "GPU:$(get_stat_color $GPU)$(printf "%3.0f" $GPU)%${NC} | "
    echo -ne "${CYAN}[DSK] ${NC}$(df -h / | awk 'NR==2 {print $5}') usage\n"
    echo -e "----------------------------------------------------------------"
    
    for svc in "${SERVICES[@]}"; do
        IFS='|' read -r ID NAME PORT KEY STOPID LOGID <<< "$svc"
        
        # ID 10 또는 포트가 00인 경우 포트 체크 건너뜀
        if [ "$ID" == "10" ] || [ "$PORT" == "00" ]; then
            #printf " %-15s (ID:%s)     -> ${CYAN}[ GROUP MGMT ]${NC}\n" "$NAME" "$ID"
            continue
        fi

        COUNT=$(ss -tunlp | grep -c ":$PORT " 2>/dev/null)
        if [ $COUNT -gt 0 ]; then
            printf " %-15s (Port:%5s) -> ${GREEN}[ RUNNING ]${NC}\n" "$NAME" "$PORT"
        else
            printf " %-15s (Port:%5s) -> ${RED}[ STOPPED ]${NC}\n" "$NAME" "$PORT"
        fi
    done
    echo -e "${GRAY}================================================================${NC}"
}

# 2. 메인 루프 (fzf 15 height + 확인 절차)
main_menu() {
    while true; do
        show_dashboard
        echo -e "${YELLOW} [동작 선택] (ESC: 새로고침)${NC}"

        # fzf 메뉴 생성
        MENU_DATA=$(for svc in "${SERVICES[@]}"; do
            IFS='|' read -r ID NAME PORT KEY STOPID LOGID <<< "$svc"
            echo "▶ START | $NAME ($KEY)"
            echo "■ STOP  | $NAME ($KEY)"
            [ -n "${LOG_PATHS[$KEY]}" ] && echo "▤ LOG   | $NAME ($KEY)"
        done; echo "ⓧ EXIT  | 프로그램 종료")

        SELECTED=$(echo "$MENU_DATA" | fzf --height 21 --reverse --border --ansi --header="대상 서비스를 선택하세요")

        # ESC 입력 시 대시보드 갱신
        [ -z "$SELECTED" ] && continue
        [[ "$SELECTED" == *"EXIT"* ]] && { tput cnorm; clear; exit 0; }

        ACT=$(echo "$SELECTED" | awk '{print $1}')
        KEY=$(echo "$SELECTED" | awk -F'(' '{print $2}' | tr -d ')[:space:]')
        NAME_DISPLAY=$(echo "$SELECTED" | awk -F'|' '{print $2}' | awk -F'(' '{print $1}' | xargs)

        case "$ACT" in
            "▶"|"■")
                [ "$ACT" == "▶" ] && TYPE="기동(START)" && CMD_PATH="${START_PATHS[$KEY]}"
                [ "$ACT" == "■" ] && TYPE="중지(STOP)" && CMD_PATH="${STOP_PATHS[$KEY]}"

                # 2단계 확인 절차
                CONFIRM=$(echo -e "✅ 진행 (Proceed)\n❌ 취소 (Cancel)" | fzf --height 5 --reverse --border --header="[$NAME_DISPLAY] $TYPE 작업을 진행하시겠습니까?")
                
                if [[ "$CONFIRM" == *"진행"* ]]; then
                    if [ -n "$CMD_PATH" ] && [ -f "$CMD_PATH" ]; then
                        echo -e "\n${GREEN}>> 실행 중: $CMD_PATH${NC}"
                        sh "$CMD_PATH" &
                        sleep 2
                    else
                        echo -e "\n${RED}>> 에러: 파일을 찾을 수 없습니다. ($CMD_PATH)${NC}"
                        sleep 2
                    fi
                else
                    echo -e "\n${YELLOW}>> 사용자에 의해 취소되었습니다.${NC}"
                    sleep 1
                fi
                ;;
            "▤")
                CMD_PATH="${LOG_PATHS[$KEY]}"
                if [ -f "$CMD_PATH" ]; then
                    clear
                    echo -e "${YELLOW}>> 로그 확인: $CMD_PATH (종료: Ctrl+C)${NC}"
                    tail -f -n 50 "$CMD_PATH"
                else
                    echo -e "${RED}>> 로그 파일이 없습니다.${NC}"; sleep 2
                fi
                ;;
        esac
    done
}

# 실행
tput civis
main_menu
tput cnorm