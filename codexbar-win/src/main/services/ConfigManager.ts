import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import Store from 'electron-store';
import keytar from 'keytar';
import axios from 'axios';

const SERVICE_NAME = 'codexbar';
const ACCOUNT_PREFIX = 'account-';

interface CodexBarAccount {
  id: string;
  email: string;
  accountId: string;
  accessToken?: string;
  refreshToken?: string;
  idToken?: string;
  planType: string;
  primaryUsedPercent?: number;
  secondaryUsedPercent?: number;
  primaryResetAt?: string;
  secondaryResetAt?: string;
  isActive: boolean;
  isSuspended: boolean;
  tokenExpired: boolean;
  addedAt: string;
}

interface CodexBarConfig {
  version: number;
  accounts: CodexBarAccount[];
  activeAccountId: string | null;
  settings: {
    quotaWarning: boolean;
    quotaWarningThreshold: number;
    keyboardShortcuts: boolean;
    clipboardProtection: boolean;
    language: 'zh' | 'en' | 'auto';
  };
  quickStartCompleted: boolean;
}

interface CodexPaths {
  codexRoot: string;
  codexBarRoot: string;
  configPath: string;
  authPath: string;
  tokenPoolPath: string;
  configTomlPath: string;
}

export class ConfigManager {
  private store: Store;
  public config: CodexBarConfig;
  public accounts: CodexBarAccount[];
  private paths: CodexPaths;

  constructor() {
    this.store = new Store({ name: 'config' });
    this.paths = this.getCodexPaths();

    // 默认配置
    this.config = {
      version: 1,
      accounts: [],
      activeAccountId: null,
      settings: {
        quotaWarning: true,
        quotaWarningThreshold: 80,
        keyboardShortcuts: true,
        clipboardProtection: true,
        language: 'auto'
      },
      quickStartCompleted: false
    };
    this.accounts = [];
  }

  private getCodexPaths(): CodexPaths {
    const home = os.homedir();
    const codexRoot = path.join(home, '.codex');
    const codexBarRoot = path.join(home, '.codexbar');

    return {
      codexRoot,
      codexBarRoot,
      configPath: path.join(codexBarRoot, 'config.json'),
      authPath: path.join(codexRoot, 'auth.json'),
      tokenPoolPath: path.join(codexRoot, 'token_pool.json'),
      configTomlPath: path.join(codexRoot, 'config.toml')
    };
  }

  async load(): Promise<void> {
    // 确保目录存在
    this.ensureDirectories();

    // 从 electron-store 加载配置
    const storedConfig = this.store.get('config') as CodexBarConfig | undefined;
    if (storedConfig) {
      this.config = storedConfig;
    }

    // 加载账号（从 Keychain 恢复 Token）
    this.accounts = this.config.accounts;
    for (const account of this.accounts) {
      await this.loadAccountTokens(account);
    }

    // 尝试从 Codex 目录迁移已有账号
    await this.migrateFromCodex();
  }

  async save(config?: CodexBarConfig): Promise<void> {
    if (config) {
      this.config = config;
    }

    // 保存 Token 到 Keychain
    for (const account of this.config.accounts) {
      await this.saveAccountTokens(account);
    }

    // 保存不含敏感信息的配置到文件
    const sanitizedConfig = {
      ...this.config,
      accounts: this.config.accounts.map(acc => ({
        ...acc,
        accessToken: undefined,
        refreshToken: undefined,
        idToken: undefined
      }))
    };

    this.store.set('config', sanitizedConfig);
    this.accounts = this.config.accounts;
  }

  private ensureDirectories(): void {
    if (!fs.existsSync(this.paths.codexRoot)) {
      fs.mkdirSync(this.paths.codexRoot, { recursive: true, mode: 0o700 });
    }
    if (!fs.existsSync(this.paths.codexBarRoot)) {
      fs.mkdirSync(this.paths.codexBarRoot, { recursive: true, mode: 0o700 });
    }
  }

