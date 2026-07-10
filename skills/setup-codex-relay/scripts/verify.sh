#!/usr/bin/env bash
# 验证 codex + 中转 配置是否正常。
# 用法: PROFILE=necodex bash verify.sh
#   profile 从 <此脚本目录>/../assets/profiles/<PROFILE>.json 读取；
#   连通/端到端所需 key 从 profile.key（env/inline）解析。
# 关键约束：codex 0.133.0 起仅支持 wire_api=responses，中转必须暴露 /v1/responses。
# 端到端用隔离 CODEX_HOME，绝不改用户 ~/.codex 下的真实配置。
set -u
fail=0
PROFILE="${PROFILE:-necodex}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_FILE="$SCRIPT_DIR/../assets/profiles/$PROFILE.json"

if [ ! -f "$PROFILE_FILE" ]; then echo "✗ 找不到 profile: $PROFILE_FILE"; exit 1; fi
echo "== profile: $PROFILE =="

eval "$(node -e '
const fs=require("fs");
const p=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
const sh=(k,v)=>console.log(k+"="+JSON.stringify(String(v==null?"":v)));
sh("PNAME",p.name);
sh("PDISP",p.displayName||p.name);
sh("BASE",p.baseUrl.replace(/\/+$/,""));   // 已含 /v1（codex 只在其后拼 /responses）
sh("MAIN",p.models.main?p.models.main.id:"");
sh("MAINREASON",p.models.main&&p.models.main.reasoning?p.models.main.reasoning:"high");
sh("HIGH",p.models.high?p.models.high.id:"");
sh("KEYMODE",p.key.mode);
sh("KEYREF",p.key.ref||"");
sh("KEYVAL",p.key.value||"");
sh("CODEXAUTH",p.codexAuth||"env_key");   // env_key | openai_auth（七牛 bypass 用后者）
' "$PROFILE_FILE")"

if [ "$KEYMODE" = "env" ]; then KEY="${!KEYREF:-}"; else KEY="$KEYVAL"; fi
RESP_URL="$BASE/responses"

echo "== 1. codex 已装 =="
if command -v codex >/dev/null 2>&1; then echo "  $(codex --version)"; else echo "  ✗ 未找到 codex（见 SKILL.md 第 1 步）"; fail=1; fi

echo "== 2. 中转 /v1/responses 连通（应 200；chat-only 中转会 404，codex 不可用）=="
if [ -n "$KEY" ]; then
  for m in "$MAIN" "$HIGH"; do
    [ -z "$m" ] && continue
    code=$(curl -s -o /tmp/codex-verify-body -w "%{http_code}" "$RESP_URL" \
      -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
      -d "{\"model\":\"$m\",\"input\":\"say ok\",\"max_output_tokens\":16}")
    echo "  $m @ $RESP_URL -> HTTP $code $([ "$code" != 200 ] && head -c 120 /tmp/codex-verify-body)"
    [ "$code" = "200" ] || fail=1
  done
  rm -f /tmp/codex-verify-body
else
  echo "  ✗ key 未解析，连通测试跳过（env 模式请 export $KEYREF；inline 模式检查 profile.key.value）"; fail=1
fi

echo "== 3. 端到端（隔离 CODEX_HOME，不碰真实 ~/.codex）=="
if [ -n "$KEY" ] && command -v codex >/dev/null 2>&1; then
  # CODEX_HOME 放 $HOME 下，避免 codex 拒绝在 /tmp 建 helper 的告警
  CH="$(mktemp -d "$HOME/.codex-verify-XXXXXX")"
  if [ "$CODEXAUTH" = "openai_auth" ]; then
    # 七牛 bypass 端点：requires_openai_auth + auth.json（官方 qiniu-coding-helper 写法）
    AUTHLINE="requires_openai_auth = true"
    printf '{"auth_mode":"apikey","OPENAI_API_KEY":"%s"}\n' "$KEY" > "$CH/auth.json"
    chmod 600 "$CH/auth.json"
  else
    AUTHLINE="env_key = \"$KEYREF\""
  fi
  cat > "$CH/config.toml" <<EOF
model = "$MAIN"
model_provider = "$PNAME"
model_reasoning_effort = "$MAINREASON"
disable_response_storage = true
[model_providers.$PNAME]
name = "$PDISP"
base_url = "$BASE"
$AUTHLINE
wire_api = "responses"
EOF
  check() { # $1=label $2=model
    local label="$1" model="$2" out
    # 关键：codex exec 会阻塞读 stdin，必须 < /dev/null 关掉，否则 timeout 卡死
    out=$(env "$KEYREF=$KEY" CODEX_HOME="$CH" timeout 120 codex exec --skip-git-repo-check \
      ${model:+-c model="\"$model\""} "reply with exactly: CODEX_${label}_OK" < /dev/null 2>&1 | grep -oE "CODEX_${label}_OK" | head -1)
    if [ -n "$out" ]; then echo "  $label($model) -> $out"; else echo "  $label($model) -> 无 OK 标记 ✗"; fail=1; fi
  }
  # env_key 模式下 codex 从环境读 key；openai_auth 模式从 auth.json 读，$KEYREF=$KEY 无害
  check "MAIN" "$MAIN"
  [ -n "$HIGH" ] && [ "$HIGH" != "$MAIN" ] && check "HIGH" "$HIGH"
  rm -rf "$CH"
else
  echo "  跳过（缺 key 或 codex 未装）"
fi

echo "== 结果 =="
if [ "$fail" = "0" ]; then echo "  全部通过 ✓"; else echo "  有失败项 ✗（见上）"; fi
exit $fail
