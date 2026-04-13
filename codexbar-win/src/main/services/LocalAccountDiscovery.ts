import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';

interface DiscoveredAccount {
  email: string;
  accountId: string;
  accessToken: string;
  refreshToken: string;
  idToken: string;
  source: string;
}

export class LocalAccountDiscovery {
  static discover(): DiscoveredAccount[] {
    const home = os.homedir();
    const codexRoot = path.join(home, '.codex');
    const accounts: DiscoveredAccount[] = [];

    // 从 auth.json 发现
    const authPath = path.join(codexRoot, 'auth.json');
    if (fs.existsSync(authPath)) {
      try {
        const auth = JSON.parse(fs.readFileSync(authPath, 'utf-8'));
        if (auth.tokens) {
          accounts.push({
            email: auth.tokens.email || '',
            accountId: auth.tokens.account_id || '',
            accessToken: auth.tokens.access_token || '',
            refreshToken: auth.tokens.refresh_token || '',
            idToken: auth.tokens.id_token || '',
            source: 'auth.json'
          });
        }
      } catch (e) {
        // 忽略解析错误
      }
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
              accessToken: acc.access_token || '',
              refreshToken: acc.refresh_token || '',
              idToken: acc.id_token || '',
              source: 'token_pool.json'
            });
          }
        }
      } catch (e) {
        // 忽略解析错误
      }
    }

    return accounts;
  }
}