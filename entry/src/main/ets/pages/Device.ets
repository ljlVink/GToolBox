import { LogService } from '../utils/LogService';
import { HdcClient } from '../utils/HdcClient';

@Component
export struct DevicePage {
  private hdcClient: HdcClient = new HdcClient();

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
      }
      .width('90%')
      .margin({ top: 20 })

    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
