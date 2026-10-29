# 生化危机9 安魂曲 修改器 / Resident Evil Requiem Trainer

**版本 Version:** v11.11 ・ **协议 License:** GPL-3.0-or-later ・ **平台 Platform:** Windows (Steam / Epic) ・ **框架 Framework:** REFramework (Nightly)

一个基于 [REFramework](https://github.com/praydog/REFramework) 的《生化危机9 安魂曲 / Resident Evil Requiem》游戏内修改器，提供战斗、武器、经济三类功能，界面支持简体中文与 English 一键切换。

An in-game trainer for *Resident Evil Requiem*, running on REFramework. Combat, weapon and economy toggles with a bilingual (Chinese / English) UI.

> 本工具为单机离线使用，不联网、不上传任何数据。详见 [免责声明](#免责声明--disclaimer)。
>
> Offline single-player only. No network access, no telemetry. See [Disclaimer](#免责声明--disclaimer).

---

## 目录 / Table of Contents

- [功能一览](#功能一览--features)
- [环境要求](#环境要求--requirements)
- [安装](#安装--installation)
- [使用](#使用--usage)
- [配置文件](#配置文件--configuration)
- [已知限制](#已知限制--known-limitations)
- [文件校验](#文件校验--file-verification)
- [自行开发与调试](#自行开发与调试--development--debugging)
- [参与贡献](#参与贡献--contributing)
- [免责声明](#免责声明--disclaimer)
- [许可](#许可--license)
- [致谢](#致谢--credits)

---

## 功能一览 / Features

界面分为「战斗 / Combat」「武器 / Weapon」「经济 / Economy」三个分区。

| 功能 | Feature | 效果 |
|---|---|---|
| 无敌 / 无视伤害 | God Mode / Ignore Hits | 受到攻击不掉血，也不会被判定致死。关闭后立即恢复正常受伤逻辑，不影响剧情演出与其他模组的设定 |
| 无限生命 | Infinite Health | 生命条始终保持满值 |
| 无限投掷物 | Infinite Throwables | 投掷物数量不再减少；实际覆盖范围见下方说明 |
| 无限弹药 | Infinite Ammo | 弹匣内弹药不再消耗，界面数字同步不跳动 |
| 无需换弹 | No Reload | 持续射击不会触发换弹动作 |
| 无后坐力 | No Recoil | 连续开火时准星不上跳、不偏移 |
| 快速射击 | Rapid Fire | 射速大幅提升，可长时间压制 |
| 高伤害（两枪击杀） | High Damage (2-shot kill) | 命中敌人造成极高伤害，通常两枪击杀；不会误伤自己 |
| CP 点数 | CP Points | 把关通点数直接设为指定值，界面即时刷新 |

**关于「无限投掷物」的覆盖范围 / About Infinite Throwables scope**

这个开关的作用是让消耗品「用不掉」。它**不区分物品种类**，因此开启后以下物品的数量都不会减少：

- 投掷物（手雷、燃烧瓶等）
- 治疗类消耗品（医疗注射器、急救喷雾等）
- 其他同类消耗品，可能包含合成材料

也就是说这是一项「消耗品不减」的效果，而不是只针对投掷物的精确开关。按物品类别收窄范围已列入后续计划。

This toggle makes consumables non-depleting **without filtering by item type**, so it also covers healing items (syringes, first-aid spray) and possibly crafting materials — not throwables alone. Precise per-category filtering is planned.

---

## 环境要求 / Requirements

| 项目 | 要求 |
|---|---|
| 游戏 | Resident Evil Requiem / 生化危机9 安魂曲（Steam 或 Epic 版本） |
| 框架 | **REFramework Nightly 版本**（必须）。Release 稳定版的脚本接口可能不完整 |
| 平台 | Windows 10 / 11，64 位 |
| 运行方式 | 游戏内脚本，不需要额外进程，不需要 Cheat Engine |

**必须使用 Nightly。** 使用稳定版时，部分功能可能静默失效（开关可勾选但不生效），脚本不会崩溃，也不会影响游戏本体运行。

---

## 安装 / Installation

1. 确认游戏目录下已安装 REFramework，即存在 `reframework\` 目录和 `dinput8.dll`。
2. 把 `marvis_re9_trainer.lua` 放到：

```
<游戏安装目录>\reframework\autorun\marvis_re9_trainer.lua
```

3. 启动游戏，进入存档（存档界面内玩家尚未就绪，功能在进入可操作世界后才生效）。

```
<游戏安装目录>\
├─ dinput8.dll
└─ reframework\
   ├─ autorun\
   │  └─ marvis_re9_trainer.lua   ← 本脚本
   └─ data\
      ├─ marvis_re9_trainer.json  ← 配置（脚本自动生成）
      └─ marvis_probe.json        ← 调试日志（仅调试项开启时生成）
```

**卸载**：删除 `reframework\autorun\marvis_re9_trainer.lua`，并按需删除 `reframework\data\marvis_re9_trainer.json`。

---

## 使用 / Usage

1. 游戏内按 `Insert`（REFramework 默认 UI 键，可在框架设置中修改）打开 REFramework 面板。
2. 切到 **Script Generated UI** 分区，找到 `wdre9 RE9 修改器` 窗口。
3. 勾选需要的功能，开关即时生效，无需重启或读档。
4. 界面顶部可在「简体中文 / English」之间切换，选择会随配置保存。
5. CP 修改：在输入框填入非负整数，点「应用 CP」。

部分功能（无敌、无限生命、无限弹药、CP）依赖玩家上下文，需进入可操作世界后再操作。在主菜单或读档过程中勾选不报错，但不会立刻生效。

---

## 配置文件 / Configuration

脚本自动读写：

```
<游戏安装目录>\reframework\data\marvis_re9_trainer.json
```

配置文件由脚本自动生成，界面中的开关与语言选择会自动保存到该文件，**日常使用无需手动编辑**。

**调试面板（隐藏项）**：关闭游戏，编辑该 json 打开调试项后重启游戏，主窗口之外会多出一个 `wdre9 DEBUG` 窗口，显示运行状态与各项计数，并可一键清零重新统计。同时会在 `reframework\data\marvis_probe.json` 写诊断日志，上限 800 行（约 100 KB），写满即停，不会无限增长。**日常使用请保持调试项关闭**，否则会有额外磁盘写入。

---

## 已知限制 / Known Limitations

1. **必须 Nightly**。使用 REFramework 稳定版时部分功能会静默失效。
2. **高伤害是「两枪击杀」，不是真正的一击必杀**。游戏对单次伤害设有上限，第一枪压到临界值，第二枪由游戏自身逻辑结算击杀，死亡表现正常。
3. **阶段性 Boss 有伤害上限或无敌帧**，改伤害无法跳过阶段转换。
4. **CP 只能填非负整数**；写入后可能需要在主菜单往返一次或重新读档才能刷新显示。
5. **游戏没有「黄金」货币**，本工具未做金钱修改。
6. **无限投掷物是「消耗品不减」效果**，会连带影响医疗注射器、急救喷雾等治疗消耗品，也可能影响合成材料，详见[功能一览](#功能一览--features)。
7. 调试面板默认隐藏，需手动编辑配置文件打开调试项（见[配置文件](#配置文件--configuration)）。
8. 换弹过程中移动或被击退导致换弹中断时，功能不会误判为「仍在换弹」而漏掉弹药消耗。
9. 开启无敌后，某些剧情演出中的强制伤害可能一并被免疫；遇到剧情无法推进时请先关闭该功能。

---

## 文件校验 / File Verification

v11.11 发布文件：

| 项目 | 值 |
|---|---|
| 文件 | `reframework/autorun/marvis_re9_trainer.lua` |
| 大小 | 53,397 字节 |
| 行数 | 1,094 |
| SHA256 | `3E84360A6C6B75A02D60EB85EF477A3D791035F9D770B95A878A90A85C35A5E9` |

Windows 校验命令：

```powershell
Get-FileHash .\marvis_re9_trainer.lua -Algorithm SHA256
```

哈希不一致说明文件被修改或被第三方二次打包，请勿使用。

---

## 自行开发与调试 / Development & Debugging

本脚本为单文件 Lua，没有构建步骤。修改保存后，在 REFramework 面板点「Reset Scripts」或重启游戏即可生效。

调试可用配置文件中的隐藏调试项打开面板与日志（见[配置文件](#配置文件--configuration)）。日志会记录功能启停与异常兜底事件，提 Issue 时附上相关片段能显著加快定位。

希望提交改动的，请先阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。本项目只接受经过实机验证的改动。

---

## 参与贡献 / Contributing

- 提交 PR 前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。
- 所有提交必须带 DCO 签名：`git commit -s`。
- 功能相关的改动**必须附上实机验证记录**（游戏版本、Nightly 构建日期、测试步骤与结果），否则不予合并。
- Bug 报告请使用 Issue 模板，并填写游戏版本、REFramework 版本、复现步骤与日志片段。

---

## 免责声明 / Disclaimer

- 本工具仅用于**单机离线**游戏体验，**禁止**用于联机模式、排行榜、速通计时提交或任何形式的竞技场景。
- 本工具**不联网**，不收集、不上传任何数据，不修改游戏外文件。
- 使用修改器可能导致存档异常、成就判定异常或游戏崩溃，**风险自负**。
- 本项目与 CAPCOM CO., LTD. 无任何关联，未获其授权或背书。《Resident Evil》《BIOHAZARD》为 CAPCOM 的商标，此处仅作描述性引用。
- 请支持正版游戏。使用本工具前建议备份存档。

- For **offline single-player use only**. Do not use in multiplayer, leaderboards, or speedrun submissions.
- No network access, no telemetry, no data collection.
- Save corruption and crash risks are borne by the user. Back up your saves.
- Not affiliated with or endorsed by CAPCOM. All trademarks belong to their respective owners.

---

## 许可 / License

本项目以 **GNU General Public License v3.0 or later** 授权，全文见 [LICENSE](LICENSE)。

脚本首行含机器可读的 SPDX 标识：

```lua
-- SPDX-License-Identifier: GPL-3.0-or-later
```

```
Copyright (C) 2026 wdre9

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
```

二次分发（包括修改后再分发）必须保留版权声明与许可证，并提供完整对应源码。不得附加额外限制。

---

## 致谢 / Credits

- [praydog/REFramework](https://github.com/praydog/REFramework) — RE 引擎脚本框架与 Lua API
- RE 引擎逆向与 trainer 社区的公开研究成果

REFramework 以 **MIT 协议**授权（Copyright (c) 2019 praydog）。其完整版权声明与许可证文本已在本仓库根目录存档，见 [REFramework_LICENSE](REFramework_LICENSE)，再分发时请一并保留。

REFramework is licensed under the **MIT License** (Copyright (c) 2019 praydog). The full copyright notice and license text are archived at [REFramework_LICENSE](REFramework_LICENSE) in the repository root; keep it when redistributing.

---
