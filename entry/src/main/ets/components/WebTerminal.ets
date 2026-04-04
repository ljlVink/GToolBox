/*
Original code from https://github.com/harmoninux/HiSH/blob/master/entry/src/main/ets/components/WebTerminal.ets

*/
import util from '@ohos.util';
import { buffer } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import napi from 'libhdc_napi.so';
import { webview } from '@kit.ArkWeb';
import { pasteboard, deviceInfo } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';

const DOMAIN = 0x0000;

// Device type detection for virtual key sizing
const isPhone = deviceInfo.deviceType === 'phone';
const VKeyMargin = isPhone ? 1 : 2;
const VKeyPadding = isPhone ? 2 : 4;
const VKeyHeight = 28;
const VKeyWidth = isPhone ? 48 : 60;
const VKeyFontSize = isPhone ? 11 : 14;
const VKeyRadius = 5;

@Component
export default struct WebTerminal {
  @Require virtKeyEnabled: boolean
  @Prop isShellRunning: boolean = false
  @State ctrlPressed: boolean = false
  @State shiftPressed: boolean = false
  @State showVirtKey: boolean = true
  webviewController: WebviewController = new webview.WebviewController()
  resizeTimeout?: number = undefined

  @Builder
  contextMenu(webController: WebviewController) {
    Flex({
      direction: FlexDirection.Column
    }) {
      MenuItem({ content: $r('app.string.terminal_copy') })
        .width('100%')
        .onClick(async () => {
          const selection = await webController.runJavaScript('exports.copy()')
          if (selection !== '""') {
            let text: string = JSON.parse(selection);
            const board = pasteboard.getSystemPasteboard()
            const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text)
            board.setData(pasteData)
          }
        })
      MenuItem() {
        PasteButton({ buttonType: ButtonType.ROUNDED_RECTANGLE })
          .onClick(async (event: ClickEvent, result: PasteButtonOnClickResult) => {
            if (PasteButtonOnClickResult.SUCCESS === result) {
              let board = pasteboard.getSystemPasteboard();
              const data = await board.getData()
              const text = data.getPrimaryText()
              webController.runJavaScript(`exports.paste('${text.replace(/'/g, "\\'")}')`)
            }
          })
          .width('100%')
          .align(Alignment.Start)
          .backgroundColor('#292b2e')
      }
    }
    .width('160vp')
  }

  @Builder
  buildVKey(name: string, value: string) {
    Button(name, { buttonStyle: ButtonStyleMode.TEXTUAL })
      .height(VKeyHeight)
      .width(VKeyWidth)
      .borderRadius(VKeyRadius)
      .fontSize(VKeyFontSize)
      .fontColor($r('sys.color.white'))
      .margin(VKeyMargin)
      .padding({ left: VKeyPadding, right: VKeyPadding })
      .onClick(() => {
        this.sendInput(value)
      })
  }

  @Builder
  toggleCtrlKey(name: string, action: () => void) {
    Toggle({ type: ToggleType.Button, isOn: this.ctrlPressed }) {
      Text(name).fontSize(VKeyFontSize).fontWeight(FontWeight.Medium)
    }
    .height(VKeyHeight)
    .width(VKeyWidth)
    .borderRadius(VKeyRadius)
    .margin(VKeyMargin)
    .backgroundColor($r('sys.color.black'))
    .selectedColor($r('sys.color.interactive_active'))
    .onClick(() => action())
  }

  @Builder
  toggleShiftKey(name: string, action: () => void) {
    Toggle({ type: ToggleType.Button, isOn: this.shiftPressed }) {
      Text(name).fontSize(VKeyFontSize).fontWeight(FontWeight.Medium)
    }
    .height(VKeyHeight)
    .width(VKeyWidth)
    .borderRadius(VKeyRadius)
    .margin(VKeyMargin)
    .backgroundColor($r('sys.color.black'))
    .selectedColor($r('sys.color.interactive_active'))
    .onClick(() => action())
  }

  @Builder
  hideVKeyButton() {
    Button('▼', { buttonStyle: ButtonStyleMode.TEXTUAL })
      .height(VKeyHeight)
      .width(VKeyHeight)
      .borderRadius(VKeyRadius)
      .margin(VKeyMargin)
      .padding({ left: VKeyPadding, right: VKeyPadding })
      .fontColor($r('sys.color.white'))
      .onClick(() => {
        this.showVirtKey = false
      })
  }

  build() {
    Column() {
      Stack({ alignContent: Alignment.TopEnd }) {
        Web({
          src: $rawfile('term/term.html'),
          controller: this.webviewController
        })
        .javaScriptProxy({
          object: this,
          name: 'native',
          methodList: ['sendInput', 'resize', 'load'],
          controller: this.webviewController,
          asyncMethodList: [],
          permission: `{
          "javascriptProxyPermission": {
            "urlPermissionList": [
              {
                "scheme": "resource",
                "host": "rawfile",
                "port": "",
                "path": ""
              }
            ]
          }
        }`
        })
          .backgroundColor('#000')
          .layoutWeight(1)
          .bindContextMenu(this.contextMenu(this.webviewController), ResponseType.RightClick)
        Circle({ width: 8, height: 8 })
          .fill(this.isShellRunning ? $r('app.color.success_color') : $r('app.color.error_color'))
          .margin({ top: 8, right: 8 })
      }
      .layoutWeight(1)

      if (this.virtKeyEnabled) {
        if (this.showVirtKey) {
          this.buildVirtualKeys()
        } else {
          this.buildShowVirtualKeysButton()
        }
      }
    }
    .height('100%')
  }

  @Builder
  buildShowVirtualKeysButton() {
    Column() {
      Button('▲', { buttonStyle: ButtonStyleMode.TEXTUAL })
        .width(120)
        .height(16)
        .fontSize(16)
        .borderRadius(VKeyRadius)
        .fontColor('#444')
        .padding({ left: VKeyPadding, right: VKeyPadding })
        .onClick(() => {
          this.showVirtKey = true
        })
    }
    .width('100%')
  }

  @Builder
  buildVirtualKeys() {
    Column() {
      Row() {
        this.buildVKey('ESC', '\x1b');
        this.toggleShiftKey('SHIFT', () => this.toggleShift());

        Row().layoutWeight(1);

        this.buildVKey('PGUP', '\x1b[5~');
        this.buildVKey('HOME', '\x1b[H');
        this.buildVKey('↑', '\x1b[A');
        this.buildVKey('END', '\x1b[F');

        this.hideVKeyButton();
      }
      .margin({ left: 5, right: 5 })

      Row() {
        this.buildVKey('TAB', '\t');
        this.toggleCtrlKey('CTRL', () => this.toggleCtrl());

        Row().layoutWeight(1);

        this.buildVKey('PGDN', '\x1b[6~');
        this.buildVKey('←', '\x1b[D');
        this.buildVKey('↓', '\x1b[B');
        this.buildVKey('→', '\x1b[C');
      }
      .margin({ left: 5, right: 5 })
    }
  }

  private toggleCtrl(): void {
    this.ctrlPressed = !this.ctrlPressed;
  }

  private toggleShift(): void {
    this.shiftPressed = !this.shiftPressed;
  }

  // ============== for javascript in ArkWeb ================

  sendInput(data: string): void {
    hilog.info(DOMAIN, 'WebTerminal', 'sendInput, data: %{public}s', data);

    // Handle Ctrl state: convert lowercase letters to control characters
    if (this.ctrlPressed && data.length === 1) {
      const char = data.charAt(0);
      if (char >= 'a' && char <= 'z') {
        data = String.fromCharCode(char.charCodeAt(0) - 'a'.charCodeAt(0) + 1);
        hilog.info(DOMAIN, 'WebTerminal', 'sendInput with Ctrl, converted to control char');
      }
      // Reset Ctrl after sending
      this.toggleCtrl()
    }

    // Handle Shift state: convert lowercase to uppercase
    if (this.shiftPressed && data.length === 1) {
      const char = data.charAt(0);
      if (char >= 'a' && char <= 'z') {
        data = char.toUpperCase();
        hilog.info(DOMAIN, 'WebTerminal', 'sendInput with Shift, converted to: %{public}s', data);
      }
    }

    // Check if shell session is running before sending input
    if (!this.isShellRunning) {
      hilog.warn(DOMAIN, 'WebTerminal', 'Shell session is not running, attempting to start...');
      this.isShellRunning = napi.startShell();
      if (!this.isShellRunning) {
        hilog.error(DOMAIN, 'WebTerminal', 'Failed to start shell session');
        return;
      }
    }

    try {
      napi.sendInput(data);
    } catch (e) {
      hilog.error(DOMAIN, 'WebTerminal', 'sendInput failed: %{public}s', JSON.stringify(e));
      // Shell may have stopped unexpectedly, reset state
      this.isShellRunning = false;
    }
  }

  async load(): Promise<void> {
    this.webviewController.runJavaScript('exports.setFocused(true)')
    // Start shell session and register data callback
    this.isShellRunning = napi.startShell();
    if (!this.isShellRunning) {
      hilog.error(DOMAIN, 'WebTerminal', 'Failed to start shell session on load');
    }
    // For libhdc_napi, onData callback receives string
    napi.onData((data: string) => this.onData(data))
  }

  async resize(width: number, height: number): Promise<void> {
    //diabled
  }

  // Performance optimization: output buffer
  private pendingChunks: string[] = [];
  private flushTimeoutID: number | undefined = undefined;
  private readonly FLUSH_INTERVAL = 16; // 60FPS (16.6ms)

  private onData(data: string) {
    try {
      // Add received data chunk to queue
      this.pendingChunks.push(data);

      // If no pending flush task, schedule one
      if (this.flushTimeoutID === undefined) {
        this.flushTimeoutID = setTimeout(() => {
          this.flushData();
        }, this.FLUSH_INTERVAL);
      }
    } catch (e) {
      hilog.error(DOMAIN, 'WebTerminal', 'onData failed: %{public}s', JSON.stringify(e));
    }
  }

  private flushData() {
    this.flushTimeoutID = undefined;

    if (this.pendingChunks.length === 0) return;

    try {
      // Merge all chunks
      const merged = this.pendingChunks.join('');
      this.pendingChunks = [];

      // Encode to base64 and send to webview
      const encoder = util.TextEncoder.create('utf-8');
      const bytes = encoder.encodeInto(merged);
      const base64Helper = new util.Base64Helper();
      const base64 = base64Helper.encodeToStringSync(bytes);
      this.webviewController.runJavaScript(`exports.writeBase64("${base64}", false)`);

    } catch (e) {
      hilog.error(DOMAIN, 'WebTerminal', 'flushData failed: %{public}s', JSON.stringify(e));
      this.pendingChunks = [];
    }
  }

  getDeviceType(): string {
    return deviceInfo.deviceType;
  }
}