  private async saveAccountTokens(account: CodexBarAccount): Promise<void> {
    const key = `${ACCOUNT_PREFIX}${account.id}`;
    if (account.accessToken) {
      await keytar.setPassword(SERVICE_NAME, `${key}.access`, account.accessToken);
    }
    if (account.refreshToken) {
      await keytar.setPassword(SERVICE_NAME, `${key}.refresh`, account.refreshToken);
    }
    if (account.idToken) {
      await keytar.setPassword(SERVICE_NAME, `${key}.id`, account.idToken);
    }
  }

  private async loadAccountTokens(account: CodexBarAccount): Promise<void> {
    const key = `${ACCOUNT_PREFIX}${account.id}`;
    account.accessToken = await keytar.getPassword(SERVICE_NAME, `${key}.access`) || undefined;
    account.refreshToken = await keytar.getPassword(SERVICE_NAME, `${key}.refresh`) || undefined;
    account.idToken = await keytar.getPassword(SERVICE_NAME, `${key}.id`) || undefined;
  }

  async migrateFromCodex(): Promise<void> {
    // 从 auth.json 迁移
    if (fs.existsSync(this.paths.authPath)) {
      try {
        const authData = JSON.parse(fs.readFileSync(this.paths.authPath, 'utf-8'));
        if (authData.tokens) {
          const account = this.parseAuthTokens(authData.tokens);
          if (account && !this.accounts.find(a => a.accountId === account.accountId)) {
            await this.addAccount(account);
          }
        }
      } catch (e) {
        // 忽略解析错误
      }
    }

    // 从 token_pool.json 迁移
    if (fs.existsSync(this.paths.tokenPoolPath)) {
      try {
        const poolData = JSON.parse(fs.readFileSync(this.paths.tokenPoolPath, 'utf-8'));
        if (poolData.accounts) {
          for (const acc of poolData.accounts) {
            if (!this.accounts.find(a => a.accountId === acc.account_id)) {
              const account: CodexBarAccount = {
                id: acc.account_id,
                email: acc.email,
                accountId: acc.account_id,
                accessToken: acc.access_token,
                refreshToken: acc.refresh_token,
                idToken: acc.id_token,
                planType: acc.plan_type || 'free',
                primaryUsedPercent: acc.primary_used_percent,
                secondaryUsedPercent: acc.secondary_used_percent,
                primaryResetAt: acc.primary_reset_at,
                secondaryResetAt: acc.secondary_reset_at,
                isActive: acc.is_active,
                isSuspended: acc.is_suspended,
                tokenExpired: acc.token_expired,
                addedAt: new Date().toISOString()
              };
              await this.addAccount(account);
            }
          }
        }
      } catch (e) {
        // 忽略解析错误
      }
    }
  }

  private parseAuthTokens(tokens: any): CodexBarAccount | null {
    if (!tokens.access_token || !tokens.refresh_token || !tokens.id_token) {
      return null;
    }

    // 解析 JWT 获取账号信息
    const idTokenPayload = this.parseJWT(tokens.id_token);
    const email = idTokenPayload?.email || '';
    const accountId = tokens.account_id || idTokenPayload?.sub || '';

    return {
      id: accountId,
      email,
      accountId,
      accessToken: tokens.access_token,
      refreshToken: tokens.refresh_token,
      idToken: tokens.id_token,
      planType: 'free',
      isActive: false,
      isSuspended: false,
      tokenExpired: false,
      addedAt: new Date().toISOString()
    };
  }

  private parseJWT(token: string): any | null {
    try {
      const payload = token.split('.')[1];
      return JSON.parse(Buffer.from(payload, 'base64').toString('utf-8'));
    } catch {
      return null;
    }
  }

  async addAccount(account: CodexBarAccount): Promise<void> {
    // 检查是否已存在
    const existing = this.accounts.find(a => a.accountId === account.accountId);
    if (existing) {
      // 更新现有账号
      Object.assign(existing, account);
    } else {
      // 添加新账号
      this.accounts.push(account);
      this.config.accounts.push(account);
    }
    await this.save();
  }

