import { router } from "@kit.ArkUI";
import { HdcClient } from "../utils/HdcClient";
import { picker } from "@kit.CoreFileKit";
import { fileIo as fs } from "@kit.CoreFileKit";
import { BusinessError } from "@kit.BasicServicesKit";
import { util } from "@kit.ArkTS";

interface FileSaveResult {
  uri: string;
  fd: number;
}

interface FaultLogDetailParams {
  logFileName: string;
  logType: string;
  packageName: string;
  dateTime: string;
  pid: string;
}

class TextChunk {
  id: string;
  content: string;

  constructor(id: string, content: string) {
    this.id = id;
    this.content = content;
  }
}

class TextChunkDataSource implements IDataSource {
  private chunks: TextChunk[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.chunks.length;
  }

  getData(index: number): TextChunk {
    return this.chunks[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    this.listeners.push(listener);
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const idx = this.listeners.indexOf(listener);
    if (idx >= 0) {
      this.listeners.splice(idx, 1);
    }
  }

  setChunks(chunks: TextChunk[]): void {
    this.chunks = chunks;
    for (const listener of this.listeners) {
      listener.onDataReloaded();
    }
  }

  getChunks(): TextChunk[] {
    return this.chunks;
  }
}

@Entry
@Component
struct FaultLogDetailPage {
  @State isLoading: boolean = true;
  @State errorMsg: string = "";
  @State isSaving: boolean = false;
  @State hasContent: boolean = false;
  private hdcClient: HdcClient = new HdcClient();
  private logFileName: string = "";
  private logType: string = "";
  private packageName: string = "";
  private dateTime: string = "";
  private pid: string = "";
  private rawLogContent: string = "";
  private chunkDataSource: TextChunkDataSource = new TextChunkDataSource();
  private static readonly CHUNK_LINES = 80;

  aboutToAppear() {
    const params = router.getParams() as FaultLogDetailParams;
    if (params) {
      this.logFileName = params.logFileName;
      this.logType = params.logType;
      this.packageName = params.packageName;
      this.dateTime = params.dateTime;
      this.pid = params.pid;
    }
    this.fetchLogDetail();
  }

  private splitTextToChunks(text: string): TextChunk[] {
    const lines = text.split("\n");
    const chunks: TextChunk[] = [];
    for (let i = 0; i < lines.length; i += FaultLogDetailPage.CHUNK_LINES) {
      const end = Math.min(i + FaultLogDetailPage.CHUNK_LINES, lines.length);
      const chunkLines: string[] = [];
      for (let j = i; j < end; j++) {
        chunkLines.push(lines[j]);
      }
      chunks.push(new TextChunk(`chunk_${i}`, chunkLines.join("\n")));
    }
    return chunks;
  }

  async fetchLogDetail() {
    this.isLoading = true;
    this.errorMsg = "";
    this.rawLogContent = "";
    this.hasContent = false;
    this.chunkDataSource.setChunks([]);
    try {
      const cmd = `shell hidumper -s 1201 -a "-p Faultlogger -f ${this.logFileName}"`;
      console.log(cmd);
      const result = await this.hdcClient.executeCommand(cmd);
      const separator = "================================================================";
      const sepIdx = result.indexOf(separator);
      const logBody = sepIdx >= 0 ? result.substring(result.indexOf("\n", sepIdx) + 1) : result;
      this.rawLogContent = logBody;
      this.chunkDataSource.setChunks(this.splitTextToChunks(logBody));
      this.hasContent = logBody.length > 0;
    } catch (error) {
      this.errorMsg = (error as Error).message;
    }
    this.isLoading = false;
  }

