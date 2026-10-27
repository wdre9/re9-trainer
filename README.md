# 生化危机9 安魂曲 修改器 / Resident Evil Requiem Trainer

**版本 Version:** v11.2 ・ **协议 License:** GPL-3.0-or-later ・ **平台 Platform:** Windows (Steam / Epic) ・ **框架 Framework:** REFramework (Nightly)

一个基于 [REFramework](https://github.com/praydog/REFramework) 的 Lua 修改器，运行于《生化危机9 安魂曲 / Resident Evil Requiem》游戏内，提供战斗、武器、经济三类功能，界面支持简体中文与 English 一键切换。

A Lua trainer for *Resident Evil Requiem* running inside the game via REFramework. Combat, weapon and economy toggles with a bilingual (Chinese / English) in-game UI.

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

| 功能 | Feature | 配置字段 | 实现方式 |
|---|---|---|---|
| 无敌 / 无视伤害 | God Mode / Ignore Hits | `god` | 每帧调用 `HitPoint.set_Invincible(true)` + `setNoDieCharacter(true)`，血量低于上限时回满。关闭时恢复开启前的原状态，不覆盖剧情或其他 mod 的设置 |
| 无限生命 | Infinite Health | `inf_hp` | 每帧把 `CurrentHitPoint` 拉回 `CurrentMaximumHitPoint` |
| 无限投掷物 | Infinite Throwables | `inf_throw` | Hook `app.Inventory.consumeStock` 的两个重载，命中时返回 `SKIP_ORIGINAL` 阻止库存扣减。**注意：这是通用入口拦截，实际覆盖范围见下方说明** |
| 无限弹药 | Infinite Ammo | `inf_ammo` | 只读 Hook 组合：`getLoadedAmmoCount` 后置返回弹匣容量、`isAmmoEmpty` 恒 `false`、`setLoadedAmmoCount` 拦写、`consumeLoading` 跳过 |
| 无需换弹 | No Reload | `no_reload` | 复用无限弹药机制（弹药不消耗即无需换弹）。换弹进行中会放行原逻辑，避免打断装填状态机 |
| 即时重载 | Instant Reload | `instant_reload` | 每帧把 `PlayerGun` 的 `_ReloadSpeed` / `_BoltActionSpeed` / `_ShootMotionSpeed` 拉到极大值，关闭时还原原值 |
| 无后坐力 | No Recoil | `no_recoil` | Hook `app.CameraRecoilController.addRecoil` / `updateRecoil`，返回 `SKIP_ORIGINAL` |
| 快速射击 | Rapid Fire | `rapid_fire` | 每帧把 `PlayerEquipment` 的 `_ShotInterval` / `_ExcessShotInterval` / `_AddShotInterVal` 置 0，关闭时还原 |
| 高伤害（两枪击杀） | High Damage (2-shot kill) | `ohk` | Hook `HitPoint.addDamageHitPoint` 登记命中目标，随后在帧回调里补一次高额伤害结算；会先排除玩家自身 |
| CP 点数 | CP Points | `cp_value` | 写入 `app.AchievementManager._TotalClearPoint`，写后读回校验，失败时按 `RecordManager` / `BonusManager` / `GameDataManager` 顺序回退尝试 |

**关于「无限投掷物」覆盖范围 / About Infinite Throwables scope**

该开关拦截的是库存消耗的通用入口 `app.Inventory.consumeStock`，**不区分物品类型**。因此实际生效范围包括：

- 投掷物（手雷、燃烧瓶等）
- 治疗类消耗品（医疗注射器、急救喷雾等）
- 其他经由同一入口扣减的消耗品，可能包含合成材料

也就是说，开启后这些物品的数量都不会减少。这是 v11.2 的既定行为，不是 bug，但也不是精确的白名单实现。按物品类型收窄范围已列入后续计划。

This toggle hooks the generic stock-consumption entry `app.Inventory.consumeStock` **without filtering by item type**. It therefore covers throwables, healing consumables (syringes, first-aid spray) and anything else routed through the same call — possibly crafting materials. Precise per-item filtering is on the roadmap.

---

## 环境要求 / Requirements

| 项目 | 要求 |
|---|---|
| 游戏 | Resident Evil Requiem / 生化危机9 安魂曲（Steam 或 Epic 版本） |
| 框架 | **REFramework Nightly 版本**（必须）。Release 稳定版的 Lua API 可能缺少本脚本用到的字段与方法 |
| 平台 | Windows 10 / 11，64 位 |
| 运行方式 | 游戏内脚本，不需要额外进程，不需要 Cheat Engine |

**必须使用 Nightly。** 使用稳定版时，`app.PlayerEquipment` / `app.PlayerGun` 的部分方法可能不存在，脚本会把这些 Hook 块标记为 `missing` 并跳过，对应功能静默失效（不会崩溃）。

---

## 安装 / Installation

1. 确认游戏目录下已安装 REFramework，即存在 `reframework\` 目录和 `dinput8.dll`。
2. 把 `marvis_re9_trainer.lua` 放到：

```
<游戏安装目录>\reframework\autorun\marvis_re9_trainer.lua
```

3. 启动游戏，进入存档（存档界面内的玩家上下文未就绪，功能在进入可操作世界后才生效）。

```
<游戏安装目录>\
├─ dinput8.dll
└─ reframework\
   ├─ autorun\
   │  └─ marvis_re9_trainer.lua   ← 本脚本
   └─ data\
      ├─ marvis_re9_trainer.json  ← 配置（脚本自动生成）
      └─ marvis_probe.json        ← 调试日志（仅 dbg 开启时生成）
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

字段说明：

| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `lang` | string | `"zh"` | 界面语言，`"zh"` 或 `"en"` |
| `god` | bool | `false` | 无敌 / 无视伤害 |
| `inf_hp` | bool | `false` | 无限生命 |
| `inf_ammo` | bool | `false` | 无限弹药 |
| `no_reload` | bool | `false` | 无需换弹 |
| `instant_reload` | bool | `false` | 即时重载 |
| `no_recoil` | bool | `false` | 无后坐力 |
| `rapid_fire` | bool | `false` | 快速射击 |
| `ohk` | bool | `false` | 高伤害（两枪击杀） |
| `inf_throw` | bool | `false` | 无限投掷物 |
| `cp_value` | number | `0` | 要写入的 CP 数值，非负整数 |
| `dbg` | bool | `false` | 调试面板与调试日志开关，默认隐藏 |

**打开调试面板**：关闭游戏，编辑上面的 json，把 `"dbg"` 改成 `true` 再启动游戏。开启后在主窗口之外会多出一个 `wdre9 DEBUG` 窗口，显示 Hook 代数、各 Hook 计数器、当前 PE/Gun 引用类型，并可一键重置计数。

同时会在 `reframework\data\marvis_probe.json` 写诊断日志，上限 800 行（约 100 KB），写满即停，不会无限增长。**日常使用请保持 `dbg` 为 `false`**，否则会有额外磁盘写入。

调试字段初值参考：

```json
{
  "lang": "zh",
  "god": false,
  "inf_hp": false,
  "inf_ammo": false,
  "no_reload": false,
  "instant_reload": false,
  "no_recoil": false,
  "rapid_fire": false,
  "ohk": false,
  "inf_throw": false,
  "cp_value": 0,
  "dbg": false
}
```

---

## 已知限制 / Known Limitations

1. **必须 Nightly**。使用 REFramework 稳定版时部分功能会静默失效。
2. **高伤害是「两枪击杀」，不是真正的一击必杀**。引擎对单次伤害有钳制，第一枪压到临界值，第二枪由游戏自身逻辑结算击杀，死亡表现正常。
3. **阶段性 Boss 有伤害上限或无敌帧**，改伤害无法跳过阶段转换。
4. **CP 字段是 UInt64**，只能填非负数；写入后可能需要在主菜单往返一次或重新读档才能刷新显示。
5. **游戏没有「黄金」货币**，本工具未做金钱修改。
6. **无限投掷物是通用入口拦截**，会连带影响医疗注射器、急救喷雾等治疗消耗品，也可能影响合成材料，详见[功能一览](#功能一览--features)。
7. 调试面板默认隐藏，需手动在 json 里加 `"dbg": true`。
8. 换弹状态标志设有 10 秒超时兜底：换弹被移动或受击打断时，标志会被强制清除，防止误判为持续换弹而放行弹药扣减。
9. 当前 **v11.2 脚本文件头部尚未加 SPDX 许可证标识**。仓库整体按 GPL-3.0-or-later 授权，从 v11.3 起会在脚本首行加入 SPDX 标识（届时文件哈希会变化，届时更新下方校验值）。

---

## 文件校验 / File Verification

v11.2 发布文件：

| 项目 | 值 |
|---|---|
| 文件 | `reframework/autorun/marvis_re9_trainer.lua` |
| 大小 | 51,985 字节 |
| 行数 | 1,144 |
| SHA256 | `8FFDA0B41BCB54F0335CCB4E85A9AF932AF4E4334512C850AFE362BC3D188BCF` |

Windows 校验命令：

```powershell
Get-FileHash .\marvis_re9_trainer.lua -Algorithm SHA256
```

哈希不一致说明文件被修改或被第三方二次打包，请勿使用。

---

## 自行开发与调试 / Development & Debugging

本脚本为单文件 Lua，无构建步骤，改完保存、游戏内按 REFramework 面板的「Reset Scripts」或重启游戏即可生效。

开发要点：

- **状态表存放在 `_G`**（`_G.__MARVIS_RE9_TRAINER_CFG__`），这样 Reset 后 Hook 回调与 UI 仍共享同一状态，避免重复注册 Hook。
- **Hook 注册是分块且幂等的**：每块有 `installed` / `failed` / `missing` 三种状态，`failed` 下一帧重试，`missing` 表示当前框架版本不存在该方法，不阻塞其他功能。
- **不要在 Hook 回调里调用被 Hook 的函数**。REFramework 会判定递归并抛异常，连带破坏正常伤害结算。本脚本的做法是在 Hook 里只登记目标，实际游戏调用延后到 `on_frame`。
- **探查字段优先用类型定义逐个列名**，不要用不存在的批量扫描 API。
- 日志走 `log.info`（REFramework 控制台）与可选 `marvis_probe.json`。

Contributions are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).

---

## 参与贡献 / Contributing

- 提交 PR 前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。
- 所有提交必须带 DCO 签名：`git commit -s`。
- 字段相关的改动**必须附上探测证据**（`dump_type_methods` 输出、日志片段或截图），否则不予合并。
- 只接受经过实机验证的改动。请注明测试使用的游戏版本与 REFramework Nightly 构建日期。
- Bug 报告请使用 Issue 模板，并填写游戏版本、REFramework 版本、复现步骤。

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
