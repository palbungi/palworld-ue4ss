#!/usr/bin/env bash

# ======================
# 팰월드 서버 안전 종료 스크립트
# ======================

# 설정 값
YAML_FILE="/home/$(whoami)/docker-compose.yml"
CONTAINER_NAME="palworld"
SHUTDOWN_PREFIX="Server_will_restart_in"
SHUTDOWN_DELAY=5  # 초 단위 카운트다운 시간

# 현재 상태 출력
echo "🔴 팰월드 서버 안전 종료 절차 시작..."

# 월드 데이터 저장
echo "💾 게임 데이터 저장 중..."
docker exec -i "$CONTAINER_NAME" rcon-cli save

# 카운트다운 알림
echo "⏱️ 플레이어에게 ${SHUTDOWN_DELAY}초 카운트다운 알림 전송"
for ((i=SHUTDOWN_DELAY; i>0; i--)); do
    docker exec -i "$CONTAINER_NAME" rcon-cli "Broadcast ${SHUTDOWN_PREFIX}_${i}_seconds"
    sleep 1
done

# 서버 종료 및 업데이트
echo "🛑 서버 종료 및 업데이트 진행..."
docker-compose -f "${YAML_FILE}" pull
docker-compose -f "${YAML_FILE}" down

echo "✅ 서버 종료 절차 완료!"
