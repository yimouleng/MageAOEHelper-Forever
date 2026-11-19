-- MageAOEHelper-Forever 1.6.2: compact UI and per-wave XP statistics.
-- Original addon concept: Zerka. See README.md for provenance and limits.
local addonName, ns = ...
local S = ns.Stats
local db, session, runtime, patterns, ready
local entered, resumeWait, loadingMoneyPending
local failures = {}
local eventsSeen = 0
local frame, settings, values, footer, lockCheck, slider, scaleLabel, resize
local rows, detailButton, resetDialog, layoutHeight, layoutKey
local primaryRows = {19, 2, 5, 3, 7, 10, 12}
local detailRows = {4, 6, 8, 9, 11, 13, 14, 15, 16, 17, 18}
local killRows = {[2]=true, [3]=true, [6]=true, [7]=true, [14]=true, [15]=true, [16]=true, [17]=true, [19]=true}

local function Say(text)
    print("|cff69ccf0[MageAOEHelper-Forever]|r " .. text)
end
local function Number(n)
    if n >= 10000 then return string.format("%.1f万", n / 10000) end
    return tostring(math.floor(n))
end
local function Gold(n)
    local sign = n < 0 and "-" or ""
    n = math.abs(math.floor(n))
    return string.format("%s%d金%d银%d铜", sign, math.floor(n / 10000), math.floor(n / 100) % 100, n % 100)
end
local function Baseline()
    S.Baseline(runtime, UnitXP("player"), UnitXPMax("player"), UnitLevel("player"), GetMoney())
end
local function UpdateXP()
    S.XP(session, runtime, UnitXP("player"), UnitXPMax("player"), UnitLevel("player"))
end
local function UpdateMoney()
    S.Money(session, runtime, GetMoney(), loadingMoneyPending)
    if not runtime.moneyUnavailable then loadingMoneyPending = nil end
end
local function Reset()
    local inCombat = runtime.inCombat
    session = S.New()
    MageAOEHelperForeverSession = session
    runtime = S.Runtime()
    loadingMoneyPending = nil
    Baseline()
    S.Combat(runtime, inCombat)
    Say("本次统计已重置。")
end

local function SyncCombat()
    -- Generated Blizzard interface source (target-client support remains probed):
    -- https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua
    if type(UnitAffectingCombat) == "function" then
        S.Combat(runtime, S.Safe(UnitAffectingCombat("player")))
    end
end

local function Layout(killUnavailable, maxLevel, hasWarning)
    local key = tostring(db.showDetails) .. tostring(killUnavailable) .. tostring(maxLevel) .. tostring(hasWarning)
    if key == layoutKey then return end
    layoutKey = key
    local count = 0
    local function Place(ids, enabled)
        for _, id in ipairs(ids) do
            local visible = enabled and not (killUnavailable and killRows[id]) and not (maxLevel and (id == 7 or id == 15))
            rows[id]:SetShown(visible)
            if visible then
                rows[id]:ClearAllPoints()
                rows[id]:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -42 - count * 22)
                rows[id]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -42 - count * 22)
                count = count + 1
            end
        end
    end
    Place(primaryRows, true)
    Place(detailRows, db.showDetails)
    local height = 42 + count * 22 + 64 + (hasWarning and 32 or 0)
    -- Keep the top edge steady when expanding, collapsing or displaying warnings.
    if layoutHeight and layoutHeight ~= height then
        db.frameY = db.frameY + (layoutHeight - height) / 2
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", db.frameX, db.frameY)
    end
    -- SetResizeBounds is optional on the target client, as in the previous version.
    -- https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua
    if frame.SetResizeBounds then frame:SetResizeBounds(400, height, 650, height) end
    frame:SetHeight(height)
    layoutHeight = height
    footer:ClearAllPoints()
    footer:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -46 - count * 22)
    footer:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -46 - count * 22)
    footer:SetShown(hasWarning)
    detailButton:SetText(db.showDetails and "收起详情" or "展开详情")
end

local function ApplySettings()
    frame:SetScale(db.frameScale)
    frame:SetShown(db.showFrame)
    resize:SetShown(not db.locked)
    lockCheck:SetChecked(db.locked)
    slider:SetValue(db.frameScale)
    scaleLabel:SetText(string.format("界面缩放：%.1f", db.frameScale))
end

