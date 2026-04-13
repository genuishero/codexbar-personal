import { contextBridge, ipcRenderer } from 'electron';

// 向渲染进程暴露安全的 API
contextBridge.exposeInMainWorld('electronAPI', {
  // 配置相关
  getConfig: () => ipcRenderer.invoke('get-config'),
  saveConfig: (config: any) => ipcRenderer.invoke('save-config', config),

  // 账号相关
  getAccounts: () => ipcRenderer.invoke('get-accounts'),
  activateAccount: (accountId: string) => ipcRenderer.invoke('activate-account', accountId),
  addAccountOAuth: () => ipcRenderer.invoke('add-account-oauth'),
  getUsage: (accountId: string) => ipcRenderer.invoke('get-usage', accountId),
  refreshAllUsage: () => ipcRenderer.invoke('refresh-all-usage'),

  // 本地账号发现
  importLocalAccounts: () => ipcRenderer.invoke('import-local-accounts'),
  importSelectedAccounts: (accounts: any[]) => ipcRenderer.invoke('import-selected-accounts', accounts),

  // CSV 导入导出
  exportCSV: (accounts: any[]) => ipcRenderer.invoke('export-csv', accounts),
  importCSV: () => ipcRenderer.invoke('import-csv'),

  // 更新相关
  checkUpdates: () => ipcRenderer.invoke('check-updates'),

  // 窗口操作
  openSettings: () => ipcRenderer.invoke('open-settings'),
  openExternal: (url: string) => ipcRenderer.invoke('open-external', url),

  // OAuth 回调
  onOAuthComplete: (callback: (result: any) => void) => {
    ipcRenderer.on('oauth-complete', (_event, result) => callback(result));
  },
  onOAuthCancel: (callback: () => void) => {
    ipcRenderer.on('oauth-cancel', () => callback());
  },
  sendOAuthComplete: (result: any) => ipcRenderer.send('oauth-complete', result),
  sendOAuthCancel: () => ipcRenderer.send('oauth-cancel'),

  // 导入导出对话框
  onShowExport: (callback: () => void) => {
    ipcRenderer.on('show-export', () => callback());
  },
  onShowImport: (callback: () => void) => {
    ipcRenderer.on('show-import', () => callback());
  },

  // 本地账号列表
  getLocalAccounts: () => ipcRenderer.invoke('get-local-accounts')
});