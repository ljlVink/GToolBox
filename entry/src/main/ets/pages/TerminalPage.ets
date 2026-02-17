import { hilog } from '@kit.PerformanceAnalysisKit';
import napi from 'libhdc_napi.so';
import WebTerminal from '../components/WebTerminal';

const DOMAIN = 0x0000;

@Entry
@Component
struct TerminalPage {
  @State isShellRunning: boolean = false;
  @State shellOutput: string = '';

  async aboutToAppear() {
    hilog.info(DOMAIN, 'TerminalPage', 'aboutToAppear');
    await this.startShell();
  }

  async startShell() {
    try {
      hilog.info(DOMAIN, 'TerminalPage', 'Starting shell...');
      const result = napi.startShell();
      this.isShellRunning = result;
      hilog.info(DOMAIN, 'TerminalPage', 'Shell started: %{public}s', result.toString());
    } catch (e) {
      hilog.error(DOMAIN, 'TerminalPage', 'Failed to start shell: %{public}s', JSON.stringify(e));
    }
  }


  build() {
    Column() {
      Row() {
        Text('HDC Shell')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        
        Blank()
        
        Row({ space: 8 }) {
          Circle({ width: 8, height: 8 })
            .fill(this.isShellRunning ? $r('app.color.success_color') : $r('app.color.error_color'))


        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .backgroundColor($r('app.color.page_background'))

      WebTerminal({ virtKeyEnabled: true })
        .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000')
  }
}

export { TerminalPage }
