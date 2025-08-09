#!/bin/bash
set -euo pipefail

# =============================================================================
# 색상 및 스타일 정의
# =============================================================================
BOLD=$(tput bold)
NORMAL=$(tput sgr0)
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
MAGENTA='\033[1;35m'
CYAN='\033[1;36m'
ORANGE='\033[38;5;208m'
NC='\033[0m' # No Color

# =============================================================================
# 사용자 정보 및 경로 설정
# =============================================================================
USER_NAME=$(whoami)
USER_HOME="/home/$USER_NAME"
SERVER_DIR="$USER_HOME/palworld"
CONFIG_DIR="$SERVER_DIR/Pal/Saved/Config/LinuxServer"
SAVE_DIR="$SERVER_DIR/Pal/Saved/SaveGames/0/0123456789ABCDEF0123456789ABCDEF"
GITHUB_REPO="https://raw.githubusercontent.com/palbungi/palworld-googlecloud/main"

# =============================================================================
# 진행 상태 출력 함수
# =============================================================================
print_step() {
    echo -e "\n${CYAN}${BOLD}>>> $1${NC}${NORMAL}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${ORANGE}⚠ $1${NC}"
}

print_error() {
    echo -e "\n${RED}${BOLD}[ERROR] $1${NC}${NORMAL}" >&2
    exit 1
}

# =============================================================================
# 시스템 정보 확인
# =============================================================================
clear
echo -e "${MAGENTA}${BOLD}"
echo "================================================"
echo "   팰월드 서버 자동 설치 스크립트"
echo "================================================"
echo -e "${NC}"

print_step "시스템 정보 확인"
echo -e "• 사용자: ${BLUE}$USER_NAME${NC}"
echo -e "• 홈 디렉토리: ${BLUE}$USER_HOME${NC}"
echo -e "• OS: ${BLUE}$(lsb_release -ds)${NC}"
echo -e "• 커널 버전: ${BLUE}$(uname -r)${NC}"
echo -e "• CPU: ${BLUE}$(lscpu | grep 'Model name' | cut -d':' -f2 | xargs)${NC}"
echo -e "• 메모리: ${BLUE}$(free -h | awk '/^Mem:/ {print $2}')${NC}"

# =============================================================================
# 한국 시간 설정
# =============================================================================
print_step "한국 시간대 설정"
sudo timedatectl set-timezone Asia/Seoul || print_error "시간대 설정 실패"
print_success "현재 시간: $(date +'%Y-%m-%d %H:%M:%S %Z')"

# =============================================================================
# 필수 패키지 설치
# =============================================================================
print_step "필수 패키지 설치"
export DEBIAN_FRONTEND=noninteractive
echo "tzdata tzdata/Areas select Asia" | sudo debconf-set-selections
echo "tzdata tzdata/Zones/Asia select Seoul" | sudo debconf-set-selections

sudo apt-get update || print_error "패키지 목록 업데이트 실패"
sudo apt-get install -y debconf-utils unzip cron gosu libgl1 libvulkan1 tzdata \
    nano man-db systemd net-tools iproute2 dialog apt-transport-https \
    ca-certificates gnupg software-properties-common util-linux || print_error "패키지 설치 실패"

print_success "필수 패키지 설치 완료"

# =============================================================================
# 시스템 업그레이드
# =============================================================================
print_step "시스템 업그레이드"
sudo apt-get -o Dpkg::Options::="--force-confdef" \
            -o Dpkg::Options::="--force-confold" \
            upgrade -y || print_error "시스템 업그레이드 실패"
print_success "시스템 업그레이드 완료"

# =============================================================================
# Docker 설치
# =============================================================================
print_step "Docker 설치"
if ! getent group docker >/dev/null; then
    sudo groupadd docker || print_error "Docker 그룹 생성 실패"
fi

sudo usermod -aG docker $USER_NAME || print_error "사용자 Docker 그룹 추가 실패"

sudo mkdir -p /etc/apt/keyrings || print_error "디렉토리 생성 실패"
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg || print_error "GPG 키 다운로드 실패"

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null || print_error "저장소 추가 실패"

sudo apt-get update || print_error "Docker 저장소 업데이트 실패"
sudo apt-get install -y docker-ce docker-ce-cli containerd.io || print_error "Docker 설치 실패"

