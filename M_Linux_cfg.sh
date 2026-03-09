#!/bin/bash
# M_cfg.sh

# 서비스 정의: "ID|Name|Port|Key|StopID|LogID"
SERVICES=(
    "11|Web Service|9999|web|21|81"
    "12|WAS Service|8888|was|22|82"
    "13|Web Agent|18001|webAgent|23|83"
    "14|WAS Agent|18002|wasAgent|24|84"
    "15|Lena Manager|7700|manager|25|85"
    "16|DB Service|5001|db|26|86"
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
)

STOP_PATHS=(
    ["web"]="/engn001/lenaw/1.3/bin/stop.sh"
    ["was"]="/engn001/lena/1.3/bin/stop.sh"
    ["webAgent"]="/engn001/lenaw/1.3/bin/stop_agent.sh"
    ["wasAgent"]="/engn001/lena/1.3/bin/stop_agent.sh"
    ["manager"]="/engn001/lenaw/1.3/bin/stop_manager.sh"
    ["db"]="echo 'DB Stop'"
)

LOG_PATHS=(
    ["web"]="/logs001/lenaw/node/weblog.log"
    ["was"]="/logs001/lena/node/weblog.log"
    ["webAgent"]="/logs001/lenaw/node/weblog.log"
    ["wasAgent"]="/logs001/lena/node/weblog.log"
    ["manager"]="/logs001/lenaw/node/weblog.log"
    ["db"]="/logs001/tomcat/log.log"
)