# 双 UI 演进检查点台账 (checkpoint.md)

## 当前构建基线：fix(core-dll): coordinate appear on visible and purge skill action deadlock
- **事故状态**：彻底撤回 a6871eb（导致技能释放死锁及超时），重构入场协同与死锁根治补丁。
- **修复内容**：
  1. `Fighter.as`: 拦截 `visible` 属性变化（仅在胶囊落地、战斗精灵首度显现时由 `set visible` 协同触发 `个性出场`，初始 `active` 设为 `待机`），杜绝过早播放入场动画。
  2. `FighterAnimation.as`: 彻底剔除看门狗定时器（`watchdogId` 与 `_externalTimer`）及 `isAppearAction && !isEffectivelyVisible()` 的自旋等待逻辑，彻底杜绝技能释放卡死与停滞。
- **推送策略**：严格执行本地 commit，绝对严禁 git push 远程仓库！等待用户实测并明确确认。
- **范围锁定**：使用 `-CoreOnly` 构建，FramePlayer 保持 100% 原封不动。
- **产物哈希**：CoreDLL.swf SHA256 `013785AE029D3FD155DCD2AC6DCF08B0D1C25DF49E05BDE1E095EAE07B6B493E`（官方 7×0x00 + zlib level 9 封包，100% Byte-Exact 回环比对验证通过）。

### 1. 目标与范围锁定
- **状态**：胶囊落地协同与技能死锁剔除补丁已完成官方增量构建与部署闭环。
- **范围锁定**：仅修改旧 UI（CoreDLL），新 UI（FramePlayer）保持 100% 原封不动。
- **运行状态**：已清零独立 Flash 播放器，平滑拉起正式春树登陆器 (PID 20144)。
