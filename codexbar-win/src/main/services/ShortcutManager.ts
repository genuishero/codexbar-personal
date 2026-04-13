import { globalShortcut, app } from 'electron';
import { ConfigManager } from './ConfigManager';

export class ShortcutManager {
  private configManager: ConfigManager;
  private registered: boolean = false;

  constructor(configManager: ConfigManager) {
    this.configManager = configManager;
  }

  registerAll(): void {
    if (this.registered) return;

    // 注册 Cmd+Shift+1~5 快捷键 (Windows 上是 Ctrl+Shift)
    for (let i = 1; i <= 5; i++) {
      const shortcut = `CommandOrControl+Shift+${i}`;
      globalShortcut.register(shortcut, () => {
        this.handleShortcut(i);
      });
    }

    this.registered = true;
  }

  unregisterAll(): void {
    if (!this.registered) return;

    for (let i = 1; i <= 5; i++) {
      globalShortcut.unregister(`CommandOrControl+Shift+${i}`);
    }

    this.registered = false;
  }

  private handleShortcut(index: number): void {
    const accounts = this.configManager.accounts;
    if (accounts.length === 0) return;

    // 快捷键 1~5 对应账号 0~4
    const accountIndex = index - 1;
    if (accountIndex < accounts.length) {
      this.configManager.activateAccount(accounts[accountIndex].accountId);
    }
  }

  updateFromConfig(): void {
    if (this.configManager.config.settings.keyboardShortcuts) {
      this.registerAll();
    } else {
      this.unregisterAll();
    }
  }
}