# CodexBar Windows Version

基于 Electron + React + TypeScript 的 Windows 版本 CodexBar。

## 功能特性

- ✅ 多账号管理 (从 Mac 版迁移)
- ✅ 系统托盘集成
- ✅ 本地账号发现 (~/.codex 目录)
- ✅ CSV 导入导出
- ✅ 用量监控与预警
- ✅ 全局快捷键 (Ctrl+Shift+1~5)
- ✅ 自动更新检查
- ✅ 安全 Token 存储 (Windows Credential Manager)

## 技术栈

- **Electron 28** - 主进程框架
- **React 18** - 渲染器 UI
- **TypeScript 5** - 类型安全
- **keytar** - Windows Credential Manager 集成
- **electron-store** - 配置持久化
- **electron-vite** - 构建工具

## 开发指南

### 安装依赖

```bash
cd codexbar-win
npm install
```

### 开发模式

```bash
npm run dev
```

### 构建

```bash
npm run build
```

### 打包 Windows 安装程序

```bash
npm run dist
```

## 目录结构

```
codexbar-win/
├── src/
│   ├── main/           # Electron 主进程
│   │   ├── index.ts    # 入口文件
│   │   ├── preload.ts  # 预加载脚本
│   │   └── services/   # 服务模块
│   │       ├── ConfigManager.ts
│   │       ├── TrayManager.ts
│   │       ├── WindowManager.ts
│   │       ├── ShortcutManager.ts
│   │       ├── UpdateManager.ts
│   │       ├── QuotaWarningService.ts
│   │       └── LocalAccountDiscovery.ts
│   └── renderer/       # React 渲染器
│       ├── index.tsx   # 入口
│       ├── App.tsx     # 主组件
│       └── components/ # UI 组件
│           ├── MenuBarView.tsx
│           ├── SettingsView.tsx
│           ├── OAuthView.tsx
│           ├── QuickStartView.tsx
│           ├── LocalAccountPicker.tsx
│           └── UpdateView.tsx
├── resources/          # 资源文件
│   └── icon.png        # 托盘图标 (需转换为 .ico)
├── package.json
├── tsconfig.json
├── electron.vite.config.ts
└── electron-builder.yml
```

## 注意事项

1. **图标文件**: Windows 需要 `.ico` 格式图标,请将 `icon.png` 转换为 `icon.ico`
2. **Keytar**: 在某些 Windows 版本可能需要 Visual Studio Build Tools 来编译原生模块
3. **签名**: 发布版本建议进行代码签名,否则 Windows SmartScreen 会警告