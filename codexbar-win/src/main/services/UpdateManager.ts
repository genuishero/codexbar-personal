import { app, BrowserWindow } from 'electron';
import axios from 'axios';

interface ReleaseArtifact {
  platform: 'darwin' | 'win32';
  arch: 'x64' | 'arm64';
  url: string;
  sha256?: string;
}

interface Release {
  version: string;
  buildNumber: number;
  releaseNotes: string;
  artifacts: ReleaseArtifact[];
}

interface UpdateFeed {
  schemaVersion: number;
  channel: 'stable' | 'beta';
  release: Release;
}

export class UpdateManager {
  private feedUrl: string = 'https://raw.githubusercontent.com/GenuisZ/codexbar-personal/main/release-feed.json';
  private currentVersion: string;
  private currentBuild: number;

  constructor() {
    this.currentVersion = app.getVersion();
    this.currentBuild = parseInt(process.env.BUILD_NUMBER || '0', 10);
  }

  async checkForUpdates(showNotification: boolean = true): Promise<Release | null> {
    try {
      const response = await axios.get<UpdateFeed>(this.feedUrl);
      const feed = response.data;

      if (!feed.release) return null;

      const latestVersion = feed.release.version;
      const latestBuild = feed.release.buildNumber;

      // 比较版本号
      if (this.isNewerVersion(latestVersion, latestBuild)) {
        // 找到 Windows 的下载链接
        const artifact = feed.release.artifacts.find(
          a => a.platform === 'win32' && a.arch === 'x64'
        );

        if (artifact) {
          return {
            ...feed.release,
            artifacts: [artifact]
          };
        }
      }

      return null;
    } catch (e) {
      console.error('Failed to check for updates:', e);
      return null;
    }
  }

  private isNewerVersion(version: string, build: number): boolean {
    // 先比较版本号
    const currentParts = this.currentVersion.split('.').map(Number);
    const newParts = version.split('.').map(Number);

    for (let i = 0; i < Math.max(currentParts.length, newParts.length); i++) {
      const current = currentParts[i] || 0;
      const newPart = newParts[i] || 0;

      if (newPart > current) return true;
      if (newPart < current) return false;
    }

    // 版本号相同则比较 build number
    return build > this.currentBuild;
  }

  getDownloadUrl(release: Release): string | null {
    const artifact = release.artifacts.find(
      a => a.platform === 'win32' && a.arch === 'x64'
    );
    return artifact?.url || null;
  }
}