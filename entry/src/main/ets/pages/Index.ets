import { common, Want, wantAgent, WantAgent } from '@kit.AbilityKit';
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { socket } from '@kit.NetworkKit';
import { preferences } from '@kit.ArkData';
import { HdcClient, HdcConnectionCallback, HdcConnectionConfig } from '../utils/HdcClient';
import { LogService } from '../utils/LogService';
import { window, promptAction } from '@kit.ArkUI';
import { util } from '@kit.ArkTS';

interface AppInfo {
  icon: Resource | string;
  appName: string;
  bundleName: string;
  abilityName: string;
  appver: string;
  isGame: boolean;
}

interface AppDataResponse {
  package: string;
  abilityName: string;
  appVersion: string;
  name: string;
}

interface AppIconResponse {
  package: string;
  abilityName: string;
  appVersion: string;
  name: string;
  icon: string;
}

@Preview
@Component
export struct HomePage {
  @State cmdInput: string = "tconn 127.0.0.1:5555";
  @State connectStatus: string = '';
  @State isConnected: boolean = false;
  @State appList: AppInfo[] = [];
  @State gridColumns: number = 1;
  @State hideAtomicService: boolean = true;
  @State skipAppIcon: boolean = true;
  @State showAppActionDialog: boolean = false;
  @State selectedApp: AppInfo | null = null;
  @State searchKeyword: string = '';
  @State showUninstallConfirmDialog: boolean = false;
  @State showCleanConfirmDialog: boolean = false;
  @State cleanType: 'cache' | 'data' = 'cache';
  
  private getConnectStatusString(): string {
    return String(this.connectStatus || '');
  }

  private getFilteredAppList(): AppInfo[] {
    if (!this.searchKeyword || this.searchKeyword.trim() === '') {
      return this.appList;
    }
    const keyword = this.searchKeyword.toLowerCase().trim();
    return this.appList.filter((app: AppInfo) => {
      return app.appName.toLowerCase().includes(keyword) ||
             app.bundleName.toLowerCase().includes(keyword);
    });
  }
  private workPath: string = '';
  private defaultPort: string = '5555';
  private defaultIP: string = '127.0.0.1';
  private preferencesStore: preferences.Preferences | null = null;
  private hdcClient: HdcClient = new HdcClient();
  private logService: LogService = LogService.getInstance();
  private context: common.UIAbilityContext | undefined = undefined;

  async aboutToAppear() {
    this.context = getContext(this) as common.UIAbilityContext;
    this.checkSettingsAndConnect();
    await this.updateGridColumns();
    await this.loadCachedAppList();
    await this.refreshGameStatus();
  }

  async refreshGameStatus() {
    if (!this.isConnected) {
      return;
    }
    try {
      this.logService.appendLog('[GameStatus] Fetching game status...');
      const gamePackages = await this.hdcClient.fetchGameStatus();
      let updatedCount = 0;
      this.appList = this.appList.map((app: AppInfo): AppInfo => {
        const isGame = gamePackages.has(app.bundleName);
        if (isGame) {
          updatedCount++;
        }
        return {
          icon: app.icon,
          appName: app.appName,
          bundleName: app.bundleName,
          abilityName: app.abilityName,
          appver: app.appver,
          isGame: isGame
        };
      });
      
      this.logService.appendLog(`[GameStatus] Updated ${updatedCount} games`);
      await this.saveAppListToCache();
    } catch (error) {
      this.logService.appendLog(`[GameStatus] Error: ${(error as Error).message}`);
    }
  }

