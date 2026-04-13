import React, { useState, useEffect } from 'react';
import './SettingsView.css';

interface Settings {
  quotaWarning: boolean;
  quotaWarningThreshold: number;
  keyboardShortcuts: boolean;
  clipboardProtection: boolean;
  language: 'zh' | 'en' | 'auto';
}

interface Config {
  settings: Settings;
  quickStartCompleted: boolean;
}

const SettingsView: React.FC = () => {
  const [config, setConfig] = useState<Config | null>(null);
  const [version, setVersion] = useState<string>('');
  const [checking, setChecking] = useState(false);
  const [updateAvailable, setUpdateAvailable] = useState<any>(null);

  useEffect(() => {
    loadConfig();
    // 从 package.json 获取版本
    setVersion('2.1.1');
  }, []);

  const loadConfig = async () => {
    const cfg = await window.electronAPI.getConfig();
    setConfig(cfg);
  };

  const handleSave = async () => {
    if (config) {
      await window.electronAPI.saveConfig(config);
    }
  };

  const handleCheckUpdates = async () => {
    setChecking(true);
    const update = await window.electronAPI.checkUpdates();
    setUpdateAvailable(update);
    setChecking(false);
  };

  const handleDownloadUpdate = () => {
    if (updateAvailable?.artifacts?.[0]?.url) {
      window.electronAPI.openExternal(updateAvailable.artifacts[0].url);
    }
  };

  if (!config) return <div>加载中...</div>;

  return (
    <div className="settings-view">
      <div className="settings-header">
        <h1>设置</h1>
      </div>

      <div className="settings-section">
        <h2>用量预警</h2>
        <div className="setting-item">
          <label>
            <input
              type="checkbox"
              checked={config.settings.quotaWarning}
              onChange={(e) => setConfig({
                ...config,
                settings: { ...config.settings, quotaWarning: e.target.checked }
              })}
            />
            启用量额用量预警
          </label>
        </div>
        <div className="setting-item">
          <label>
            预警阈值:
            <input
              type="number"
              value={config.settings.quotaWarningThreshold}
              onChange={(e) => setConfig({
                ...config,
                settings: { ...config.settings, quotaWarningThreshold: parseInt(e.target.value, 10) }
              })}
              min={10}
              max={100}
            />
            %
          </label>
        </div>
      </div>

      <div className="settings-section">
        <h2>快捷键</h2>
        <div className="setting-item">
          <label>
            <input
              type="checkbox"
              checked={config.settings.keyboardShortcuts}
              onChange={(e) => setConfig({
                ...config,
                settings: { ...config.settings, keyboardShortcuts: e.target.checked }
              })}
            />
            启用全局快捷键 (Ctrl+Shift+1~5 切换账号)
          </label>
        </div>
      </div>

      <div className="settings-section">
        <h2>剪贴板保护</h2>
        <div className="setting-item">
          <label>
            <input
              type="checkbox"
              checked={config.settings.clipboardProtection}
              onChange={(e) => setConfig({
                ...config,
                settings: { ...config.settings, clipboardProtection: e.target.checked }
              })}
            />
            清除剪贴板中的敏感 Token (Ctrl+Shift+C)
          </label>
        </div>
      </div>

      <div className="settings-section">
        <h2>语言</h2>
        <div className="setting-item">
          <select
            value={config.settings.language}
            onChange={(e) => setConfig({
              ...config,
              settings: { ...config.settings, language: e.target.value as any }
            })}
          >
            <option value="auto">自动检测</option>
            <option value="zh">中文</option>
            <option value="en">English</option>
          </select>
        </div>
      </div>

      <div className="settings-section">
        <h2>版本与更新</h2>
        <div className="setting-item">
          <span>当前版本: {version}</span>
        </div>
        <div className="setting-item">
          <button onClick={handleCheckUpdates} disabled={checking}>
            {checking ? '检查中...' : '检查更新'}
          </button>
          {updateAvailable && (
            <div className="update-info">
              <p>发现新版本: {updateAvailable.version}</p>
              <button onClick={handleDownloadUpdate}>下载更新</button>
            </div>
          )}
        </div>
      </div>

      <div className="settings-actions">
        <button className="save-btn" onClick={handleSave}>保存设置</button>
      </div>
    </div>
  );
};

export default SettingsView;