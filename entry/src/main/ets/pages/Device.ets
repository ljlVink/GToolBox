import { taskpool } from '@kit.ArkTS';
import { deviceInfo } from '@kit.BasicServicesKit';
import { HdcClient } from '../utils/HdcClient';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { fileUri } from '@kit.CoreFileKit';
import { LogService } from '../utils/LogService';

@Concurrent
async function backgroundCopyFile(selectedUri: string, tempFileUri: string, tempFilePath: string): Promise<string> {
  await fs.copy(selectedUri, tempFileUri);
  return tempFilePath;
}

@Component
export struct DevicePage {
  @State isInstalling: boolean = false;
  private hdcClient: HdcClient = new HdcClient();
  private context: common.UIAbilityContext | null = null;
  private logService: LogService = LogService.getInstance();

  aboutToAppear() {
    this.context = getContext(this) as common.UIAbilityContext;
  }

  async rebootToRecovery() {
    try {
      await this.hdcClient.executeCommand('target boot -recovery');
    } catch (error) {}
  }

  async rebootToBootloader() {
    try {
      await this.hdcClient.executeCommand('target boot -bootloader');
    } catch (error) {}
  }
  async rebootNormal() {
    try {
      await this.hdcClient.executeCommand('target boot');
    } catch (error) {}
  }

  async targetMount() {
    try {
      await this.hdcClient.executeCommand('target mount');
    } catch (error) {}
  }

  async smodeRoot() {
    try {
      await this.hdcClient.executeCommand('smode');
    } catch (error) {}
  }

  async installHapPackage() {
    if (this.isInstalling) {
      this.logService.appendLog('Installation already in progress');
      return;
    }

    if (!this.context) return;

    this.isInstalling = true;
    this.logService.appendLog('Starting HAP installation...');

    try {
      const documentSelectOptions = new picker.DocumentSelectOptions();
      documentSelectOptions.maxSelectNumber = 1;
      const documentViewPicker = new picker.DocumentViewPicker();
      const uris = await documentViewPicker.select(documentSelectOptions);

      if (!uris || uris.length === 0) {
        this.logService.appendLog('No file selected');
        this.isInstalling = false;
        return;
      }

      const selectedUri = uris[0];
      this.logService.appendLog(`Selected file URI: ${selectedUri}`);

      // Yield to UI thread to update log
      await new Promise<void>(resolve => setTimeout(resolve, 50));

      const cacheDir = this.context.cacheDir;
      const tempFileName = `temp_${Date.now()}.hap`;
      const tempFilePath = `${cacheDir}/${tempFileName}`;
      const tempFileUri = fileUri.getUriFromPath(tempFilePath);

      // Copy file (run in taskpool to avoid UI freeze)
      this.logService.appendLog('Copying file...');
      const copyTask = new taskpool.Task(backgroundCopyFile, selectedUri, tempFileUri, tempFilePath);

      const tempFilePathResult = await taskpool.execute(copyTask) as string;
      this.logService.appendLog(`File copied to: ${tempFilePathResult}`);

      // Yield to UI thread
      await new Promise<void>(resolve => setTimeout(resolve, 50));

      try {
        this.logService.appendLog('Installing HAP...');
        let result = await this.hdcClient.executeCommand(`install ${tempFilePathResult}`);
        this.logService.appendLog(result);
        this.logService.appendLog('HAP installation completed');
      } catch (installError) {
        this.logService.appendLog(`Installation failed: ${(installError as Error).message}`);
      } finally {
        try {
          if (fs.accessSync(tempFilePathResult)) {
            fs.unlinkSync(tempFilePathResult);
          }
        } catch (cleanupError) {
          this.logService.appendLog(`Failed to cleanup temporary file: ${(cleanupError as Error).message}`);
        }
      }
    } catch (error) {
      this.logService.appendLog(`HAP installation failed: ${(error as Error).message}`);
    } finally {
      this.isInstalling = false;
    }
  }

  build() {
    Column() {
      Row() {
        Text($r('app.string.device_title'))
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
      }
      .width('90%')
      .margin({ top: 20, bottom: 20 })

      Column({ space: 20 }) {
        Button() {
          Row({ space: 12 }) {
            if (this.isInstalling) {
              LoadingProgress()
                .width(24)
                .height(24)
                .color($r('app.color.button_text'))
            } else {
              Image($r('app.media.install_hap'))
                .width(24)
                .height(24)
                .fillColor($r('app.color.button_text'))
            }
            Text(this.isInstalling ? $r('app.string.installing') : $r('app.string.install_hap'))
              .fontSize(18)
              .fontColor($r('app.color.button_text'))
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .height(56)
        .backgroundColor($r('app.color.primary_color'))
        .borderRadius(12)
        .enabled(!this.isInstalling)
        .onClick(() => {
          this.installHapPackage();
        })
        Button() {
          Row({ space: 12 }) {
            Image($r('app.media.rays'))
              .width(24)
              .height(24)
              .fillColor($r('app.color.button_text'))
            Text($r('app.string.reboot_nornal'))
              .fontSize(18)
              .fontColor($r('app.color.button_text'))
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .height(56)
        .backgroundColor($r('app.color.success_color'))
        .borderRadius(12)
        .onClick(() => {
          this.rebootNormal();
        })
        Button() {
          Row({ space: 12 }) {
            Image($r('app.media.rays'))
              .width(24)
              .height(24)
              .fillColor($r('app.color.button_text'))
            Text($r('app.string.reboot_recovery'))
              .fontSize(18)
              .fontColor($r('app.color.button_text'))
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .height(56)
        .backgroundColor($r('app.color.primary_color'))
        .borderRadius(12)
        .onClick(() => {
          this.rebootToRecovery();
        })

        Button() {
          Row({ space: 12 }) {
            Image($r('app.media.rays'))
              .width(24)
              .height(24)
              .fillColor($r('app.color.button_text'))
            Text($r('app.string.reboot_bootloader'))
              .fontSize(18)
              .fontColor($r('app.color.button_text'))
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .height(56)
        .backgroundColor($r('app.color.accent_color'))
        .borderRadius(12)
        .onClick(() => {
          this.rebootToBootloader();
        })

        if (deviceInfo.distributionOSName !== 'HarmonyOS') {
          Button() {
            Row({ space: 12 }) {
              Image($r('app.media.rays'))
                .width(24)
                .height(24)
                .fillColor($r('app.color.button_text'))
              Text($r('app.string.target_mount'))
                .fontSize(18)
                .fontColor($r('app.color.button_text'))
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
          }
          .width('100%')
          .height(56)
          .backgroundColor($r('app.color.error_color'))
          .borderRadius(12)
          .onClick(() => {
            this.targetMount();
          })

          Button() {
            Row({ space: 12 }) {
              Image($r('app.media.rays'))
                .width(24)
                .height(24)
                .fillColor($r('app.color.button_text'))
              Text($r('app.string.smode_root'))
                .fontSize(18)
                .fontColor($r('app.color.button_text'))
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
          }
          .width('100%')
          .height(56)
          .backgroundColor($r('app.color.error_color'))
          .borderRadius(12)
          .onClick(() => {
            this.smodeRoot();
          })
        }
      }
      .width('90%')
      .margin({ top: 20 })

    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
