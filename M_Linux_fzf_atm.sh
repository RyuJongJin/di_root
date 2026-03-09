#!/bin/bash

# 1. 서비스 및 경로 정의 (기존 설정 유지)
SERVICES=(
    "10|All Service|00|all"
    "11|Web Service|80|web"
    "12|WAS Service|8080|was"
    "13|DB  Service|3306|db"
)

declare -A START_PATHS STOP_PATHS LOG_PATHS
START_PATHS=(   ["all"]="/di_root/10.start_all.sh" 
       		["web"]="/di_root/11.start_apache.sh" 
		["was"]="/di_root/12.start_tomcat.sh" 
		["db"]="/di_root/13.start_db.sh" )
STOP_PATHS=( ["all"]="/di_root/30.stop_all.sh" 
	     ["web"]="/di_root/31.stop_apache.sh" 
	     ["was"]="/di_root/32.stop_tomcat.sh" 
	     ["db"]="/di_root/33.stop_db.sh" )
LOG_PATHS=( ["web"]="/var/log/apache2/access.log" 
	    ["was"]="/opt/tomcat/latest/logs/catalina.out" 
	    ["db"]="/logs001/tomcat/log.log" )

RED='\033[0;31m'; 
GREEN='\033[0;32m'; 
YELLOW='\033[1;33m'; 
CYAN='\033[0;36m'; 
GRAY='\033[0;90m'; 
NC='\033[0m'

# 2. 상단 실시간 대시보드 함수
show_dashboard() {
    clear
    local TIME=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "${GRAY}================================================================${NC}"
    echo -e "${CYAN} [MONITOR] ${NC}Host: $(hostname) | Time: $TIME"
    echo -e "${GRAY}----------------------------------------------------------------${NC}"
    for svc in "${SERVICES[@]}"; do
        IFS='|' read -r ID NAME PORT KEY <<< "$svc"
        if [ "$PORT" == "00" ]; then
         #   printf " %-15s : ${CYAN}[ GROUP MGMT ]${NC}\n" "$NAME"
            continue
        fi
        # 포트 체크
        ss -tunlp | grep -q ":$PORT " && \
        printf " %-15s : ${GREEN}[ RUNNING ]${NC}\n" "$NAME" || \
        printf " %-15s : ${RED}[ STOPPED ]${NC}\n" "$NAME"
    done
    echo -e "${GRAY}================================================================${NC}"
}

# 3. 메인 실행 루프
while true; do
    show_dashboard
    echo -e "${YELLOW} [메뉴 선택] (ESC: 대시보드 새로고침)${NC}"

    # fzf 리스트 생성
    MENU_DATA=$(for svc in "${SERVICES[@]}"; do
        IFS='|' read -r ID NAME PORT KEY <<< "$svc"
        echo "▶ START | $NAME ($KEY)"
        echo "■ STOP  | $NAME ($KEY)"
        [ -n "${LOG_PATHS[$KEY]}" ] && echo "▤ LOG   | $NAME ($KEY)"
    done; echo "ⓧ EXIT  | 프로그램 종료")

    # 서비스 선택
    SELECTED=$(echo "$MENU_DATA" | fzf --height 20 --reverse --border --ansi --header="수행할 작업을 선택하세요")

    # ESC 혹은 빈 값일 경우 (sh '' 에러 방지)
    [ -z "$SELECTED" ] && continue
    [[ "$SELECTED" == *"EXIT"* ]] && { clear; exit 0; }

    # 파싱
    ACT=$(echo "$SELECTED" | awk '{print $1}')
    KEY=$(echo "$SELECTED" | awk -F'(' '{print $2}' | tr -d ')')
    NAME_ONLY=$(echo "$SELECTED" | awk -F'|' '{print $2}' | awk -F'(' '{print $1}' | xargs)

    # 4. 실행 여부 확인 (Confirm)
    if [[ "$ACT" == "▶" || "$ACT" == "■" ]]; then
        ACTION_NAME=$([ "$ACT" == "▶" ] && echo "기동(START)" || echo "중지(STOP)")
        
        # 확인창 띄우기
        CONFIRM=$(echo -e "✅ 진행 (Proceed)\n❌ 취소 (Cancel)" | fzf --height 5 --reverse --border --header="[$NAME_ONLY] $ACTION_NAME 작업을 진행하시겠습니까?")
        
        if [[ "$CONFIRM" == *"취소"* || -z "$CONFIRM" ]]; then
            echo -e "${YELLOW}>> 작업을 취소하였습니다.${NC}"
            sleep 1
            continue
        fi

        # 실제 경로 설정 및 실행
        [ "$ACT" == "▶" ] && CMD_PATH="${START_PATHS[$KEY]}" || CMD_PATH="${STOP_PATHS[$KEY]}"
        
        if [ -n "$CMD_PATH" ] && [ -f "$CMD_PATH" ]; then
            echo -e "${GREEN}>> 실행 중: $CMD_PATH${NC}"
            sh "$CMD_PATH" &
            sleep 1.5
        else
            echo -e "${RED}>> 에러: 실행 파일을 찾을 수 없습니다. ($CMD_PATH)${NC}"
            sleep 2
        fi

    elif [[ "$ACT" == "▤" ]]; then
        # 로그는 확인 절차 없이 즉시 실행
        CMD_PATH="${LOG_PATHS[$KEY]}"
        if [ -f "$CMD_PATH" ]; then
            clear
            echo -e "${YELLOW}>> 로그 확인: $CMD_PATH (종료: Ctrl+C)${NC}"
            tail -f -n 50 "$CMD_PATH"
        else
            echo -e "${RED}>> 로그 파일이 없습니다.${NC}"; sleep 1.5
        fi
    fi
done
