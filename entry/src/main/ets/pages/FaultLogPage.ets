import { HdcClient } from '../utils/HdcClient';
import { router } from '@kit.ArkUI';

interface FaultLogEntry {
  type: string;
  packageName: string;
  pid: string;
  dateTime: string;
  raw: string;
}

interface AppGroup {
  packageName: string;
  entries: FaultLogEntry[];
}

@Component
export struct FaultLogPage {
  @State isLoading: boolean = false;
  @State filteredGrouped: AppGroup[] = [];
  @State filteredCount: number = 0;
  @State filterType: string = 'all';
  @State errorMsg: string = '';
  @State totalCount: number = 0;
  @State expandedApps: string[] = [];
  @State searchKeyword: string = '';
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

  groupEntries(entries: FaultLogEntry[]): AppGroup[] {
    const groups: AppGroup[] = [];
    for (let i = 0; i < entries.length; i++) {
      const entry = entries[i];
      let found = false;
      for (let j = 0; j < groups.length; j++) {
        if (groups[j].packageName === entry.packageName) {
          groups[j].entries.push(entry);
          found = true;
          break;
        }
      }
      if (!found) {
        groups.push({ packageName: entry.packageName, entries: [entry] });
      }
    }
    return groups;
  }

  isExpanded(packageName: string): boolean {
    return this.expandedApps.indexOf(packageName) >= 0;
  }

  toggleExpand(packageName: string) {
    const idx = this.expandedApps.indexOf(packageName);
    const newArr: string[] = [];
    for (let i = 0; i < this.expandedApps.length; i++) {
      newArr.push(this.expandedApps[i]);
    }
    if (idx >= 0) {
      newArr.splice(idx, 1);
    } else {
      newArr.push(packageName);
    }
    this.expandedApps = newArr;
  }

  applyFilter(type: string) {
    this.filterType = type;
    let filtered: FaultLogEntry[];
    if (type === 'all') {
      filtered = this.allEntries.slice();
    } else {
      const result: FaultLogEntry[] = [];
      for (let i = 0; i < this.allEntries.length; i++) {
        if (this.allEntries[i].type === type) {
          result.push(this.allEntries[i]);
        }
      }
      filtered = result;
    }
    this.filteredCount = filtered.length;
    this.filteredGrouped = this.groupEntries(filtered);
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
      this.filteredGrouped = [];
      this.filteredCount = 0;
      this.totalCount = 0;
    }
    this.isLoading = false;
  }

  getVisibleGroups(): AppGroup[] {
    if (!this.searchKeyword || this.searchKeyword.trim() === '') {
      return this.filteredGrouped;
    }
    const keyword = this.searchKeyword.toLowerCase().trim();
    const result: AppGroup[] = [];
    for (let i = 0; i < this.filteredGrouped.length; i++) {
      if (this.filteredGrouped[i].packageName.toLowerCase().includes(keyword)) {
        result.push(this.filteredGrouped[i]);
      }
    }
    return result;
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
        Search({ value: this.searchKeyword, placeholder: $r('app.string.search_placeholder') })
          .layoutWeight(1)
          .height(36)
          .backgroundColor($r('app.color.card_background'))
          .cancelButton({
            style: CancelButtonStyle.INPUT,
            icon: {
              src: $r('sys.media.ohos_ic_public_cancel_filled')
            }
          })
          .onChange((value: string) => {
            this.searchKeyword = value;
          })

        if (this.isLoading) {
          LoadingProgress()
            .width(40)
            .height(40)
            .color($r('app.color.icon_color'))
            .margin({ left: 8 })
        } else {
          Button({ type: ButtonType.Circle }) {
            Image($r('app.media.arrow_clockwise'))
              .width(24)
              .height(24)
              .fillColor($r('app.color.icon_color'))
          }
          .width(40)
          .height(40)
          .backgroundColor(Color.Transparent)
          .margin({ left: 8 })
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
          Text(type === 'all' ? $r('app.string.fault_log_filter_all') : type)
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
        Text(getContext(this).resourceManager.getStringSync($r('app.string.fault_log_records_info').id, this.filteredCount, this.getVisibleGroups().length))
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

      // Grouped log list
      List({ space: 8 }) {
        ForEach(this.getVisibleGroups(), (group: AppGroup) => {
          ListItem() {
            Column() {
              Row({ space: 8 }) {
                Text('󰃙')  // this symbol is copied from https://developer.huawei.com/consumer/cn/design/harmonyos-symbol
                  .fontSize(15)
                  .fontColor($r('app.color.primary_color'))
                  .rotate({ angle: this.isExpanded(group.packageName) ? 90 : 0 })
                  .animation({ duration: 200 })

                Text(group.packageName)
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Text(`${group.entries.length}`)
                  .fontSize(11)
                  .fontColor('#FFFFFF')
                  .padding({ left: 7, right: 7, top: 2, bottom: 2 })
                  .backgroundColor($r('app.color.primary_color'))
                  .borderRadius(10)
              }
              .width('100%')
              .padding(14)
              .backgroundColor($r('app.color.card_background'))
              .borderRadius(
                this.isExpanded(group.packageName)
                  ? { topLeft: 10, topRight: 10, bottomLeft: 0, bottomRight: 0 }
                  : { topLeft: 10, topRight: 10, bottomLeft: 10, bottomRight: 10 }
              )
              .onClick(() => {
                this.toggleExpand(group.packageName);
              })

              // Expanded entries
              if (this.isExpanded(group.packageName)) {
                Column() {
                  ForEach(group.entries, (entry: FaultLogEntry) => {
                    Row({ space: 10 }) {
                      // Type badge
                      Text(entry.type)
                        .fontSize(10)
                        .fontColor('#FFFFFF')
                        .padding({ left: 6, right: 6, top: 3, bottom: 3 })
                        .backgroundColor(this.typeColor(entry.type))
                        .borderRadius(4)

                      // Info
                      Column({ space: 2 }) {
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
                    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
                    .backgroundColor($r('app.color.card_background'))
                    .border({ width: { top: 1 }, color: $r('app.color.page_background') })
                    .onClick(() => {
                      router.pushUrl({
                        url: 'pages/FaultLogDetailPage',
                        params: {
                          logFileName: entry.raw,
                          logType: entry.type,
                          packageName: entry.packageName,
                          dateTime: entry.dateTime,
                          pid: entry.pid
                        }
                      });
                    })
                  }, (entry: FaultLogEntry) => entry.raw)
                }
                .width('100%')
                .borderRadius({ topLeft: 0, topRight: 0, bottomLeft: 10, bottomRight: 10 })
                .clip(true)
              }
            }
            .width('100%')
            .borderRadius(10)
          }
        }, (group: AppGroup) => group.packageName)
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
