#!/usr/bin/env bash
set -euo pipefail

RIME_DIR="$HOME/.local/share/fcitx5/rime"
mkdir -p "$RIME_DIR"
cd "$RIME_DIR"

# 安装 plum 工具
if ! command -v rime-install >/dev/null 2>&1; then
  sudo apt update
  sudo apt install -y git curl
  mkdir -p "$HOME/.local/bin"
  curl -fsSL https://git.io/rime-install -o "$HOME/.local/bin/rime-install"
  chmod +x "$HOME/.local/bin/rime-install"
  export PATH="$PATH:$HOME/.local/bin"
fi

# 安装基础方案
if [ ! -f "$RIME_DIR/luna_pinyin.schema.yaml" ]; then
  echo "Installing luna_pinyin ..."
  bash rime-install luna_pinyin
else
  echo "luna_pinyin.schema.yaml exists. skip."
fi

# 安装 emoji
if ! find "$RIME_DIR" -maxdepth 2 -iname 'emoji.json' | grep -q .; then
  echo "Installing emoji ..."
  bash rime-install emoji:customize:schema=luna_pinyin || true
fi

# 侦测 emoji.json 实际路径
EMOJI_JSON_PATH="$(find "$RIME_DIR" -maxdepth 2 -iname 'emoji.json' | head -n1 || true)"
if [ -z "${EMOJI_JSON_PATH:-}" ]; then
  echo "⚠️ 未找到 emoji.json，可能网络或 GitHub 访问失败。稍后重试：bash rime-install emoji:customize:schema=luna_pinyin"
else
  # 规范成相对路径给 opencc_config 用
  REL_PATH="${EMOJI_JSON_PATH#"$RIME_DIR"/}"
  echo "✅ emoji.json found at: $REL_PATH"

  # 如果 opencc_config 写的不是实际路径，则自动修补
  if grep -q 'opencc_config:' "$RIME_DIR/luna_pinyin.custom.yaml"; then
    sed -i "s#^\(\s*opencc_config:\s*\).*#\1$REL_PATH#g" "$RIME_DIR/luna_pinyin.custom.yaml"
  else
    # 如果用户文件里没有该行，就追加一份最小段落
    cat >> "$RIME_DIR/luna_pinyin.custom.yaml" <<EOF

# auto-patched by fix_rime_emoji.sh
patch:
  emoji_suggestion:
    opencc_config: $REL_PATH
    option_name: emoji_suggestion
EOF
  fi
fi

# 部署 & 重启
rime_deployer --build "$RIME_DIR" || true
nohup fcitx5 -r >/dev/null 2>&1 &

echo "🎉 Done. 现在重新切换到 Rime 输入法，输入 'xiao' 试试是否出现 emoji 候选。"
