#!/usr/bin/env bash
# 验证 Pi + EasyClaude 中转配置是否正常。
# 用法: EASYCLAUDE_KEY=sk-... bash verify.sh
set -u

fail=0

# 让 node 自己解析配置目录，避免 Git Bash 的 $HOME(/c/Users/..) 被 Windows node 误解析成 C:\c\Users\..
checkjson() {
  node -e "const os=require('os'),path=require('path'),fs=require('fs');const dir=process.env.PI_CODING_AGENT_DIR||path.join(os.homedir(),'.pi','agent');JSON.parse(fs.readFileSync(path.join(dir,'$1'),'utf8'));console.log('  $1 OK')" \
    || { echo "  $1 解析失败"; fail=1; }
}

echo "== 1. JSON 合法性 =="
checkjson models.json
checkjson settings.json

echo "== 2. 中转直连（curl 基线，应 200）=="
if [ -n "${EASYCLAUDE_KEY:-}" ]; then
  for ua in "plain" "OpenAI/JS 6.26.0" "pi/0.80.3"; do
    if [ "$ua" = "plain" ]; then H=(); else H=(-H "user-agent: $ua"); fi
    code=$(curl -s -o /dev/null -w "%{http_code}" "https://api.easyclaude.com/v1/chat/completions" \
      -H "Authorization: Bearer $EASYCLAUDE_KEY" -H "Content-Type: application/json" "${H[@]}" \
      -d '{"model":"gpt-5.5","messages":[{"role":"user","content":"hi"}],"max_tokens":5}')
    echo "  UA=[$ua] -> HTTP $code"
    if [ "$ua" = "OpenAI/JS 6.26.0" ] && [ "$code" = "200" ]; then echo "    (注：该中转当前未拦此 UA，headers 覆盖仍无害)"; fi
  done
else
  echo "  跳过（未设 EASYCLAUDE_KEY）"
fi

echo "== 3. pi 识别模型 =="
pi --list-models 2>/dev/null | grep -iE "easyclaude|opus|gpt-5" || { echo "  未发现模型"; fail=1; }

echo "== 4. 端到端（三个 provider）=="
check() { # $1=label $2..=args
  local label="$1"; shift
  local out; out=$(timeout 90 pi -p --no-session "$@" 2>&1 | tail -1)
  echo "  $label -> $out"
  case "$out" in *OK*) ;; *) fail=1;; esac
}
check "default(opus4.8)" "reply with exactly: PI_DEFAULT_OK"
check "gpt-5.5"          --provider easyclaude --model gpt-5.5 "reply with exactly: PI_GPT_OK"
check "claude-opus-4-8"  --provider easyclaude-anthropic --model claude-opus-4-8 "reply with exactly: PI_CLAUDE_OK"

echo "== 结果 =="
if [ "$fail" = "0" ]; then echo "  全部通过 ✓"; else echo "  有失败项 ✗（见上）"; fi
exit $fail
