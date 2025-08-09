# 서버 시작
YAML_FILE="/home/$(whoami)/docker-compose.yml"
docker-compose -f "${YAML_FILE}" up -d
