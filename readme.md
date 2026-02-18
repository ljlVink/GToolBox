# GToolBox

用于提升在HarmonyOS下侧载游戏性能的工具。

## 原理

通过HiSmartPerf获取应用列表，使用HDC命令强制将应用拉回前台。

发送特定事件激活游戏服务，并设置app为游戏类型。

## 参考

- [LHDC](https://github.com/ljlVink/developtools_hdc)
- [HiSmartPerf Device](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/smartperf-guidelines)
- [HiSH](https://github.com/harmoninux/HiSH)