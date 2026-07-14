#!/usr/bin/env bash
# 验证 OMP + SiliconFlow 配置是否正常。
# 用法: PROFILE=siliconflow bash verify.sh
#   profile 从 <此脚本目录>/../assets/profiles/<PROFILE>.json 读取；
#   key 从 profile.key（env/inline）解析。
set -u
fail=0
PROFILE="${PROFILE:-siliconflow}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_FILE="$SCRIPT_DIR/../assets/profiles/$PROFILE.json"

if [ ! -f "$PROFILE_FILE" ]; then echo "✗ 找不到 profile: $PROFILE_FILE"; exit 1; fi
echo "== profile: $PROFILE =="

# 解析 profile
eval "$(node -e '
const fs=require("fs");
const p=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
const sh=(k,v)=>console.log(k+"="+JSON.stringify(String(v==null?"":v)));
sh("PNAME",p.name);
sh("BASE",p.baseUrl.replace(/\/+$/,""));
sh("KEYMODE",p.key.mode);
sh("KEYREF",p.key.ref||"");
sh("KEYVAL",p.key.value||"");
sh("M1_ID",p.models.v4pro?p.models.v4pro.id:"");
sh("M2_ID",p.models.v4flash?p.models.v4flash.id:"");
sh("M3_ID",p.models.kimi?p.models.kimi.id:"");
sh("M4_ID",p.models.glm?p.models.glm.id:"");
sh("IMG_DEFAULT",p.imagegen?p.imagegen.default:"");
' "$PROFILE_FILE")"

if [ "$KEYMODE" = "env" ]; then KEY="${!KEYREF:-}"; else KEY="$KEYVAL"; fi
if [ -z "$KEY" ]; then echo "✗ API Key 为空（env=$KEYREF）"; exit 1; fi

echo "== 1. omp 安装检查 =="
if command -v omp &>/dev/null; then
  echo "  ✓ omp: $(omp --version 2>&1 | head -1)"
else
  echo "  ✗ omp 未安装"; fail=1
fi

echo "== 2. Node.js 版本检查 =="
NODE_VER=$(node --version 2>/dev/null || echo "none")
if [[ "$NODE_VER" == "none" ]]; then
  echo "  ✗ Node.js 未安装"; fail=1
else
  MAJOR=$(echo "$NODE_VER" | sed 's/v//' | cut -d. -f1)
  if [ "$MAJOR" -ge 22 ]; then
    echo "  ✓ Node.js $NODE_VER"
  else
    echo "  ✗ Node.js $NODE_VER (需要 >= 22)"; fail=1
  fi
fi

echo "== 3. 配置文件检查 =="
OMP_DIR="$HOME/.omp/agent"
if [ -f "$OMP_DIR/models.yml" ]; then
  echo "  ✓ models.yml 存在"
else
  echo "  ✗ models.yml 不存在: $OMP_DIR/models.yml"; fail=1
fi
if [ -f "$OMP_DIR/mcp.json" ]; then
  echo "  ✓ mcp.json 存在"
else
  echo "  ✗ mcp.json 不存在: $OMP_DIR/mcp.json"; fail=1
fi
IMAGEGEN_CONFIG="$HOME/.config/imagegen-mcp/config.json"
if [ -f "$IMAGEGEN_CONFIG" ]; then
  echo "  ✓ imagegen-mcp config.json 存在"
else
  echo "  ✗ imagegen-mcp config.json 不存在"; fail=1
fi

echo "== 4. omp 模型发现 =="
if command -v omp &>/dev/null; then
  COUNT=$(omp models find "$PNAME" 2>&1 | grep -c "│" || true)
  if [ "$COUNT" -gt 0 ]; then
    echo "  ✓ omp 识别到 $PNAME 的模型"
  else
    echo "  ✗ omp 未识别到 $PNAME 的模型"; fail=1
  fi
fi

echo "== 5. API 连通性（chat） =="
URL="$BASE/v1/chat/completions"
BODY="{\"model\":\"$M2_ID\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":5}"
CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 "$URL" \
  -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d "$BODY")
if [ "$CODE" = "200" ]; then
  echo "  ✓ chat completions ($M2_ID): $CODE"
else
  echo "  ✗ chat completions ($M2_ID): HTTP $CODE"; fail=1
fi

echo "== 6. API 连通性（图片生成） =="
if [ -n "$IMG_DEFAULT" ]; then
  IMG_URL="$BASE/v1/images/generations"
  IMG_BODY="{\"model\":\"$IMG_DEFAULT\",\"prompt\":\"a red circle\",\"image_size\":\"256x256\"}"
  IMG_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 30 "$IMG_URL" \
    -H "Authorization: Bearer $KEY" \
    -H "Content-Type: application/json" \
    -d "$IMG_BODY")
  if [ "$IMG_CODE" = "200" ]; then
    echo "  ✓ images/generations ($IMG_DEFAULT): $IMG_CODE"
  else
    echo "  ✗ images/generations ($IMG_DEFAULT): HTTP $IMG_CODE"; fail=1
  fi
fi

echo "== 7. imagegen-mcp server 启动 =="
IMAGEGEN_DIR="$HOME/projects/imagegen-mcp"
if [ -d "$IMAGEGEN_DIR" ]; then
  INIT='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"0.1.0"}}}'
  RESP=$(echo "$INIT" | SILICONFLOW_API_KEY="$KEY" timeout 10 npx -y tsx "$IMAGEGEN_DIR/src/server.ts" 2>/dev/null | head -1)
  if echo "$RESP" | grep -q '"protocolVersion"'; then
    echo "  ✓ imagegen-mcp server 启动正常"
  else
    echo "  ✗ imagegen-mcp server 启动失败"; fail=1
  fi
else
  echo "  ✗ imagegen-mcp 未安装: $IMAGEGEN_DIR"; fail=1
fi

echo ""
if [ "$fail" -eq 0 ]; then
  echo "🎉 OMP_SILICONFLOW_ALL_OK"
else
  echo "❌ 部分检查失败，见上方 ✗ 标记"
  exit 1
fi
