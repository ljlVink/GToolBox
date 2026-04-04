import { hilog } from "@kit.PerformanceAnalysisKit";
import napi from "libhdc_napi.so";
import WebTerminal from "../components/WebTerminal";

const DOMAIN = 0x0000;

@Entry
@Component
struct TerminalPage {
  @State isShellRunning: boolean = false;
  @State shellOutput: string = "";

  async aboutToAppear() {
    hilog.info(DOMAIN, "TerminalPage", "aboutToAppear");
    await this.startShell();
  }

  async startShell() {
    try {
      hilog.info(DOMAIN, "TerminalPage", "Starting shell...");
      const result = napi.startShell();
      this.isShellRunning = result;
      hilog.info(DOMAIN, "TerminalPage", "Shell started: %{public}s", result.toString());
    } catch (e) {
      hilog.error(DOMAIN, "TerminalPage", "Failed to start shell: %{public}s", JSON.stringify(e));
    }
  }

  build() {
    Column() {
      WebTerminal({ virtKeyEnabled: true, isShellRunning: this.isShellRunning }).layoutWeight(1)
    }
    .width("100%")
    .height("100%")
    .backgroundColor("#000");
  }
}

export { TerminalPage };
