#!/bin/bash
set -e

# ========== 环境与目录 ==========
RIME_DIR="$HOME/.local/share/fcitx5/rime"
BACKUP_DIR="$HOME/rime_backup_$(date +%Y%m%d_%H%M%S)"

echo "🧩 检查系统环境 ..."

# 检查桌面环境
DESKTOP_ENV=$(echo "$XDG_CURRENT_DESKTOP" | tr '[:upper:]' '[:lower:]')
if [[ "$DESKTOP_ENV" == *"gnome"* ]]; then
  ENV_TYPE="gnome"
elif [[ "$DESKTOP_ENV" == *"kde"* ]]; then
  ENV_TYPE="kde"
else
  ENV_TYPE="other"
fi
echo "📺 检测到桌面环境：$ENV_TYPE"

# ========== 安装 fcitx5-rime ==========
echo "🧩 检查 fcitx5-rime ..."
if ! dpkg -l | grep -q fcitx5-rime; then
  echo "⬇️ 安装 fcitx5-rime ..."
  sudo apt update
  sudo apt install -y fcitx5 fcitx5-rime fcitx5-configtool
fi

# ========== 配置输入法环境 ==========
echo "⚙️ 检查输入法环境变量 ..."
ENV_FILE="/etc/environment"
NEED_UPDATE=false

grep -q "INPUT_METHOD" $ENV_FILE 2>/dev/null || NEED_UPDATE=true
grep -q "XMODIFIERS" $ENV_FILE 2>/dev/null || NEED_UPDATE=true
grep -q "GTK_IM_MODULE" $ENV_FILE 2>/dev/null || NEED_UPDATE=true
grep -q "QT_IM_MODULE" $ENV_FILE 2>/dev/null || NEED_UPDATE=true

if [ "$NEED_UPDATE" = true ]; then
  echo "🔧 配置 fcitx5 环境变量 ..."
  sudo bash -c "cat >> $ENV_FILE <<'EOF'

# >>> Rime & fcitx5 配置 <<<
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
export INPUT_METHOD=fcitx
EOF"
  echo "✅ 已写入 /etc/environment"
else
  echo "✅ fcitx5 环境变量已存在，跳过"
fi

# ========== 备份旧配置 ==========
echo "📦 备份旧配置到 $BACKUP_DIR ..."
mkdir -p "$BACKUP_DIR"
cp -a "$RIME_DIR" "$BACKUP_DIR" 2>/dev/null || true
mkdir -p "$RIME_DIR"

# ========== 写入新配置 ==========
echo "🧾 写入新的配置文件 ..."

# 1️⃣ default.custom.yaml
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
      states: [ 繁, 简 ]              # ✅ 默认简体
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

# 2️⃣ luna_pinyin.custom.yaml
cat > "$RIME_DIR/luna_pinyin.custom.yaml" <<'EOF'
patch:
  engine/filters:
    - uniquifier
    - simplifier@emoji_suggestion
    - simplifier

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

# 3️⃣ style.yaml （横排 + 美化 + 自动暗色）
cat > "$RIME_DIR/style.yaml" <<'EOF'
patch:
  style:
    candidate_list_layout: linear      # 横向候选
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

# ========== 安装 emoji 模块 ==========
if [ -f "$RIME_DIR/emoji_suggestion.yaml" ]; then
  echo "😊 检测到 emoji 已安装，跳过安装。"
else
  echo "⬇️ 安装 emoji 模块 ..."
  if ! command -v rime-install >/dev/null; then
    echo "⚙️  安装 rime-install 工具（依赖 git, curl）..."
    sudo apt install -y git curl
    curl -fsSL https://git.io/rime-install | bash
  fi
  bash rime-install emoji:customize:schema=luna_pinyin || echo "⚠️ emoji 模块安装可能失败，请手动重试。"
fi

# ========== 部署 Rime ==========
echo "🚀 部署 Rime ..."
rime_deployer --build "$RIME_DIR" || fcitx5-rime-deployer --build "$RIME_DIR" || true

echo "🔁 重启 fcitx5 ..."
nohup fcitx5 -r >/dev/null 2>&1 &

echo "✅ 安装完成！"
echo "📦 旧配置已备份到: $BACKUP_DIR"
echo "🈶 默认简体 ✅  横排候选 ✅  emoji ✅  标点/全角/中英切换 ✅"
echo "💡 如果你刚修改 /etc/environment，请重新登录或执行：source /etc/environment"