# =============================================================================
# Docker Compose 설치
# =============================================================================
print_step "Docker Compose 설치"
DOCKER_COMPOSE_URL="https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)"
sudo curl -L "$DOCKER_COMPOSE_URL" -o /usr/local/bin/docker-compose || print_error "Docker Compose 다운로드 실패"
sudo chmod +x /usr/local/bin/docker-compose || print_error "Docker Compose 실행 권한 설정 실패"

# Docker 권한 설정
sudo chmod 666 /var/run/docker.sock || print_warning "Docker 소켓 권한 설정 실패 (재시작 필요)"

print_success "Docker 및 Docker Compose 설치 완료"

# =============================================================================
# 서버 파일 다운로드
# =============================================================================
print_step "PalWorld 서버 설정 파일 다운로드"

# docker-compose.yml 다운로드
wget -q "$GITHUB_REPO/docker-compose.yml" -O "$USER_HOME/docker-compose.yml" || print_error "docker-compose.yml 다운로드 실패"

# config.env 다운로드
wget -q "$GITHUB_REPO/config.env" -O "$USER_HOME/config.env" || print_error "config.env 다운로드 실패"

# 정기 관리 스크립트 다운로드
wget -q "$GITHUB_REPO/regular_maintenance.sh" -O "$USER_HOME/regular_maintenance.sh" || print_error "정기 관리 스크립트 다운로드 실패"
chmod +x "$USER_HOME/regular_maintenance.sh" || print_error "스크립트 실행 권한 설정 실패"
sed -i "s|docker-compose.yml|$USER_HOME/docker-compose.yml|g" "$USER_HOME/regular_maintenance.sh" || print_error "스크립트 경로 수정 실패"

# =============================================================================
# 서버 설정 디렉토리 생성
# =============================================================================
print_step "서버 설정 디렉토리 생성"
mkdir -p "$CONFIG_DIR" || print_error "설정 디렉토리 생성 실패"

# 설정 파일 다운로드
wget -q "$GITHUB_REPO/Engine.ini" -O "$CONFIG_DIR/Engine.ini" || print_error "Engine.ini 다운로드 실패"
wget -q "$GITHUB_REPO/GameUserSettings.ini" -O "$CONFIG_DIR/GameUserSettings.ini" || print_error "GameUserSettings.ini 다운로드 실패"

# 저장 디렉토리 생성
print_step "게임 저장 디렉토리 생성"
mkdir -p "$SAVE_DIR" || print_error "저장 디렉토리 생성 실패"
print_success "서버 디렉토리 구조 생성 완료"

# =============================================================================
# 서버 설정 수정
# =============================================================================
print_step "서버 설정 수정"
PUBLIC_IP=$(curl -s ifconfig.me)
sed -i "s/^REGION=.*/REGION=$PUBLIC_IP/" "$USER_HOME/config.env" || print_error "REGION 설정 수정 실패"
sed -i "s/^PUBLIC_IP=.*/PUBLIC_IP=$PUBLIC_IP/" "$USER_HOME/config.env" || print_error "PUBLIC_IP 설정 수정 실패"

echo -e "\n${ORANGE}${BOLD}=== 서버 설정 편집기 실행 ===${NC}"
echo -e "• 현재 공인 IP: ${BLUE}$PUBLIC_IP${NC}"
echo -e "• 필수 설정 항목:"
echo -e "  - ${CYAN}SERVER_PASSWORD${NC}: 서버 접속 비밀번호"
echo -e "  - ${CYAN}ADMIN_PASSWORD${NC}: 관리자 비밀번호"
echo -e "  - ${CYAN}SERVER_NAME${NC}: 서버 이름"
echo -e "\n${YELLOW}편집을 마치면 ${ORANGE}Ctrl+O${YELLOW}, ${GREEN}Enter${YELLOW}, ${RED}Ctrl+X${YELLOW} 를 눌러 저장하세요.${NC}"
sleep 3

# config.env 파일 직접 편집
nano "$USER_HOME/config.env"

# =============================================================================
# cron 설정
# =============================================================================
print_step "정기 관리 작업 설정"
wget -q "$GITHUB_REPO/timer.sh" -O "$USER_HOME/timer.sh" || print_error "타이머 스크립트 다운로드 실패"
chmod +x "$USER_HOME/timer.sh" || print_error "스크립트 실행 권한 설정 실패"
sed -i "s|/home/\$(whoami)/|$USER_HOME/|g" "$USER_HOME/timer.sh" || print_error "스크립트 경로 수정 실패"

