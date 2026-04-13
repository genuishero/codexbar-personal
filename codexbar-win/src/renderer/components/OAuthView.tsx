import React, { useState } from 'react';
import './OAuthView.css';

const OAuthView: React.FC = () => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  // 注意: 这是一个简化的 OAuth 流程模拟
  // 实际实现需要与 OpenAI OAuth 服务器交互
  const handleLogin = async () => {
    setLoading(true);
    setError('');

    try {
      // 模拟 OAuth 流程
      // 实际应用中这里应该打开 OpenAI OAuth 页面
      // 或通过后端服务器完成 OAuth 认证

      // 这里模拟获取 token
      const result = {
        email,
        accountId: `acc_${Date.now()}`,
        accessToken: 'mock_access_token',
        refreshToken: 'mock_refresh_token',
        idToken: 'mock_id_token',
        planType: 'free',
        isActive: false,
        isSuspended: false,
        tokenExpired: false,
        addedAt: new Date().toISOString()
      };

      window.electronAPI.sendOAuthComplete(result);
    } catch (e) {
      setError('登录失败，请重试');
      setLoading(false);
    }
  };

  const handleCancel = () => {
    window.electronAPI.sendOAuthCancel();
  };

  return (
    <div className="oauth-view">
      <div className="oauth-header">
        <h1>OpenAI 账号登录</h1>
        <p>请输入您的 OpenAI 账号信息</p>
      </div>

      <div className="oauth-form">
        <div className="form-group">
          <label>邮箱</label>
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="your@email.com"
          />
        </div>

        <div className="form-group">
          <label>密码</label>
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            placeholder="密码"
          />
        </div>

        {error && <div className="error-message">{error}</div>}

        <div className="oauth-actions">
          <button onClick={handleCancel} className="cancel-btn">取消</button>
          <button onClick={handleLogin} className="login-btn" disabled={loading}>
            {loading ? '登录中...' : '登录'}
          </button>
        </div>
      </div>

      <div className="oauth-note">
        <p>注意: 实际 OAuth 流程需要通过 OpenAI 官方授权页面完成</p>
      </div>
    </div>
  );
};

export default OAuthView;