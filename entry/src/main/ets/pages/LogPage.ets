import { LogService } from '../utils/LogService';

@Component
export struct LogPage {
  @State logText: string = $r('app.string.logs_ready').toString();
  private logService: LogService = LogService.getInstance();
  private logUpdateListener = (logs: string) => {
    this.logText = logs;
  };

  aboutToAppear() {
    this.logText = this.logService.getLogs();
    this.logService.addListener(this.logUpdateListener);
  }

  aboutToDisappear() {
    this.logService.removeListener(this.logUpdateListener);
  }

  build() {
    Column() {
      // Header
      Row() {
        Text($r('app.string.logs_title'))
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))

        Blank()

      }
      .width('90%')
      .margin({ top: 20, bottom: 20 })

      // Log display area
      Scroll() {
        Text(this.logText)
          .fontSize(14)
          .fontColor($r('app.color.text_primary'))
          .padding(10)
          .backgroundColor($r('app.color.log_background'))
          .width('100%')
      }
      .layoutWeight(1)
      .width('90%')
      .align(Alignment.TopStart)
      .border({ width: 1, color: $r('app.color.border_color'), radius: 8 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  appendLog(msg: string) {
    this.logText += msg + "\n";
  }
}
