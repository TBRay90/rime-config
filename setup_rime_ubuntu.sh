#!/bin/bash
set -euo pipefail

RIME_DIR="$HOME/.local/share/fcitx5/rime"
BACKUP_DIR="$HOME/rime_backup_$(date +%Y%m%d_%H%M%S)"
ENV_FILE="/etc/environment"

# 镜像设置（按需替换）
GITHUB="https://github.com"
MIRROR_DEFAULT="https://github.com.cnpmjs.org"

echo "=== Rime 一键安装 v4（含 pinyin 资源补齐 & 镜像兜底） ==="

mkdir -p "$RIME_DIR" "$RIME_DIR/opencc" "$RIME_DIR/pinyin"

log(){ echo -e "$@"; }

# 1) 必备包
if ! dpkg -l | grep -q "^ii\s\+fcitx5-rime"; then
  log "⬇️ 安装 fcitx5-rime..."
  sudo apt update && sudo apt install -y fcitx5 fcitx5-rime fcitx5-configtool git curl
else
  log "✅ fcitx5-rime 已安装。"
fi

# 2) /etc/environment（缺才写）
NEED_ENV=false
for k in GTK_IM_MODULE QT_IM_MODULE XMODIFIERS INPUT_METHOD; do
  grep -q "$k=fcitx" "$ENV_FILE" 2>/dev/null || NEED_ENV=true
done
if $NEED_ENV; then
  log "⚙️ 更新 /etc/environment ..."
  sudo bash -c "cat >> '$ENV_FILE' <<'EOF'

# >>> Rime & fcitx5 config <<<
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
export INPUT_METHOD=fcitx
EOF"
  log "ℹ️ 已写入；重新登录或：source /etc/environment"
fi

# 3) 备份
cp -a "$RIME_DIR" "$BACKUP_DIR" 2>/dev/null || true
log "📦 旧配置已备份到: $BACKUP_DIR"

# 4) 写入三份配置（与之前一致）
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
  reverse_lookup/comment_format: ""
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

# 5) 优先 rime-install 安装；失败则 Git 兜底
ensure_rime_install() {
  if command -v rime-install >/dev/null 2>&1; then return 0; fi
  mkdir -p "$HOME/.local/bin"
  curl -fsSL https://git.io/rime-install -o "$HOME/.local/bin/rime-install" || return 1
  chmod +x "$HOME/.local/bin/rime-install"
  export PATH="$PATH:$HOME/.local/bin"
}

install_via_rime_install() {
  ensure_rime_install || return 1
  [ -f "$RIME_DIR/luna_pinyin.schema.yaml" ] || bash rime-install luna_pinyin || return 1
  if [ ! -f "$RIME_DIR/opencc/emoji.json" ] && [ ! -f "$RIME_DIR/emoji.json" ]; then
    bash rime-install emoji:customize:schema=luna_pinyin || return 1
  fi
  return 0
}

clone_with_mirror() {
  local repo="$1" dest="$2"
  local url="$GITHUB/rime/$repo"
  if ! git clone --depth=1 "$url" "$dest" 2>/dev/null; then
    log "⚠️ GitHub 失败，尝试镜像 $MIRROR_DEFAULT ..."
    git clone --depth=1 "$MIRROR_DEFAULT/rime/$repo" "$dest"
  fi
}

install_via_git() {
  tmp="$(mktemp -d)"
  clone_with_mirror "rime-luna-pinyin" "$tmp/luna"
  cp -f "$tmp/luna"/luna_pinyin*.yaml "$RIME_DIR"/ 2>/dev/null || true
  cp -f "$tmp/luna"/opencc/* "$RIME_DIR/opencc"/ 2>/dev/null || true
  rm -rf "$tmp/luna"

  # 关键：补齐 pinyin 资源
  clone_with_mirror "rime-data" "$tmp/data"
  cp -rf "$tmp/data/pinyin/"* "$RIME_DIR/pinyin/" 2>/dev/null || true
  rm -rf "$tmp/data"

  # emoji
  clone_with_mirror "rime-emoji" "$tmp/emoji"
  [ -f "$tmp/emoji/opencc/emoji.json" ] && cp -f "$tmp/emoji/opencc/emoji.json" "$RIME_DIR/opencc/emoji.json" || true
  rm -rf "$tmp/emoji"
}

log "🔍 安装 schema 与 emoji ..."
if install_via_rime_install; then
  log "✅ rime-install 成功。"
else
  log "⚠️ rime-install 失败，使用 Git + 镜像兜底 ..."
  install_via_git
fi

# 修正 emoji.json 路径为 opencc/emoji.json
if [ -f "$RIME_DIR/emoji.json" ] && [ ! -f "$RIME_DIR/opencc/emoji.json" ]; then
  mv "$RIME_DIR/emoji.json" "$RIME_DIR/opencc/emoji.json"
fi
sed -i 's#opencc_config:.*#opencc_config: opencc/emoji.json#g' "$RIME_DIR/luna_pinyin.custom.yaml" || true

# 6) 验证关键文件是否存在
ok=true
[ -f "$RIME_DIR/luna_pinyin.schema.yaml" ] || { log "❌ 缺少 luna_pinyin.schema.yaml"; ok=false; }
[ -f "$RIME_DIR/pinyin/abbreviation.txt" ] || { log "❌ 缺少 pinyin/abbreviation.txt"; ok=false; }
[ -f "$RIME_DIR/pinyin/speller.yaml" ] || { log "❌ 缺少 pinyin/speller.yaml"; ok=false; }
[ -f "$RIME_DIR/opencc/emoji.json" ] || { log "⚠️ 未找到 opencc/emoji.json（可稍后重试）"; }

$ok || log "⚠️ 基础资源不完整，构建可能失败。请检查网络或更换 MIRROR 后重跑。"

# 7) 构建 & 后台重启
if command -v rime_deployer >/dev/null 2>&1; then
  rime_deployer --build "$RIME_DIR" || true
fi
nohup fcitx5 -r >/dev/null 2>&1 &

echo "🎉 完成！功能：默认简体 ✅  横排候选 ✅  emoji ✅  简繁/全角/标点切换 ✅"
echo "🧪 验证：输入 xiao 应看到中文候选 + emoji；若失败，检查 $RIME_DIR/pinyin 与 $RIME_DIR/opencc"
