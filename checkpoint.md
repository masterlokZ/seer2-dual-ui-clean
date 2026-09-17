# 双 UI 演进检查点台账 (checkpoint.md)

## 当前构建基线：fix(core-dll): coordinate appear on visible and purge skill action deadlock
- **实测验证**：用户在登录器中实战测试确认完全有效（“非常好这次 传统swf测试完全有效 而且是完整的入场效果 提交并推送”），入场胶囊协同起播与技能释放零卡顿已达成完整闭环。
- **修复内容**：
  1. `Fighter.as`: 拦截 `visible` 属性变化（仅在胶囊落地、战斗精灵首度显现时由 `set visible` 协同触发 `个性出场`，初始 `active` 设为 `待机`），杜绝过早播放入场动画；
  2. `FighterAnimation.as`: 彻底剔除看门狗定时器（`watchdogId` 与 `_externalTimer`）及 `isAppearAction && !isEffectivelyVisible()` 的自旋等待逻辑，彻底杜绝技能释放卡死与停滞。
- **推送策略**：已实测验证通过并获得用户明确指令，正式提交并推送到 GitHub 远程仓库 (`origin/main`)。
- **范围锁定**：使用 `-CoreOnly` 构建，FramePlayer 保持 100% 原封不动。
- **产物哈希**：CoreDLL.swf SHA256 `013785AE029D3FD155DCD2AC6DCF08B0D1C25DF49E05BDE1E095EAE07B6B493E`（官方 7×0x00 + zlib level 9 封包，100% Byte-Exact 回环比对验证通过）。

### 1. 目标与范围锁定
- **状态**：胶囊落地协同与技能死锁剔除补丁已实测验证完全生效，双 UI 核心攻坚项全量闭环，完成远程交付。
- **范围锁定**：仅修改旧 UI（CoreDLL），新 UI（FramePlayer）保持 100% 原封不动。
- **运行状态**：实战测试通过，文档台账已全部对齐。
