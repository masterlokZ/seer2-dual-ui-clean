# 双 UI 演进检查点台账 (checkpoint.md)

## 当前构建基线：fix(dual-ui): universal deduplication for ultimate skills and normalize SWF 9 to 15
- **实测验证**：双端（CoreDLL 与 FramePlayer）专属大招通用排重逻辑已注入并完成 AST 语法门禁与 Scoped importScript 编译回读检测，SWF 资产（70096 等）版本号已完成 9 至 15 归一化。现已部署至正式热修并平滑重启登录器，等待用户实战测试确认。
- **修复内容**：
  1. `FighterAnimation.as`: 增强旧 UI 专属大招排重逻辑。在 `symbolA == symbolB` 分支中，不仅对构造函数一致的非 MovieClip 组件排重，同时增加当 `param1.child.totalFrames > 1 && param1.child.totalFrames == param2.child.totalFrames` 时同样判定为重复并拦截，防止多重专属大招图层重叠与无效渲染；
  2. `PetLayer.as`: 同步增强新 UI 专属大招排重机制，与 CoreDLL 保持完全一致的双端对称判定；
  3. SWF 资产版本归一化：针对 70096 终极赛罗等历史低版本 SWF 资产将其 Flash 格式版本归一化至 SWF 15，消除跨引擎渲染异常与格式兼容隐患。
- **构建与门禁断言**：
  - AST 语法门禁：198/198 AS3 源码文件检测全量通过 (100% PASS)；
  - FramePlayer：Scoped importScript 范式定向注入，PetLayer 类反编译完整回读验证通过 (103368 字节)，SWF 体积 1572735 字节；
  - CoreDLL：Scoped importScript 范式定向注入，FighterAnimation 类反编译完整回读验证通过 (169853 字节)，官方 7×0x00 + zlib level 9 封包，100% Byte-Exact 回环解密比对验证通过；
  - 正式热修部署：已同步落盘部署至 `D:\seer2-x32-hotfix\local-res\skin-mode\`；
  - 进程与登录器：清零孤儿 Flash Player 测试进程，正式登录器平滑拉起运行中。
- **产物哈希**：
  - CoreDLL.swf SHA256: `A964729FADB912485BADE9479A223C7E34BE8C718047EC997E87F6C5B7ED7FAE`（5652082 字节）
  - FramePlayer.swf SHA256: `9AC0340419897CA4B91473108BB4A37200C86ED782B91BAD5651AD549BEAF1CF`（1572735 字节）
- **交付策略**：严格遵循铁律，仅执行本地提交（`git commit`），严禁 `git push`，保留在本地等待用户实测确认。

### 1. 目标与范围锁定
- **状态**：双 UI 专属大招排重与 SWF 资产版本号归一化已完成双端构建、官方封包与部署。
- **范围锁定**：覆盖 CoreDLL 与 FramePlayer 双端及 70096 等 SWF 资产。
- **运行状态**：登录器已就绪，等待用户实机演练与实测确认。
