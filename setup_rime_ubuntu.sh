#!/bin/bash
set -euo pipefail

RIME_DIR="$HOME/.local/share/fcitx5/rime"
BACKUP_DIR="$HOME/rime_backup_$(date +%Y%m%d_%H%M%S)"
ENV_FILE="/etc/environment"
GITHUB="https://github.com"
MIRROR="https://github.com.cnpmjs.org"

echo "=== Rime 一键安装 v3（含 GitHub 镜像兜底）==="

mkdir -p "$RIME_DIR" "$RIME_DIR/opencc"

# 检测桌面环境
DESKTOP_ENV=$(echo "${XDG_CURRENT_DESKTOP:-}" | tr '[:upper:]' '[:lower:]')
if [[ "$DESKTOP_ENV" == *"gnome"* ]]; then ENV_TYPE="gnome"
elif [[ "$DESKTOP_ENV" == *"kde"* ]]; then ENV_TYPE="kde"
else ENV_TYPE="other"; fi
echo "桌面环境：$ENV_TYPE"

# 安装 fcitx5-rime
if ! dpkg -l | grep -q "^ii\s\+fcitx5-rime"; then
  echo "⬇️ 安装 fcitx5-rime..."
  sudo apt update && sudo apt install -y fcitx5 fcitx5-rime fcitx5-configtool git curl
else
  echo "✅ fcitx5-rime 已安装。"
fi

# 写入 /etc/environment
for k in GTK_IM_MODULE QT_IM_MODULE XMODIFIERS INPUT_METHOD; do
  grep -q "$k=fcitx" "$ENV_FILE" 2>/dev/null || NEED_ENV_UPDATE=true
done
if ${NEED_ENV_UPDATE:-false}; then
  echo "⚙️ 更新 /etc/environment ..."
  sudo bash -c "cat >> '$ENV_FILE' <<'EOF'

# >>> Rime & fcitx5 config <<<
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
export INPUT_METHOD=fcitx
EOF"
fi

# 备份旧配置
echo "📦 备份旧配置到 $BACKUP_DIR"
cp -a "$RIME_DIR" "$BACKUP_DIR" 2>/dev/null || true

# 确保 rime-install 可用
ensure_rime_install() {
  if command -v rime-install >/dev/null 2>&1; then return 0; fi
  echo "⬇️ 安装 rime-install ..."
  mkdir -p "$HOME/.local/bin"
  curl -fsSL https://git.io/rime-install -o "$HOME/.local/bin/rime-install" || return 1
  chmod +x "$HOME/.local/bin/rime-install"
  export PATH="$PATH:$HOME/.local/bin"
}

ensure_rime_install || echo "⚠️ 无法下载 rime-install，将使用 Git 兜底。"

# 写入基础配置文件
cat > "$RIME_DIR/default.custom.yaml" <<'EOF'
patch:
  schema_list:
    - schema: luna_pinyin
  menu/page_size: 9
  switches:
    - name: ascii_mode
      reset: 0
      states: [ 中文, 英文 ]
    - name: full_shape
      reset: 0
      states: [ 半角, 全角 ]
    - name: simplification
      reset: 1
      states: [ 繁, 简 ]
    - name: ascii_punct
      reset: 0
      states: [ 中标, 英标 ]
  key_binder:
    bindings:
      - { when: always, accept: "Control+Shift+F", toggle: simplification }
      - { when: always, accept: "Control+Shift+J", toggle: full_shape }
      - { when: always, accept: "Control+Shift+space", toggle: ascii_mode }
      - { when: always, accept: "Control+Shift+period", toggle: ascii_punct }
      - { when: composing, accept: "Shift+space", send: space }
EOF

