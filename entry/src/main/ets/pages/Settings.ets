import { preferences } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { common, OpenLinkOptions } from '@kit.AbilityKit';

@Component
export struct SettingsPage {
  @State portInput: string = '5555';
  @State saveStatus: string = '';
  @State hideAtomicService: boolean = true;
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
      this.portInput = savedPort as string;
      this.hideAtomicService = savedHideAtomic as boolean;
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

  build() {

    Column() {
      Row() {
        Text($r('app.string.settings_title'))
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
      }
      .width('90%')
      .margin({ top: 20, bottom: 20 })
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
