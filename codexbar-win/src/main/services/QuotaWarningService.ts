import { Notification } from 'electron';
import { ConfigManager } from './ConfigManager';

export class QuotaWarningService {
  private configManager: ConfigManager;
  private intervalId: NodeJS.Timeout | null = null;
  private checkInterval: number = 60 * 60 * 1000; // 1 小时

  constructor(configManager: ConfigManager) {
    this.configManager = configManager;
  }

  startMonitoring(): void {
    if (this.intervalId) return;

    // 立即检查一次
    this.checkQuotas();

    // 定时检查
    this.intervalId = setInterval(() => {
      this.checkQuotas();
    }, this.checkInterval);
  }

  stopMonitoring(): void {
    if (this.intervalId) {
      clearInterval(this.intervalId);
      this.intervalId = null;
    }
  }

  private async checkQuotas(): void {
    const threshold = this.configManager.config.settings.quotaWarningThreshold;

    for (const account of this.configManager.accounts) {
      // 刷新用量
      await this.configManager.fetchUsage(account.accountId);

      // 检查是否超过阈值
      const percent = account.primaryUsedPercent || 0;
      if (percent >= threshold && account.isActive) {
        this.showWarning(account.email, percent);
      }
    }
  }

  private showWarning(email: string, percent: number): void {
    new Notification({
      title: '用量预警',
      body: `${email} 的用量已达到 ${Math.round(percent)}%，请注意控制使用`,
      silent: false
    }).show();
  }

  updateFromConfig(): void {
    if (this.configManager.config.settings.quotaWarning) {
      this.startMonitoring();
    } else {
      this.stopMonitoring();
    }
  }
}