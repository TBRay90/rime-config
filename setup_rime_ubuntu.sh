#!/bin/bash
set -euo pipefail

# ========= 基本路径 =========
RIME_DIR="$HOME/.local/share/fcitx5/rime"
BACKUP_DIR="$HOME/rime_backup_$(date +%Y%m%d_%H%M%S)"
ENV_FILE="/etc/environment"

echo "=== Rime 一键安装（Ubuntu 24.04.3 Desktop）v2 ==="

# ========= 检测桌面环境（仅日志用） =========
DESKTOP_ENV=$(echo "${XDG_CURRENT_DESKTOP:-}" | tr '[:upper:]' '[:lower:]')
if [[ "$DESKTOP_ENV" == *"gnome"* ]]; then
  ENV_TYPE="gnome"
elif [[ "$DESKTOP_ENV" == *"kde"* ]]; then
  ENV_TYPE="kde"
else
  ENV_TYPE="other"
fi
echo "桌面环境：$ENV_TYPE"

# ========= 安装 fcitx5-rime =========
if ! dpkg -l | grep -q "^ii\s\+fcitx5-rime"; then
  echo "安装 fcitx5-rime ..."
  sudo apt update
  sudo apt install -y fcitx5 fcitx5-rime fcitx5-configtool
else
  echo "fcitx5-rime 已安装。"
fi

# ========= 写入/补充 输入法环境变量 =========
NEED_ENV_UPDATE=false
for k in GTK_IM_MODULE QT_IM_MODULE XMODIFIERS INPUT_METHOD; do
  if ! grep -q "$k=fcitx" "$ENV_FILE" 2>/dev/null; then NEED_ENV_UPDATE=true; fi
done
if $NEED_ENV_UPDATE; then
  echo "写入 /etc/environment 的 fcitx5 变量 ..."
  sudo bash -c "cat >> '$ENV_FILE' <<'EOF'

# >>> Rime & fcitx5 config <<<
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
export INPUT_METHOD=fcitx
EOF"
  echo "已写入。⚠️ 新会话生效（建议稍后重新登录或运行：source /etc/environment）"
else
  echo "/etc/environment 已包含 fcitx5 变量，跳过。"
fi

# ========= 备份旧配置 =========
echo "备份旧配置到：$BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
cp -a "$RIME_DIR" "$BACKUP_DIR" 2>/dev/null || true
mkdir -p "$RIME_DIR"

# ========= 安装 rime-install 工具（若缺失） =========
ensure_rime_install() {
  if command -v rime-install >/dev/null 2>&1; then
    echo "rime-install 已存在：$(command -v rime-install)"
    return
  fi
  echo "安装 rime-install ..."
  sudo apt install -y git curl
  mkdir -p "$HOME/.local/bin"
  curl -fsSL https://git.io/rime-install -o "$HOME/.local/bin/rime-install"
  chmod +x "$HOME/.local/bin/rime-install"
  if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
    echo 'export PATH="$PATH:$HOME/.local/bin"' >> "$HOME/.bashrc"
    export PATH="$PATH:$HOME/.local/bin"
  fi
  echo "rime-install 已安装：$HOME/.local/bin/rime-install"
}

ensure_rime_install

# ========= 写入三份配置 =========
echo "写入 default.custom.yaml ..."
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
      states: [ 繁, 简 ]              # ✅ reset:1 -> 选中第二项 = 简体
    - name: ascii_punct
      reset: 0
      states: [ 中标, 英标 ]

  key_binder:
    bindings:
      - { when: always, accept: "Control+Shift+F",     toggle: simplification }
      - { when: always, accept: "Control+Shift+J",     toggle: full_shape }
      - { when: always, accept: "Control+Shift+space", toggle: ascii_mode }
      - { when: always, accept: "Control+Shift+period", toggle: ascii_punct }
      - { when: composing, accept: "Shift+space", send: space }
EOF

echo "写入 luna_pinyin.custom.yaml ..."
cat > "$RIME_DIR/luna_pinyin.custom.yaml" <<'EOF'
patch:
  engine/filters:
    - uniquifier
    - simplifier@emoji_suggestion   # 先给 emoji 建议
    - simplifier                    # 再简繁转换

  emoji_suggestion:
    opencc_config: emoji.json
    option_name: emoji_suggestion

  switches:
    - { name: ascii_mode,       reset: 0, states: [ 中文, 英文 ] }
    - { name: full_shape,       reset: 0, states: [ 半角, 全角 ] }
    - { name: simplification,   reset: 1, states: [ 繁, 简 ] }   # ✅ 默认简体
    - { name: emoji_suggestion, reset: 1, states: [ "😶 关", "😊 开" ] }
    - { name: ascii_punct,      reset: 0, states: [ 中标, 英标 ] }

  punctuator:
    import_preset: symbols

  reverse_lookup/comment_format: ""
EOF

echo "写入 style.yaml（横排 + 主题） ..."
cat > "$RIME_DIR/style.yaml" <<'EOF'
patch:
  style:
    candidate_list_layout: linear      # 横向候选（fcitx5-rime 支持）
    font_point: 14
    candidate_spacing: 14
    corner_radius: 10
    color_scheme: solarized_light
    color_scheme_dark: solarized_dark

  preset_color_schemes:
    solarized_light:
      name: "Solarized Light"
      back_color: 0xFDF6E3
      border_color: 0xEEE8D5
      candidate_text_color: 0x073642
      hilited_candidate_back_color: 0xD33682
      hilited_candidate_text_color: 0xFFFFFF

    solarized_dark:
      name: "Solarized Dark"
      back_color: 0x002B36
      border_color: 0x073642
      candidate_text_color: 0xEEE8D5
      hilited_candidate_back_color: 0x586E75
      hilited_candidate_text_color: 0xFFFFFF
EOF

# ========= 安装基础方案 & emoji（若缺失） =========
need_schema=false
if ! ls "$RIME_DIR" | grep -q "luna_pinyin.schema.yaml"; then
  need_schema=true
fi

if $need_schema; then
  echo "安装基础方案 luna_pinyin ..."
  bash rime-install luna_pinyin || { echo "安装 luna_pinyin 失败，请检查网络或稍后重试。"; }
else
  echo "已检测到 luna_pinyin.schema.yaml，跳过安装。"
fi

if [ -f "$RIME_DIR/emoji_suggestion.yaml" ]; then
  echo "emoji 已安装，跳过。"
else
  echo "安装 emoji 模块 ..."
  bash rime-install emoji:customize:schema=luna_pinyin || echo "⚠️ emoji 安装失败（可稍后重试：bash rime-install emoji:customize:schema=luna_pinyin）"
fi

# ========= 部署 Rime =========
echo "部署 Rime ..."
if command -v rime_deployer >/dev/null 2>&1; then
  rime_deployer --build "$RIME_DIR" || true
else
  echo "找不到 rime_deployer（通常随 fcitx5-rime 提供），将尝试通过重启 fcitx5 触发构建。"
fi

# ========= 后台重启 fcitx5（不阻塞） =========
echo "重启 fcitx5 ..."
nohup fcitx5 -r >/dev/null 2>&1 &

echo "=== 完成！==="
echo "备份目录：$BACKUP_DIR"
echo "功能：默认简体 ✅  横排候选 ✅  emoji ✅  简繁/全角/标点/中英切换 ✅"
echo "若首次配置输入法，可在『设置→区域与语言』里添加 Chinese (Rime)。"
echo "若刚修改 /etc/environment，建议重新登录或执行：source /etc/environment"