  async loadCachedAppList() {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const store = await preferences.getPreferences(context, 'app_list_cache');
      const cachedData = await store.get('appList', '');

      if (cachedData && cachedData !== '') {
        const cachedAppList = JSON.parse(cachedData as string) as AppInfo[];
        if (cachedAppList.length > 0) {
          this.appList = cachedAppList;
          this.logService.appendLog(`[Cache] Loaded ${this.appList.length} apps from cache`);
        }
      }
    } catch (error) {
      this.logService.appendLog(`[Cache] Failed to load cached app list: ${(error as Error).message}`);
    }
  }

  // Save app list to preferences cache
  async saveAppListToCache() {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const store = await preferences.getPreferences(context, 'app_list_cache');
      const dataToSave = JSON.stringify(this.appList);
      await store.put('appList', dataToSave);
      await store.flush();
      this.logService.appendLog(`[Cache] Saved ${this.appList.length} apps to cache`);
    } catch (error) {
      this.logService.appendLog(`[Cache] Failed to save app list to cache: ${(error as Error).message}`);
    }
  }

  async updateGridColumns() {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const windowClass = await window.getLastWindow(context);
      const properties = windowClass.getWindowProperties();
      const width = properties.windowRect.width;
      const density = context.resourceManager.getConfigurationSync().screenDensity / 160;
      const widthDp = width / density;

      if (widthDp >= 600) {
        this.gridColumns = 3;
      } else if (widthDp >= 400) {
        this.gridColumns = 2;
      } else {
        this.gridColumns = 1;
      }
    } catch (error) {
      console.error('Failed to get window properties: ' + JSON.stringify(error));
      this.gridColumns = 1;
    }
  }

  async checkSettingsAndConnect() {
    try {
      let context = getContext(this) as common.UIAbilityContext;
      this.preferencesStore = await preferences.getPreferences(context, 'hdc_settings');

      const savedPort = await this.preferencesStore.get('port', '');
      const savedIP = await this.preferencesStore.get('ip', '');
      const savedHideAtomic = await this.preferencesStore.get('hideAtomicService', true);
      const savedSkipAppIcon = await this.preferencesStore.get('skipAppIcon', true);

      if (!savedPort || savedPort === '') {
        this.logService.appendLog('[Settings] Port not configured. Please go to Settings.');
        //todo: skip to settings page
        this.connectStatus = await context.resourceManager.getStringValue($r('app.string.connect_status_not_configured'));
        return;
      }

      this.defaultPort = savedPort as string;
      this.defaultIP = savedIP as string;
      this.hideAtomicService = savedHideAtomic as boolean;
      this.skipAppIcon = savedSkipAppIcon as boolean;
      this.cmdInput = `tconn ${this.defaultIP}:${this.defaultPort}`;

      this.autoStartAndConnect();

    } catch (error) {
      console.error('Failed to load settings: ' + (error as BusinessError).message);
      this.connectStatus = 'Error loading settings';
    }
  }

  async autoStartAndConnect() {
    let context = getContext(this) as common.UIAbilityContext;
    const callback: HdcConnectionCallback = {
      onDaemonStarted: () => {
        this.logService.appendLog('[Server] onDaemonStarted');
      },
      onDaemonFailed: async (error: string) => {
        this.logService.appendLog(`[Server] [fail] ${error}`);
        this.connectStatus = await context.resourceManager.getStringValue($r('app.string.connect_status_daemon_fail'));
        this.isConnected = false;
      },
      onConnected: async () => {
        this.logService.appendLog('[Connect] Connect OK');
        this.connectStatus = await context.resourceManager.getStringValue($r('app.string.connect_status_connected'));
        this.isConnected = true;
      },
      onConnectionFailed: async (error: string) => {
        this.logService.appendLog(`[Connect] [fail] ${error}`);
        this.connectStatus = await context.resourceManager.getStringValue($r('app.string.connect_status_fail'));
        this.isConnected = false;
      }
    };
    this.hdcClient.setCallback(callback);
    this.hdcClient.setWorkPath(this.workPath);
    const portMatch = this.cmdInput.match(/:(\d+)/);
    const port = portMatch ? portMatch[1] : this.defaultPort;
    const ip = this.defaultIP;
    if (!port || port === '') {
      this.logService.appendLog('[Connect] [fail] Port not configured. Please configure port in command input (e.g., tconn 127.0.0.1:5555)');
      this.connectStatus = await context.resourceManager.getStringValue($r('app.string.connect_status_port_not_configured'));
      this.isConnected = false;
      return;
    }

    const config: HdcConnectionConfig = {
      ip: ip,
      port: parseInt(port),
      workPath: this.workPath
    };

    const result = await this.hdcClient.autoConnect(config);
    this.logService.appendLog(result.log);
    // Ensure message is converted to string to avoid [object Object]
    this.connectStatus = String(result.message || '');
    this.isConnected = result.connected;
  }

  build() {
    Stack() {
      Column() {
        Row() {
          Text($r('app.string.home_title'))
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Blank()
          Search({ value: this.searchKeyword, placeholder: $r('app.string.search_placeholder') })
            .width(200)
            .height(36)
            .backgroundColor($r('app.color.card_background'))
            .cancelButton({
              style: CancelButtonStyle.INPUT,
              icon: {
                src: $r('sys.media.ohos_ic_public_cancel_filled')
              }
            })
            .onChange((value: string) => {
              this.searchKeyword = value;
            })
          Button({ type: ButtonType.Circle }) {
            Image($r('app.media.arrow_clockwise'))
              .width(24)
              .height(24)
              .fillColor($r('app.color.icon_color'))
          }
          .width(40)
          .height(40)
          .backgroundColor(Color.Transparent)
          .margin({ left: 8 })
          .onClick(() => {
            this.showRefreshConfirmDialog();
          })
        }
        .width('90%')
        .margin({ top: 20, bottom: 10 })
        Row({ space: 10 }) {
          if (this.isConnected) {
            Circle({ width: 12, height: 12 })
              .fill($r('app.color.success_color'))
          } else if (this.getConnectStatusString().includes('[fail]') || this.getConnectStatusString().includes('失败')) {
            Circle({ width: 12, height: 12 })
              .fill($r('app.color.error_color'))
          } else {
            Circle({ width: 12, height: 12 })
              .fill($r('app.color.text_tertiary'))
          }
          Text(this.getConnectStatusString() || $r('app.string.connect_status_connecting'))
            .fontSize(16)
            .fontColor(this.isConnected ? $r('app.color.success_color') : (this.getConnectStatusString().includes('[fail]') || this.getConnectStatusString().includes('失败') ? $r('app.color.error_color') : $r('app.color.text_secondary')))
        }
        .margin({ bottom: 10 })
        Grid() {
          ForEach(this.getFilteredAppList(), (item: AppInfo, index: number) => {
            GridItem() {
              Row() {
                Image(typeof item.icon === 'string' ? item.icon : item.icon)
                  .width(48)
                  .height(48)
                  .borderRadius(8)
                  .objectFit(ImageFit.Cover)
                Column() {
                  Text(item.appName)
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_primary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width('100%')
                  Text(item.bundleName)
                    .fontSize(12)
                    .fontColor($r('app.color.text_secondary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width('100%')
                    .margin({ top: 4 })
                  Text(item.appver)
                    .fontSize(10)
                    .fontColor($r('app.color.text_secondary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width('100%')
                    .margin({ top: 4 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                .margin({ left: 12 })
                if (item.isGame) {
                  Image($r('app.media.gamepad'))
                    .width(20)
                    .height(20)
                    .fillColor($r('app.color.accent_color'))
                    .margin({ left: 8 })
                }
              }
              .width('100%')
              .height(72)
              .padding(12)
              .backgroundColor($r('app.color.card_background'))
              .borderRadius(8)
              .onClick(() => {
                this.selectedApp = item;
                this.showAppActionDialog = true;
              })
            }
          }, (item: AppInfo, index: number) => `${item.bundleName}_${item.isGame}`)
        }
        .columnsTemplate(this.gridColumns === 1 ? '1fr' : this.gridColumns === 2 ? '1fr 1fr' : '1fr 1fr 1fr')
        .columnsGap(12)
        .rowsGap(12)
        .padding(16)
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring)
        .onAreaChange(() => {
          this.updateGridColumns();
        })
      }
      .width('100%')
      .height('100%')

      if (this.showAppActionDialog && this.selectedApp !== null) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0, 0, 0, 0.5)')
          .onClick(() => {
            this.showAppActionDialog = false;
            this.selectedApp = null;
          })

        this.AppActionDialog()
      }
      if (this.showUninstallConfirmDialog && this.selectedApp !== null) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0, 0, 0, 0.5)')
          .hitTestBehavior(HitTestMode.Block)
          .onClick(() => {
            this.showUninstallConfirmDialog = false;
          })
        this.AppConfirmDialog('uninstall')
      }

      if (this.showCleanConfirmDialog && this.selectedApp !== null) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0, 0, 0, 0.5)')
          .hitTestBehavior(HitTestMode.Block)
          .onClick(() => {
            this.showCleanConfirmDialog = false;
          })
        this.AppConfirmDialog(this.cleanType)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  async startServer() {
    this.hdcClient.setWorkPath(this.workPath);
    const callback: HdcConnectionCallback = {
      onDaemonStarted: () => {
        this.logService.appendLog('[Server] OK');
      },
      onDaemonFailed: (error: string) => {
        this.logService.appendLog(`[Server] Fail: ${error}`);
      }
    };
    this.hdcClient.setCallback(callback);
    await this.hdcClient.startDaemon();
  }

  private showRefreshConfirmDialog() {
    this.getUIContext().showAlertDialog({
      title: $r('app.string.refresh_dialog_title'),
      message: $r('app.string.refresh_dialog_message'),
      autoCancel: false,
      alignment: DialogAlignment.Center,
      offset: { dx: 0, dy: -20 },
      gridCount: 3,
      buttons: [
        {
          enabled: true,
          defaultFocus: true,
          style: DialogButtonStyle.HIGHLIGHT,
          value: $r('app.string.refresh_dialog_confirm'),
          action: () => {
            this.onRefreshClick();
          }
        }],
    });
  }

  async startContinuousTask(): Promise<boolean> {
    if (!this.context) {
      return false;
    }

    let wantAgentInfo: wantAgent.WantAgentInfo = {
      wants: [
        {
          bundleName: "com.ljlvink.gtoolbox",
          abilityName: "EntryAbility"
        }
      ],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: 0,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };

    try {
      const wantAgentObj: WantAgent = await wantAgent.getWantAgent(wantAgentInfo);
      try {
        let list: Array<string> = ["dataTransfer"];
        const res: backgroundTaskManager.ContinuousTaskNotification = await backgroundTaskManager.startBackgroundRunning(this.context, list, wantAgentObj);
        this.logService.appendLog(`[ContinuousTask] Started successfully, notificationId: ${res.notificationId}`);
        return true;
      } catch (error) {
        this.logService.appendLog(`[ContinuousTask] Failed to start: ${(error as BusinessError).message}`);
        return false;
      }
    } catch (error) {
      this.logService.appendLog(`[ContinuousTask] Failed to get WantAgent: ${(error as BusinessError).message}`);
      return false;
    }
  }

  async stopContinuousTask() {
    if (!this.context) {
      this.logService.appendLog('[ContinuousTask] Context not available');
      return;
    }

    try {
      await backgroundTaskManager.stopBackgroundRunning(this.context);
      this.logService.appendLog(`[ContinuousTask] Stopped successfully`);
    } catch (error) {
      this.logService.appendLog(`[ContinuousTask] Failed to stop: ${(error as BusinessError).message}`);
    }
  }

  private sendTcpCommand(command: string, logTag: string, onDataReceived: (jsonData: string) => void) {
    const tcp: socket.TCPSocket = socket.constructTCPSocketInstance();
    const netAddress: socket.NetAddress = {
      address: '127.0.0.1',
      port: 4567
    };
    const tcpConnectOptions: socket.TCPConnectOptions = {
      address: netAddress,
      timeout: 6000
    };
    let receivedData = '';

    tcp.on('message', (value: socket.SocketMessageInfo) => {
      const uint8Array = new Uint8Array(value.message);
      const textDecoder = new util.TextDecoder('utf-8');
      const messageView = textDecoder.decodeWithStream(uint8Array, { stream: true });
      receivedData += messageView;
      if (receivedData.includes('$$$')) {
        const jsonData = receivedData.substring(0, receivedData.indexOf('$$$'));
        onDataReceived(jsonData);
        tcp.close(() => {
          this.logService.appendLog(`[${logTag}] TCP connection closed`);
        });
      }
    });

    tcp.on('error', (err: BusinessError) => {
      this.logService.appendLog(`[${logTag}] TCP error: ${err.message}`);
      tcp.close();
    });

    tcp.on('close', () => {
      this.logService.appendLog(`[${logTag}] TCP connection closed`);
    });

    tcp.connect(tcpConnectOptions, () => {
      this.logService.appendLog(`[${logTag}] TCP connected to 127.0.0.1:4567`);
      const tcpSendOptions: socket.TCPSendOptions = {
        data: command
      };
      tcp.send(tcpSendOptions, (err: BusinessError) => {
        if (err) {
          this.logService.appendLog(`[${logTag}] Failed to send command: ${err.message}`);
          tcp.close();
          return;
        }
        const logCommand = command.length > 50 ? `${command.substring(0, 50)}...` : command;
        this.logService.appendLog(`[${logTag}] Command sent: ${logCommand}`);
      });
    });
  }

  async onRefreshClick() {
    try {
      this.logService.appendLog('[Refresh] Starting app list refresh...');
      const taskStarted = await this.startContinuousTask();
      if (!taskStarted) {
        this.logService.appendLog('[Refresh] Failed to start continuous task, aborting refresh');
        return;
      }
      const context = getContext(this) as common.UIAbilityContext;
      const want: Want = {
        bundleName: 'com.huawei.hmsapp.hismartperf',
        abilityName: 'MainAbility'
      };
      try {
        await context.startAbility(want);
        this.logService.appendLog('[Refresh] HiSmartPerf opened successfully');
      } catch (error) {
        this.logService.appendLog(`[Refresh] Failed to open HiSmartPerf: ${(error as BusinessError).message}`);
        this.hdcClient.installHiSmartPerf();
        await this.stopContinuousTask();
        return;
      }
      await new Promise<void>(resolve => setTimeout(resolve, 1000));
      this.sendTcpCommand('get_bundle_info_no_icon', 'Refresh', async (jsonData: string) => {
        try {
          const appData = JSON.parse(jsonData) as AppDataResponse[];
          let filteredData = appData;
          if (this.hideAtomicService) {
            filteredData = appData.filter((app: AppDataResponse) => !app.package.startsWith('com.atomicservice'));
          }
          this.appList = filteredData.map((app: AppDataResponse): AppInfo => ({
            icon: $r('app.media.fallback'),
            appName: app.name || app.package,
            bundleName: app.package,
            abilityName: app.abilityName,
            appver: app.appVersion,
            isGame: false
          }));
          this.logService.appendLog(`[Refresh] Successfully loaded ${this.appList.length} apps`);
          if (!this.skipAppIcon) {
            this.fetchAppIcons(filteredData);
          } else {
            this.logService.appendLog('[Refresh] Skipping app icon fetch (disabled in settings)');
            await this.saveAppListToCache();
            await this.refreshGameStatus();
            this.pullUpApp();
          }
        } catch (parseError) {
          this.logService.appendLog(`[Refresh] Failed to parse app data: ${(parseError as Error).message}`);
          this.stopContinuousTask();
        }
      });
    } catch (error) {
      this.logService.appendLog(`[Refresh] Error: ${(error as BusinessError).message}`);
      await this.stopContinuousTask();
    }
  }

  async fetchAppIcons(appList: AppDataResponse[]) {
    if (appList.length === 0) {
      return;
    }
    const packageNames = appList.map(app => app.package).join('&&');
    const command = `get_bundle_info&&${packageNames}`;
    this.sendTcpCommand(command, 'Icons', async (jsonData: string) => {
      try {
        const iconData = JSON.parse(jsonData) as AppIconResponse[];
        const iconMap = new Map<string, string>();
        iconData.forEach((item: AppIconResponse) => {
          iconMap.set(item.package, item.icon);
        });
        this.appList = this.appList.map((app: AppInfo): AppInfo => {
          const icon = iconMap.get(app.bundleName);
          if (icon) {
            return {
              icon: icon,
              appName: app.appName,
              bundleName: app.bundleName,
              abilityName: app.abilityName,
              appver: app.appver,
              isGame: app.isGame
            };
          }
          return app;
        });
        this.logService.appendLog(`[Icons] Successfully loaded icons for ${iconData.length} apps`);
        await this.saveAppListToCache();
        await this.refreshGameStatus();
        this.pullUpApp();
      } catch (parseError) {
        this.logService.appendLog(`[Icons] Failed to parse icon data: ${(parseError as Error).message}`);
      }
    });
  }
  async pullUpApp(){
    this.logService.appendLog(`[pullUpApp] pulling up app`);
    try {
      const result = await this.hdcClient.executeCommand("shell aa start -b com.ljlvink.gtoolbox -a EntryAbility");
      this.logService.appendLog(`[pullUpApp] Result: ${result}`);
      await this.stopContinuousTask();
    } catch (error) {
      this.logService.appendLog(`[pullUpApp] Failed: ${(error as Error).message}`);
      await this.stopContinuousTask();
    }
  }

  @Builder
  AppActionDialog() {
      Column() {
        Row() {
          Image(typeof this.selectedApp?.icon === 'string' ? this.selectedApp?.icon : this.selectedApp?.icon)
            .width(40)
            .height(40)
            .borderRadius(8)
          Column() {
            Text(this.selectedApp?.appName || '')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.selectedApp?.bundleName || '')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .margin({ left: 12 })
        }
        .width('100%')
        .padding(16)
        Divider()
          .color($r('app.color.divider_color'))
        Column() {
          Button() {
            Row() {
              Text($r('app.string.open_ability'))
                .fontSize(16)
                .fontColor($r('app.color.text_primary'))
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
          }
          .width('100%')
          .height(50)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.openAbility();
          })
          Divider()
            .color($r('app.color.divider_color'))
          Button() {
            Row() {
              Text($r('app.string.uninstall_app'))
                .fontSize(16)
                .fontColor($r('app.color.error_color'))
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
          }
          .width('100%')
          .height(50)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.showAppActionDialog = false;
            this.showUninstallConfirmDialog = true;
          })
          Divider()
            .color($r('app.color.divider_color'))
          Button() {
            Row() {
              Text($r('app.string.clear_cache'))
                .fontSize(16)
                .fontColor($r('app.color.text_primary'))
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
          }
          .width('100%')
          .height(50)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.cleanType = 'cache';
            this.showAppActionDialog = false;
            this.showCleanConfirmDialog = true;
          })
          Divider()
            .color($r('app.color.divider_color'))
          Button() {
            Row() {
              Text($r('app.string.clear_data'))
                .fontSize(16)
                .fontColor($r('app.color.error_color'))
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
          }
          .width('100%')
          .height(50)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.cleanType = 'data';
            this.showAppActionDialog = false;
            this.showCleanConfirmDialog = true;
          })
          Divider()
            .color($r('app.color.divider_color'))
          if (deviceInfo.sdkApiVersion < 23) {
            Button() {
              Row() {
                Text(this.selectedApp?.isGame ? $r('app.string.remove_from_game') : $r('app.string.set_game'))
                  .fontSize(16)
                  .fontColor($r('app.color.text_primary'))
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
            }
            .width('100%')
            .height(50)
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              this.toggleGameStatus();
            })
            Divider()
              .color($r('app.color.divider_color'))
          }
          Button() {
            Row() {
              Text($r('app.string.cancel'))
                .fontSize(16)
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
          }
          .width('100%')
          .height(50)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.showAppActionDialog = false;
            this.selectedApp = null;
          })
        }
        .width('100%')
      }
      .width('85%')
      .backgroundColor($r('app.color.card_background'))
      .borderRadius(16)
      .shadow({
        radius: 24,
        color: 'rgba(0, 0, 0, 0.15)',
        offsetX: 0,
        offsetY: 8
      })
  }

  async openAbility() {
    if (!this.selectedApp || !this.context) {
      this.logService.appendLog('[OpenAbility] No app selected or context unavailable');
      return;
    }
    this.showAppActionDialog = false;
    const want: Want = {
      bundleName: this.selectedApp.bundleName,
      abilityName: this.selectedApp.abilityName
    };
    try {
      await this.context.startAbility(want);
      this.logService.appendLog(`[OpenAbility] Successfully opened ${this.selectedApp.appName}`);
    } catch (error) {
      this.logService.appendLog(`[OpenAbility] Failed to open ${this.selectedApp.appName}: ${(error as BusinessError).message}`);
    }
    this.selectedApp = null;
  }

  async toggleGameStatus() {
    if (!this.selectedApp) {
      this.logService.appendLog('[GameStatus] No app selected');
      return;
    }
    const appName = this.selectedApp.appName;
    const bundleName = this.selectedApp.bundleName;
    const isCurrentlyGame = this.selectedApp.isGame;
    const newGameStatus = !isCurrentlyGame;
    this.showAppActionDialog = false;
    try {
      let context = getContext(this) as common.UIAbilityContext;
      this.logService.appendLog(`[GameStatus] ${newGameStatus ? 'Adding' : 'Removing'} ${bundleName} ${newGameStatus ? 'to' : 'from'} game list...`);
      const success = await this.hdcClient.setGameStatus(bundleName, newGameStatus);
      if (success) {
        this.logService.appendLog(`[GameStatus] Successfully ${newGameStatus ? 'added' : 'removed'} ${bundleName} ${newGameStatus ? 'to' : 'from'} game list`);
        const updatedList = this.appList.map((app: AppInfo): AppInfo => {
          if (app.bundleName === bundleName) {
            return {
              icon: app.icon,
              appName: app.appName,
              bundleName: app.bundleName,
              abilityName: app.abilityName,
              appver: app.appver,
              isGame: newGameStatus
            };
          }
          return app;
        });
        this.appList = [...updatedList];
        await this.saveAppListToCache();
        const successMsg = newGameStatus ?
          await context.resourceManager.getStringValue($r('app.string.game_set_success')) :
          await context.resourceManager.getStringValue($r('app.string.game_remove_success'));
        promptAction.showToast({
          message: successMsg.replace('{0}', appName),
          duration: 2000
        });
      } else {
        this.logService.appendLog(`[GameStatus] Failed to update game status for ${bundleName}`);
        promptAction.showToast({
          message: await context.resourceManager.getStringValue($r('app.string.game_status_update_failed')),
          duration: 2000
        });
      }
    } catch (error) {
      let context = getContext(this) as common.UIAbilityContext;
      this.logService.appendLog(`[GameStatus] Error updating game status: ${(error as Error).message}`);
      promptAction.showToast({
        message: await context.resourceManager.getStringValue($r('app.string.game_status_update_error')),
        duration: 2000
      });
    }
    this.selectedApp = null;
  }

  @Builder
  AppConfirmDialog(type: 'uninstall' | 'cache' | 'data') {
    Column() {
      Text(type === 'uninstall'
        ? $r('app.string.confirm_uninstall_title')
        : (type === 'cache' ? $r('app.string.confirm_clear_cache_title') : $r('app.string.confirm_clear_data_title')))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .margin({ top: 20, bottom: 12 })
      Text(this.selectedApp?.appName || '')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .margin({ bottom: 16 })
      Divider()
        .color($r('app.color.divider_color'))
      Row() {
        Button() {
          Text($r('app.string.cancel'))
            .fontSize(16)
            .fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1)
        .height(50)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          if (type === 'uninstall') {
            this.showUninstallConfirmDialog = false;
          } else {
            this.showCleanConfirmDialog = false;
          }
        })
        Divider()
          .color($r('app.color.divider_color'))
          .vertical(true)
          .height(30)
        Button() {
          Text(type === 'uninstall'
            ? $r('app.string.uninstall_app')
            : (type === 'cache' ? $r('app.string.clear_cache') : $r('app.string.clear_data')))
            .fontSize(16)
            .fontColor($r('app.color.error_color'))
        }
        .layoutWeight(1)
        .height(50)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.executeAppAction(type);
        })
      }
      .width('100%')
      .height(50)
    }
    .width('80%')
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(16)
    .shadow({
      radius: 24,
      color: 'rgba(0, 0, 0, 0.15)',
      offsetX: 0,
      offsetY: 8
    })
  }

  async executeAppAction(type: 'uninstall' | 'cache' | 'data') {
    if (!this.selectedApp) {
      this.logService.appendLog(`[${type}] No app selected`);
      return;
    }
    const appName = this.selectedApp.appName;
    const bundleName = this.selectedApp.bundleName;

    if (type === 'uninstall') {
      this.showUninstallConfirmDialog = false;
    } else {
      this.showCleanConfirmDialog = false;
    }
    this.showAppActionDialog = false;

    const tag = type === 'uninstall' ? 'Uninstall' : (type === 'cache' ? 'ClearCache' : 'ClearData');
    const command = type === 'uninstall'
      ? `shell bm uninstall -n ${bundleName}`
      : `shell bm clean --${type} -n ${bundleName}`;
    const successKey = type === 'uninstall'
      ? $r('app.string.uninstall_success')
      : (type === 'cache' ? $r('app.string.clear_cache_success') : $r('app.string.clear_data_success'));
    const failKey = type === 'uninstall'
      ? $r('app.string.uninstall_failed')
      : (type === 'cache' ? $r('app.string.clear_cache_failed') : $r('app.string.clear_data_failed'));

    try {
      const context = getContext(this) as common.UIAbilityContext;
      this.logService.appendLog(`[${tag}] Executing on ${bundleName}...`);
      const result = await this.hdcClient.executeCommand(command);
      if (type !== 'uninstall') {
        this.logService.appendLog(result);
      }
      const isSuccess = !result.includes('[fail]') && !result.includes('[Fail]') && !result.toLowerCase().includes('error');
      if (isSuccess) {
        if (type === 'uninstall') {
          this.logService.appendLog(`[${tag}] Successfully uninstalled ${bundleName}`);
          this.appList = this.appList.filter((app: AppInfo) => app.bundleName !== bundleName);
          await this.saveAppListToCache();
        } else {
          this.logService.appendLog(`[${tag}] Success`);
        }
        const successMsg = await context.resourceManager.getStringValue(successKey);
        promptAction.showToast({ message: successMsg.replace('{0}', appName), duration: 2000 });
      } else {
        this.logService.appendLog(`[${tag}] Failed: ${result}`);
        const failMsg = await context.resourceManager.getStringValue(failKey);
        promptAction.showToast({ message: failMsg.replace('{0}', appName).replace('{1}', result), duration: 2000 });
      }
    } catch (error) {
      const context = getContext(this) as common.UIAbilityContext;
      const errorMsg = (error as Error).message;
      this.logService.appendLog(`[${tag}] Error: ${errorMsg}`);
      const failMsg = await context.resourceManager.getStringValue(failKey);
      promptAction.showToast({ message: failMsg.replace('{0}', appName).replace('{1}', errorMsg), duration: 2000 });
    }
    this.selectedApp = null;
  }
}