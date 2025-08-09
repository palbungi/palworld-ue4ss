#!/usr/bin/env bash

# ======================================================
# 팰월드 서버 안전 재시작 스크립트 (Docker Container 버전)
# ======================================================

# ---------------------
# 주요 설정 변수
# ---------------------
YAML_FILE="docker-compose.yml"       # 도커 컴포즈 파일
CONTAINER_NAME="palworld"            # 컨테이너 이름
RESTART_PREFIX="Server_restart_in"   # 재시작 알림 접두사
SHUTDOWN_MSG="Server_shutting_down"  # 종료 알림 메시지

# ---------------------
# 기능 함수 정의
# ---------------------

# 브로드캐스트 메시지 전송
broadcast() {
    local message="$1"
    docker exec -i "$CONTAINER_NAME" rcon-cli "Broadcast ${message}"
    echo "[$(date +'%T')] 브로드캐스트: ${message}"
}

# 게임 데이터 저장
save_world() {
    docker exec -i "$CONTAINER_NAME" rcon-cli save
    echo "[$(date +'%T')] 월드 데이터 저장 완료"
}

# 카운트다운 알림
countdown() {
    local time_left="$1"
    broadcast "${RESTART_PREFIX}_${time_left}"
}

# ---------------------
# 메인 재시작 프로세스
# ---------------------
echo "[시작] 팰월드 서버 안전 재시작 절차를 시작합니다..."

# 10분 전 알림
countdown "10_minutes"
sleep 300  # 5분 대기

# 5분 전 알림
countdown "5_minutes"
sleep 120  # 2분 대기

# 3분 전 알림
countdown "3_minutes"
sleep 60   # 1분 대기

# 2분 전 알림
countdown "2_minutes"
sleep 60   # 1분 대기

# 1분 전 알림 및 저장
countdown "1_minute"
save_world
sleep 50  # 50초 대기

# 10초 전 알림 및 저장
countdown "10_seconds"
sleep 5
save_world

# 5초 카운트다운
for i in {5..1}; do
    countdown "${i}_seconds"
    sleep 1
done

# 최종 종료 알림
broadcast "$SHUTDOWN_MSG"
sleep 1  # 메시지 전달 대기

# ---------------------
# 서버 재시작
# ---------------------
echo "[진행] 서버 재시작 작업 시작..."
docker-compose -f "$YAML_FILE" pull
docker-compose -f "$YAML_FILE" down
docker-compose -f "$YAML_FILE" up -d

echo "[완료] 서버 재시작이 성공적으로 완료되었습니다!"
