# RimeConfig

Rime 输入法配置项目，提供跨平台的自动安装和配置脚本。

## 📋 项目简介

本项目包含 Rime 输入法的自动化配置脚本，支持：
- 🐧 Ubuntu/Linux 系统（使用 fcitx5-rime）
- 🍎 macOS 系统（使用鼠须管 Squirrel）

## ✨ 功能特性

- ✅ 默认简体中文输入
- ✅ 横向候选词显示
- ✅ Emoji 表情支持
- ✅ 快捷键切换（繁简、中英、标点、全角等）
- ✅ 自动适配明暗主题
- ✅ 自动备份旧配置

## 📁 文件说明

- `setup_rime_ubuntu.sh` - Ubuntu/Linux 系统完整安装和配置脚本
  - 自动安装 fcitx5-rime
  - 配置环境变量
  - 生成 Rime 配置文件
  - 安装 emoji 模块

- `update_rime_config.sh` - macOS 系统配置更新脚本
  - 备份现有配置
  - 更新 Rime 配置文件
  - 重新部署配置

## 🚀 使用方法

### Ubuntu/Linux 系统

```bash
chmod +x setup_rime_ubuntu.sh
./setup_rime_ubuntu.sh
```

脚本会自动：
1. 检查并安装 fcitx5-rime
2. 配置系统环境变量
3. 备份旧配置
4. 生成新的配置文件
5. 安装 emoji 模块
6. 部署并重启输入法

**注意**：如果修改了 `/etc/environment`，需要重新登录或执行：
```bash
source /etc/environment
```

### macOS 系统

```bash
chmod +x update_rime_config.sh
./update_rime_config.sh
```

脚本会自动：
1. 备份现有配置
2. 更新配置文件
3. 重新部署 Rime
4. 重启鼠须管

## ⌨️ 快捷键说明

- `Ctrl+Shift+F` - 繁简切换
- `Ctrl+Shift+J` - 全角/半角切换
- `Ctrl+Shift+Space` - 中英文切换
- `Ctrl+Shift+.` - 中英文标点切换
- `Shift+Space` - 输入空格（在输入过程中）

## 🎨 主题配置

- **Linux**: Solarized Light/Dark 主题，自动适配系统主题
- **macOS**: macOS Light/Dark 主题，自动适配系统主题

## 📝 配置文件说明

### default.custom.yaml
- 输入法方案列表
- 菜单分页大小
- 全局开关设置
- 快捷键绑定

### luna_pinyin.custom.yaml
- 输入引擎过滤器
- Emoji 建议配置
- 输入法开关
- 标点符号配置

### style.yaml / squirrel.custom.yaml
- 候选词布局（横向）
- 字体大小和间距
- 圆角和阴影
- 颜色主题配置

## 🔧 手动配置

如果需要手动调整配置，配置文件位置：
- **Linux**: `~/.local/share/fcitx5/rime/`
- **macOS**: `~/Library/Rime/`

## 📦 备份说明

所有脚本都会自动备份旧配置：
- **Linux**: `~/rime_backup_YYYYMMDD_HHMMSS/`
- **macOS**: `~/Library/Rime_backup_YYYYMMDD_HHMMSS/`

## ⚠️ 注意事项

1. 运行脚本前建议先备份重要数据
2. macOS 脚本需要确保已安装 Rime 输入法
3. Linux 脚本需要 sudo 权限来修改系统环境变量
4. 首次运行后可能需要重新登录系统才能完全生效

## 📄 许可证

本项目采用 MIT 许可证。

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

