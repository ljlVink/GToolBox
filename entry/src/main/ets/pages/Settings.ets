import { preferences } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { common, OpenLinkOptions } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { router } from '@kit.ArkUI';

@Component
export struct SettingsPage {
  @State portInput: string = '5555';
  @State saveStatus: string = '';
  @State hideAtomicService: boolean = true;
  @State skipAppIcon: boolean = true;
  @State deleteKeyStatus: string = '';
  private preferencesStore: preferences.Preferences | null = null;

  async aboutToAppear() {
    await this.loadSettings();
  }

  async loadSettings() {
    try {
      let context = getContext(this) as common.UIAbilityContext;
      this.preferencesStore = await preferences.getPreferences(context, 'hdc_settings');
      const savedPort = await this.preferencesStore.get('port', '5555');
      const savedHideAtomic = await this.preferencesStore.get('hideAtomicService', true);
      const savedSkipAppIcon = await this.preferencesStore.get('skipAppIcon', true);
      this.portInput = savedPort as string;
      this.hideAtomicService = savedHideAtomic as boolean;
      this.skipAppIcon = savedSkipAppIcon as boolean;
    } catch (error) {
      console.error('Failed to load settings: ' + (error as BusinessError).message);
    }
  }

  async saveSettings() {
    try {
      if (!this.portInput || this.portInput.trim() === '') {
        let context = getContext(this) as common.UIAbilityContext;
        this.saveStatus = await context.resourceManager.getStringValue($r('app.string.settings_port_required'));
        return;
      }

      const portNum = parseInt(this.portInput);
      if (isNaN(portNum) || portNum < 1 || portNum > 65535) {
        let context = getContext(this) as common.UIAbilityContext;
        this.saveStatus = await context.resourceManager.getStringValue($r('app.string.settings_port_invalid'));
        return;
      }
      if (this.preferencesStore) {
        await this.preferencesStore.put('port', this.portInput);
        await this.preferencesStore.put('ip', '127.0.0.1');
        await this.preferencesStore.put('hideAtomicService', this.hideAtomicService);
        await this.preferencesStore.put('skipAppIcon', this.skipAppIcon);
        await this.preferencesStore.flush();
        let context = getContext(this) as common.UIAbilityContext;
        this.saveStatus = await context.resourceManager.getStringValue($r('app.string.settings_save_success'));
      }
    } catch (error) {
      let context = getContext(this) as common.UIAbilityContext;
      let errorMsg = await context.resourceManager.getStringValue($r('app.string.settings_save_failed'));
      this.saveStatus = errorMsg.replace('{0}', (error as BusinessError).message);
    }
  }

  openGithubLink() {
    try {
      let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      let link: string = "https://github.com/ljlvink/GToolBox";
      let openLinkOptions: OpenLinkOptions = {
        appLinkingOnly: false,
        parameters: {}
      };
      context.openLink(link, openLinkOptions)
    } catch (e) {

    }
  }
  private async tryDeleteFile(path: string): Promise<boolean> {
    try {
      await fs.unlink(path);
      return true;
    } catch {
      return false;
    }
  }

  async deleteHdcKeys() {
    const keyPath = '/data/storage/el2/base/haps/entry/files/hdckey';
    const pubKeyPath = '/data/storage/el2/base/haps/entry/files/hdckey.pub';
    const context = getContext(this) as common.UIAbilityContext;
    try {
      const results = await Promise.all([
        this.tryDeleteFile(keyPath),
        this.tryDeleteFile(pubKeyPath)
      ]);
      const strRes = (results[0] || results[1])
        ? $r('app.string.delete_key_success')
        : $r('app.string.delete_key_not_found');
      this.deleteKeyStatus = await context.resourceManager.getStringValue(strRes);
    } catch (error) {
      const errorMsg = await context.resourceManager.getStringValue($r('app.string.delete_key_failed'));
      this.deleteKeyStatus = errorMsg.replace('{0}', (error as BusinessError).message);
    }
  }

