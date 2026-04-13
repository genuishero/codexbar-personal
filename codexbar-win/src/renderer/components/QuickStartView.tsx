import React, { useState } from 'react';
import './QuickStartView.css';

interface Step {
  title: string;
  description: string;
  icon: string;
}

const steps: Step[] = [
  {
    title: '添加账号',
    description: '从本地 ~/.codex 目录导入已有账号，或通过 OAuth 登录新账号',
    icon: '👤'
  },
  {
    title: '选择活跃账号',
    description: '在账号列表中点击要使用的账号，使其成为活跃账号',
    icon: '✓'
  },
  {
    title: '查看用量',
    description: '主界面会显示每个账号的用量百分比，帮助您监控使用情况',
    icon: '📊'
  },
  {
    title: '快捷键',
    description: '使用 Ctrl+Shift+1~5 快速切换账号，Ctrl+Shift+C 清除剪贴板',
    icon: '⌨'
  }
];

const QuickStartView: React.FC = () => {
  const [currentStep, setCurrentStep] = useState(0);

  const handleNext = () => {
    if (currentStep < steps.length - 1) {
      setCurrentStep(currentStep + 1);
    }
  };

  const handlePrev = () => {
    if (currentStep > 0) {
      setCurrentStep(currentStep - 1);
    }
  };

  const handleSkip = async () => {
    const config = await window.electronAPI.getConfig();
    config.quickStartCompleted = true;
    await window.electronAPI.saveConfig(config);
    window.close();
  };

  const handleFinish = async () => {
    const config = await window.electronAPI.getConfig();
    config.quickStartCompleted = true;
    await window.electronAPI.saveConfig(config);
    window.close();
  };

  return (
    <div className="quickstart-view">
      <div className="quickstart-header">
        <h1>CodexBar 快速开始</h1>
        <p>欢迎使用 CodexBar，跟随引导快速上手</p>
      </div>

      <div className="progress-bar">
        {steps.map((_, index) => (
          <div
            key={index}
            className={`progress-step ${index <= currentStep ? 'active' : ''}`}
          />
        ))}
      </div>

      <div className="step-content">
        <div className="step-icon">{steps[currentStep].icon}</div>
        <h2>{steps[currentStep].title}</h2>
        <p>{steps[currentStep].description}</p>
      </div>

      <div className="quickstart-actions">
        <button onClick={handleSkip} className="skip-btn">跳过引导</button>
        {currentStep > 0 && (
          <button onClick={handlePrev} className="prev-btn">上一步</button>
        )}
        {currentStep < steps.length - 1 ? (
          <button onClick={handleNext} className="next-btn">下一步</button>
        ) : (
          <button onClick={handleFinish} className="finish-btn">完成</button>
        )}
      </div>
    </div>
  );
};

export default QuickStartView;