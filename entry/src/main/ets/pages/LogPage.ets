import { router } from "@kit.ArkUI";
import { LogService } from "../utils/LogService";
import { picker } from "@kit.CoreFileKit";
import { fileIo as fs } from "@kit.CoreFileKit";
import { BusinessError } from "@kit.BasicServicesKit";
import { util } from "@kit.ArkTS";

@Entry
@Component
struct LogPage {
  @State logText: string = "";
  @State isSaving: boolean = false;
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

  async saveLogToFile() {
    if (this.isSaving || this.logText.length === 0) {
      return;
    }
    this.isSaving = true;
    try {
      const now = new Date();
      const pad = (n: number): string => (n < 10 ? `0${n}` : `${n}`);
      const filename = `log_${now.getFullYear()}${pad(now.getMonth() + 1)}${pad(now.getDate())}_${pad(now.getHours())}${pad(now.getMinutes())}${pad(now.getSeconds())}.txt`;
      let documentSaveOptions = new picker.DocumentSaveOptions();
      documentSaveOptions.newFileNames = [filename];
      let documentPicker = new picker.DocumentViewPicker();
      const result = await documentPicker.save(documentSaveOptions);
      if (result && result.length > 0) {
        const uri = result[0];
        let file: fs.File | null = null;
        try {
          file = await fs.open(uri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
          const encoder = new util.TextEncoder();
          const encoded = encoder.encodeInto(this.logText);
          await fs.write(file.fd, encoded.buffer);
          await fs.close(file.fd);
        } catch (openErr) {
          console.error(`Save log failed to open file: ${(openErr as BusinessError).message}`);
        }
      }
    } catch (error) {
      console.error(`Save log failed: ${(error as Error).message}`);
    }
    this.isSaving = false;
  }

  build() {
    Column() {
      // Top bar
      Row() {
        Button({ type: ButtonType.Circle }) {
          Image($r("sys.media.ohos_ic_public_arrow_left"))
            .width(24)
            .height(24)
            .fillColor($r("app.color.icon_color"))
        }
        .width(40)
        .height(40)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          router.back();
        })
        Text($r("app.string.logs_title"))
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r("app.color.text_primary"))
          .layoutWeight(1)
          .margin({ left: 8 })

        if (this.isSaving) {
          LoadingProgress().width(36).height(36).color($r("app.color.icon_color"));
        } else {
          Button({ type: ButtonType.Circle }) {
            Text("󰀻")
              .width(22)
              .height(22)
          }
          .width(40)
          .height(40)
          .backgroundColor(Color.Transparent)
          .enabled(this.logText.length > 0)
          .onClick(() => {
            this.saveLogToFile();
          });
        }
      }
      .width("100%")
      .padding({ left: 12, right: 12, top: 12, bottom: 8 })

      // Log display area
      Scroll() {
        Text(this.logText)
          .fontSize(12)
          .fontColor($r("app.color.text_primary"))
          .fontFamily("monospace")
          .padding(12)
          .width("100%")
          .copyOption(CopyOptions.LocalDevice)
      }
      .layoutWeight(1)
      .width("90%")
      .align(Alignment.TopStart)
      .backgroundColor($r("app.color.card_background"))
      .borderRadius(10)
      .margin({ bottom: 12 })
    }
    .width("100%")
    .height("100%")
    .backgroundColor($r("app.color.page_background"));
  }
}
