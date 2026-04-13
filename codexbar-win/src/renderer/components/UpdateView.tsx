import React, { useState, useEffect } from 'react';
import './UpdateView.css';

interface Release {
  version: string;
  buildNumber: number;
  releaseNotes: string;
  artifacts: {
    url: string;
    sha256?: string;
  }[];
}

const UpdateView: React.FC = () => {
  const [checking, setChecking] = useState(true);
  const [update, setUpdate] = useState<Release | null>(null);
  const [error, setError] = useState('');
  const [currentVersion, setCurrentVersion] = useState('2.1.1');

  useEffect(() => {
    checkUpdates();
  }, []);

  const checkUpdates = async () => {
    setChecking(true);
    setError('');
    try {
      const result = await window.electronAPI.checkUpdates();
      setUpdate(result);
    } catch (e) {
      setError('检查更新失败');
    }
    setChecking(false);
  };

  const handleDownload = () => {
    if (update?.artifacts?.[0]?.url) {
      window.electronAPI.openExternal(update.artifacts[0].url);
    }
  };

  return (
    <div className="update-view">
      <div className="update-header">
        <h1>检查更新</h1>
      </div>

      <div className="update-content">
        <div className="version-info">
          <span>当前版本: {currentVersion}</span>
        </div>

        {checking && (
          <div className="checking">
            <p>正在检查更新...</p>
          </div>
        )}

        {error && (
          <div className="error">
            <p>{error}</p>
            <button onClick={checkUpdates}>重试</button>
          </div>
        )}

        {!checking && !error && !update && (
          <div className="no-update">
            <p>✓ 已是最新版本</p>
          </div>
        )}

        {!checking && update && (
          <div className="update-available">
            <h2>发现新版本: {update.version}</h2>
            <div className="release-notes">
              <p>{update.releaseNotes}</p>
            </div>
            {update.artifacts[0]?.sha256 && (
              <div className="checksum">
                <p>SHA256: {update.artifacts[0].sha256}</p>
              </div>
            )}
            <button onClick={handleDownload} className="download-btn">
              下载更新
            </button>
          </div>
        )}
      </div>
    </div>
  );
};

export default UpdateView;