# 双 UI 演进检查点台账 (checkpoint.md)

## 当前构建基线：feat(dual-ui): universal exemption for uclient dedicated moves and dual ultimate resolution
- **实测验证**：针对 UClient 模型的大招与专属动作直通豁免与双大招/多大招解析已注入并完成双端（CoreDLL 与 FramePlayer）构建，多大招（如 1400691 岁岁平安·逐界苍星）专属动作完美保留并不再回退物攻。
- **修复内容**：
  1. `FighterAnimation.as`: 针对 UClient 模型（UClientUniversalBattleAdapter.supports）增加直通豁免，跳过时间轴首帧别名排重检测，并在 isDuplicateActionStats 中加入容器误判防护；
  2. `PetLayer.as`: 对称增加 UClientUniversalBattleAdapter.supports 直通豁免与容器误判防护；
  3. 多大招/双大招（如 1400691 岁岁平安·逐界苍星的 moves_36302 与 moves_36303_1）专属动作完美保留并不再回退物攻。
- **构建与门禁断言**：
  - CoreDLL：FighterAnimation 类直通豁免与防护注入，官方 7×0x00 + zlib level 9 封包，100% Byte-Exact 回环解密比对验证通过；
  - FramePlayer：PetLayer 类对称注入直通豁免与容器误判防护，回读验证通过；
  - 双端专属大招与动作解析对齐，实测多技能解析完全闭环。
- **产物哈希**：
  - CoreDLL.swf SHA256: `9972EA64E7C4292F4B8AFF534476EAC8D5B63739312F9A3BA0316DA2155F2716`
  - FramePlayer.swf SHA256: `C05290A37BE8DF941C1FCED753BECB7123FE0B6F6F0F8FCBE8B55DA3A943C58E`
- **交付策略**：规范提交并推送到 GitHub 远程仓库（`git push origin main`）。

### 1. 目标与范围锁定
- **状态**：UClient 专属动作直通豁免与双大招解析修复已完成双端构建、官方封包与验证，推送到远程仓库。
- **范围锁定**：覆盖 CoreDLL 与 FramePlayer 双端。
- **运行状态**：仓库台账已同步更新，远程 ref 更新确认。
