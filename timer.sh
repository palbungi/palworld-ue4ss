#!/bin/bash

# 색상 및 스타일 정의
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
NC='\033[0m' # No Color
BOLD=$(tput bold)
NORMAL=$(tput sgr0)

# 경로 설정
CRON_FILE="/tmp/mycron"
SCRIPT_PATH="/home/$(whoami)/regular_maintenance.sh"

# 함수: 크론 삭제 및 종료
disable_cron_and_exit() {
    crontab -r 2>/dev/null
    echo -e "${RED}${BOLD}기존 재시작 목록을 삭제했습니다.${NC}"
    echo -e "${RED}서버 재시작 기능이 비활성화되었습니다.${NC}"
    echo -e "${YELLOW}스크립트를 종료합니다.${NC}"
    exit 0
}

# 함수: 기존 크론 삭제
clear_existing_cron() {
    crontab -r 2>/dev/null
    echo -e "${RED}기존 재시작 목록을 삭제했습니다.${NC}"
    echo
}

# 함수: 크론 등록 및 결과 출력
register_cron_and_display() {
    local times=("${!1}")
    
    # 크론 등록
    crontab "$CRON_FILE"
    rm -f "$CRON_FILE"
    sudo systemctl restart cron

    # 설정된 시간 출력
    echo
    echo -e "${BOLD}${CYAN}설정된 재시작 시간:${NC}"
    for TIME in "${times[@]}"; do
        HOUR=$(echo "$TIME" | cut -d':' -f1 | sed 's/^0//')
        MIN=$(echo "$TIME" | cut -d':' -f2)
        
        # 시간 변환 (24시간제 → 12시간제)
        if [[ $HOUR -eq 0 || $HOUR -eq 24 ]]; then
            DISPLAY_HOUR=12
            AMPM="오전"
            COLOR="${YELLOW}"
        elif [[ $HOUR -lt 12 ]]; then
            DISPLAY_HOUR=$HOUR
            AMPM="오전"
            COLOR="${YELLOW}"
        elif [[ $HOUR -eq 12 ]]; then
            DISPLAY_HOUR=12
            AMPM="오후"
            COLOR="${GREEN}"
        else
            DISPLAY_HOUR=$((HOUR - 12))
            AMPM="오후"
            COLOR="${GREEN}"
        fi
        
        # 한 자리 시간일 경우 앞에 0 추가 (오전 03시 형식)
        printf -v DISPLAY_HOUR_FORMATTED "%02d" "$DISPLAY_HOUR"
        echo -e "${COLOR}${AMPM} ${DISPLAY_HOUR_FORMATTED}시 ${MIN}분${NC}"
    done
}

# 메인 실행부
clear

# 제목 출력
echo -e "${CYAN}${BOLD}=============================================="
echo -e " 팰월드서버 자동 재시작 설정 프로그램"
echo -e "==============================================${NC}"
echo

# 스크립트 다운로드 확인
if [ ! -f "$SCRIPT_PATH" ]; then
    echo -e "${YELLOW}regular_maintenance.sh 파일이 없어서 다운로드 중...${NC}"
    curl -so "$SCRIPT_PATH" https://raw.githubusercontent.com/palbungi/palworld-ue4ss/main/regular_maintenance.sh
    chmod +x "$SCRIPT_PATH"
    echo -e "${GREEN}파일 다운로드 및 실행 권한 설정 완료!${NC}"
fi

# 모드 선택
while true; do
    echo -e "${BOLD}팰월드 서버 재시작 모드를 선택하세요:${NORMAL}"
    echo -e "${YELLOW}0. 팰월드 서버 재시작 안함${NC}"
    echo -e "${GREEN}1. 하루 횟수만 지정 (추천)${NC}"
    echo -e "${BLUE}2. 하루 횟수/시간 지정${NC}"
    echo
    read -p $'\033[1;36m번호 선택 (0-2): \033[0m' MODE
    echo

    case $MODE in
        0)
            disable_cron_and_exit
            ;;
        1|2)
            # 횟수 입력
            while true; do
                read -p $'\033[1;36m하루에 몇 번 재시작할까요? (0=비활성화, 숫자 입력): \033[0m' COUNT
                if [[ "$COUNT" == "0" ]]; then
                    disable_cron_and_exit
                elif [[ "$COUNT" =~ ^[1-9][0-9]*$ ]]; then
                    break
                else
                    echo -e "${RED}올바른 숫자를 입력해주세요.${NC}"
                fi
            done

            # 기존 크론 삭제
            clear_existing_cron

            # 모드별 처리
            declare -a TIMES
            > "$CRON_FILE"
            
            if [[ $MODE == 1 ]]; then
                # 자동 시간 계산
                INTERVAL=$((24 * 60 / COUNT))
                for ((i=0; i<COUNT; i++)); do
                    TOTAL_MINUTES=$((i * INTERVAL))
                    HOUR=$((TOTAL_MINUTES / 60))
                    MIN=$((TOTAL_MINUTES % 60))
                    printf -v HOUR_STR "%02d" "$HOUR"
                    printf -v MIN_STR "%02d" "$MIN"
                    TIMES+=("${HOUR_STR}:${MIN_STR}")
                    
                    echo "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" >> "$CRON_FILE"
                    echo "$MIN_STR $HOUR_STR * * * $SCRIPT_PATH" >> "$CRON_FILE"
                done
            else
                # 수동 시간 입력
                echo -e "${BOLD}${CYAN}재시작 시간을 24시간 형식(HH:MM)으로 입력해주세요:${NC}"
                for ((i=1; i<=COUNT; i++)); do
                    while true; do
                        read -p $'\033[1;36m'"${i}번째 실행 시간 (예: 03:00): "$'\033[0m' TIME
                        if [[ "$TIME" == "24:00" ]]; then
                            TIME="00:00"
                            echo -e "${YELLOW}24:00은 00:00으로 변환됩니다.${NC}"
                        fi
                        if [[ "$TIME" =~ ^([01]?[0-9]|2[0-3]):[0-5][0-9]$ ]]; then
                            TIMES+=("$TIME")
                            break
                        else
                            echo -e "${RED}올바른 시간 형식(예: 03:00)을 입력해주세요.${NC}"
                        fi
                    done
                done

                for TIME in "${TIMES[@]}"; do
                    HOUR=$(echo "$TIME" | cut -d':' -f1)
                    MIN=$(echo "$TIME" | cut -d':' -f2)
                    echo "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" >> "$CRON_FILE"
                    echo "$MIN $HOUR * * * $SCRIPT_PATH" >> "$CRON_FILE"
                done
            fi

            register_cron_and_display TIMES[@]
            break
            ;;
        *)
            echo -e "${RED}0, 1 또는 2를 입력해주세요.${NC}"
            ;;
    esac
done
