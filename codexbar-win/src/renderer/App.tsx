import React, { useEffect, useState } from 'react';
import MenuBarView from './components/MenuBarView';
import SettingsView from './components/SettingsView';
import OAuthView from './components/OAuthView';
import QuickStartView from './components/QuickStartView';
import LocalAccountPicker from './components/LocalAccountPicker';
import UpdateView from './components/UpdateView';

declare global {
  interface Window {
    electronAPI: {
      getConfig: () => Promise<any>;
      saveConfig: (config: any) => Promise<void>;
      getAccounts: () => Promise<any[]>;
      activateAccount: (accountId: string) => Promise<void>;
      addAccountOAuth: () => Promise<any>;
      getUsage: (accountId: string) => Promise<any>;
      refreshAllUsage: () => Promise<void>;
      importLocalAccounts: () => Promise<any[]>;
      importSelectedAccounts: (accounts: any[]) => Promise<void>;
      exportCSV: (accounts: any[]) => Promise<boolean>;
      importCSV: () => Promise<number>;
      checkUpdates: () => Promise<any>;
      openSettings: () => Promise<void>;
      openExternal: (url: string) => Promise<void>;
      onOAuthComplete: (callback: (result: any) => void) => void;
      onOAuthCancel: (callback: () => void) => void;
      sendOAuthComplete: (result: any) => void;
      sendOAuthCancel: () => void;
      onShowExport: (callback: () => void) => void;
      onShowImport: (callback: () => void) => void;
      getLocalAccounts: () => Promise<any[]>;
    };
  }
}

const App: React.FC = () => {
  const [view, setView] = useState<string>('main');

  // 根据 URL hash 确定当前视图
  useEffect(() => {
    const hash = window.location.hash.slice(1);
    setView(hash || 'main');
  }, []);

  return (
    <div className="app">
      {view === 'main' && <MenuBarView />}
      {view === 'settings' && <SettingsView />}
      {view === 'oauth' && <OAuthView />}
      {view === 'quickstart' && <QuickStartView />}
      {view === 'local-picker' && <LocalAccountPicker />}
      {view === 'update' && <UpdateView />}
    </div>
  );
};

export default App;