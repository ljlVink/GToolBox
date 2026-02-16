export class LogService {
  private static instance: LogService;
  private logs: string = 'Ready...\n';
  private listeners: Array<(log: string) => void> = [];

  private constructor() {}

  static getInstance(): LogService {
    if (!LogService.instance) {
      LogService.instance = new LogService();
    }
    return LogService.instance;
  }

  appendLog(message: string) {
    this.logs += message + '\n';
    console.info(message);
    this.notifyListeners();
  }

  getLogs(): string {
    return this.logs;
  }

  clearLogs() {
    this.logs = 'Ready...\n';
    this.notifyListeners();
  }

  addListener(callback: (log: string) => void) {
    this.listeners.push(callback);
  }

  removeListener(callback: (log: string) => void) {
    const index = this.listeners.indexOf(callback);
    if (index > -1) {
      this.listeners.splice(index, 1);
    }
  }

  private notifyListeners() {
    this.listeners.forEach(listener => listener(this.logs));
  }
}
