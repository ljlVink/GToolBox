import { HdcClient } from '../utils/HdcClient';

interface FaultLogEntry {
  type: string;
  packageName: string;
  pid: string;
  dateTime: string;
  raw: string;
}

@Component
export struct FaultLogPage {
  @State isLoading: boolean = false;
  @State filteredEntries: FaultLogEntry[] = [];
  @State filterType: string = 'all';
  @State errorMsg: string = '';
  @State totalCount: number = 0;
  private hdcClient: HdcClient = new HdcClient();
  private allEntries: FaultLogEntry[] = [];

  aboutToAppear() {
    this.fetchFaultLogs();
  }

  formatDateTime(raw: string): string {
    if (raw.length !== 14) {
      return raw;
    }
    const y = raw.substring(0, 4);
    const mo = raw.substring(4, 6);
    const d = raw.substring(6, 8);
    const h = raw.substring(8, 10);
    const mi = raw.substring(10, 12);
    const s = raw.substring(12, 14);
    return `${y}-${mo}-${d} ${h}:${mi}:${s}`;
  }

  parseOutput(output: string): FaultLogEntry[] {
    const entries: FaultLogEntry[] = [];
    const lines = output.split('\n');
    let inList = false;

    for (let i = 0; i < lines.length; i++) {
      const trimmed = lines[i].trim();

      if (trimmed === '******') {
        inList = !inList;
        continue;
      }

      if (inList && trimmed.length > 0) {
        // format: type-packagename-pid-datetime
        const sepIdx1 = trimmed.indexOf('-');
        if (sepIdx1 < 0) {
          continue;
        }
        const type = trimmed.substring(0, sepIdx1);
        if (type !== 'appfreeze' && type !== 'cppcrash' && type !== 'jscrash') {
          continue;
        }
        const rest = trimmed.substring(sepIdx1 + 1);
        // last segment: datetime (14 digits), second-to-last: pid, rest: packageName
        const lastDash = rest.lastIndexOf('-');
        if (lastDash < 0) {
          continue;
        }
        const dateTimeRaw = rest.substring(lastDash + 1);
        if (dateTimeRaw.length !== 14) {
          continue;
        }
        const beforeDateTime = rest.substring(0, lastDash);
        const pidDash = beforeDateTime.lastIndexOf('-');
        if (pidDash < 0) {
          continue;
        }
        const pid = beforeDateTime.substring(pidDash + 1);
        const packageName = beforeDateTime.substring(0, pidDash);

        entries.push({
          type: type,
          packageName: packageName,
          pid: pid,
          dateTime: this.formatDateTime(dateTimeRaw),
          raw: trimmed
        });
      }
    }

    return entries;
  }

  applyFilter(type: string) {
    this.filterType = type;
    if (type === 'all') {
      this.filteredEntries = this.allEntries.slice();
    } else {
      const result: FaultLogEntry[] = [];
      for (let i = 0; i < this.allEntries.length; i++) {
        if (this.allEntries[i].type === type) {
          result.push(this.allEntries[i]);
        }
      }
      this.filteredEntries = result;
    }
  }

  async fetchFaultLogs() {
    this.isLoading = true;
    this.errorMsg = '';
    try {
      const result = await this.hdcClient.executeCommand('shell hidumper -s 1201 -a "-p Faultlogger"');
      this.allEntries = this.parseOutput(result);
      this.totalCount = this.allEntries.length;
      this.applyFilter(this.filterType);
    } catch (error) {
      this.errorMsg = (error as Error).message;
      this.allEntries = [];
      this.filteredEntries = [];
      this.totalCount = 0;
    }
    this.isLoading = false;
  }

  typeColor(type: string): string {
    if (type === 'cppcrash') {
      return '#E53935';
    }
    if (type === 'jscrash') {
      return '#FB8C00';
    }
    if (type === 'appfreeze') {
      return '#F9A825';
    }
    return '#757575';
  }

  build() {
    Column() {
      // Header
      Row() {
        Text($r('app.string.fault_logs_title'))
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))

        Blank()

        if (this.isLoading) {
          LoadingProgress()
            .width(28)
            .height(28)
            .color($r('app.color.primary_color'))
        } else {
          Button({ type: ButtonType.Circle }) {
            Image($r('app.media.arrow_clockwise'))
              .width(20)
              .height(20)
              .fillColor($r('app.color.primary_color'))
          }
          .width(36)
          .height(36)
          .backgroundColor($r('app.color.card_background'))
          .onClick(() => {
            this.fetchFaultLogs();
          })
        }
      }
      .width('90%')
      .margin({ top: 20, bottom: 12 })

      // Filter chips
      Row({ space: 8 }) {
        ForEach(['all', 'cppcrash', 'jscrash', 'appfreeze'], (type: string) => {
          Text(type === 'all' ? 'All' : type)
            .fontSize(12)
            .fontColor(this.filterType === type ? '#FFFFFF' : $r('app.color.text_secondary'))
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .backgroundColor(
              this.filterType === type
                ? (type === 'all' ? $r('app.color.primary_color') : this.typeColor(type))
                : $r('app.color.card_background')
            )
            .borderRadius(16)
            .onClick(() => {
              this.applyFilter(type);
            })
        }, (type: string) => type)
      }
      .width('90%')
      .margin({ bottom: 8 })

      // Record count
      Row() {
        Text(`${this.filteredEntries.length} records`)
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'))
      }
      .width('90%')
      .margin({ bottom: 8 })

      // Error message
      if (this.errorMsg.length > 0) {
        Text(this.errorMsg)
          .fontSize(13)
          .fontColor($r('app.color.error_color'))
          .width('90%')
          .padding(10)
          .backgroundColor($r('app.color.card_background'))
          .borderRadius(8)
          .margin({ bottom: 8 })
      }

      // Log list
      List({ space: 6 }) {
        ForEach(this.filteredEntries, (entry: FaultLogEntry) => {
          ListItem() {
            Row({ space: 10 }) {
              // Type badge
              Text(entry.type)
                .fontSize(10)
                .fontColor('#FFFFFF')
                .padding({ left: 6, right: 6, top: 3, bottom: 3 })
                .backgroundColor(this.typeColor(entry.type))
                .borderRadius(4)

              // Info
              Column({ space: 4 }) {
                Text(entry.packageName)
                  .fontSize(13)
                  .fontColor($r('app.color.text_primary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')

                Row({ space: 10 }) {
                  Text(`PID: ${entry.pid}`)
                    .fontSize(11)
                    .fontColor($r('app.color.text_tertiary'))
                  Text(entry.dateTime)
                    .fontSize(11)
                    .fontColor($r('app.color.text_secondary'))
                }
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .padding(12)
            .backgroundColor($r('app.color.card_background'))
            .borderRadius(10)
            .alignItems(VerticalAlign.Center)
          }
        }, (entry: FaultLogEntry) => entry.raw)
      }
      .layoutWeight(1)
      .width('90%')
      .padding({ bottom: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
