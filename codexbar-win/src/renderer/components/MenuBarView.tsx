import React, { useState, useEffect } from 'react';
import './MenuBarView.css';

interface Account {
  id: string;
  email: string;
  accountId: string;
  planType: string;
  primaryUsedPercent?: number;
  isActive: boolean;
  isSuspended: boolean;
  tokenExpired: boolean;
}

const MenuBarView: React.FC = () => {
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [activeAccountId, setActiveAccountId] = useState<string | null>(null);
  const [showDropdown, setShowDropdown] = useState(false);

  useEffect(() => {
    loadAccounts();

    // 定时刷新
    const interval = setInterval(loadAccounts, 60000);
    return () => clearInterval(interval);
  }, []);

  const loadAccounts = async () => {
    const accs = await window.electronAPI.getAccounts();
    setAccounts(accs);
    const config = await window.electronAPI.getConfig();
    setActiveAccountId(config.activeAccountId);
  };

  const handleActivate = async (accountId: string) => {
    await window.electronAPI.activateAccount(accountId);
    await loadAccounts();
  };

  const handleRefresh = async () => {
    await window.electronAPI.refreshAllUsage();
    await loadAccounts();
  };

  const handleImportLocal = async () => {
    setShowDropdown(false);
    await window.electronAPI.importLocalAccounts();
  };

  const handleNewOAuth = async () => {
    setShowDropdown(false);
    await window.electronAPI.addAccountOAuth();
    await loadAccounts();
  };

  const getStatusIcon = (account: Account) => {
    if (account.tokenExpired) return '⚠️';
    if (account.isSuspended) return '🚫';
    return '✓';
  };

  const getUsageText = (account: Account) => {
    if (account.primaryUsedPercent !== undefined) {
      return `${Math.round(account.primaryUsedPercent)}%`;
    }
    return '';
  };

  return (
    <div className="menubar-view">
      <div className="header">
        <h1>CodexBar</h1>
        <div className="toolbar">
          <button
            className="toolbar-btn"
            onClick={() => setShowDropdown(!showDropdown)}
          >
            + 添加账号
          </button>
          {showDropdown && (
            <div className="dropdown-menu">
              <button onClick={handleImportLocal}>从本地导入账号</button>
              <button onClick={handleNewOAuth}>新 OAuth 登录</button>
            </div>
          )}
          <button className="toolbar-btn" onClick={handleRefresh}>
            ↻ 刷新
          </button>
          <button className="toolbar-btn" onClick={() => window.electronAPI.openSettings()}>
            ⚙ 设置
          </button>
        </div>
      </div>

      <div className="accounts-list">
        {accounts.length === 0 ? (
          <div className="no-accounts">
            <p>暂无账号</p>
            <p>请点击上方"添加账号"按钮添加 OpenAI 账号</p>
          </div>
        ) : (
          accounts.map((account) => (
            <div
              key={account.accountId}
              className={`account-item ${account.accountId === activeAccountId ? 'active' : ''}`}
              onClick={() => handleActivate(account.accountId)}
            >
              <div className="account-status">
                {account.accountId === activeAccountId ? '●' : '○'}
              </div>
              <div className="account-info">
                <div className="account-email">{account.email}</div>
                <div className="account-meta">
                  {getStatusIcon(account)} {getUsageText(account)}
                </div>
              </div>
              <div className="account-plan">{account.planType}</div>
            </div>
          ))
        )}
      </div>
    </div>
  );
};

export default MenuBarView;