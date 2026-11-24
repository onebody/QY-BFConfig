# QYBFConfig

面向 Android 10+ 的 Betaflight / SpeedyBee 兼容飞控调参与数据工具（Flutter）。

## 开发环境准备

本仓库默认使用“仓库内置 Flutter SDK 路径”的方式运行（避免依赖全局安装）。

1. 获取 Flutter stable 到 `.tooling/flutter`（已在本仓库执行过一次即可复用）：

```bash
git clone --depth 1 -b stable https://github.com/flutter/flutter.git .tooling/flutter
```

2. 验证：

```bash
bash scripts/flutterw --version
```

## 常用命令

```bash
# App 依赖
cd QYBFConfig
bash ../scripts/flutterw pub get

# 运行测试
bash ../scripts/flutterw test
```

## 代码结构

- App：`QYBFConfig/`
- 协议与底层能力：`packages/`（当前包含 `qy_msp`：MSP v1 编解码与流式解析）
