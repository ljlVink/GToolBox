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

  @Builder
  SectionHeader(title: string) {
    Text(title)
      .fontSize(13)
      .fontColor($r('app.color.text_tertiary'))
      .fontWeight(FontWeight.Medium)
      .width('100%')
      .padding({ left: 4, bottom: 6 })
  }

  @Builder
  ActionRow(icon: Resource, label: Resource | string, iconBgColor: ResourceColor, onClick: () => void) {
    Row() {
      Row() {
        Image(icon)
          .width(18)
          .height(18)
          .fillColor(Color.White)
      }
      .width(32)
      .height(32)
      .borderRadius(8)
      .backgroundColor(iconBgColor)
      .justifyContent(FlexAlign.Center)

      if (typeof label === 'string') {
        Text(label)
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .margin({ left: 14 })
          .layoutWeight(1)
      } else {
        Text(label as Resource)
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .margin({ left: 14 })
          .layoutWeight(1)
      }

      Image($r('sys.media.ohos_ic_public_arrow_right'))
        .width(16)
        .height(16)
        .fillColor($r('app.color.text_tertiary'))
    }
    .width('100%')
    .height(52)
    .padding({ left: 14, right: 14 })
    .onClick(onClick)
  }

  build() {
    Column() {
      // Page Title
      Row() {
        Text($r('app.string.device_title'))
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 20, bottom: 8 })

      Scroll() {
        Column({ space: 20 }) {
          // === Install Section ===
          Column() {
            this.SectionHeader('Package')
            Column() {
              Row() {
                Row() {
                  if (this.isInstalling) {
                    LoadingProgress()
                      .width(18)
                      .height(18)
                      .color(Color.White)
                  } else {
                    Image($r('app.media.install_hap'))
                      .width(18)
                      .height(18)
                      .fillColor(Color.White)
                  }
                }
                .width(32)
                .height(32)
                .borderRadius(8)
                .backgroundColor($r('app.color.primary_color'))
                .justifyContent(FlexAlign.Center)

                Text(this.isInstalling ? $r('app.string.installing') : $r('app.string.install_hap'))
                  .fontSize(16)
                  .fontColor($r('app.color.text_primary'))
                  .margin({ left: 14 })
                  .layoutWeight(1)

                Image($r('sys.media.ohos_ic_public_arrow_right'))
                  .width(16)
                  .height(16)
                  .fillColor($r('app.color.text_tertiary'))
              }
              .width('100%')
              .height(52)
              .padding({ left: 14, right: 14 })
              .enabled(!this.isInstalling)
              .onClick(() => {
                this.installHapPackage();
              })
            }
            .width('100%')
            .backgroundColor($r('app.color.card_background'))
            .borderRadius(12)
          }
          .width('100%')

          // === Reboot Section ===
          Column() {
            this.SectionHeader('Reboot')
            Column() {
              this.ActionRow($r('app.media.power'), $r('app.string.reboot_nornal'), $r('app.color.success_color'), () => {
                this.rebootNormal();
              })
              Divider().color($r('app.color.divider_color')).margin({ left: 60 })
              this.ActionRow($r('app.media.rays'), $r('app.string.reboot_recovery'), $r('app.color.primary_color'), () => {
                this.rebootToRecovery();
              })
              Divider().color($r('app.color.divider_color')).margin({ left: 60 })
              this.ActionRow($r('app.media.rays'), $r('app.string.reboot_bootloader'), $r('app.color.accent_color'), () => {
                this.rebootToBootloader();
              })
            }
            .width('100%')
            .backgroundColor($r('app.color.card_background'))
            .borderRadius(12)
          }
          .width('100%')

          // === Advanced Section (OpenHarmony only) ===
          if (deviceInfo.distributionOSName !== 'HarmonyOS') {
            Column() {
              this.SectionHeader('Advanced')
              Column() {
                this.ActionRow($r('app.media.bolt'), $r('app.string.target_mount'), $r('app.color.error_color'), () => {
                  this.targetMount();
                })
                Divider().color($r('app.color.divider_color')).margin({ left: 60 })
                this.ActionRow($r('app.media.bolt'), $r('app.string.smode_root'), $r('app.color.error_color'), () => {
                  this.smodeRoot();
                })
              }
              .width('100%')
              .backgroundColor($r('app.color.card_background'))
              .borderRadius(12)
            }
            .width('100%')
          }
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 8, bottom: 24 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