  build() {
    Column() {
      Column({ space: 20 }) {
          Column({ space: 8 }) {
            Text($r('app.string.settings_port_label'))
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .alignSelf(ItemAlign.Start)

            TextInput({ text: this.portInput, placeholder: $r('app.string.settings_port_placeholder') })
              .width('100%')
              .height(50)
              .fontSize(16)
              .type(InputType.Number)
              .onChange((value: string) => {
                this.portInput = value;
                this.saveStatus = '';
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          Row() {
            Text($r('app.string.settings_hide_atomic_service'))
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
            Blank()
            Toggle({ type: ToggleType.Switch, isOn: this.hideAtomicService })
              .selectedColor($r('app.color.primary_color'))
              .onChange((isOn: boolean) => {
                this.hideAtomicService = isOn;
                this.saveStatus = '';
              })
          }
          .width('100%')
          .height(50)

          Row() {
            Text($r('app.string.settings_skip_app_icon'))
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
            Blank()
            Toggle({ type: ToggleType.Switch, isOn: this.skipAppIcon })
              .selectedColor($r('app.color.primary_color'))
              .onChange((isOn: boolean) => {
                this.skipAppIcon = isOn;
                this.saveStatus = '';
              })
          }
          .width('100%')
          .height(50)

          Button($r('app.string.settings_save_button'))
            .width('100%')
            .height(50)
            .fontSize(18)
            .backgroundColor($r('app.color.primary_color'))
            .onClick(() => {
              this.saveSettings();
            })

          if (this.saveStatus !== '') {
            Text(String(this.saveStatus))
              .fontSize(14)
              .fontColor(this.saveStatus.includes('success') ? $r('app.color.success_color') : $r('app.color.error_color'))
              .margin({ top: 10 })
          }

          Button($r('app.string.delete_key_button'))
            .width('100%')
            .height(50)
            .fontSize(18)
            .backgroundColor($r('app.color.error_color'))
            .onClick(async () => {
              let context = getContext(this) as common.UIAbilityContext;
              let confirmTitle = await context.resourceManager.getStringValue($r('app.string.delete_key_confirm_title'));
              let confirmMsg = await context.resourceManager.getStringValue($r('app.string.delete_key_confirm_message'));
              let confirmBtn = await context.resourceManager.getStringValue($r('app.string.refresh_dialog_confirm'));
              let cancelBtn = await context.resourceManager.getStringValue($r('app.string.cancel'));

              AlertDialog.show({
                title: confirmTitle,
                message: confirmMsg,
                autoCancel: true,
                alignment: DialogAlignment.Center,
                primaryButton: {
                  value: cancelBtn,
                  action: () => {
                    // 取消操作
                  }
                },
                secondaryButton: {
                  value: confirmBtn,
                  fontColor: $r('app.color.error_color'),
                  action: () => {
                    this.deleteHdcKeys();
                  }
                }
              });
            })

          if (this.deleteKeyStatus !== '') {
            Text(String(this.deleteKeyStatus))
              .fontSize(14)
              .fontColor(this.deleteKeyStatus.includes('success') || this.deleteKeyStatus.includes('成功') ?
                $r('app.color.success_color') : $r('app.color.error_color'))
              .margin({ top: 5 })
          }

          Row() {
            Image($r('app.media.doc_plaintext'))
              .width(20)
              .height(20)
              .fillColor($r('app.color.text_primary'))
            Text($r('app.string.logs_title'))
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .margin({ left: 12 })
            Blank()
            Text('›')
              .fontSize(22)
              .fontColor($r('app.color.text_tertiary'))
          }
          .width('100%')
          .height(50)
          .onClick(() => {
            router.pushUrl({ url: 'pages/LogPage' });
          })

          Column({ space: 12 }) {
            Divider()
              .margin({ top: 20, bottom: 10 })

            Text('Gtoolbox')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .alignSelf(ItemAlign.Start)

            Row() {
              Text('GitHub')
                .fontSize(14)
                .fontColor($r('app.color.primary_color'))
                .decoration({ type: TextDecorationType.Underline })
                .onClick(() => {
                  this.openGithubLink();
                })
            }
            .alignSelf(ItemAlign.Start)

            Text('GToolBox是免费开源软件，如果你付费购买请立即退款并问候其家人')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .lineHeight(22)
              .textAlign(TextAlign.Start)
              .width('100%')
            Text('GToolBox is free and open-source software. If you paid for it, please refund immediately and greet their family members.')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .lineHeight(22)
              .textAlign(TextAlign.Start)
              .width('100%')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

        }
        .width('90%')
        .margin({ top: 20 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_background'))
  }
}
