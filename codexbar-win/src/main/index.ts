import { app, BrowserWindow, Tray, Menu, nativeImage, dialog, Notification, shell } from 'electron';
import * as path from 'path';
import * as fs from 'fs';
import { ConfigManager } from './services/ConfigManager';
import { TrayManager } from './services/TrayManager';
import { WindowManager } from './services/WindowManager';
import { ShortcutManager } from './services/ShortcutManager';
import { UpdateManager } from './services/UpdateManager';
import { QuotaWarningService } from './services/QuotaWarningService';
import { LocalAccountDiscovery } from './services/LocalAccountDiscovery';

let trayManager: TrayManager;
let windowManager: WindowManager;
let configManager: ConfigManager;
let shortcutManager: ShortcutManager;
let updateManager: UpdateManager;
let quotaWarningService: QuotaWarningService;

const isDev = process.env.NODE_ENV === 'development';

// 单实例锁
const gotTheLock = app.requestSingleInstanceLock();
if (!gotTheLock) {
  app.quit();
  process.exit(0);
}

app.on('second-instance', () => {
  windowManager?.showMainWindow();
});

app.whenReady().then(() => {
  main();
});

async function main() {
  // 初始化配置管理器
  configManager = new ConfigManager();
  await configManager.load();

  // 初始化窗口管理器
  windowManager = new WindowManager(configManager);

  // 初始化托盘管理器
  trayManager = new TrayManager(configManager, windowManager);

  // 初始化快捷键管理器
  shortcutManager = new ShortcutManager(configManager);
  if (configManager.config.settings.keyboardShortcuts) {
    shortcutManager.registerAll();
  }

  // 初始化更新管理器
  updateManager = new UpdateManager();
  updateManager.checkForUpdates(false);

  // 初始化用量预警服务
  quotaWarningService = new QuotaWarningService(configManager);
  if (configManager.config.settings.quotaWarning) {
    quotaWarningService.startMonitoring();
  }

  // 检查是否需要显示快速开始引导
  if (!configManager.config.quickStartCompleted) {
    windowManager.showQuickStartWindow();
  }
}

app.on('window-all-closed', () => {
  // Windows 上关闭所有窗口时不退出应用（托盘应用）
});

app.on('before-quit', () => {
  shortcutManager?.unregisterAll();
  quotaWarningService?.stopMonitoring();
  trayManager?.destroy();
});

// IPC 处理
import { ipcMain } from 'electron';

ipcMain.handle('get-config', () => {
  return configManager.config;
});

ipcMain.handle('save-config', async (event, config) => {
  await configManager.save(config);
  trayManager.updateTray();
});

ipcMain.handle('get-accounts', () => {
  return configManager.accounts;
});

ipcMain.handle('activate-account', async (event, accountId) => {
  await configManager.activateAccount(accountId);
  trayManager.updateTray();
});

ipcMain.handle('add-account-oauth', async () => {
  // 开始 OAuth 登录流程
  const result = await windowManager.showOAuthWindow();
  if (result) {
    await configManager.addAccount(result);
    trayManager.updateTray();
  }
});

ipcMain.handle('import-local-accounts', async () => {
  const accounts = LocalAccountDiscovery.discover();
  return accounts;
});

ipcMain.handle('import-selected-accounts', async (event, accounts) => {
  for (const account of accounts) {
    await configManager.addAccount(account);
  }
  trayManager.updateTray();
});

ipcMain.handle('export-csv', async (event, accounts) => {
  // 显示警告对话框
  const result = dialog.showMessageBoxSync({
    type: 'warning',
    title: '导出包含敏感信息',
    message: 'CSV 文件将包含 access_token、refresh_token 和 id_token。请妥善保管此文件，不要分享给他人。',
    buttons: ['继续导出', '取消']
  });

  if (result === 0) {
    const filePath = dialog.showSaveDialogSync({
      title: '导出 CSV',
      defaultPath: 'codexbar-accounts.csv',
      filters: [{ name: 'CSV', extensions: ['csv'] }]
    });

    if (filePath) {
      const csv = ConfigManager.generateCSV(accounts);
      fs.writeFileSync(filePath, csv, 'utf-8');
      return true;
    }
  }
  return false;
});

ipcMain.handle('import-csv', async () => {
  const filePath = dialog.showOpenDialogSync({
    title: '导入 CSV',
    filters: [{ name: 'CSV', extensions: ['csv'] }],
    properties: ['openFile']
  });

  if (filePath && filePath[0]) {
    const content = fs.readFileSync(filePath[0], 'utf-8');
    const accounts = ConfigManager.parseCSV(content);
    for (const account of accounts) {
      await configManager.addAccount(account);
    }
    trayManager.updateTray();
    return accounts.length;
  }
  return 0;
});

ipcMain.handle('check-updates', async () => {
  return await updateManager.checkForUpdates(true);
});

ipcMain.handle('open-settings', () => {
  windowManager.showSettingsWindow();
});

ipcMain.handle('open-external', (event, url) => {
  shell.openExternal(url);
});

ipcMain.handle('get-usage', async (event, accountId) => {
  return await configManager.fetchUsage(accountId);
});

ipcMain.handle('refresh-all-usage', async () => {
  await configManager.refreshAllUsage();
  trayManager.updateTray();
});