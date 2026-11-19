# MageAOEHelper-Forever

[中文](#中文) · [English](#english) · [下载 / Releases](https://github.com/yimouleng/MageAOEHelper-Forever/releases/latest)

魔兽世界无限服刷怪统计助手：本波经验与击杀、效率、升级估算和金币收支。

A farming tracker for WoW Forever: per-pull XP and kills, farming rates, leveling estimates, and gold changes.

**文档为中英双语，插件界面目前为简体中文。 / This README is bilingual; the in-game UI is currently Simplified Chinese.**

## 中文

魔兽世界无限服刷怪统计助手，简体中文界面。当前版本：**1.6.3**。

目标客户端：WoW Forever 1.60.1（Interface 16001）。这是本地定制版，不是原作者官方发行版。

## 安装与升级

请从 [Releases](https://github.com/yimouleng/MageAOEHelper-Forever/releases/latest) 下载附件 `MageAOEHelper-Forever_1.6.3.zip`。这是整理好目录的安装包；GitHub 自动生成的 “Source code” 是源码包。

1. 完全退出游戏。先备份旧插件文件夹与相关 WTF/SavedVariables 文件；在插件列表停用旧的 MageAOEHelper，不要同时启用新旧两个版本。
2. 将本包中的 MageAOEHelper-Forever 文件夹放到无限服客户端的 Interface/AddOns 下。最终必须是 Interface/AddOns/MageAOEHelper-Forever/MageAOEHelper-Forever.toc，不能多嵌套一层。从 GitHub 下载源码 ZIP 后，需把带有分支后缀的文件夹改名为 MageAOEHelper-Forever。
3. 重新启动游戏。输入 `/mah settings` 打开设置，`/mah show` 显示或隐藏面板。

不需要安装 WombatLog，也没有任何插件依赖。本包不修改游戏其他文件。

从1.6.1升级保留已有累计统计与窗口设置，不需要重置。新增详情开关默认收起；本波数据仅在本次加载期间保留。

### 调整窗口大小

在设置中取消“锁定窗口位置与宽度”，拖动主面板右下角把手向左即可缩窄。1.6.3将最小宽度由400降为260（游戏UI单位），最大仍为650；保留你原有宽度，不会自动改变窗口大小。重新加载、展开/收起详情都会保留所选宽度。

宽度低于360时标题简写为“MAH-Forever”，插件目录和名称不变；左右文字分栏，不让长数值挤进标签。过长文字会受栏宽限制，悬停该行可查看完整名称、当前值和说明。若还想连字体和按钮一起缩小，可在设置中调整“界面缩放”（0.6～2.0）。

### 从旧名称迁移数据（可选）

游戏按插件名称加载保存文件，单改安装目录不会自动读到旧的 `MageAOEHelper.lua` 保存文件。本版保留原有保存变量名与数据结构，方便迁移，但没有自动读取其他插件文件的能力。

完全退出游戏并备份后，分别在账号级和需要迁移的角色级 `SavedVariables` 目录中，将旧的 `MageAOEHelper.lua` **复制**为 `MageAOEHelper-Forever.lua`，保留旧文件不动。若新文件已存在，先备份并选择保留哪一份，勿直接覆盖新统计。这里指 WTF 下的保存文件，不是 Interface/AddOns 下的插件代码。无需迁移时，新名称首次加载从零开始。

从1.5升级时保留累计数据，但显示“含旧版数据，建议重置”：旧算法可能已累计错误，无法凭现有汇总数字修复。建议先备份，再在准备开始刷怪时输入 `/mah reset`；此操作清除本角色累计统计。不会自动替你清空旧数据。

## 功能口径

- **本波经验（击杀数）**：固定在主面板第一行，例如 `12500（12只）`。经验为本波所有可识别杀怪经验消息的总和，以完整整数显示；括号内是本波有经验击杀数，不是当前存活怪数。进入战斗自动开始新一波；脱战后保留结果，允许后到的经验消息继续累计；下次进战只清空本波，不影响累计统计。任务与探索经验不计入本波。按有效消息编号去重，组队奖励和休息奖励不重复加算。
- **有经验击杀**：只计入 CHAT_MSG_COMBAT_XP_GAIN 中能匹配客户端杀怪模板的消息。组队共享经验计入；不是个人最后一击统计。相同名称、相同经验、同一时刻出现的多条消息分别计数。有有效消息编号时才按编号去重。
- **总经验、经验/小时**：读取自身经验条变化，包含杀怪、任务、探索。升级时保留已确认基线，等待等级、经验、经验上限稳定后计算，不虚构等级。快照静止1秒后尝试确认；5秒后仍有歧义则重新建立基线并报告经验缺口，累计值显示“至少”。这些等待阈值是本插件的保守规则，并非游戏接口保证。跨多级、升级前后经验恰好相同等情况可能无法还原。
- **杀怪经验（消息）**：累计杀怪消息主数字；奖励括号用于说明，不重复加算。无法识别的消息不混入样本。
- **升级还需**：按同等级最近30只怪的消息经验平均值估算，至少需要3条样本，超过10分钟在线统计时间的样本淘汰。升级、队伍更新、地区切换、地图载入和重载后重新采样。任务、探索经验不参与均值；改变怪物或经验增益后可手动 `/mah sample`，避免旧样本干扰。
- **估算样本**：显示样本数和波动提示。3至9条提示“样本较少”；标准差除以均值大于35%提示“波动较大”；其他情况提示“样本较稳定”。这是经验性提醒，不是统计置信度，也不能证明样本代表未来。
- **近期效率**：最近约5分钟总经验/小时、有经验击杀/小时，包含在线空闲，至少预热60秒。每5秒分桶，窗口边缘最多约5秒误差。队伍/地区更新、载入或重新采样会重新预热；累计数据不变。
- **按近期刷怪升级**：剩余经验除以近期“杀怪消息经验”的速度，展示大约还需多少分钟，不混入任务和探索经验。需预热完成且有至少3条当前等级样本；明显缺口、未知消息、旧版统计或经验来源不一致时显示“数据待核对”。满级判断沿用目标客户端60级上限。
- **数据核对**：数据变动后等待2秒，检查总经验和杀怪经验。差额仅称“其他/未归类经验”，可能含任务、探索、未识别消息等，不擅自归因。负差额提示异常，旧版数据或经验缺口时不显示差额。“未发现差额异常”不等于没有漏怪，两个来源都未收到的数据无法靠相减发现。
- **金币**：累计余额的正向/负向变化，分别显示收入、支出、净收入和收入/小时。收入可能来自掉落、卖货、邮件或交易；合并交易只能按观察到的余额变化统计。同次登录过图保留旧余额，回到场景后补计净差值并标注；无法还原载入期间的各笔收入和支出。金币暂不可读时保留上次读数，每0.5秒重新尝试。
- **统计时间**：在线、场景已加载时累计，包含空闲和跑图。离线和加载期间不累计。重载、重登后继续；`/mah reset` 开始新一轮。
- **界面**：默认依次显示本波经验（击杀数）、有经验击杀、总经验/小时、有经验击杀/小时、升级还需、净收入、在线统计时长。点击“展开详情”查看累计总经验、金币明细、近期效率和诊断。永久不支持的实时交战怪数不再占行；击杀事件/模板不可用时隐藏相关行，满级隐藏升级估算。暂时不可读与统计异常仍会提示，避免把旧值误当有效数据。正常时不显示诊断警告。支持拖动、横向调整宽度、缩放、锁定、隐藏和回中；悬停每一行可查看口径。
- **重置**：主面板和设置内都有重置按钮，点击后须确认；确认清空本角色累计统计、本波数据、估算样本和近期窗口，但保留窗口设置。只想手动换一波时使用 `/mah wave`，不要用重置统计。
- **保存**：设置沿用 MageAOEHelperDB，统计使用按角色保存的 MageAOEHelperForeverSession。保留1.5统计并标注历史风险；更早不兼容口径不导入。重载后保留汇总但清除近期窗口和估算样本，经验与金币从新基线继续，不追补离线/重载期间未知变化。有效窗口宽度范围为260～650，缺失或无效时使用默认420。

## 明确限制

- 不提供实时交战怪物数，也不再显示其“不可用”占位行。本版本不注册或读取受限的战斗日志，不把当前目标或姓名板数量冒充完整交战名单。
- **波次按角色进出战斗划分，不是精确的怪群识别**：连续不脱战拉下一批怪仍算同一波，可用 `/mah wave` 手动分段。任何重新进战（包括没有击杀的战斗）都会清零本波；脱战后的组队共享经验会加入当前保留的一波。跨越下一次进战才到达的延迟经验消息无法准确分回上一波。不自动猜测未收到消息的击杀数；满级、灰怪无经验也不会增加本波。事件无法注册时提示手动分段；未进战就收到的第一条经验消息会创建临时波次，1秒内进战保留该临时波次，这是兼容事件顺序的启发式规则。重载、重登清空本波，但不清累计；不保存历史波次。
- 满级、灰怪等无经验击杀不统计；也不根据经验条每次上涨推断击杀数。
- 若消息本身不可读、模板缺失或事件无法注册，界面会提示；解析失败时不会猜测击杀。
- 采用客户端自带的 FIRSTPERSON/EXHAUSTION 模板，支持中文、英文及位置参数。已知未命名/任务模板归为“排除非击杀”，不会误报解析失败；确实未知和不可读的消息单独报告。排除只代表不参与击杀计数，不证明实际来源必然是任务。
- 同次登录载入期间仍计入已收到的杀怪消息，并保留经验基线；返回后等待1秒再核对快照。客户端完全没有发来的消息仍无法补算，跨多级经验不猜测。在线效率不包含载入时间，因此载入期间观察到的收益会计入累计收益，但分母不含这段载入时间。
- 队伍/地区更新事件采取保守重新采样策略，可能比实际换队/换地图更频繁。若当前客户端不能注册这些事件，`/mah status` 会报告；可用 `/mah sample` 手动重采样。
- 诊断计数保留到重置，不用解析成功比例冒充真实击杀覆盖率；没有消息不等于没有击杀。本插件不保存聊天原文、角色名字或战斗日志，不向外发送数据。
- 没有无限服客户端实测环境。自动测试验证逻辑和事件接线，不能证明当前游戏版本的事件权限、实际消息格式、视觉效果或磁盘保存都正常。

## 命令

`/mah settings` 设置；`/mah show` 显示/隐藏；`/mah lock` 锁定/解锁。

`/mah details` 展开/收起详情；`/mah wave` 手动开始新一波（只清本波经验和击杀数）。

`/mah reset` 直接清除本角色统计（命令不再弹确认，按钮需要确认）；`/mah sample` 清除估算样本与近期窗口（累计数据不变）；`/mah status` 或 `/mah debug` 显示版本、模板数、本波统计、消息分类、数据缺口、可读状态和事件注册情况。

也支持 `/mah 设置`、`/mah 显示`、`/mah 锁定`、`/mah 详情`、`/mah 新一波`、`/mah 重置`、`/mah 采样`、`/mah 状态`。

## 游戏内验证

1. 输入 `/mah reset`，单杀3只有经验怪，检查击杀数、杀怪经验和升级估算。
2. AOE击杀若干只同名怪，对比第一行的经验总和、消息条数与击杀数；脱战后应保留，下一次进战本波应清零、累计应保留。连续不脱战时测试 `/mah wave`。展开详情，等60秒观察近期效率和升级预计时间。
3. 交任务：总经验应增加，击杀数和杀怪经验不应增加；数据稳定后差额显示为“其他/未归类”。
4. 升一级，等数秒检查总经验是否只增加一次、样本是否重建；组队与双倍经验也分别检查。
5. 卖货、买东西，确认收入、支出和净收入；隐藏面板后统计应继续。过图前后核对经验与金币变化。
6. `/mah sample` 应只清空样本和近期窗口；`/reload` 和正常重登应保留累计值，重新采样。把窗口拉到最窄，检查标题、首行和按钮；展开详情、悬停长文本、重载后核对宽度仍被保留。核对窗口位置和缩放。
7. 主面板“重置”点击后先取消，数据应保留；确认后统计归零、窗口设置不变。检查正常时警告不占行、展开/收起后第一行仍是本波数据。
8. 有问题时提供 `/mah status` 输出和实际杀怪经验消息原文（可遮盖角色名）；报错请提供完整错误文本。

## 参考与验证依据

功能概念源于用户提供的 MageAOEHelper（原作者 Zerka）。此版本重新实现统计模块和中文布局，未复制 WombatLog 代码。

- WombatLog 作者的实现是消息驱动方案的参考，并非暴雪保证：
  https://github.com/fkleindev/WombatLog/blob/main/KillAlert.lua
  https://github.com/fkleindev/WombatLog/blob/main/Stats.lua
- 事件参数参考暴雪生成接口文档的公开镜像；该镜像 live 分支不等于无限服当前版本的完整接口保证：
  https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua
  https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua
  https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/PartyInfoDocumentation.lua
- 地区更新事件也可在暴雪默认小地图源码镜像中核对；同样不构成无限服兼容承诺：
  https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_Minimap/Mainline/Minimap.lua
- 波次边界参考暴雪默认战斗文字对进出战斗事件的处理，初始化与载入时查询 UnitAffectingCombat；布局调整参考生成的框架接口文档。资料不保证目标客户端提供完全相同的行为，因此事件注册会检测失败，窗口尺寸接口保留可选检查：
  https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_CombatText/Shared/CombatText.lua
  https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua
- 窄窗口的文字不换行与完整值提示参考生成的字体接口；没有用截图像素假设字体实际宽度，长内容通过分栏限制与悬停补全：
  https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua
- 本地使用 Lua 5.1 执行362项断言，覆盖解析分类、同名AOE、编号去重、6种升级字段顺序、延迟快照、多级缺口、金币恢复、过图补差、近期窗口、样本过期与波动、旧版迁移，以及本波累加/自动清零/手动分段、精简布局与首行顺序、重置确认/取消、满级与来源缺失隐藏、重载和事件缺失降级。新增窄窗上下限、短标题切换、文字分栏、不换行、完整值提示、宽度保存和重载恢复检查。测试不运行在真实游戏内，不替代上面的游戏内验证。

## 开发与测试

仓库根目录即插件目录。`MageAOEHelper-Forever.toc` 先加载 `Stats.lua`，再加载 `MageAOEHelper-Forever.lua`。内部保存变量名与 `/mah` 命令为兼容旧数据而保留，不影响插件的新名称。

安装 Lua 5.1 后，在仓库根目录运行：

```sh
lua tests/test_stats.lua
```

测试使用模拟游戏接口，不依赖真实角色或聊天记录，不将本地测试运行环境打包到插件中。公开源码保留原概念作者与参考说明，未附加未经确认的上游许可证声明。

## English

**Version: 1.6.3.** Target client: **WoW Forever 1.60.1, Interface 16001**. This is a customized adaptation, not an official release by the original author. The in-game UI is Simplified Chinese; English slash commands and English kill-message templates are supported. English documentation does not imply an English UI or compatibility with every WoW client.

### Installation and upgrades

1. Download the attached **MageAOEHelper-Forever_1.6.3.zip** from [Releases](https://github.com/yimouleng/MageAOEHelper-Forever/releases/latest). Use this ready-to-install asset, not GitHub's automatically generated “Source code” archive.
2. Exit the game completely and back up the old addon folder and relevant WTF/SavedVariables files. Disable the old MageAOEHelper addon; do not enable both versions together.
3. Extract the `MageAOEHelper-Forever` folder into the client's `Interface/AddOns` folder. The final path must be `Interface/AddOns/MageAOEHelper-Forever/MageAOEHelper-Forever.toc`, without an extra nested folder. If you choose the source archive instead, rename its branch/tag-suffixed root folder to `MageAOEHelper-Forever`.
4. Restart the game. Use `/mah settings` for settings and `/mah show` to toggle visibility. **Tracking continues while the panel is hidden.**

No WombatLog installation or other addon dependency is required. The package does not modify other game files. Upgrading from 1.6.1 or 1.6.2 retains cumulative statistics and window preferences; no statistics reset is needed. Details are initially collapsed when the preference has not been saved. Current-pull data is held in memory only.

### Window size

In settings, uncheck **锁定窗口位置与宽度** (lock position and width). Drag the bottom-right resize handle left to narrow the panel. Version 1.6.3 lowers the minimum width from 400 to **260 UI units**; the maximum remains 650. Existing valid widths are preserved rather than automatically changed. Reloading or expanding/collapsing details does not widen the saved window.

Below 360 units, the title becomes **MAH-Forever**; the addon name and installation directory do not change. Labels and values occupy separate columns. Long text may be clipped to its column; hover over the row to read the full label, current value, and explanation. To shrink fonts and buttons as well, adjust **界面缩放** (UI scale) from 0.6 to 2.0.

### Optional migration from the old addon name

WoW loads saved files by addon name. Renaming the installation folder alone does not load the old `MageAOEHelper.lua` saved file. The internal variable names and compatible data structure are retained, but this addon cannot automatically read another addon's saved files.

With the game fully closed and backups made, **copy** the old `MageAOEHelper.lua` to `MageAOEHelper-Forever.lua` in the account-level and relevant character-level `SavedVariables` folders, leaving the original untouched. These are files under **WTF**, not addon source files under Interface/AddOns. If a destination file already exists, back it up and choose which data to keep; do not overwrite newer statistics blindly. Without migration, the renamed addon starts with fresh data.

Version 1.5 totals are preserved but marked as legacy data. Historical calculation errors cannot be repaired from aggregate counters. After backing up, consider `/mah reset` before a fresh farming session. This clears the character's statistics; the addon never performs this reset automatically. Older incompatible statistical formats are not imported.

### What the statistics mean

- **Current-pull XP (kills):** always the first row, for example `12500（12只）`. It sums the main XP amount in recognized kill messages for the current pull and shows the number of XP-granting kills. It is not a count of living enemies. Entering combat starts a new pull; leaving combat retains the result and accepts late XP messages. The next combat entry clears only the pull, not cumulative totals. Quest and exploration XP are excluded, and rested/group bonus annotations are not added twice.
- **XP-granting kills:** one count per recognized `CHAT_MSG_COMBAT_XP_GAIN` kill message. Shared group XP counts too; this is not a personal killing-blow counter. Simultaneous messages with identical names and XP are counted separately. Deduplication uses valid message IDs only, so it is not guaranteed when IDs are unavailable.
- **Total XP and XP/hour:** based on changes in the player's XP bar, including kills, quests, and exploration. Level transitions retain the confirmed baseline and wait for level, XP, and maximum XP to settle. After one second of unchanged snapshots, the addon attempts reconciliation; ambiguity lasting five seconds establishes a new baseline and records an XP gap. Totals with gaps are labeled as a lower bound. These are conservative addon heuristics, not API guarantees. Multiple-level jumps or identical old/new XP values may be impossible to reconstruct.
- **Kill-message XP:** the main XP number from recognized kill messages, without double-counting bonus annotations. Unrecognized messages do not enter the sample set.
- **Estimated kills to level:** remaining XP divided by average kill-message XP from up to 30 recent, same-level samples. At least three samples are required; samples expire after ten minutes of tracked online time. Level, group, zone, loading, and reload changes recalibrate samples. Quest/exploration XP is excluded. Use `/mah sample` after changing mobs or XP buffs.
- **Sample quality:** 3–9 samples receive a small-sample notice; standard deviation divided by the mean above 35% receives a high-variation notice. Otherwise the sample is described as relatively stable. These are advisory rules, not confidence intervals or proof of future performance.
- **Recent rates:** approximately five-minute XP/hour and kills/hour, including online idle time, with a 60-second warmup. Five-second buckets introduce up to roughly five seconds of boundary error. Context changes and resampling restart the recent window without clearing totals.
- **Estimated time to level:** remaining XP divided by the recent kill-message XP rate, excluding quests and exploration. Requires warmup and at least three current-level samples. Gaps, unknown messages, legacy data, or inconsistent XP sources suppress the estimate. The target level cap is treated as 60.
- **Reconciliation:** after two quiet seconds, compares total XP with kill-message XP. The difference is labeled “other/unclassified XP,” not automatically quest XP. It can include exploration, unrecognized messages, or synchronization differences. Negative differences are flagged; legacy data or XP gaps suppress the difference. A clean comparison does not prove all kills were observed.
- **Gold:** positive and negative changes in the character's balance become income and spending; net income and income/hour are derived from them. Income may include loot, sales, mail, or trades. Combined transactions cannot be separated beyond observed balance changes. During same-login loading, only the net balance difference can be recovered and is flagged. Unreadable gold values are retried every 0.5 seconds.
- **Tracked time:** online time while the world is loaded, including idle time and travel. Offline time and loading screens are excluded. Cumulative time survives reload/relogin; `/mah reset` starts a fresh session.
- **Compact panel:** seven default rows: current pull, cumulative XP-granting kills, total XP/hour, kills/hour, estimated kills to level, net income, and tracked time. “展开详情” expands totals, gold breakdowns, recent rates, and diagnostics. Unsupported live-enemy counts are omitted; missing kill sources hide related rows, and level-cap characters do not see leveling estimates. Temporary unreadability and anomalies still produce warnings. Normal operation does not show a warning block.
- **Reset and saving:** both reset buttons require confirmation and clear character totals, the current pull, samples, and recent rates while keeping window settings. `/mah reset` resets immediately without confirmation. Use `/mah wave` to clear only the current pull. Preferences use `MageAOEHelperDB`; character totals use `MageAOEHelperForeverSession`. Reloading retains totals but clears the current pull, recent rates, and samples, and establishes fresh XP/gold baselines. Offline or unobserved changes are not invented. Valid saved widths are 260–650, with 420 as the fallback.

### Limitations

- No complete live-enemy count is available. The addon does not register or read the restricted combat log, and does not substitute the target or nameplate count for a full combat roster.
- **Pulls follow player combat boundaries, not exact mob-pack detection.** Chain-pulling without leaving combat remains one pull; use `/mah wave` to split it manually. Any new combat entry, even without a kill, starts a new pull. Shared group XP received out of combat joins the retained pull. Messages arriving after the next combat entry cannot reliably be assigned back to the previous pull. If combat events cannot be registered, use manual splitting. A first XP message before combat creates a provisional pull, retained if combat begins within one second; this is an event-order heuristic. There is no pull-history archive, and reload/relogin clears the current pull only.
- Gray mobs, level-cap kills, and other kills without XP are not counted. XP-bar increases are never used to guess a kill count. Missing messages cannot be reconstructed.
- Uses the client's `FIRSTPERSON`/`EXHAUSTION` templates, including Chinese, English, and positional placeholders. Known unnamed/quest formats are excluded from kill counting; unknown and unreadable messages have separate diagnostics. Exclusion does not prove that the source was a quest.
- Same-login loading retains delivered kill messages and the XP baseline, followed by a one-second settling delay on return. Observed loading-screen rewards enter cumulative totals while loading time remains excluded from the rate denominator. Multiple-level gaps are not guessed.
- Group/zone events trigger conservative resampling and may occur more frequently than actual farming-condition changes. Unsupported events appear in `/mah status`; use `/mah sample` as needed.
- Diagnostic counts remain until reset. Parsing success is not presented as a true kill-coverage percentage. The addon does not store raw chat, character names, or combat logs, and does not send data externally.
- **No WoW Forever client test environment is available.** Mock tests verify logic and wiring, not actual event permissions, message formats, font rendering, or disk persistence in the game.

### Commands

| Command | Action |
| --- | --- |
| `/mah settings` | Open/close settings |
| `/mah show` | Toggle the panel; tracking continues while hidden |
| `/mah lock` | Lock/unlock position and width |
| `/mah details` | Expand/collapse detail rows |
| `/mah wave` | Start a new pull; cumulative totals remain |
| `/mah sample` | Clear samples and recent rates; cumulative totals remain |
| `/mah reset` | Immediately reset this character's statistics, without confirmation |
| `/mah status` or `/mah debug` | Show version, templates, current pull, message diagnostics, gaps, readability, and event registration failures |

Chinese aliases are also available: `/mah 设置`, `/mah 显示`, `/mah 锁定`, `/mah 详情`, `/mah 新一波`, `/mah 重置`, `/mah 采样`, and `/mah 状态`. The longer `/mageaoehelper` prefix is supported too.

### In-game checks

1. After backing up and intentionally resetting, kill three XP-granting mobs. Compare the count, kill XP, and leveling estimate.
2. AOE several same-name mobs and compare the first-row sum/count with XP messages. Leaving combat should retain the pull; entering again should clear only that pull. Test `/mah wave` during continuous combat. Expand details and wait 60 seconds to check recent rates.
3. Turn in a quest: total XP should increase, kill counters should not, and the settled difference should be “other/unclassified.”
4. Level up and check that XP is counted once and samples restart. Test group XP and rested XP separately.
5. Buy/sell items and compare income, spending, and net income. Hide the panel and confirm tracking continues; check loading transitions too.
6. Check `/mah sample`, `/reload`, and normal relogging for the documented persistence behavior. Resize to minimum width, expand details, hover long values, and reload to verify width, position, and scale.
7. Cancel a reset confirmation and check that totals remain. Confirm a reset and check that totals clear while preferences remain. Confirm that the current-pull row stays first.
8. For issues, provide `/mah status`, the actual kill-XP message (names may be redacted), and the full error text if one appears.

### Credits, references, and development

The concept comes from the user-supplied MageAOEHelper by **Zerka**. This adaptation reimplements the statistics module and Chinese layout. WombatLog's [KillAlert.lua](https://github.com/fkleindev/WombatLog/blob/main/KillAlert.lua) and [Stats.lua](https://github.com/fkleindev/WombatLog/blob/main/Stats.lua) informed the message-driven approach; no WombatLog code was copied, and its implementation is not an API guarantee.

API references are public mirrors of Blizzard-generated documentation and default UI source: [chat events](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua), [unit APIs](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua), [group events](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/PartyInfoDocumentation.lua), [zone events](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_Minimap/Mainline/Minimap.lua), [combat boundaries](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_CombatText/Shared/CombatText.lua), [frame sizing](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua), and [font strings](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua). The `live` branch is not a compatibility guarantee for WoW Forever. Event registration failures are reported, and resize-bound API availability is checked.

The repository root is the addon directory. The TOC loads `Stats.lua` before `MageAOEHelper-Forever.lua`. Internal saved-variable names and slash commands remain stable for compatibility. With Lua 5.1 installed, run from the repository root:

```sh
lua tests/test_stats.lua
```

**362 mocked assertions pass**, covering parsing, same-name AOE, deduplication, six upgrade-field arrival orders, delayed snapshots, XP gaps, gold recovery, loading transitions, rolling rates, sample expiry/variation, migrations, pull boundaries, reset confirmation, compact layout, missing-event degradation, narrow columns, title switching, tooltips, and width persistence. The runtime used for local tests is not included in the installation package. Tests do not replace in-game verification. Original concept attribution and reference notes are retained; no unverified upstream license grant is asserted.
