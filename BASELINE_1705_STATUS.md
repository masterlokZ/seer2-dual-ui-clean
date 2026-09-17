# Seer2 17:05 基线双 UI 全量提取物完整性审计与技术状态报告

本文档对 `D:\seer2-dual-ui-extract-1705\` 目录下的 17:05 黄金基线双 UI（CoreDLL 旧 UI 与 FramePlayer 新 UI）全量提取物执行全维度完整性与哈希审计，并系统梳理 17:05 稳定基线的当前工程状态，形成技术变更与待决问题的权威台账。

**基本信息**
- 审计时间: 2026-09-17 20:30 (UTC+8)
- 基线定位: 17:05 稳定黄金基线 (Wednesday 17:05 Golden Baseline)
- 运行时目录: `D:\seer2-x32-hotfix\local-res\skin-mode\`
- 源码基线仓库: `D:\s2-ui\`
- 全量提取物归档: `D:\seer2-dual-ui-extract-1705\`
- 状态事实台账: [session_ledger.json](/seer2-x32-hotfix/docs/.session_ledger.json)

**提取工具链**
- Java Runtime: Temurin OpenJDK 1.8.0_502 (64-Bit), `D:\swf-work-622\downloads\temurin8-jre\runtime\jdk8u502-b07-jre\bin\java.exe`
- Decompiler: JPEXS Free Flash Decompiler (FFDec) v26.2.1, `D:\s2-ui\tools\ffdec\ffdec.jar`

---

**全量提取物审计与哈希校验**

经过对 `D:\seer2-dual-ui-extract-1705\` 下全部 19,367 个文件（总容量 451,226,479 字节 / 430.32 MB）的逐项校验，所有提取物结构完整，校验和与清单 100% 吻合。

1. 权威二进制文件校验

| 模块 | 资产路径 | 体积 (字节) | SHA-256 哈希值 | 校验结论 |
| :--- | :--- | :--- | :--- | :--- |
| **CoreDLL** (封包) | `CoreDLL/input/CoreDLL.swf` | 5,652,211 | `A93D142712A8140D3A3D3F089FAA3078C195179091B497860291EDD644A14492` | 100% 匹配正式热修与源码库 |
| **CoreDLL** (明文) | `CoreDLL/decrypted/CoreDLL.decrypted.swf` | 5,679,587 | `8F7E985F5988879201E254203CEE0D6395DF524078FC9EEEAC61B50461FD7320` | 100% 匹配解密基线 |
| **FramePlayer** | `FramePlayer/input/FramePlayer.swf` | 1,572,535 | `3140EDE2B7F12183452747A30225B9EC286B3A25B55C8441054032ECB91CD8F1` | 100% 匹配正式热修 |
| **FramePlayer** (明文) | `FramePlayer/decrypted/FramePlayer.swf` | 1,572,535 | `3140EDE2B7F12183452747A30225B9EC286B3A25B55C8441054032ECB91CD8F1` | 100% 匹配输入（标准 CWS） |

2. 封包与解密回环断言 (Roundtrip Assertion)

对 `CoreDLL/input/CoreDLL.swf` 执行官方封包规范校验：
- 前导字节校验: 前 7 字节严格为 `0x00 0x00 0x00 0x00 0x00 0x00 0x00` (7 个 0x00 零字节)。
- 解密流校验: 剥离前 7 字节后，使用 zlib 解压流解压出的数据体积为 5,679,587 字节。
- 逐字节回环断言: 解密出的二进制数据与 `CoreDLL/decrypted/CoreDLL.decrypted.swf` 逐字节比对，0 字节差异（100% Byte-Exact Equality Verified）。

3. 提取物文件分布与结构统计

全量提取物总文件数为 19,367，详细分布如下：
- 根目录文件 (2 个): `manifest.json` (2,007 字节), `README.md` (1,884 字节)。
- CoreDLL 模块 (共 13,000 个文件):
  - `input/CoreDLL.swf` (1 个)
  - `decrypted/CoreDLL.decrypted.swf` (1 个)
  - `document.xml` (1 个, 102,902,623 字节, SHA256: `A8DEC661CD9F43D647EAB2313BA9FEA9FF0DC11CE4EC10528202976ADA0D8C8C`)
  - `tags.txt` (1 个, 1,387,544 字节, 共 4,803 行标签清单)
  - 日志文件 (4 个): `ffdec-export-all.log`, `ffdec-pcode.log`, `ffdec-script.log`, `ffdec-xml.log`
  - `full-extract/` (共 4,548 个文件):
    - `binaryData`: 93 个 (含 XML 配置类与元数据)
    - `buttons`: 8 个
    - `fonts`: 1 个
    - `frames`: 1 个
    - `scripts`: 4,222 个 (完整 AS3 类文件)
    - `shapes`: 41 个
    - `sprites`: 180 个
    - `symbolClass`: 1 个
    - `texts`: 1 个
  - `scripts/` (共 4,222 个独立导出的 AS3 脚本文件)
  - `pcode/` (共 4,222 个独立导出的 P-code 虚拟机字节码文件)
- FramePlayer 模块 (共 6,365 个文件):
  - `input/FramePlayer.swf` (1 个)
  - `decrypted/FramePlayer.swf` (1 个)
  - `document.xml` (1 个, 28,048,795 字节, SHA256: `9BC6420E493B83C7309878CF28B3F2ABA0860A5695D9FA01B6F8E05B9871A36A`)
  - `tags.txt` (1 个, 2,467,935 字节, 共 22,839 行标签清单)
  - 日志文件 (4 个): `ffdec-export-all.log`, `ffdec-pcode.log`, `ffdec-script.log`, `ffdec-xml.log`
  - `full-extract/` (共 5,717 个文件):
    - `buttons`: 56 个
    - `fonts`: 1 个
    - `frames`: 1 个
    - `images`: 2 个
    - `scripts`: 320 个 (完整 AS3 类文件)
    - `shapes`: 681 个
    - `sounds`: 7 个
    - `sprites`: 4,614 个 (含大量战斗 UI 与特效 Sprite)
    - `symbolClass`: 1 个
    - `texts`: 34 个 (含 3 个初始空文本占位定义 `1044.txt`, `1045.txt`, `660.txt`)
  - `scripts/` (共 320 个独立导出的 AS3 脚本文件)
  - `pcode/` (共 320 个独立导出的 P-code 虚拟机字节码文件)

4. 日志审计与异常排查

检索所有导出日志（`ffdec-*.log`）：日志中包含的 `ErrorTypes`、`InventoryErrorEvent`、`JSONParseError`、`CatchFighterFailAnimation`、`UI_FightCatchFailed` 等匹配项均为 ActionScript 类名与符号，无任何反编译中断、缺损或未捕获异常，导出日志状态全部为 Clean Success。

---

**17:05 基线核心技术方案与已解决问题**

17:05 基线作为双 UI 协同的权威稳定锚点，已经彻底攻克并固化了六大核心架构与流程机制：

1. FramePlayer 新 UI Scoped importScript 最小增量构建范式

- 历史教训与空壳危机: 早期尝试通过 Flex SDK 全量重编译或整包 XML 重构 FramePlayer，导致 SWF 丢失原生 Sprite 标签绑定与符号表（SymbolClass），破坏了关键时钟初始化，生成无实际渲染播放能力的“空壳 SWF”（Empty Shell）。
- 定向注入范式 (Scoped importScript):
  - 确立以基准 SWF 为底本，仅将发生逻辑变更的 AS3 源文件（如 `animation.layer.PetLayer`）放入匹配包路径的临时 staging 目录；
  - 使用 FFDec `-importScript` 执行单个类文件的定点字节码替换，完整保留原生 SWF 的时间轴、矢量形状（681 个）、Sprite 容器（4,614 个）与音频资产；
  - 构建前执行 AST 语法门禁（`toolchain\Test-ActionScriptAST.ps1`），严防语法残缺污染二进制；
  - 构建后实施防空壳门禁（Anti-Hollow SWF Gate）：强制断言体积位于 1.4MB - 1.8MB 阈值区间（基准约 1.57MB），校验 CWS/FWS/ZWS 头；
  - 自动回读验证：调用 FFDec `-selectclass animation.layer.PetLayer -export script` 立即反编译新 SWF，断言 `class PetLayer` 语法结构完整存在后才允许交付。

2. CoreDLL 官方 7×0x00 + zlib level 9 封包与解密回环验证机制

- 官方加密协议约束: 官方登录器对 `CoreDLL.swf` 施加了专有格式保护，文件头部为 7 字节全零（`00 00 00 00 00 00 00`），其后紧跟 zlib 最高压缩等级（level 9, SmallestSize）压缩的真实 SWF 二进制流。标准 Flash 工具无法直接解析封包文件，且若将未封包的明文 SWF 直接放入热修目录，会导致登录器启动加载崩溃。
- 闭环构建与逐字节校验:
  - 在 [Build-And-Deploy-DualUI.ps1](/s2-ui/Build-And-Deploy-DualUI.ps1:280) 中固化全自动流程：编译明文 `CoreDLL.candidate.decrypted.swf` 后，通过 `.NET System.IO.Compression.ZLibStream` 实施 7×0x00 + zlib level 9 封装；
  - 部署前强制执行内存中解密回环断言：现场对封包产物解压，与明文输入做逐字节比对（Byte-Exact Equality），仅在 100% 完全相符时才允许覆盖 `local-res\skin-mode\CoreDLL.swf`；
  - 严格区分明文基准与封包产物，杜绝将明文 SWF 误认作封包或误写入运行树的重大事故。

3. U 端模型的自动通用适配与生命周期管理

- 跨引擎资产接入: 引入 Unity 端（UClient / U-Engine）导出的现代资产（FTR 与 Spine 模型），并通过通用转换管线输出为宿主 Flash 可驱动的显示对象。
- 通用战斗适配器 (`UClientUniversalBattleAdapter`):
  - 固化版本 `1.3.0-clock-capability`，通过 `supports(target)` 动态识别 `uClientBattleReady` 标志；
  - 采用弱引用字典 `Dictionary(true)` 建立会话池，杜绝模型常驻导致的内存泄漏；
  - 时钟节拍对齐：将 Flash 宿主 40 FPS 时间轴平滑对齐至 UClient 原始 15 FPS 待机时钟（`IDLE_SOURCE_FPS = 15`），消除帧抖动与计时器漂移；
  - 生命周期确立：通过 `bind()`、`unbind()` 与显式 `dispose()` 保证换宠、退场、死亡时的对象与监听器确定性销毁；
  - 严守 Flash 全局缓存红线（工作流第 20 号规范）：严禁使用带有全局字节预算与 LRU 机制的魔改 CacheUtils，保持无侵入的局部生命周期管理。

4. 双引擎经典石台与现代石台切换、出招与状态面板挂载

- 双引擎视口与层级解耦:
  - CoreDLL 经典模式：以 `ArenaScene`、`FighterAnimation` 与 `mapModel.ground` 为核心，以居中对齐与基准偏移驱动经典石台；
  - FramePlayer 现代模式：构建 `BackLayer`（承载 `_ground` / `_front`）、`sceneProjectionLayer`、`PetLayer` 与 `FrontLayer` 的四层视差渲染体系；
- 地平线对齐规范: 确立统一地平线坐标空间（对齐对手飞亚斯 FeiYaSi 基线，Y=370 - 420 区间），解决不同战斗模式下的高低浮动；
- 状态面板与出招挂载: 实现了现代战斗中血条指示器、怒气槽、天气浮层与技能出招面板的确定性层级挂载；攻克了大招播放超时原地卡死问题（`ULT_STALL`），通过 `fuiMoveActionEnd` 事件驱动与状态机闭环，出招完毕后立即安全恢复回合待机。

5. 终极贝利亚等传统 Flash 中心注册点超大精灵与 U 端精灵的正交站位通修（实测生效闭环）

- 痛点根因: `measureRenderedSubject` 动态像素分位数测绘原本专为解决 UClient 模型（阿克希亚等）不可见辅助 Quad 干扰而设计；无差别应用到传统 Flash 矢量时间轴模型时，因其腹部中心注册点拓扑，测得的 236px/252px 半身距离被误当全身高度扣减，导致精灵被反向拉升冲穿天花板。
- 正交解耦方案: 将 `measureRenderedSubject` 严格约束在 `if(UClientUniversalBattleAdapter.supports(...))` 内部。
  - UClient 模型（阿克希亚 1400869、星皇 190003291 等）：`supports == true`，执行动态测算并放宽上限至 500px，全身高度精准贴地（阿克希亚获得 58px 下沉）；
  - 传统 Flash 模型（终极贝利亚 70098 等）：`supports == false`，绝对不调用动态测绘，坚守官方标准模板基线 `EXTERNAL_TEMPLATE_BASELINE_Y = 145`，计算得 `pet.y = 280`，脚底落于精准 532px 石台地面，经用户实战测试验证完全生效，彻底根除冲顶与悬空。

6. 传统 SWF 完整入场动画与胶囊破壳协同起播通修（实测完全生效闭环）

- 痛点根因:
  1. 根容器包装寻址脱靶：70096 终极赛罗、70097 皇帝贝利亚、70098 终极贝利亚等精灵的 `fight.swf` 根时间轴仅有 1 帧，实际动作标签全部分布在子元件 `pet` 上。在 `gotoLabel` 阶段直接执行 `this._mc.gotoAndStop(label)` 会触发 Flash Error #2109 异常并脱靶回退到第 1 帧；
  2. 胶囊飞行期隐身偷跑：进入战斗时我方精灵被提前设为 `visible = false`，而出场动作在黑暗中全速播放。当胶囊于 1800ms 落地爆开时，出场动画早已播完切入待机；
  3. 动作完结逻辑死锁与过度死等：原 `actionExitHandler` 中存在 `if (primaryVisual == null) { return; }` 提前退出拦截，且死等上百帧循环子剪辑，导致技能释放后战斗停滞数秒。
- 彻底通修方案:
  1. 有效时间轴解包：在 `gotoLabel` 与 `getActionChild` 中全面引入 `getEffectiveTimeline(this._mc)`，直达真实承载标签的 `pet` 剪辑，实现精准寻址；
  2. 胶囊破壳协同起播：在 `Fighter.as` 中重写 `visible` 属性，在我方精灵被胶囊落地破壳（`visible = true`）的瞬间精准唤醒 `this.action = "个性出场"`，精灵从第 1 帧完整展现震撼出场效果；
  3. 根除技能死锁与看门狗：动作到达标称区间末尾时立即调用 `finish()` 正常释放，彻底剔除看门狗与超时轮询，杜绝技能释放后卡顿；
  4. 无出场精灵安全放行：3291 瀚宇星皇、雷伊等无出场标签精灵直接进入待机，0 延时，0 异常。

---

**尚未解决的遗留缺陷与攻坚方向**

当前双 UI 核心攻坚项（终极贝利亚等超大模型站位对齐、传统 SWF 完整入场动画协同起播、技能释放零卡顿）已全量实战验证闭环。

---

**工程维护与部署铁律**

1. 唯一状态台账:
   所有的改动、基线状态与测试结论必须同步至 `D:\seer2-x32-hotfix\docs\.session_ledger.json`，已在 `closed_baseline` 中归档为 `VERIFIED_CLOSED` 或 `FROZEN_DO_NOT_TOUCH` 的项（如大招超时卡死、CE变速配置、3291 模型结构无损），严禁擅自触碰或重新列为待办。
2. 独立 Flash 播放器清零:
   在拉起正式登录器或交付前，必须强制扫描并清理独立测试播放器孤儿进程（`flashplayer*.exe`、`SAFlashPlayer.exe`），绝不留存悬空窗口。
3. 工具链统一入口:
   所有双 UI 构建与部署必须统一调用 `D:\s2-ui\Build-And-Deploy-DualUI.ps1`，确保 AST 语法检查、防空壳回读断言与 7×0x00+zlib 回环校验在每一轮部署中 100% 强制执行。

---

*本报告由 Codex 依据 17:05 基线全量提取物与源码仓库实机比对自动生成，数据具备唯一确定性与可复核性。*