bash "$USER_HOME/timer.sh" || print_error "cron 작업 설정 실패"
sudo systemctl restart cron || print_error "cron 서비스 재시작 실패"
sudo systemctl enable cron || print_error "cron 서비스 활성화 실패"
print_success "정기 재시작 작업 설정 완료"

# =============================================================================
# PalWorld 서버 시작
# =============================================================================
print_step "PalWorld 서버 시작"
docker-compose -f "$USER_HOME/docker-compose.yml" up -d || print_error "서버 시작 실패"
print_info "서버가 시작 중입니다. 완전히 준비되기까지 3-5분이 소요될 수 있습니다."

# =============================================================================
# Portainer 설치
# =============================================================================
print_step "Portainer 설치"
PORTAINER_DIR="$USER_HOME/portainer"
mkdir -p "$PORTAINER_DIR" || print_error "Portainer 디렉토리 생성 실패"
wget -q "$GITHUB_REPO/portainer/docker-compose.yml" -O "$PORTAINER_DIR/docker-compose.yml" || print_error "Portainer 설정 다운로드 실패"
docker-compose -f "$PORTAINER_DIR/docker-compose.yml" up -d || print_error "Portainer 시작 실패"
print_success "Portainer 설치 완료"

# =============================================================================
# 설치 완료 메시지
# =============================================================================
clear
echo -e "\n${MAGENTA}${BOLD}================================================"
echo -e "       팰월드 서버 설치 완료!"
echo -e "================================================${NC}"

# 서버 접속 정보 추출
SERVER_IP=$(curl -s ifconfig.me)
SERVER_PASSWORD=$(grep '^SERVER_PASSWORD=' "$USER_HOME/config.env" | cut -d '=' -f2- | tr -d '"')
ADMIN_PASSWORD=$(grep '^ADMIN_PASSWORD=' "$USER_HOME/config.env" | cut -d '=' -f2- | tr -d '"')
SERVER_NAME=$(grep '^SERVER_NAME=' "$USER_HOME/config.env" | cut -d '=' -f2- | tr -d '"')

# 게임 서버 접속 정보 출력
echo -e "\n${GREEN}${BOLD}■ 게임 서버 정보${NC}"
echo -e "  ${CYAN}서버 이름: ${YELLOW}${SERVER_NAME:-[미설정]}${NC}"
echo -e "  ${CYAN}서버 주소: ${YELLOW}${SERVER_IP}:8211${NC}"

if [ -n "$SERVER_PASSWORD" ]; then
    echo -e "  ${CYAN}접속 비밀번호: ${YELLOW}${SERVER_PASSWORD}${NC}"
else
    echo -e "  ${RED}※ 주의: 비밀번호가 설정되지 않았습니다!${NC}"
fi

if [ -n "$ADMIN_PASSWORD" ]; then
    echo -e "  ${CYAN}관리자 비밀번호: ${YELLOW}${ADMIN_PASSWORD}${NC}"
else
    echo -e "  ${RED}※ 주의: 관리자 비밀번호가 설정되지 않았습니다!${NC}"
fi

# 중요 정보 출력
echo -e "\n${ORANGE}${BOLD}■ 중요 정보${NC}"
echo -e " 서버 완전 시작까지 ${YELLOW}3-5분${NC} 소요 (게임 접속 전 대기 필요)"
echo -e " ${BLUE}http://${SERVER_IP}:8888${NC} ${CYAN}5분내로 접속해주세요${NC}"


# 보안 상태 메시지
if [ -z "$SERVER_PASSWORD" ]; then
    echo -e "\n${RED}${BOLD}※ 보안 경고: 비밀번호가 설정되지 않아 공개 서버입니다!${NC}"
    echo -e "   ${YELLOW}config.env 파일에서 SERVER_PASSWORD를 설정해주세요${NC}"
else
    echo -e "\n${GREEN}${BOLD}※ 보안: 비밀번호가 설정된 비공개 서버입니다${NC}"
fi

if [ -z "$ADMIN_PASSWORD" ]; then
    echo -e "\n${RED}${BOLD}※ 보안 경고: 관리자 비밀번호가 설정되지 않았습니다!${NC}"
    echo -e "   ${YELLOW}config.env 파일에서 ADMIN_PASSWORD를 설정해주세요${NC}"
fi

# 종료 메시지
echo -e "\n${MAGENTA}${BOLD}이 창은 닫아도 됩니다. 즐거운 게임 되세요!${NC}"
echo -e "${MAGENTA}${BOLD}================================================${NC}"
