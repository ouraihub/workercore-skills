#!/usr/bin/env bash
# 验证 Claude Code CLI + 中转 配置是否正常。
# 用法: PROFILE=qiniu bash verify.sh
#   profile 从 <此脚本目录>/../assets/profiles/<PROFILE>.json 读取；
#   连通/端到端所需 key 从 profile.key（env/inline）解析。
# Claude Code 走 Anthropic /v1/messages，中转必须暴露该端点。
# 端到端用隔离 HOME，绝不改用户 ~/.claude 下的真实配置。
set -u
fail=0
PROFILE="${PROFILE:-qiniu}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_FILE="$SCRIPT_DIR/../assets/profiles/$PROFILE.json"

if [ ! -f "$PROFILE_FILE" ]; then echo "✗ 找不到 profile: $PROFILE_FILE"; exit 1; fi
echo "== profile: $PROFILE =="

eval "$(node -e '
const fs=require("fs");
const p=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
const sh=(k,v)=>console.log(k+"="+JSON.stringify(String(v==null?"":v)));
const def=p.default||"opus";
sh("PNAME",p.name);
sh("BASE",p.baseUrl.replace(/\/+$/,""));   // 不含 /v1，客户端自拼 /v1/messages
sh("OPUS",p.models.opus?p.models.opus.id:"");
sh("SONNET",p.models.sonnet?p.models.sonnet.id:"");
sh("HAIKU",p.models.haiku?p.models.haiku.id:"");
sh("DEFID",p.models[def]?p.models[def].id:(p.models.opus?p.models.opus.id:""));
sh("KEYMODE",p.key.mode);
sh("KEYREF",p.key.ref||"");
sh("KEYVAL",p.key.value||"");
' "$PROFILE_FILE")"

if [ "$KEYMODE" = "env" ]; then KEY="${!KEYREF:-}"; else KEY="$KEYVAL"; fi
MSG_URL="$BASE/v1/messages"

echo "== 1. claude 已装 =="
if command -v claude >/dev/null 2>&1; then echo "  $(claude --version)"; else echo "  ✗ 未找到 claude（见 SKILL.md 第 1 步）"; fail=1; fi

echo "== 2. 中转 /v1/messages 连通（应 200；无此端点则 codex 那类走 responses 的不可用）=="
if [ -n "$KEY" ]; then
  for m in "$OPUS" "$SONNET" "$HAIKU"; do
    [ -z "$m" ] && continue
    code=$(curl -s -m 30 -o /tmp/claude-verify-body -w "%{http_code}" "$MSG_URL" \
      -H "Authorization: Bearer $KEY" -H "anthropic-version: 2023-06-01" -H "Content-Type: application/json" \
      -d "{\"model\":\"$m\",\"max_tokens\":16,\"messages\":[{\"role\":\"user\",\"content\":\"say ok\"}]}")
    echo "  $m @ $MSG_URL -> HTTP $code $([ "$code" != 200 ] && head -c 120 /tmp/claude-verify-body)"
    [ "$code" = "200" ] || fail=1
  done
  rm -f /tmp/claude-verify-body
else
  echo "  ✗ key 未解析，连通测试跳过（env 模式请 export $KEYREF；inline 模式检查 profile.key.value）"; fail=1
fi

echo "== 3. 端到端（隔离 HOME，不碰真实 ~/.claude）=="
if [ -n "$KEY" ] && command -v claude >/dev/null 2>&1; then
  TH="$(mktemp -d "$HOME/.claude-verify-XXXXXX")"
  # 跳过 onboarding
  printf '{"hasCompletedOnboarding":true,"bypassPermissionsModeAccepted":true}\n' > "$TH/.claude.json"
  out=$(env -i PATH="$PATH" HOME="$TH" \
    ANTHROPIC_BASE_URL="$BASE" \
    ANTHROPIC_AUTH_TOKEN="$KEY" \
    ANTHROPIC_MODEL="$DEFID" \
    ANTHROPIC_SMALL_FAST_MODEL="${HAIKU:-$DEFID}" \
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
    timeout 90 claude -p "reply with exactly: CLAUDE_RELAY_OK" < /dev/null 2>&1 | grep -oE "CLAUDE_RELAY_OK" | head -1)
  if [ -n "$out" ]; then echo "  default($DEFID) -> $out"; else echo "  default($DEFID) -> 无 OK 标记 ✗"; fail=1; fi
  rm -rf "$TH"
else
  echo "  跳过（缺 key 或 claude 未装）"
fi

echo "== 结果 =="
if [ "$fail" = "0" ]; then echo "  全部通过 ✓"; else echo "  有失败项 ✗（见上）"; fi
exit $fail
