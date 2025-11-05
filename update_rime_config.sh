#!/bin/bash
set -e

RIME_DIR="$HOME/Library/Rime"
BACKUP_DIR="$HOME/Library/Rime_backup_$(date +%Y%m%d_%H%M%S)"

echo "🧩 检查 Rime 目录..."
if [ ! -d "$RIME_DIR" ]; then
  echo "❌ 未找到 Rime 目录: $RIME_DIR"
  exit 1
fi

echo "📦 备份旧配置到 $BACKUP_DIR ..."
mkdir -p "$BACKUP_DIR"
cp -a "$RIME_DIR"/* "$BACKUP_DIR"/ 2>/dev/null || true

echo "🧾 写入新的配置文件..."

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
    # - reverse_lookup_filter

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

# 3️⃣ squirrel.custom.yaml
cat > "$RIME_DIR/squirrel.custom.yaml" <<'EOF'
patch:
  style:
    candidate_list_layout: linear
    inline_preedit: true
    font_point: 16
    candidate_spacing: 16
    corner_radius: 12
    border_width: 1
    shadow_size: 12
    shadow_color: 0x33000000
    color_scheme: mac_light
    color_scheme_dark: mac_dark

  preset_color_schemes:
    mac_light:
      name: "macOS Light"
      author: "ray x Rime"
      back_color: 0xFFFFFF
      border_color: 0xD0D0D0
      candidate_text_color: 0x111111
      label_color: 0x999999
      comment_text_color: 0x888888
      hilited_candidate_back_color: 0xE6F0FF
      hilited_candidate_text_color: 0x000000
      hilited_comment_text_color: 0x666666
      hilited_label_color: 0x007AFF

    mac_dark:
      name: "macOS Dark"
      author: "ray x Rime"
      back_color: 0x1E1E1E
      border_color: 0x3A3A3A
      candidate_text_color: 0xEDEDED
      label_color: 0x9A9A9A
      comment_text_color: 0xA0A0A0
      hilited_candidate_back_color: 0x2A3B52
      hilited_candidate_text_color: 0xFFFFFF
      hilited_comment_text_color: 0xC8C8C8
      hilited_label_color: 0x5AA9FF
EOF

# 🧠 检查是否已有 emoji_suggestion.yaml
if [ -f "$RIME_DIR/emoji_suggestion.yaml" ]; then
  echo "😊 检测到 emoji 已安装，跳过安装。"
else
  echo "⬇️ 未检测到 emoji，自动执行安装..."
  bash rime-install emoji:customize:schema=luna_pinyin || echo "⚠️ emoji 安装命令未执行成功，请确认 rime-install 可用。"
fi

echo "🚀 重新部署 Rime ..."
/Library/Input\ Methods/Squirrel.app/Contents/MacOS/rime_deployer --build "$RIME_DIR"

echo "🔁 重启鼠须管 ..."
killall "Squirrel" 2>/dev/null || true
open -a "Squirrel"

echo "✅ 全部完成！"
echo "📦 已备份旧配置至: $BACKUP_DIR"
echo "🈶 默认简体 ✅  横向候选 ✅  emoji ✅  标点切换 ✅"