  async activateAccount(accountId: string): Promise<void> {
    const account = this.accounts.find(a => a.accountId === accountId);
    if (!account) return;

    // 设置为活跃账号
    this.accounts.forEach(a => a.isActive = false);
    account.isActive = true;
    this.config.activeAccountId = accountId;

    // 同步到 Codex 配置
    await this.syncToCodex(account);
    await this.save();
  }

  private async syncToCodex(account: CodexBarAccount): Promise<void> {
    if (!account.accessToken) return;

    // 更新 auth.json
    const authData = {
      tokens: {
        access_token: account.accessToken,
        refresh_token: account.refreshToken,
        id_token: account.idToken,
        account_id: account.accountId
      }
    };
    fs.writeFileSync(this.paths.authPath, JSON.stringify(authData, null, 2), 'utf-8');

    // 更新 config.toml (简化版本)
    const configToml = `
model = "gpt-5.4"
[model_providers.OpenAI]
base_url = "https://api.openai.com/v1"
`;
    fs.writeFileSync(this.paths.configTomlPath, configToml, 'utf-8');
  }

  async fetchUsage(accountId: string): Promise<any> {
    const account = this.accounts.find(a => a.accountId === accountId);
    if (!account?.accessToken) return null;

    try {
      const response = await axios.get('https://api.openai.com/v1/engines/gpt-4', {
        headers: {
          Authorization: `Bearer ${account.accessToken}`
        }
      });

      // 更新用量信息
      account.primaryUsedPercent = response.data?.usage?.percent || 0;
      await this.save();

      return response.data;
    } catch (e) {
      account.tokenExpired = true;
      await this.save();
      return null;
    }
  }

  async refreshAllUsage(): Promise<void> {
    for (const account of this.accounts) {
      if (account.accessToken && !account.tokenExpired) {
        await this.fetchUsage(account.accountId);
      }
    }
  }

  static generateCSV(accounts: CodexBarAccount[]): string {
    const header = 'format_version,email,account_id,access_token,refresh_token,id_token,is_active';
    const rows = accounts.map(acc => [
      'v1',
      acc.email,
      acc.accountId,
      acc.accessToken || '',
      acc.refreshToken || '',
      acc.idToken || '',
      acc.isActive ? 'true' : 'false'
    ].map(field => `"${field.replace(/"/g, '""')}"`).join(','));

    return `${header}\n${rows.join('\n')}\n`;
  }

  static parseCSV(content: string): CodexBarAccount[] {
    const lines = content.trim().split('\n');
    if (lines.length < 2) return [];

    const accounts: CodexBarAccount[] = [];
    for (let i = 1; i < lines.length; i++) {
      const fields = lines[i].match(/("([^"]|"")*"|[^,]*)/g) || [];
      const cleanFields = fields.map(f => f.replace(/^"|"$/g, '').replace(/""/g, '"'));

      accounts.push({
        id: cleanFields[2] || '',
        email: cleanFields[1] || '',
        accountId: cleanFields[2] || '',
        accessToken: cleanFields[3] || undefined,
        refreshToken: cleanFields[4] || undefined,
        idToken: cleanFields[5] || undefined,
        planType: 'free',
        isActive: cleanFields[6] === 'true',
        isSuspended: false,
        tokenExpired: false,
        addedAt: new Date().toISOString()
      });
    }
    return accounts;
  }

  deleteAccount(accountId: string): void {
    this.accounts = this.accounts.filter(a => a.accountId !== accountId);
    this.config.accounts = this.config.accounts.filter(a => a.accountId !== accountId);

    if (this.config.activeAccountId === accountId) {
      this.config.activeAccountId = this.accounts[0]?.accountId || null;
    }

    // 删除 Keychain 中的 Token
    const key = `${ACCOUNT_PREFIX}${accountId}`;
    keytar.deletePassword(SERVICE_NAME, `${key}.access`);
    keytar.deletePassword(SERVICE_NAME, `${key}.refresh`);
    keytar.deletePassword(SERVICE_NAME, `${key}.id`);

    this.save();
  }
}