local function Render()
    if not ready then return end
    local h = session.seconds / 3600
    local xpRate = h >= 1 / 3600 and session.totalXP / h or 0
    local killRate = h >= 1 / 3600 and session.kills / h or 0
    local moneyRate = h >= 1 / 3600 and session.income / h or 0
    local level = S.Number(UnitLevel("player"), nil, 1, 1000)
    local xp = S.Number(UnitXP("player"), nil, 0, 1e12)
    local maximum = S.Number(UnitXPMax("player"), nil, 0, 1e12)
    local killUnavailable = failures.CHAT_MSG_COMBAT_XP_GAIN or (patterns.killCount or 0) == 0
    local wave = runtime.wave
    values[19]:SetText(wave and (tostring(math.floor(wave.xp)) .. "（" .. wave.kills .. "只）") or "0（0只）")
    values[2]:SetText(Number(session.kills))
    values[3]:SetText(failures.CHAT_MSG_COMBAT_XP_GAIN and "不可用" or Number(killRate))
    local xpPrefix = session.xpGaps > 0 and "至少 " or ""
    values[4]:SetText(xpPrefix .. Number(session.totalXP))
    values[5]:SetText(runtime.xpUnavailable and "暂不可读" or xpPrefix .. Number(xpRate))
    values[6]:SetText(Number(session.killXP))
    local estimate = "待采样"
    if not xp or not maximum or not level then
        estimate = "暂不可读"
    elseif level >= 60 then
        estimate = "满级"
    else
        local count = not runtime.pending and S.Estimate(session, maximum - xp, level, runtime)
        if count then estimate = "约 " .. count .. " 只" end
        if runtime.pending then estimate = "等待升级数据稳定" end
    end
    values[7]:SetText(estimate)
    values[8]:SetText(Gold(session.income))
    values[9]:SetText(Gold(session.spending))
    values[10]:SetText(runtime.moneyUnavailable and "暂不可读" or Gold(session.income - session.spending))
    values[11]:SetText(runtime.moneyUnavailable and "暂不可读" or Gold(moneyRate))
    values[12]:SetText(string.format("%02d:%02d:%02d", math.floor(session.seconds / 3600), math.floor(session.seconds / 60) % 60, math.floor(session.seconds) % 60))
    local recent = S.Recent(runtime)
    local info = S.SampleInfo(session, runtime, level)
    local check, other = S.Check(session, runtime)
    local warm = "预热 " .. math.floor(recent.seconds) .. "/60秒"
    values[13]:SetText(recent.warmed and Number(recent.xp * 3600 / recent.seconds) or warm)
    values[14]:SetText(recent.warmed and Number(recent.kills * 3600 / recent.seconds) or warm)
    local eta = "待采样"
    if level and level >= 60 then eta = "满级"
    elseif runtime.pending or runtime.xpUnavailable then eta = "等待经验数据稳定"
    elseif not xp or not maximum or not level then eta = "暂不可读"
    elseif session.legacy or session.xpGaps > 0 or session.unknown + session.unreadable > 0 or session.killXP > session.totalXP then eta = "数据待核对"
    elseif recent.warmed and info.mean then
        if recent.killXP > 0 then
            eta = "约 " .. math.ceil(math.max(0, maximum - xp) * recent.seconds / recent.killXP / 60) .. " 分钟"
        else eta = "近期无杀怪经验" end
    end
    values[15]:SetText(eta)
    values[16]:SetText(info.count .. "/30 · " .. info.state)
    values[17]:SetText(other and Number(other) or "待核对")
    values[18]:SetText(check)
    local warnings = {}
    if killUnavailable then warnings[#warnings + 1] = "击杀统计来源不可用" end
    if failures.PLAYER_REGEN_DISABLED or failures.PLAYER_REGEN_ENABLED then warnings[#warnings + 1] = "波次需用 /mah wave 手动分段" end
    if session.legacy then warnings[#warnings + 1] = "含旧版数据，建议重置" end
    if runtime.xpUnavailable then warnings[#warnings + 1] = "经验暂不可读" end
    if session.unknown + session.unreadable > 0 then warnings[#warnings + 1] = "消息可能不全" end
    if session.xpGaps > 0 then warnings[#warnings + 1] = "经验有缺口" end
    if runtime.moneyUnavailable then warnings[#warnings + 1] = "金币暂不可读" end
    if session.moneyGaps > 0 then warnings[#warnings + 1] = "载入期间金币仅计净变动" end
    if check == "经验不一致，请查看状态" then warnings[#warnings + 1] = "经验来源不一致" end
    if killUnavailable then
        values[18]:SetText("缺少击杀数据来源")
    end
    local status = #warnings > 0 and (warnings[1] .. (#warnings > 1 and "（另有" .. (#warnings - 1) .. "项）" or "") .. " · /mah status") or ""
    footer:SetText(status)
    Layout(not not killUnavailable, level and level >= 60 or false, #warnings > 0)
    frame:SetShown(db.showFrame)
end

local function Tooltip(owner, text)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(text, 1, 1, 1, 1, true)
    GameTooltip:Show()
end
local function Backdrop(f)
    f:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12, insets = {left = 3, right = 3, top = 3, bottom = 3}})
    f:SetBackdropColor(0.035, 0.045, 0.07, 0.94)
    f:SetBackdropBorderColor(0.3, 0.6, 0.8, 1)
end
local function Text(parent, template)
    return parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
end
local function Button(parent, label, width, click)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 24)
    b:SetText(label)
    b:SetScript("OnClick", click)
    return b
end
local function CreateUI()
    frame = CreateFrame("Frame", "MageAOEHelperFrame", UIParent, "BackdropTemplate")
    frame:SetSize(db.frameWidth, 260)
    frame:SetScale(db.frameScale)
    frame:SetPoint("CENTER", UIParent, "CENTER", db.frameX, db.frameY)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) if not db.locked then self:StartMoving() end end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetCenter()
        local ratio = UIParent:GetEffectiveScale() / self:GetEffectiveScale()
        db.frameX, db.frameY = x - UIParent:GetWidth() * ratio / 2, y - UIParent:GetHeight() * ratio / 2
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", db.frameX, db.frameY)
    end)
    Backdrop(frame)
    local title = Text(frame)
    title:SetPoint("TOPLEFT", 14, -14)
    title:SetText("|cff69ccf0MageAOEHelper-Forever|r  1.6.2")
    local gear = Button(frame, "设置", 48, function() settings:SetShown(not settings:IsShown()); ApplySettings() end)
    gear:SetPoint("TOPRIGHT", -12, -8)
    local names = {[2]="有经验击杀", [3]="有经验击杀 / 小时", [4]="总经验", [5]="总经验 / 小时", [6]="杀怪经验（消息）", [7]="升级还需", [8]="收入", [9]="支出", [10]="净收入", [11]="收入 / 小时", [12]="在线统计时长", [13]="近期总经验 / 小时", [14]="近期击杀 / 小时", [15]="按近期刷怪升级", [16]="估算样本", [17]="其他 / 未归类经验", [18]="数据核对", [19]="本波经验（击杀数）"}
    local tips = {
        "", -- Retired row 1; keep tooltip indices aligned with row IDs.
        "按可识别的杀怪经验消息逐条统计。组队共享经验也会计入；满级和灰怪等无经验击杀不计入。",
        "有经验击杀数除以在线统计时间。",
        "根据经验条变化累计，包括杀怪、任务、探索等来源。",
        "总经验除以在线统计时间，包含休息和跑图时间。",
        "累计杀怪消息中报告的经验，不把奖励括号里的数字重复加算。",
        "同等级最近30条杀怪消息的平均经验；至少3条、最长保留10分钟在线时间。切换地区或队伍后重新采样；增益变化可用 /mah sample 手动重新采样。",
        "余额增加累计，可能包括掉落、卖货、邮件等。",
        "余额减少累计，包括买东西、修理等。",
        "收入减去支出。",
        "累计收入除以在线统计时间，不是净收益速度。",
        "在线时累计（包含空闲）；跨重登保留，离线及载入不计时。输入 /mah reset 开始新一轮。",
        "最近约5分钟总经验效率，包含任务等来源和在线空闲；以5秒分桶，窗口边界最多约5秒误差。至少预热60秒；切换地区、队伍或重新加载后重新预热。",
        "最近约5分钟有经验击杀效率，统计口径与累计击杀相同；不能代表全部死亡怪物。",
        "剩余经验除以近期杀怪消息经验速度，不包含任务、探索经验。至少预热60秒且有3条当前等级样本；样本较少或波动较大时仅供参考。",
        "最近30条、10分钟以内的当前等级杀怪经验样本。少于3条不估算；3至9条提示样本较少；标准差/均值大于35%提示波动较大。这是提示规则，不是置信区间。",
        "总经验减去杀怪消息经验。可能包含任务、探索、漏识别消息、同步差异等，不能直接称为任务经验；经验缺口或旧版统计未重置时不展示此差额。",
        "等待数据安静2秒后核对两个来源。没有发现差额异常不等于击杀完整；可用 /mah status 查看未识别、不可读和经验缺口等诊断。",
        "当前一波杀怪经验消息的总和，括号是有经验击杀数。进战自动开始新一波，脱战后保留结果并接收延迟消息；再次进战只清空本波，不清累计。连续不脱战视为同一波，可输入 /mah wave 手动新开一波。任务经验不计入。没有消息编号时无法保证去重；组队共享经验也计入。"
    }
    values, rows = {}, {}
    for i = 2, 19 do
        local name = names[i]
        local row = CreateFrame("Frame", nil, frame)
        rows[i] = row
        row:Hide()
        row:SetHeight(22)
        row:EnableMouse(true)
        local tip = tips[i]
        row:SetScript("OnEnter", function(self) Tooltip(self, tip) end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        local label = Text(row, "GameFontHighlightSmall")
        label:SetPoint("LEFT", 0, 0)
        label:SetText(name)
        local v = Text(row, "GameFontHighlightSmall")
        v:SetPoint("RIGHT", 0, 0)
        v:SetText("—")
        values[i] = v
    end
    footer = Text(frame, "GameFontNormalSmall")
    footer:SetJustifyH("LEFT")
    footer:SetHeight(28)
    footer:Hide()
    local help = Text(frame, "GameFontDisableSmall")
    help:SetPoint("BOTTOMLEFT", 14, 12)
    help:SetText("仅计有经验击杀 · 鼠标悬停查看说明")
    detailButton = Button(frame, "展开详情", 84, function() db.showDetails = not db.showDetails; Render() end)
    detailButton:SetPoint("BOTTOMLEFT", 14, 32)
    local quickReset = Button(frame, "重置", 60, function() resetDialog:Show() end)
    quickReset:SetPoint("LEFT", detailButton, "RIGHT", 10, 0)
    resize = CreateFrame("Button", nil, frame)
    resize:SetSize(16, 16)
    resize:SetPoint("BOTTOMRIGHT", -3, 3)
    resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resize:SetScript("OnMouseDown", function(_, b) if b == "LeftButton" and not db.locked then frame:StartSizing("RIGHT") end end)
    resize:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        db.frameWidth = frame:GetWidth()
        local x, y = frame:GetCenter()
        local ratio = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
        db.frameX, db.frameY = x - UIParent:GetWidth() * ratio / 2, y - UIParent:GetHeight() * ratio / 2
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", db.frameX, db.frameY)
    end)

    settings = CreateFrame("Frame", "MageAOEHelperSettingsFrame", UIParent, "BackdropTemplate")
    settings:SetSize(290, 240)
    settings:SetPoint("CENTER")
    settings:SetFrameStrata("DIALOG")
    settings:EnableMouse(true)
    Backdrop(settings)
    local heading = Text(settings)
    heading:SetPoint("TOP", 0, -16)
    heading:SetText("MageAOEHelper-Forever · 设置")
    local close = CreateFrame("Button", nil, settings, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    lockCheck = CreateFrame("CheckButton", nil, settings, "UICheckButtonTemplate")
    lockCheck:SetPoint("TOPLEFT", 18, -42)
    local label = Text(lockCheck)
    label:SetPoint("LEFT", lockCheck, "RIGHT", 2, 0)
    label:SetText("锁定窗口位置与宽度")
    lockCheck:SetScript("OnClick", function(self) db.locked = not not self:GetChecked(); ApplySettings() end)
    scaleLabel = Text(settings)
    scaleLabel:SetPoint("TOPLEFT", 24, -86)
    slider = CreateFrame("Slider", nil, settings, "BackdropTemplate")
    slider:SetPoint("TOPLEFT", 24, -112)
    slider:SetSize(240, 18)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(0.6, 2)
    slider:SetValueStep(0.1)
    Backdrop(slider)
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    slider:EnableMouse(true)
    slider:SetScript("OnValueChanged", function(_, v)
        db.frameScale = math.floor(v * 10 + 0.5) / 10
        frame:SetScale(db.frameScale)
        scaleLabel:SetText(string.format("界面缩放：%.1f", db.frameScale))
    end)
    local reset = Button(settings, "重置统计", 110, function() resetDialog:Show() end)
    reset:SetPoint("BOTTOMLEFT", 24, 58)
    local home = Button(settings, "窗口回中", 110, function()
        db.frameX, db.frameY = 0, 100
        frame:ClearAllPoints(); frame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    end)
    home:SetPoint("BOTTOMRIGHT", -24, 58)
    local note = Text(settings, "GameFontDisableSmall")
    note:SetPoint("BOTTOM", 0, 18)
    note:SetText("重置只清除本角色统计\n关闭游戏前请正常退出以保存")
    settings:Hide()

    resetDialog = CreateFrame("Frame", "MageAOEHelperResetDialog", UIParent, "BackdropTemplate")
    resetDialog:SetSize(340, 150)
    resetDialog:SetPoint("CENTER")
    resetDialog:SetFrameStrata("FULLSCREEN_DIALOG")
    resetDialog:EnableMouse(true)
    Backdrop(resetDialog)
    local question = Text(resetDialog)
    question:SetPoint("TOP", 0, -20)
    question:SetText("确认重置统计？")
    local explanation = Text(resetDialog, "GameFontHighlightSmall")
    explanation:SetPoint("TOP", 0, -50)
    explanation:SetText("清空本角色累计统计、本波数据与样本。\n窗口设置保留；此操作无法撤销。")
    local cancel = Button(resetDialog, "取消", 100, function() resetDialog:Hide() end)
    cancel:SetPoint("BOTTOMLEFT", 50, 18)
    local confirm = Button(resetDialog, "确认重置", 100, function()
        resetDialog:Hide()
        if ready then Reset(); Render() else Say("请等待角色进入游戏后再重置。") end
    end)
    confirm:SetPoint("BOTTOMRIGHT", -50, 18)
    resetDialog:Hide()
    ApplySettings()
end

local function Status()
    local version, build, _, interface = GetBuildInfo()
    Say("版本 1.6.2；客户端 " .. tostring(S.Safe(version)) .. " / " .. tostring(S.Safe(build)) .. "；接口 " .. tostring(S.Safe(interface)))
    Say("杀怪模板 " .. (patterns.killCount or 0) .. "；本次加载收到经验消息 " .. eventsSeen)
    Say("累计排除非击杀 " .. session.excluded .. "；未识别 " .. session.unknown .. "；不可读 " .. session.unreadable .. "；重复ID " .. session.duplicates)
    Say("有经验击杀 " .. session.kills .. "；杀怪经验 " .. session.killXP .. "；总经验 " .. session.totalXP)
    local wave = runtime.wave
    Say("本波经验 " .. (wave and wave.xp or 0) .. "；本波击杀 " .. (wave and wave.kills or 0) .. "；进战划分波次，连续不脱战可用 /mah wave")
    local info = S.SampleInfo(session, runtime, S.Number(UnitLevel("player"), nil, 1, 1000))
    Say("样本 " .. info.count .. "/30（" .. info.state .. "）；经验缺口 " .. session.xpGaps .. "；载入期间金币净变动 " .. session.moneyGaps .. " 次")
    Say("数据核对：" .. S.Check(session, runtime) .. "；最近重新采样原因：" .. (runtime.sampleReason or "登录/重载"))
    Say("经验：" .. (runtime.xpUnavailable and "暂不可读" or runtime.pending and "等待稳定" or "可读") .. "；金币：" .. (runtime.moneyUnavailable and "暂不可读" or "可读"))
    Say("实时交战数量不可用；无经验击杀不统计；/reload 与重登保留统计。")
    for e in pairs(failures) do Say("未能注册事件：" .. e) end
end

local function Slash(msg)
    if not ready then Say("请等待角色进入游戏。") return end
    msg = type(msg) == "string" and msg:lower():match("^%s*(.-)%s*$") or ""
    if msg == "settings" or msg == "设置" then settings:SetShown(not settings:IsShown()); ApplySettings()
    elseif msg == "show" or msg == "显示" then db.showFrame = not db.showFrame; Render()
    elseif msg == "lock" or msg == "锁定" then db.locked = not db.locked; ApplySettings()
    elseif msg == "details" or msg == "详情" then db.showDetails = not db.showDetails; Render()
    elseif msg == "wave" or msg == "新一波" then S.StartWave(runtime, "manual"); Say("已开始新一波，累计统计不变。"); Render()
    elseif msg == "reset" or msg == "重置" then Reset(); Render()
    elseif msg == "sample" or msg == "采样" then S.ChangeContext(session, runtime, "手动重新采样"); Say("已清除估算样本与近期窗口，累计统计不变。"); Render()
    elseif msg == "status" or msg == "debug" or msg == "状态" then Status()
    else
        Say("/mah settings 设置；/mah show 显示或隐藏；/mah lock 锁定或解锁")
        Say("/mah reset 重置统计；/mah sample 重新采样；/mah status 查看统计与兼容情况")
        Say("/mah details 展开详情；/mah wave 手动开始新一波（只清本波）")
    end
end
SLASH_MAGEAOEHELPER1 = "/mah"
SLASH_MAGEAOEHELPER2 = "/mageaoehelper"
SlashCmdList.MAGEAOEHELPER = Slash

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= addonName then return end
        db = type(MageAOEHelperDB) == "table" and MageAOEHelperDB or {}
        db.frameX = S.Number(db.frameX, 0, -10000, 10000)
        db.frameY = S.Number(db.frameY, 100, -10000, 10000)
        db.frameScale = S.Number(db.frameScale, 1, 0.6, 2)
        db.frameWidth = S.Number(db.frameWidth, 420, 400, 650)
        db.showFrame = db.showFrame ~= false
        db.locked = db.locked == true
        db.showDetails = db.showDetails == true
        MageAOEHelperDB = db
        session = S.Restore(MageAOEHelperForeverSession)
        MageAOEHelperForeverSession = session
        runtime = S.Runtime()
        patterns = S.BuildPatterns(_G)
    elseif event == "PLAYER_ENTERING_WORLD" then
        if not session then return end
        if not frame then CreateUI() end
        if not entered then
            Baseline() -- a fresh login/reload has no earlier readable baseline
            SyncCombat()
            entered, ready = true, true
            Render()
        else
            -- Preserve the confirmed baseline across loading. Let transient
            -- entry snapshots settle before reconciliation, excluding this wait.
            ready, resumeWait, loadingMoneyPending = false, 1, true
        end
    elseif event == "PLAYER_LEAVING_WORLD" then
        ready, resumeWait = false, nil
        if resetDialog then resetDialog:Hide() end
    elseif event == "CHAT_MSG_COMBAT_XP_GAIN" and entered then
        -- Count delivered messages even during a same-session loading screen.
        -- Blizzard's ChatInfoDocumentation places lineID at payload position 11.
        eventsSeen = eventsSeen + 1
        S.Kill(session, runtime, (...), select(11, ...), UnitLevel("player"), patterns)
    elseif ready then
        -- Blizzard's default combat text maps these events to entering/leaving combat:
        -- https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_CombatText/Shared/CombatText.lua
        if event == "PLAYER_REGEN_DISABLED" then
            S.Combat(runtime, true); Render()
        elseif event == "PLAYER_REGEN_ENABLED" then
            S.Combat(runtime, false); Render()
        elseif event == "PLAYER_XP_UPDATE" then
            if S.Safe(...) == "player" then UpdateXP() end
        elseif event == "PLAYER_MONEY" then
            UpdateMoney()
        -- Event source (generated Blizzard docs; target-client support is probed):
        -- https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/PartyInfoDocumentation.lua
        -- Zone event source: https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_Minimap/Mainline/Minimap.lua
        elseif event == "GROUP_ROSTER_UPDATE" or event == "ZONE_CHANGED_NEW_AREA" then
            S.ChangeContext(session, runtime, event == "GROUP_ROSTER_UPDATE" and "队伍变化" or "地区变化")
        end
    end
end)
local tick = 0
eventFrame:SetScript("OnUpdate", function(_, elapsed)
    if resumeWait then
        resumeWait = resumeWait - elapsed
        if resumeWait <= 0 then
            resumeWait, ready = nil, true
            S.ChangeContext(session, runtime, "地图载入")
            SyncCombat(); UpdateXP(); UpdateMoney(); Render()
        end
        return
    end
    if not ready then return end
    session.seconds = session.seconds + elapsed
    runtime.clock = runtime.clock + elapsed
    tick = tick + elapsed
    if tick >= 0.5 then
        tick = 0
        UpdateXP()
        UpdateMoney() -- recover from unavailable values even without another event
        Render()
    end
end)
for _, e in ipairs({"ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "PLAYER_XP_UPDATE", "PLAYER_MONEY", "CHAT_MSG_COMBAT_XP_GAIN", "GROUP_ROSTER_UPDATE", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED"}) do
    local ok = pcall(eventFrame.RegisterEvent, eventFrame, e)
    if not ok then failures[e] = true end
end
