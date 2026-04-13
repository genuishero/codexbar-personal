import React, { useState, useEffect } from 'react';
import './LocalAccountPicker.css';

interface DiscoveredAccount {
  email: string;
  accountId: string;
  accessToken: string;
  refreshToken: string;
  idToken: string;
  source: string;
}

const LocalAccountPicker: React.FC = () => {
  const [accounts, setAccounts] = useState<DiscoveredAccount[]>([]);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadAccounts();
  }, []);

  const loadAccounts = async () => {
    try {
      const accs = await window.electronAPI.getLocalAccounts();
      setAccounts(accs);
    } catch (e) {
      // 可能没有 getLocalAccounts API，尝试从 IPC 获取
      const accs = await window.electronAPI.importLocalAccounts();
      setAccounts(accs);
    }
    setLoading(false);
  };

  const handleToggle = (accountId: string) => {
    const newSelected = new Set(selected);
    if (newSelected.has(accountId)) {
      newSelected.delete(accountId);
    } else {
      newSelected.add(accountId);
    }
    setSelected(newSelected);
  };

  const handleImport = async () => {
    const selectedAccounts = accounts.filter(a => selected.has(a.accountId));
    if (selectedAccounts.length > 0) {
      await window.electronAPI.importSelectedAccounts(selectedAccounts.map(acc => ({
        id: acc.accountId,
        email: acc.email,
        accountId: acc.accountId,
        accessToken: acc.accessToken,
        refreshToken: acc.refreshToken,
        idToken: acc.idToken,
        planType: 'free',
        isActive: false,
        isSuspended: false,
        tokenExpired: false,
        addedAt: new Date().toISOString()
      })));
      window.close();
    }
  };

  const handleCancel = () => {
    window.close();
  };

  if (loading) {
    return <div className="loading">加载中...</div>;
  }

  return (
    <div className="local-picker-view">
      <div className="picker-header">
        <h1>选择本地账号</h1>
        <p>以下账号已从 ~/.codex 目录发现</p>
      </div>

      {accounts.length === 0 ? (
        <div className="no-accounts">
          <p>未发现本地账号</p>
          <p>请先通过 Codex CLI 登录账号</p>
        </div>
      ) : (
        <div className="accounts-list">
          {accounts.map((account) => (
            <div
              key={account.accountId}
              className={`account-item ${selected.has(account.accountId) ? 'selected' : ''}`}
              onClick={() => handleToggle(account.accountId)}
            >
              <input
                type="checkbox"
                checked={selected.has(account.accountId)}
                onChange={() => handleToggle(account.accountId)}
              />
              <div className="account-info">
                <div className="account-email">{account.email}</div>
                <div className="account-source">来源: {account.source}</div>
              </div>
            </div>
          ))}
        </div>
      )}

      <div className="picker-actions">
        <button onClick={handleCancel} className="cancel-btn">取消</button>
        <button
          onClick={handleImport}
          className="import-btn"
          disabled={selected.size === 0}
        >
          导入选中 ({selected.size})
        </button>
      </div>
    </div>
  );
};

export default LocalAccountPicker;