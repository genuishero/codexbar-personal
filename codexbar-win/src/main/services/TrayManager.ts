import { Tray, Menu, nativeImage, app, BrowserWindow, MenuItem } from 'electron';
import * as path from 'path';
import { ConfigManager } from './ConfigManager';
import { WindowManager } from './WindowManager';

export class TrayManager {
  private tray: Tray;
  private configManager: ConfigManager;
  private windowManager: WindowManager;
  private contextMenu!: Menu;

  constructor(configManager: ConfigManager, windowManager: WindowManager) {
    this.configManager = configManager;
    this.windowManager = windowManager;

    // 创建托盘图标
    const iconPath = this.getIconPath();
    const icon = nativeImage.createFromPath(iconPath);
    this.tray = new Tray(icon.resize({ width: 16, height: 16 }));

    // 设置托盘提示
    this.tray.setToolTip('CodexBar');

    // 创建初始菜单
    this.updateTray();

    // 点击事件
    this.tray.on('click', () => {
      this.windowManager.showMainWindow();
    });

    this.tray.on('double-click', () => {
      this.windowManager.showMainWindow();
    });
  }

  private getIconPath(): string {
    const isDev = process.env.NODE_ENV === 'development';
    if (isDev) {
      return path.join(process.cwd(), 'resources', 'icon.png');
    }
    return path.join(process.resourcesPath, 'resources', 'icon.png');
  }

  updateTray(): void {
    this.contextMenu = this.buildMenu();
    this.tray.setContextMenu(this.contextMenu);
  }

  private buildMenu(): Menu {
    const accounts = this.configManager.accounts;
    const activeAccountId = this.configManager.config.activeAccountId;

    const menuItems: MenuItem[] = [];

    // 账号列表
    if (accounts.length > 0) {
      menuItems.push(new MenuItem({
        label: 'OpenAI 账号',
        enabled: false
      }));

      for (const account of accounts) {
        const isActive = account.accountId === activeAccountId;
        const usageText = this.getUsageText(account);
        const statusIcon = account.tokenExpired ? '⚠️' : (account.isSuspended ? '🚫' : '✓');

        menuItems.push(new MenuItem({
          label: `${isActive ? '● ' : '○ '}${account.email} ${statusIcon} ${usageText}`,
          click: () => {
            this.configManager.activateAccount(account.accountId);
            this.updateTray();
          }
        }));
      }

      menuItems.push(new MenuItem({ type: 'separator' }));
    }

    // 添加账号
    menuItems.push(new MenuItem({
      label: '添加账号',
      submenu: Menu.buildFromTemplate([
        {
          label: '从本地导入账号',
          click: () => this.windowManager.showLocalAccountPicker()
        },
        {
          label: '新 OAuth 登录',
          click: () => this.windowManager.showOAuthWindow()
        }
      ])
    }));

    // 导入导出 CSV
    menuItems.push(new MenuItem({
      label: 'CSV 导入/导出',
      submenu: Menu.buildFromTemplate([
        {
          label: '导出 CSV',
          click: () => this.windowManager.showExportDialog()
        },
        {
          label: '导入 CSV',
          click: () => this.windowManager.showImportDialog()
        }
      ])
    }));

    menuItems.push(new MenuItem({ type: 'separator' }));

    // 刷新用量
    menuItems.push(new MenuItem({
      label: '刷新用量',
      click: async () => {
        await this.configManager.refreshAllUsage();
        this.updateTray();
      }
    }));

    // 设置
    menuItems.push(new MenuItem({
      label: '设置',
      click: () => this.windowManager.showSettingsWindow()
    }));

    // 检查更新
    menuItems.push(new MenuItem({
      label: '检查更新',
      click: () => this.windowManager.showUpdateWindow()
    }));

    menuItems.push(new MenuItem({ type: 'separator' }));

    // 退出
    menuItems.push(new MenuItem({
      label: '退出',
      click: () => {
        app.quit();
      }
    }));

    return Menu.buildFromTemplate(menuItems);
  }

  private getUsageText(account: any): string {
    if (account.primaryUsedPercent !== undefined) {
      return `${Math.round(account.primaryUsedPercent)}%`;
    }
    return '';
  }

  destroy(): void {
    this.tray.destroy();
  }
}