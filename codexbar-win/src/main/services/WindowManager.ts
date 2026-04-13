import { BrowserWindow, app, screen, dialog, ipcMain } from 'electron';
import * as path from 'path';
import * as fs from 'fs';
import { ConfigManager } from './ConfigManager';

export class WindowManager {
  private mainWindow: BrowserWindow | null = null;
  private settingsWindow: BrowserWindow | null = null;
  private oauthWindow: BrowserWindow | null = null;
  private quickStartWindow: BrowserWindow | null = null;
  private configManager: ConfigManager;

  constructor(configManager: ConfigManager) {
    this.configManager = configManager;
  }

  private getPreloadPath(): string {
    const isDev = process.env.NODE_ENV === 'development';
    if (isDev) {
      return path.join(process.cwd(), 'dist', 'preload.js');
    }
    return path.join(process.resourcesPath, 'dist', 'preload.js');
  }

  private getRendererPath(): string {
    const isDev = process.env.NODE_ENV === 'development';
    if (isDev) {
      return 'http://localhost:5173';
    }
    return path.join(process.resourcesPath, 'dist', 'renderer', 'index.html');
  }

  showMainWindow(): BrowserWindow {
    if (this.mainWindow) {
      this.mainWindow.show();
      return this.mainWindow;
    }

    const { width, height } = screen.getPrimaryDisplay().workAreaSize;
    const windowWidth = 400;
    const windowHeight = Math.min(600, height - 100);

    this.mainWindow = new BrowserWindow({
      width: windowWidth,
      height: windowHeight,
      x: width - windowWidth - 20,
      y: 50,
      frame: false,
      resizable: false,
      show: false,
      webPreferences: {
        preload: this.getPreloadPath(),
        contextIsolation: true,
        nodeIntegration: false
      }
    });

    this.mainWindow.loadURL(this.getRendererPath() + '#main');

    this.mainWindow.once('ready-to-show', () => {
      this.mainWindow?.show();
    });

    this.mainWindow.on('blur', () => {
      // 失焦时隐藏窗口（类似 macOS 菜单栏行为）
      this.mainWindow?.hide();
    });

    return this.mainWindow;
  }

  showSettingsWindow(): BrowserWindow {
    if (this.settingsWindow) {
      this.settingsWindow.show();
      return this.settingsWindow;
    }

    this.settingsWindow = new BrowserWindow({
      width: 820,
      height: 620,
      resizable: true,
      minimizable: true,
      maximizable: false,
      webPreferences: {
        preload: this.getPreloadPath(),
        contextIsolation: true,
        nodeIntegration: false
      }
    });

    this.settingsWindow.loadURL(this.getRendererPath() + '#settings');

    this.settingsWindow.on('closed', () => {
      this.settingsWindow = null;
    });

    return this.settingsWindow;
  }

  async showOAuthWindow(): Promise<any | null> {
    if (this.oauthWindow) {
      this.oauthWindow.show();
      return null;
    }

    // 创建 OAuth 登录窗口
    this.oauthWindow = new BrowserWindow({
      width: 560,
      height: 420,
      resizable: false,
      webPreferences: {
        preload: this.getPreloadPath(),
        contextIsolation: true,
        nodeIntegration: false
      }
    });

    this.oauthWindow.loadURL(this.getRendererPath() + '#oauth');

    // 等待 OAuth 完成
    return new Promise((resolve) => {
      ipcMain.once('oauth-complete', (event, result) => {
        this.oauthWindow?.close();
        this.oauthWindow = null;
        resolve(result);
      });

      ipcMain.once('oauth-cancel', () => {
        this.oauthWindow?.close();
        this.oauthWindow = null;
        resolve(null);
      });
    });
  }

  showQuickStartWindow(): BrowserWindow {
    if (this.quickStartWindow) {
      this.quickStartWindow.show();
      return this.quickStartWindow;
    }

    this.quickStartWindow = new BrowserWindow({
      width: 520,
      height: 420,
      resizable: false,
      minimizable: false,
      webPreferences: {
        preload: this.getPreloadPath(),
        contextIsolation: true,
        nodeIntegration: false
      }
    });

    this.quickStartWindow.loadURL(this.getRendererPath() + '#quickstart');

    this.quickStartWindow.on('closed', () => {
      this.quickStartWindow = null;
    });

    return this.quickStartWindow;
  }

  showLocalAccountPicker(): void {
    const accounts = this.discoverLocalAccounts();

    if (accounts.length === 0) {
      dialog.showMessageBox({
        type: 'info',
        title: '未找到本地账号',
        message: '未在 ~/.codex 目录中发现已登录的账号'
      });
      return;
    }

    // 创建选择窗口
    const pickerWindow = new BrowserWindow({
      width: 400,
      height: 300,
      resizable: false,
      webPreferences: {
        preload: this.getPreloadPath(),
        contextIsolation: true,
        nodeIntegration: false
      }
    });

    pickerWindow.loadURL(this.getRendererPath() + '#local-picker');

    ipcMain.handleOnce('get-local-accounts', () => accounts);
  }

  private discoverLocalAccounts(): any[] {
    const home = process.env.USERPROFILE || process.env.HOME || '';
    const codexRoot = path.join(home, '.codex');
    const accounts: any[] = [];

    // 从 auth.json 发现
    const authPath = path.join(codexRoot, 'auth.json');
    if (fs.existsSync(authPath)) {
      try {
        const auth = JSON.parse(fs.readFileSync(authPath, 'utf-8'));
        if (auth.tokens) {
          accounts.push({
            email: auth.tokens.email || '',
            accountId: auth.tokens.account_id || '',
            accessToken: auth.tokens.access_token,
            refreshToken: auth.tokens.refresh_token,
            idToken: auth.tokens.id_token,
            source: 'auth.json'
          });
        }
      } catch {}
    }

    // 从 token_pool.json 发现
    const poolPath = path.join(codexRoot, 'token_pool.json');
    if (fs.existsSync(poolPath)) {
      try {
        const pool = JSON.parse(fs.readFileSync(poolPath, 'utf-8'));
        for (const acc of pool.accounts || []) {
          if (!accounts.find(a => a.accountId === acc.account_id)) {
            accounts.push({
              email: acc.email || '',
              accountId: acc.account_id,
              accessToken: acc.access_token,
              refreshToken: acc.refresh_token,
              idToken: acc.id_token,
              source: 'token_pool.json'
            });
          }
        }
      } catch {}
    }

    return accounts;
  }

  showExportDialog(): void {
    // 通过 IPC 触发导出
    if (this.mainWindow) {
      this.mainWindow.webContents.send('show-export');
    }
  }

  showImportDialog(): void {
    // 通过 IPC 触发导入
    if (this.mainWindow) {
      this.mainWindow.webContents.send('show-import');
    }
  }

  showUpdateWindow(): BrowserWindow {
    const updateWindow = new BrowserWindow({
      width: 400,
      height: 300,
      resizable: false,
      webPreferences: {
        preload: this.getPreloadPath(),
        contextIsolation: true,
        nodeIntegration: false
      }
    });

    updateWindow.loadURL(this.getRendererPath() + '#update');
    return updateWindow;
  }

  closeAll(): void {
    this.mainWindow?.close();
    this.settingsWindow?.close();
    this.oauthWindow?.close();
    this.quickStartWindow?.close();
  }
}