#!/usr/bin/env bash
# 验证 OpenCode + EasyClaude 中转 + oh-my-openagent 配置是否正常。
# 用法: EASYCLAUDE_KEY=sk-... bash verify.sh
set -u
fail=0

# 让 node 自己解析路径，避免 Git Bash 的 $HOME(/c/Users/..) 被 Windows node 误解析
cfgpath() { node -e "console.log(require('path').join(require('os').homedir(),'.config','opencode','$1'))"; }

echo "== 1. opencode.json 合法性 + provider =="
node -e "
const os=require('os'),path=require('path'),fs=require('fs');
const c=JSON.parse(fs.readFileSync(path.join(os.homedir(),'.config','opencode','opencode.json'),'utf8'));
const ids=Object.keys(c.provider||{});
console.log('  providers:',ids.join(',')||'(none)');
if(ids.includes('openai')||ids.includes('anthropic')) console.log('  ⚠ 使用了保留名 provider（坑一）');
const p=c.provider&&c.provider.easyclaude;
if(!p){console.log('  ✗ 缺 easyclaude provider');process.exit(1);}
console.log('  npm:',p.npm,'| baseURL:',p.options.baseURL);
console.log('  models:',Object.keys(p.models).join(','));
" || { echo "  opencode.json 解析失败"; fail=1; }

echo "== 2. oh-my-openagent.jsonc 合法性 + 模型前缀 =="
node -e "
const os=require('os'),path=require('path'),fs=require('fs');
let s=fs.readFileSync(path.join(os.homedir(),'.config','opencode','oh-my-openagent.jsonc'),'utf8');
s=s.replace(/\/\*[\s\S]*?\*\//g,'').split('\n').map(l=>l.replace(/^(\s*)\/\/.*$/,'')).join('\n').replace(/,(\s*[}\]])/g,'\$1');
const j=JSON.parse(s);
const models=new Set();
Object.values(j.agents||{}).forEach(a=>models.add(a.model));
Object.values(j.categories||{}).forEach(a=>models.add(a.model));
const bad=[...models].filter(m=>!m.startsWith('easyclaude/'));
console.log('  agents:',Object.keys(j.agents||{}).length,'| categories:',Object.keys(j.categories||{}).length);
console.log('  models:',[...models].join(', '));
if(bad.length){console.log('  ✗ 非 easyclaude 前缀（坑二未修）:',bad.join(', '));process.exit(1);}
console.log('  ✓ 全部 easyclaude/ 前缀');
" || { echo "  oh-my-openagent.jsonc 校验失败"; fail=1; }

echo "== 3. 旧名文件残留检查（坑三）=="
for f in oh-my-opencode.json oh-my-opencode.jsonc; do
  p=$(cfgpath "$f")
  if [ -f "$p" ]; then echo "  ✗ 存在旧名文件 $f（会覆盖新配置，应删除）"; fail=1; else echo "  ✓ 无 $f"; fi
done

echo "== 4. 中转连通（应 200）=="
if [ -n "${EASYCLAUDE_KEY:-}" ]; then
  code=$(curl -s -o /dev/null -w "%{http_code}" "https://api.easyclaude.com/v1/chat/completions" \
    -H "Authorization: Bearer $EASYCLAUDE_KEY" -H "Content-Type: application/json" \
    -d '{"model":"claude-opus-4-8","messages":[{"role":"user","content":"hi"}],"max_tokens":5}')
  echo "  claude-opus-4-8 -> HTTP $code"; [ "$code" = "200" ] || fail=1
else
  echo "  跳过（未设 EASYCLAUDE_KEY）"
fi

echo "== 5. opencode 识别 provider/模型 =="
mout=$(timeout 60 opencode models 2>&1 | grep -iE "easyclaude/")
if [ -n "$mout" ]; then echo "$mout" | sed 's/^/  /'; else echo "  ✗ opencode 未列出 easyclaude 模型（检查配置或重启 opencode）"; fail=1; fi

echo "== 6. omo doctor =="
docout=$(cd "$(cfgpath '')" 2>/dev/null && timeout 120 bunx oh-my-openagent@latest doctor 2>&1)
issues=$(printf '%s\n' "$docout" | grep -oE "[0-9]+ issue" | head -1 | grep -oE "[0-9]+")
issues=${issues:-0}
echo "  doctor 报告 $issues 个问题"
if printf '%s\n' "$docout" | grep -qi "legacy package name"; then echo "  ✗ plugin 用了旧名（坑：改 oh-my-openagent@latest）"; fail=1; fi
# AST-Grep 是可选依赖，是唯一可接受的遗留问题
if [ "$issues" -gt 1 ]; then echo "  ⚠ 除 AST-Grep 外还有其他问题，见下"; printf '%s\n' "$docout" | grep -iE "^[0-9]+\.|Fix:" | head -8 | sed 's/^/    /'; fi

echo "== 结果 =="
if [ "$fail" = "0" ]; then echo "  核心项全部通过 ✓（重启 opencode 生效）"; else echo "  有失败项 ✗（见上）"; fi
exit $fail
