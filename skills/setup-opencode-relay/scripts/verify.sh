#!/usr/bin/env bash
# 验证 OpenCode + 中转 + oh-my-openagent 配置是否正常。
# 用法: PROFILE=easyclaude bash verify.sh
#   profile 从 <此脚本目录>/../assets/profiles/<PROFILE>.json 读取；
#   连通测试所需 key 从 profile.key（env: 读环境变量 / inline: 直接用）解析。
set -u
fail=0
PROFILE="${PROFILE:-easyclaude}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_FILE="$SCRIPT_DIR/../assets/profiles/$PROFILE.json"

if [ ! -f "$PROFILE_FILE" ]; then echo "✗ 找不到 profile: $PROFILE_FILE"; exit 1; fi
echo "== profile: $PROFILE =="

# 从 profile 抽取变量到 shell
eval "$(node -e '
const fs=require("fs");
const p=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
const sh=(k,v)=>console.log(k+"="+JSON.stringify(String(v==null?"":v)));
sh("PNAME",p.name);
sh("BASE",p.baseUrl.replace(/\/+$/,""));
sh("OPENAI_V1", (p.apis&&p.apis.openai&&p.apis.openai.pathV1)?"1":"");
sh("OPUS", p.models.opus?p.models.opus.id:"");
sh("GPTHIGH", p.models.gptHigh?p.models.gptHigh.id:"");
sh("GPT56", p.models.gpt56?p.models.gpt56.id:"");
sh("KEYMODE", p.key.mode);
sh("KEYREF", p.key.ref||"");
sh("KEYVAL", p.key.value||"");
' "$PROFILE_FILE")"

# 解析 key：env 模式读环境变量；inline 模式直接用
if [ "$KEYMODE" = "env" ]; then KEY="${!KEYREF:-}"; else KEY="$KEYVAL"; fi
# openai 端点：pathV1 决定带不带 /v1
if [ -n "$OPENAI_V1" ]; then OAI_URL="$BASE/v1/chat/completions"; else OAI_URL="$BASE/chat/completions"; fi
# 连通测试用的模型：优先 gptHigh，退回 opus
PROBE_MODEL="${GPTHIGH:-$OPUS}"

cfgpath() { node -e "console.log(require('path').join(require('os').homedir(),'.config','opencode','$1'))"; }

echo "== 1. opencode.json 合法性 + provider =="
node -e "
const os=require('os'),path=require('path'),fs=require('fs');
const c=JSON.parse(fs.readFileSync(path.join(os.homedir(),'.config','opencode','opencode.json'),'utf8'));
const ids=Object.keys(c.provider||{});
console.log('  providers:',ids.join(',')||'(none)');
if(ids.includes('openai')||ids.includes('anthropic')||ids.includes('google')) console.log('  ⚠ 使用了保留名 provider（坑一）');
const p=c.provider&&c.provider['$PNAME'];
if(!p){console.log('  ✗ 缺 $PNAME provider');process.exit(1);}
console.log('  npm:',p.npm,'| baseURL:',p.options.baseURL);
console.log('  models:',Object.keys(p.models).join(','));
" || { echo "  opencode.json 解析失败"; fail=1; }

echo "== 2. oh-my-openagent 映射合法性 + 模型前缀 =="
# 文件名随 omo 版本变化：老版本 .jsonc，omo 4.16.x 生成 .json。自动探测二者。
PNAME="$PNAME" node -e "
const os=require('os'),path=require('path'),fs=require('fs');
const pname=process.env.PNAME;
const dir=path.join(os.homedir(),'.config','opencode');
const cand=['oh-my-openagent.json','oh-my-openagent.jsonc'].map(f=>path.join(dir,f)).filter(p=>fs.existsSync(p));
if(!cand.length){console.log('  ✗ 未找到 oh-my-openagent.json[c]');process.exit(1);}
const file=cand[0];
console.log('  使用文件:',path.basename(file));
let s=fs.readFileSync(file,'utf8');
// .json 是严格 JSON；.jsonc 需去注释/尾逗号后再解析。统一走宽松清洗，两者都能过。
s=s.replace(/\/\*[\s\S]*?\*\//g,'').split('\n').map(l=>l.replace(/^(\s*)\/\/.*\$/,'')).join('\n').replace(/,(\s*[}\]])/g,'\$1');
const j=JSON.parse(s);
const models=new Set();
Object.values(j.agents||{}).forEach(a=>models.add(a.model));
Object.values(j.categories||{}).forEach(a=>models.add(a.model));
const bad=[...models].filter(m=>!m.startsWith(pname+'/'));
console.log('  agents:',Object.keys(j.agents||{}).length,'| categories:',Object.keys(j.categories||{}).length);
console.log('  models:',[...models].join(', '));
if(bad.length){console.log('  ✗ 非 '+pname+'/ 前缀（坑二未修，如 opencode/gpt-5-nano）:',bad.join(', '));process.exit(1);}
console.log('  ✓ 全部 '+pname+'/ 前缀');
" || { echo "  oh-my-openagent 映射校验失败"; fail=1; }

echo "== 3. 旧名文件残留检查（坑三）=="
for f in oh-my-opencode.json oh-my-opencode.jsonc; do
  p=$(cfgpath "$f")
  if [ -f "$p" ]; then echo "  ✗ 存在旧名文件 $f（会覆盖新配置，应删除）"; fail=1; else echo "  ✓ 无 $f"; fi
done

echo "== 4. 中转连通（应 200）=="
if [ -n "$KEY" ]; then
  for m in "$PROBE_MODEL" "$GPT56"; do
    [ -z "$m" ] && continue
    code=$(curl -s -o /dev/null -w "%{http_code}" "$OAI_URL" \
      -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
      -d "{\"model\":\"$m\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":16}")
    echo "  $m @ $OAI_URL -> HTTP $code"; [ "$code" = "200" ] || fail=1
  done
else
  echo "  ✗ key 未解析，连通测试跳过（env 模式请 export $KEYREF；inline 模式检查 profile.key.value）"; fail=1
fi

echo "== 5. opencode 识别 provider/模型 =="
mout=$(timeout 60 opencode models 2>&1 | grep -iE "^$PNAME/|[[:space:]]$PNAME/")
if [ -n "$mout" ]; then echo "$mout" | sed 's/^/  /'; else echo "  ✗ opencode 未列出 $PNAME 模型（检查配置或重启 opencode）"; fail=1; fi

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