  async callFilePickerSaveFile(filename: string): Promise<FileSaveResult | undefined> {
    try {
      let documentSaveOptions = new picker.DocumentSaveOptions();
      documentSaveOptions.newFileNames = [filename];
      let documentPicker = new picker.DocumentViewPicker();
      const documentSaveResult = await documentPicker.save(documentSaveOptions);
      if (documentSaveResult && documentSaveResult.length > 0) {
        const uri = documentSaveResult[0];
        let file: fs.File | null = null;
        try {
          file = await fs.open(uri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
          const fd = file.fd;
          return { uri, fd };
        } catch (openErr) {
          console.error(
            `callFilePickerSaveFile failed to open file: ${(openErr as BusinessError).message}`,
          );
          return { uri, fd: -1 };
        }
      }
      return undefined;
    } catch (err) {
      const error = err as BusinessError;
      console.error(`callFilePickerSaveFile error: ${error.code}, ${error.message}`);
      return undefined;
    }
  }

  async saveLogToFile() {
    if (this.isSaving || this.rawLogContent.length === 0) {
      return;
    }
    this.isSaving = true;
    try {
      const filename = `${this.logFileName}`;
      const saveResult = await this.callFilePickerSaveFile(filename);
      if (saveResult && saveResult.fd >= 0) {
        const encoder = new util.TextEncoder();
        const encoded = encoder.encodeInto(this.rawLogContent);
        await fs.write(saveResult.fd, encoded.buffer);
        await fs.close(saveResult.fd);
      }
    } catch (error) {
      console.error(`Save log failed: ${(error as Error).message}`);
    }
    this.isSaving = false;
  }

  typeColor(type: string): string {
    if (type === "cppcrash") {
      return "#E53935";
    }
    if (type === "jscrash") {
      return "#FB8C00";
    }
    if (type === "appfreeze") {
      return "#F9A825";
    }
    return "#757575";
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
        Column({ space: 2 }) {
          Row({ space: 6 }) {
            Text(this.logType)
              .fontSize(10)
              .fontColor("#FFFFFF")
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .backgroundColor(this.typeColor(this.logType))
              .borderRadius(4)
            Text(this.packageName)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor($r("app.color.text_primary"))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          Row({ space: 10 }) {
            Text(`PID: ${this.pid}`)
              .fontSize(11)
              .fontColor($r("app.color.text_tertiary"))
            Text(this.dateTime)
              .fontSize(11)
              .fontColor($r("app.color.text_secondary"))
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
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
          .enabled(this.hasContent)
          .onClick(() => {
            this.saveLogToFile();
          });
        }
      }
      .width("100%")
      .padding({ left: 12, right: 12, top: 12, bottom: 8 })

      // Content area
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
            .color($r("app.color.icon_color"))
          Text($r("app.string.fault_log_loading"))
            .fontSize(14)
            .fontColor($r("app.color.text_tertiary"))
            .margin({ top: 12 })
        }
        .width("100%")
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center);
      } else if (this.errorMsg.length > 0) {
        Column() {
          Text(this.errorMsg)
            .fontSize(13)
            .fontColor($r("app.color.error_color"))
            .width("90%")
            .padding(12)
            .backgroundColor($r("app.color.card_background"))
            .borderRadius(8)
          Button($r("app.string.retry_button"))
            .margin({ top: 12 })
            .onClick(() => {
              this.fetchLogDetail();
            })
        }
        .width("100%")
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center);
      } else {
        List() {
          LazyForEach(
            this.chunkDataSource,
            (chunk: TextChunk) => {
              ListItem() {
                Text(chunk.content)
                  .fontSize(11)
                  .fontColor($r("app.color.text_primary"))
                  .fontFamily("monospace")
                  .width("100%")
                  .padding({ left: 12, right: 12 })
                  .wordBreak(WordBreak.BREAK_ALL)
                  .copyOption(CopyOptions.LocalDevice)
              };
            },
            (chunk: TextChunk) => chunk.id,
          )
        }
        .cachedCount(3)
        .layoutWeight(1)
        .width("100%")
        .edgeEffect(EdgeEffect.Spring)
        .backgroundColor($r("app.color.card_background"))
        .margin({ left: 12, right: 12, bottom: 12 })
        .borderRadius(10)
        .padding({ top: 12, bottom: 12 });
      }
    }
    .width("100%")
    .height("100%")
    .backgroundColor($r("app.color.page_background"));
  }
}
