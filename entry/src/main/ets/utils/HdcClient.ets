import { hilog } from '@kit.PerformanceAnalysisKit';
import hdc from 'libhdc_napi.so';
import { fileIo as fs } from '@kit.CoreFileKit';
import { taskpool } from '@kit.ArkTS';

const DOMAIN = 0x0000;
const TAG = 'HdcClient';

export interface HdcConnectionCallback {
  onDaemonStarted?: () => void;
  onDaemonFailed?: (error: string) => void;
  onConnected?: (message: string) => void;
  onConnectionFailed?: (error: string) => void;
  onCommandResult?: (output: string) => void;
  onCommandFailed?: (error: string) => void;
}

export interface HdcConnectionConfig {
  ip: string;
  port: number;
  workPath?: string;
}

export interface HdcConnectionResult {
  daemonStarted: boolean;
  connected: boolean;
  message: string;
  log: string;
}

@Concurrent
async function backgroundStartDaemon(workPath: string): Promise<boolean> {
  const filesToDelete = ["hdc.socket", "hdc.pid", "hdc.out", ".HDCServer.pid"];
  filesToDelete.forEach(fileName => {
    let filePath = workPath + fileName;
    try {
      if (fs.accessSync(filePath)) {
        fs.unlinkSync(filePath);
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  });

  const retCode = hdc.startDaemon();
  return retCode;
}

@Concurrent
async function backgroundExecuteCommand(cmd: string): Promise<string> {
  const result = hdc.executeCommand(cmd);
  return result;
}

@Concurrent
async function backgroundConnect(ip: string, port: number): Promise<string> {
  const connectCmd = `tconn ${ip}:${port}`;
  const result = hdc.executeCommand(connectCmd);
  return result;
}

export class HdcClient {
  private workPath: string = '';
  private callback: HdcConnectionCallback | null = null;

  setWorkPath(path: string): void {
    this.workPath = path;
  }

  setCallback(callback: HdcConnectionCallback): void {
    this.callback = callback;
  }

  async startDaemon(): Promise<boolean> {
    try {
      let task = new taskpool.Task(backgroundStartDaemon, this.workPath);
      const retCode = await taskpool.execute(task);
      hilog.info(DOMAIN, TAG, 'startDaemon returned: %{public}s', JSON.stringify(retCode));

      const isSuccess = (typeof retCode === 'number' && retCode === 0) || retCode === true;

      if (isSuccess) {
        this.callback?.onDaemonStarted?.();
      } else {
        this.callback?.onDaemonFailed?.(`Start daemon failed: ${retCode}`);
      }

      return isSuccess;
    } catch (error) {
      const errorMsg = (error as Error).message;
      hilog.error(DOMAIN, TAG, 'Start daemon failed: %{public}s', errorMsg);
      this.callback?.onDaemonFailed?.(errorMsg);
      return false;
    }
  }

  async connect(ip: string, port: number): Promise<string> {
    try {
      let task = new taskpool.Task(backgroundConnect, ip, port);
      const result = await taskpool.execute(task) as string;

      const isFail = result.includes('[fail]') ||
        result.toLowerCase().includes('error') ||
        result.toLowerCase().includes('failed');

      if (isFail) {
        this.callback?.onConnectionFailed?.(result);
      } else {
        this.callback?.onConnected?.(result);
      }

      return result;
    } catch (error) {
      const errorMsg = (error as Error).message;
      hilog.error(DOMAIN, TAG, 'Connect failed: %{public}s', errorMsg);
      this.callback?.onConnectionFailed?.(errorMsg);
      return `[fail] ${errorMsg}`;
    }
  }

  async executeCommand(cmd: string): Promise<string> {
    try {
      let task = new taskpool.Task(backgroundExecuteCommand, cmd);
      const result = await taskpool.execute(task) as string;
      this.callback?.onCommandResult?.(result);
      return result;
    } catch (error) {
      const errorMsg = (error as Error).message;
      hilog.error(DOMAIN, TAG, 'Command execution failed: %{public}s', errorMsg);
      this.callback?.onCommandFailed?.(errorMsg);
      throw new Error(errorMsg);
    }
  }

  async autoConnect(config: HdcConnectionConfig): Promise<HdcConnectionResult> {
    const logs: string[] = [];
    let result: HdcConnectionResult = {
      daemonStarted: false,
      connected: false,
      message: '',
      log: ''
    };
    if (config.workPath) {
      this.workPath = config.workPath;
    }
    logs.push('[Auto] Starting daemon...');
    const daemonSuccess = await this.startDaemon();
    result.daemonStarted = daemonSuccess;
    if (!daemonSuccess) {
      result.message = '[fail] Start daemon failed';
      logs.push('[Server] [fail] Start daemon failed');
      result.log = logs.join('\n');
      return result;
    }
    logs.push('[Server] OK');
    logs.push(`[Connect] Connecting to ${config.ip}:${config.port}...`);
    const connectResult = await this.connect(config.ip, config.port);

    const isFail = connectResult.includes('[fail]') ||
      connectResult.toLowerCase().includes('error') ||
      connectResult.toLowerCase().includes('failed');

    if (isFail) {
      result.connected = false;
      result.message = '[fail]';
      logs.push(`[Connect] [fail] ${connectResult}`);
    } else {
      result.connected = true;
      result.message = 'Connect OK';
      logs.push('[Connect] Connect OK');
    }
    result.log = logs.join('\n');
    return result;
  }
  async pullUpGameService(){
    try{
      await this.executeCommand('shell cem publish -e game.assistant.custom.deviceTemplate');
      await new Promise<void>(resolve => setTimeout(resolve, 500));
    }catch (error){
      const errorMsg = (error as Error).message;
      hilog.error(DOMAIN, TAG, 'Failed to fetch game status: %{public}s', errorMsg);

    }
  }
  async installHiSmartPerf(){
    await this.executeCommand('install /data/storage/el1/bundle/entry/resources/resfile/entry-HiSmartPerf-signed.hap');

  }
  //game:pkgname status:enable or not
  async setGameStatus(game: string, status: boolean): Promise<boolean> {
    try {
      await this.pullUpGameService();
      let result: string;
      if (status) {
        result = await this.executeCommand(`shell hidumper -s 66006 -a "-se ${game}"`);
      } else {
        result = await this.executeCommand(`shell hidumper -s 66006 -a "-sc ${game}"`);
      }
      return result.includes('success');
    } catch (error) {
      const errorMsg = (error as Error).message;
      hilog.error(DOMAIN, TAG, 'Failed to set game status: %{public}s', errorMsg);
      return false;
    }
  }
  async fetchGameStatus(): Promise<Set<string>> {
    const gamePackages = new Set<string>();
    try {
      await this.pullUpGameService();
      const result = await this.executeCommand('shell hidumper -s 66006 -a -t');
      const lines = result.split('\n');
      for (const line of lines) {
        const trimmed = line.trim();
        // Match lines that have isGame markers
        // Looking for lines where either isGame(live) or isGame(dev) is 1
        const match = trimmed.match(/^(\d+)\s+(\d+)\s+(\S+)$/);
        if (match) {
          const isGameLive = match[1] === '1';
          const isGameDev = match[2] === '1';
          const bundleName = match[3];
          if (isGameLive || isGameDev) {
            gamePackages.add(bundleName);
          }
        }
      }
      hilog.info(DOMAIN, TAG, 'Found %{public}d game packages', gamePackages.size);
    } catch (error) {
      const errorMsg = (error as Error).message;
      hilog.error(DOMAIN, TAG, 'Failed to fetch game status: %{public}s', errorMsg);
    }
    return gamePackages;
  }
}