cat > "$RIME_DIR/luna_pinyin.custom.yaml" <<'EOF'
patch:
  engine/filters:
    - uniquifier
    - simplifier@emoji_suggestion
    - simplifier
  emoji_suggestion:
    opencc_config: opencc/emoji.json
    option_name: emoji_suggestion
  switches:
    - { name: ascii_mode, reset: 0, states: [ 中文, 英文 ] }
    - { name: full_shape, reset: 0, states: [ 半角, 全角 ] }
    - { name: simplification, reset: 1, states: [ 繁, 简 ] }
    - { name: emoji_suggestion, reset: 1, states: [ "😶 关", "😊 开" ] }
    - { name: ascii_punct, reset: 0, states: [ 中标, 英标 ] }
  punctuator:
    import_preset: symbols
EOF

cat > "$RIME_DIR/style.yaml" <<'EOF'
patch:
  style:
    candidate_list_layout: linear
    font_point: 14
    candidate_spacing: 14
    corner_radius: 10
    color_scheme: solarized_light
    color_scheme_dark: solarized_dark
  preset_color_schemes:
    solarized_light:
      back_color: 0xFDF6E3
      border_color: 0xEEE8D5
      candidate_text_color: 0x073642
      hilited_candidate_back_color: 0xD33682
      hilited_candidate_text_color: 0xFFFFFF
    solarized_dark:
      back_color: 0x002B36
      border_color: 0x073642
      candidate_text_color: 0xEEE8D5
      hilited_candidate_back_color: 0x586E75
      hilited_candidate_text_color: 0xFFFFFF
EOF

# ========= 安装 schema 与 emoji =========
install_via_rime_install() {
  echo "📥 使用 rime-install 安装方案..."
  bash rime-install luna_pinyin || return 1
  bash rime-install emoji:customize:schema=luna_pinyin || return 1
}

install_via_git_fallback() {
  echo "🌐 使用 Git 拉取方案（带镜像兜底）..."
  tmp="$(mktemp -d)"
  for repo in "rime-luna-pinyin" "rime-emoji"; do
    url="$GITHUB/rime/$repo"
    echo "→ 拉取 $url"
    if ! git clone --depth=1 "$url" "$tmp/$repo" 2>/dev/null; then
      echo "⚠️ GitHub 拉取失败，尝试镜像..."
      git clone --depth=1 "$MIRROR/rime/$repo" "$tmp/$repo"
    fi
  done
  cp -f "$tmp/rime-luna-pinyin"/luna_pinyin*.yaml "$RIME_DIR"/ 2>/dev/null || true
  cp -f "$tmp/rime-luna-pinyin"/opencc/* "$RIME_DIR/opencc"/ 2>/dev/null || true
  cp -f "$tmp/rime-emoji"/opencc/emoji.json "$RIME_DIR/opencc/emoji.json" 2>/dev/null || true
  rm -rf "$tmp"
}

echo "🔍 安装 Rime 基础方案与 emoji..."
if install_via_rime_install; then
  echo "✅ rime-install 成功。"
else
  echo "⚠️ rime-install 失败，启用 Git 镜像兜底..."
  install_via_git_fallback
fi

# ========= 修补配置确保 emoji 生效 =========
if ! grep -q "opencc/emoji.json" "$RIME_DIR/luna_pinyin.custom.yaml"; then
  echo "修补 emoji 路径..."
  sed -i 's#opencc_config:.*#opencc_config: opencc/emoji.json#g' "$RIME_DIR/luna_pinyin.custom.yaml"
fi

# ========= 部署 & 重启 =========
echo "🚀 构建并重启 fcitx5 ..."
if command -v rime_deployer >/dev/null 2>&1; then
  rime_deployer --build "$RIME_DIR" || true
fi
nohup fcitx5 -r >/dev/null 2>&1 &

echo "🎉 安装完成！"
echo "📦 备份目录: $BACKUP_DIR"
echo "✅ 功能: 简体默认 / 横排候选 / emoji / 简繁-全角-标点切换全启用"
echo "💡 若网络仍受限，可手动修改变量 MIRROR 指向其他镜像（如 fastgit.org 或 ghproxy.com）"
