# 参与贡献 / Contributing

感谢你愿意改进这个修改器。为了减少往返，提交前请先读完下面几节。

## 提交前的三条硬性要求

1. **必须带 DCO 签名。** 所有提交请使用：

   ```bash
   git commit -s -m "fix: 修正 xxx"
   ```

   这会在提交信息末尾追加一行 `Signed-off-by: 你的名字 <你的邮箱>`，表示你同意 [Developer Certificate of Origin 1.1](https://developercertificate.org/)。
   本项目**不要求签署 CLA**：你保留自己贡献部分的著作权，并按 GPL-3.0-or-later 授权本项目使用。

2. **字段类改动必须附证据。** 任何涉及游戏内存字段、方法名、类型名的修改，请在 PR 描述里附上探测结果：`dump_type_methods` 输出、`marvis_probe.json` 日志片段、或带时间戳的截图。仅凭"我记得是这个名字"的改动不予合并。

3. **必须实机验证。** PR 描述里写清：游戏版本、REFramework Nightly 构建日期、测试过的功能清单与结果。

## 分支与提交信息

- 从 `main` 切分支：`feat/xxx`、`fix/xxx`、`docs/xxx`。
- 提交信息用 Conventional Commits 前缀：`feat:` / `fix:` / `docs:` / `refactor:` / `chore:`。
- 一个 PR 只做一件事。把格式化、重命名、功能改动混在一个 PR 里会拖慢评审。

## 代码约定

- **不要在 Hook 回调里调用被 Hook 的函数。** REFramework 会判定为递归并抛异常，连带破坏正常游戏逻辑。需要调用时，在 Hook 里只登记，实际调用延后到 `on_frame`。
- **状态必须放在 `_G`。** 脚本会被 Reset，局部状态表会失效，导致 Hook 回调读到旧表。
- **Hook 注册保持幂等与分块。** 新增 Hook 请沿用现有 `_reg()` / `_missing()` 模式，让缺失的方法只影响自身功能块。
- **热路径不做字符串拼接。** 逐帧执行的代码只做数值运算与状态判断。
- **不要新增网络请求。** 本项目承诺离线运行，任何 `require("socket")`、HTTP 调用一律拒绝。
- **不要提交个人信息。** 包括本机绝对路径、用户名、存档文件。

## 新增一个功能时

1. 在配置表 `C` 中加字段，并在 `L.zh` / `L.en` 两套本地化表里加对应文案。
2. 在 UI 里加到合适的分区（战斗 / 武器 / 经济）。
3. 若依赖新 Hook，单独写一个 `_reg("块名", function() ... end)`，并在块内用 `_missing()` 处理方法不存在的场景。
4. 关闭功能时要还原原值，不要让改动残留到存档。
5. 更新 README 的功能表与 CHANGELOG 的 `Unreleased` 段。

## 报 Bug 需要提供

- 游戏版本（Steam / Epic）与 REFramework 构建日期
- 出问题的功能项
- 复现步骤
- `"dbg": true` 下生成的 `marvis_probe.json` 关键片段，或 REFramework 控制台日志

## 会被拒绝的情况

- 引入网络请求、遥测、自动更新
- 从其他 trainer 复制粘贴的代码（本项目为原创实现，请勿引入来源不明片段）
- 修改许可证、在分发物上加额外限制
- 只改代码不验证、无证据的字段猜测

## 联系方式

优先走 Issue / PR 公开讨论，便于留下记录。
