#!/bin/bash
# 端到端联调：向本机事件服务推送四类事件，验证状态机与响应码
set -euo pipefail

PORT="${PORT:-17387}"
BASE="http://127.0.0.1:$PORT/v1/events"
TOKEN="${TOKEN:-}"

post() {
  local body="$1"
  local extra=()
  if [ -n "$TOKEN" ]; then
    extra=(-H "X-TraeChime-Token: $TOKEN")
  fi
  curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE" \
    -H "Content-Type: application/json" "${extra[@]}" -d "$body"
}

echo "== 单 agent 全状态流转 =="
echo "started:    $(post '{"source":"traecode","agent_id":"a1","task_title":"写登录接口","event":"started"}')"
sleep 1
echo "completed:  $(post '{"source":"traecode","agent_id":"a1","task_title":"写登录接口","event":"completed"}')"
sleep 1

echo "== 多 agent 并发 =="
echo "confirm a2: $(post '{"source":"traework","agent_id":"a2","task_title":"重构数据库","event":"confirm_required"}')"
sleep 0.5
echo "failed a3:  $(post '{"source":"traecode","agent_id":"a3","task_title":"部署脚本","event":"failed"}')"
sleep 0.5

echo "== 异常路径 =="
echo "缺字段(400):   $(post '{"source":"traecode","agent_id":"a4","event":"started"}')"
echo "非法JSON(400): $(post 'not-json')"
if [ -n "$TOKEN" ]; then
  echo "错误令牌(401): $(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE" -H 'Content-Type: application/json' -H 'X-TraeChime-Token: wrong' -d '{"source":"traecode","agent_id":"a5","task_title":"x","event":"started"}')"
fi

echo "== 完成 =="
