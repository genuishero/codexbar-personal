# 🦞 CodexBar - 个人定制安全增强版

**🌟 安全增强版** - 原项目维护：[@lizhelang](https://github.com/lizhelang/codexbar)  
**👤 个人定制版**：[@genuishero](https://github.com/genuishero)

> 本项目是 [lizhelang/codexbar](https://github.com/lizhelang/codexbar) 的个人定制 fork，增加了**安全增强功能**，专为日常使用优化。

[English](./README.en.md) | [中文](./README.md)

---

## ✅ 为什么选择这个版本？

| 功能 | 官方版 | 个人定制版 |
|------|--------|-----------|
| 多账号管理 | ✅ | ✅ |
| 多 Provider 切换 | ✅ | ✅ |
| 本地 Usage 统计 | ✅ | ✅ |
| **剪贴板自动清除** | ❌ | ✅ |
| **首次使用引导** | ❌ | ✅ |
| **安全状态指示器** | ❌ | ✅ |
| **自动 Token 刷新** | ❌ | ✅ |
| **用量预警通知** | ❌ | ✅ |
| **快捷键切换账号** | ❌ | ✅ |
| **完整中文翻译** | ❌ | ✅ |

---

## 🚀 核心安全增强功能

### 1️⃣ 剪贴板自动清除
复制敏感信息（API Key / Token）后 **30 秒自动清除剪贴板**，防止密码泄露。

```bash
# 示例：复制 API Key 后 30 秒自动清空
echo "sk-xxx" | pbcopy  # 30秒后 pbpaste 为空
```

### 2️⃣ 快速开始引导
首次启动时显示 **4 步引导流程**：
1. 📝 添加账号
2. 🔄 选择账号
3. ⌨️ 配置快捷键
4. ⚠️ 设置用量预警

### 3️⃣ 安全状态指示器
在设置页显示安全功能开启状态：
- 🔒 加密存储
- 🛡️ 剪贴板保护
- 🔄 自动 Token 刷新
- ⚠️ 用量预警
- ⌨️ 快捷键支持

### 4️⃣ 自动 Token 刷新
OAuth Token 过期前 **2 小时自动刷新**，保持账号始终可用。

### 5️⃣ 用量预警通知
当账号用量达到阈值时（默认 80%）触发系统通知：
```
⚠️ 用量预警  
当前用量已达 80%，建议关注额度使用情况
```

### 6️⃣ 快捷键支持
使用快捷键 **快速切换账号**：
- `Cmd + Shift + 1`：切换到第 1 个账号
- `Cmd + Shift + 2`：切换到第 2 个账号
- ...
- `Cmd + Shift + 5`：切换到第 5 个账号

---

## 📦 安装指南

### 方法 1：从 GitHub Release 下载（推荐）

1. 访问 [Releases](https://github.com/genuishero/codexbar-personal/releases)
2. 下载 `codexbar-v2.0.0.dmg`
3. 双击挂载 DMG
4. 将 `codexbar.app` 拖到 Applications 文件夹
5. 启动应用

### 方法 2：本地构建

```bash
# 克隆你的私有仓库
git clone https://github.com/genuishero/codexbar-personal.git
cd codexbar-personal

# 用 Xcode 构建
open codexbar.xcodeproj
# 选择 Xcode → Product → Build
```

---

## 🎮 使用说明

### 首次启动流程

1. **运行应用** → 自动弹出快速开始引导
2. **步骤 1**：点击菜单栏 `+` 按钮添加账号
3. **步骤 2**：选择你常用的 OpenAI 账号
4. **步骤 3**：配置快捷键（可选）
5. **步骤 4**：设置用量预警阈值（默认 80%）

### 添加账号

#### OpenAI OAuth 方式
1. 点击菜单栏 `+` 按钮
2. 选择 `Add OpenAI Account`
3. 在浏览器中完成授权
4. 自动跳转回调或手动粘贴 URL

#### CSV 导入
1. 准备 `accounts.csv` 文件：
   ```csv
   email,account_id,openai_account_id,access_token,refresh_token,id_token,expires_at,plan_type,primary_used_percent,secondary_used_percent,is_active
   test@example.com,act_abc,org_xyz,sk_token,refresh_tok,id_tok,2026-12-31T00:00:00Z,plus,10,5,true
   ```
2. 菜单栏 → `Import CSV` → 选择文件
3. 自动验证并导入账号

### 快捷键使用

在 **设置页 → Security** 中启用快捷键后：

| 快捷键 | 功能 |
|--------|------|
| `Cmd + Shift + 1` | 切换到第 1 个账号 |
| `Cmd + Shift + 2` | 切换到第 2 个账号 |
| `Cmd + Shift + 3` | 切换到第 3 个账号 |
| `Cmd + Shift + 4` | 切换到第 4 个账号 |
| `Cmd + Shift + 5` | 切换到第 5 个账号 |

### 用量预警配置

1. 打开 **设置页**
2. 切换到 **Security** 标签
3. 找到 `用量预警` 开关
4. 调整 `Quota Warning Threshold`（默认 80%）

当任一账号用量达到阈值时，会显示系统通知：
```
⚠️ 用量预警
目前用量已达 80%
账号: test@example.com
套餐: Plus
```

### 安全状态查看

在 **设置页 → Security** 页显示所有安全功能状态：
- 🔒 **加密存储**：账号凭据加密保存
- 🛡️ **剪贴板保护**：自动清除敏感信息
- 🔄 **自动 Token 刷新**：过期前自动更新
- ⚠️ **用量预警**：达到阈值时通知
- ⌨️ **快捷键支持**：快速切换账号

---

## 🏗️ 功能设计

### 多账号管理架构

```
CodexBar (菜单栏)
├── OpenAI Accounts (多个)
│   ├── Account 1: email1@domain.com (Plus)
│   ├── Account 2: email2@domain.com (Team)
│   └── Account 3: email3@domain.com (Free)
├── Custom Providers (多个)
│   └── Provider A
│       ├── Account A1: API Key 1
│       └── Account A2: API Key 2
└── Active Account (当前激活)
    └── 同步到 ~/.codex/auth.json
```

### 核心机制

| 功能 | 实现方式 |
|------|---------|
| 账号同步 | 更新 `~/.codex/config.toml` + `~/.codex/auth.json` |
| 会话池共享 | 共用 `~/.codex/sessions` 和 `~/.codex/archived_sessions` |
| 用量统计 | 扫描本地 session 文件分析 token usage |
| Token 刷新 | 后台 Timer 每小时检查，过期前 2 小时刷新 |
| 剪贴板保护 | 复制后启动 30 秒 Timer 自动清除 |
| 快捷键 | 监听 `Cmd + Shift + [1-5]` 系统事件 |

### 安全设计原则

1. **最小权限原则**
   - 只读取 `~/.codex` 目录
   - 不上传任何本地数据
   - 本地加密存储敏感信息

2. **剪贴板保护**
   - 复制敏感信息后 30 秒自动清除
   - 支持手动提前清除
   - 不记录任何剪贴板历史

3. **Token 刷新**
   - OAuth Token 过期前 2 小时自动刷新
   - 使用 Refresh Token 交换新 Token
   - 失败时弹窗提示重新授权

4. **用量预警**
   - 可配置阈值（默认 80%）
   - 每分钟检查一次
   - 系统通知提醒

---

## 🔄 同步官方更新

当官方仓库有重要更新时，你可以同步到你的定制版：

```bash
cd ~/Documents/GithubProject/codexbar-personal

# 抓取官方最新代码
git fetch upstream

# 合并到本地 main
git checkout main
git merge upstream/main

# 解决冲突（如有）
# ...

# 推送到你的 GitHub
git push origin main

# 重新编译发布
# gh release create v2.1.0 ~/Downloads/codexbar-v2.1.0.dmg
```

远程仓库配置：
- `origin` → `https://github.com/genuishero/codexbar-personal.git`
- `upstream` → `https://github.com/lizhelang/codexbar.git`

---

## 🐛 故障排除

### Q: 应用启动后没有显示账号
A: 检查 `~/.codex/` 目录是否存在，或者通过菜单栏 `+` 添加账号

### Q: 快捷键不生效
A: 在 **设置页 → Security** 启用快捷键功能

### Q: Token 刷新失败
A: 检查 Token 是否过期，可能需要手动重新授权

### Q: 用量预警不通知
A: 检查系统设置 → 通知 → codexbar 是否启用通知权限

### Q: 剪贴板清除不工作
A: macOS 可能限制自动清除，检查系统设置 → 隐私与安全性 → 辅助功能

---

## 📋 技术栈

| 类别 | 技术 |
|------|------|
| 语言 | Swift / SwiftUI |
| 架构 | Menu Bar Extra + Settings Window |
| 状态管理 | @Published ObservableObject |
| 数据持久化 | UserDefaults + UserStorage |
| 网络 | URLSession + Async/Await |
| 更新机制 | JSON Feed + Manual Check |

---

## 📄 license

本项目使用 **MIT License**，与原项目一致。

详细说明见：[LICENSE](LICENSE)

---

## 🙏 致谢

本项目基于以下开源项目：

- [lizhelang/codexbar](https://github.com/lizhelang/codexbar) - 原作者维护版本
- [xmasdong/codexbar](https://github.com/xmasdong/codexbar) - 参考项目
- [steipete/CodexBar](https://github.com/steipete/CodexBar) - 参考项目

---

## 📞 支持

- **项目地址**：https://github.com/genuishero/codexbar-personal
- **Release 下载**：https://github.com/genuishero/codexbar-personal/releases
- **问题反馈**：创建 GitHub Issue

---

## 📝 更新日志

### v2.0.0 (2026-04-13) 🎉
**初始安全增强版发布**

- ✅ 剪贴板自动清除功能（30秒）
- ✅ 首次使用快速开始引导
- ✅ 安全状态指示器 UI
- ✅ 自动 Token 刷新服务
- ✅ 用量预警通知系统
- ✅ 快捷键切换账号（Cmd+Shift+1-5）
- ✅ 完整中文翻译支持
- ✅ GitHub Releases 自动化流程

---

*最后更新: 2026-04-13*
