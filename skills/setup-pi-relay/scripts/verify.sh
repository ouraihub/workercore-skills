#!/usr/bin/env bash
# 验证 Pi + 中转 配置是否正常。
# 用法: PROFILE=easyclaude bash verify.sh
#   profile 从 <此脚本目录>/../assets/profiles/<PROFILE>.json 读取；
#   连通/端到端所需 key 从 profile.key（env/inline）解析。
set -u
fail=0
PROFILE="${PROFILE:-easyclaude}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_FILE="$SCRIPT_DIR/../assets/profiles/$PROFILE.json"

if [ ! -f "$PROFILE_FILE" ]; then echo "✗ 找不到 profile: $PROFILE_FILE"; exit 1; fi
echo "== profile: $PROFILE =="

eval "$(node -e '
const fs=require("fs");
const p=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
const sh=(k,v)=>console.log(k+"="+JSON.stringify(String(v==null?"":v)));
sh("PNAME",p.name);
sh("BASE",p.baseUrl.replace(/\/+$/,""));
sh("OPENAI_V1",(p.apis&&p.apis.openai&&p.apis.openai.pathV1)?"1":"");
sh("ANTHRO_ON",(p.apis&&p.apis.anthropic&&p.apis.anthropic.enabled)?"1":"");
sh("OPUS",p.models.opus?p.models.opus.id:"");
sh("OPUS_VIA",p.models.opus?p.models.opus.via:"");
sh("GPTHIGH",p.models.gptHigh?p.models.gptHigh.id:"");
sh("KEYMODE",p.key.mode);
sh("KEYREF",p.key.ref||"");
sh("KEYVAL",p.key.value||"");
' "$PROFILE_FILE")"

if [ "$KEYMODE" = "env" ]; then KEY="${!KEYREF:-}"; else KEY="$KEYVAL"; fi
if [ -n "$OPENAI_V1" ]; then OAI_URL="$BASE/v1/chat/completions"; else OAI_URL="$BASE/chat/completions"; fi
# opus 若 via=anthropic 且 anthropic 启用，走 <PNAME>-anthropic provider；否则走 openai provider
if [ "$OPUS_VIA" = "anthropic" ] && [ -n "$ANTHRO_ON" ]; then OPUS_PROVIDER="$PNAME-anthropic"; else OPUS_PROVIDER="$PNAME"; fi

checkjson() {
  node -e "const os=require('os'),path=require('path'),fs=require('fs');const dir=process.env.PI_CODING_AGENT_DIR||path.join(os.homedir(),'.pi','agent');JSON.parse(fs.readFileSync(path.join(dir,'$1'),'utf8'));console.log('  $1 OK')" \
    || { echo "  $1 解析失败"; fail=1; }
}

echo "== 1. JSON 合法性 =="
checkjson models.json
checkjson settings.json

echo "== 2. 中转直连（curl 基线 + UA 三连）=="
if [ -n "$KEY" ]; then
  for ua in "plain" "OpenAI/JS 6.26.0" "pi/0.80.3"; do
    if [ "$ua" = "plain" ]; then H=(); else H=(-H "user-agent: $ua"); fi
    code=$(curl -s -o /dev/null -w "%{http_code}" "$OAI_URL" \
      -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" "${H[@]}" \
      -d "{\"model\":\"$GPTHIGH\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":5}")
    echo "  UA=[$ua] -> HTTP $code"
    if [ "$ua" = "OpenAI/JS 6.26.0" ] && [ "$code" = "200" ]; then echo "    (注：该中转当前未拦此 UA，headers 覆盖仍无害)"; fi
  done
else
  echo "  跳过（key 未解析：env 模式请 export $KEYREF）"
fi

echo "== 3. pi 识别模型 =="
pi --list-models 2>/dev/null | grep -iE "$PNAME|$OPUS|$GPTHIGH" || { echo "  未发现模型"; fail=1; }

echo "== 4. 端到端（按 profile 应测的 provider）=="
check() { # $1=label $2..=args
  local label="$1"; shift
  local out; out=$(timeout 90 pi -p --no-session "$@" 2>&1 | tail -1)
  echo "  $label -> $out"
  case "$out" in *OK*) ;; *) fail=1;; esac
}
check "default" "reply with exactly: PI_DEFAULT_OK"
check "gptHigh($GPTHIGH)" --provider "$PNAME" --model "$GPTHIGH" "reply with exactly: PI_GPT_OK"
check "opus($OPUS)"       --provider "$OPUS_PROVIDER" --model "$OPUS" "reply with exactly: PI_CLAUDE_OK"

echo "== 结果 =="
if [ "$fail" = "0" ]; then echo "  全部通过 ✓"; else echo "  有失败项 ✗（见上）"; fi
exit $fail
