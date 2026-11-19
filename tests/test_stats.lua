-- Run with Lua 5.1 from the repository root. No game client is required.
local ns = {}
assert(loadfile('Stats.lua'))('MageAOEHelper-Forever', ns)
local S, tests = ns.Stats, 0
local function eq(a, b, why)
    assert(a == b, (why or '') .. ': expected ' .. tostring(b) .. ', got ' .. tostring(a))
    tests = tests + 1
end
local secret = {}
issecretvalue = function(v) return rawequal(v, secret) end
local globals = {
    COMBATLOG_XPGAIN_FIRSTPERSON = '%s死亡，你获得%d点经验值。',
    COMBATLOG_XPGAIN_FIRSTPERSON_GROUP = '%s死了，你获得了%d点经验值。（+%d组队奖励）',
    COMBATLOG_XPGAIN_EXHAUSTION1 = '%s死了，你获得了%d点经验值。（%s点%s奖励）',
    COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED = '你获得了%d点经验值。',
    COMBATLOG_XPGAIN_QUEST = '任务奖励%d点经验。',
}
local p = S.BuildPatterns(globals)
local message = '野猪死亡，你获得100点经验值。'
eq(p.killCount,3,'kill templates exclude generic/quest formats')
eq(S.Parse(message,p),100,'Chinese kill')
eq(S.Parse('野猪死了，你获得了150点经验值。（+50组队奖励）',p),150,'group reward not double counted')
eq(S.Parse('野猪死了，你获得了200点经验值。（100点休息奖励）',p),200,'rested reward not double counted')
eq(S.Parse('获得300点经验：野猪死亡。',{S.Compile('获得%2$d点经验：%1$s死亡。')}),300,'positional args')
eq(S.Parse('Boar dies, you gain 100 experience. (+20 bonus)',{S.Compile('%s dies, you gain %d experience.')}),100,'English bonus suffix')
eq(select(2,S.Parse('你获得了500点经验值。',p)),'excluded','unnamed is not parsing failure')
eq(select(2,S.Parse('任务奖励500点经验。',p)),'excluded','quest exclusion')
eq(select(2,S.Parse('未知格式',p)),'unknown','unknown separate')
eq(select(2,S.Parse(secret,p)),'unreadable','secret separate')
eq(S.Parse(string.rep('x',5000),p),nil,'input bound')
eq(S.Compile('%q'),nil,'unsupported placeholder')
eq(S.Number(secret,0),0,'secret rejected before arithmetic')
eq(S.Number(0/0,0),0,'NaN rejected')
eq(S.Number(math.huge,0),0,'infinity rejected')

local s,r = S.New(), S.Runtime()
for i=1,5 do S.Kill(s,r,message,i,20,p) end
eq(s.kills,5,'same-name simultaneous kills')
S.Kill(s,r,message,5,20,p)
eq(s.kills,5,'duplicate ID not counted')
eq(s.duplicates,1,'duplicate diagnostic')
S.Kill(s,r,message,nil,20,p); S.Kill(s,r,message,0,20,p)
eq(s.kills,7,'no valid ID means no guessing dedup')
S.Kill(s,r,'你获得了500点经验值。',8,20,p)
S.Kill(s,r,'未知格式',9,20,p)
S.Kill(s,r,secret,10,20,p)
eq(s.excluded,1,'excluded counter')
eq(s.unknown,1,'unknown counter')
eq(s.unreadable,1,'unreadable counter')
eq(s.kills,7,'nonkills cannot change counts')
eq(S.Estimate(s,1000,20,r),10,'kill-only mean')
eq(S.SampleInfo(s,r,20).state,'样本较少','small sample advisory')
for i=20,1000 do S.Kill(s,r,message,i,20,p) end
eq(#r.order,256,'bounded dedup memory')
eq(#s.samples,30,'bounded sample memory')
eq(#r.sampleTimes,30,'paired sample timestamps')
eq(S.SampleInfo(s,r,20).state,'样本较稳定','consistent sample')
r.clock=600
eq(S.SampleInfo(s,r,20).count,0,'stale sample expiry')
eq(S.Estimate(s,1000,20,r),nil,'expired samples cannot estimate')
S.Kill(s,r,message,1001,21,p)
eq(S.SampleInfo(s,r,20).count,0,'old level cannot estimate')
eq(S.SampleInfo(s,r,21).count,1,'new level starts fresh')
S.Kill(s,r,message,1002,21,p)
S.Kill(s,r,'野猪死亡，你获得900点经验值。',1003,21,p)
eq(S.SampleInfo(s,r,21).state,'波动较大','mixed conditions flagged')
local kills = s.kills
S.ChangeContext(s,r,'测试')
eq(#s.samples,0,'context clears samples')
eq(S.Recent(r).seconds,0,'context restarts warmup')
eq(s.kills,kills,'context preserves lifetime counters')

-- Exhaust all six orders of XP, maximum, and level snapshots (subsecond skew).
local orders={{1,2,3},{1,3,2},{2,1,3},{2,3,1},{3,1,2},{3,2,1}}
for _, order in ipairs(orders) do
    s,r=S.New(),S.Runtime(); S.Baseline(r,900,1000,20,0)
    local raw,final={900,1000,20},{50,1200,21}
    for _, field in ipairs(order) do
        r.clock=r.clock+0.1; raw[field]=final[field]
        S.XP(s,r,unpack(raw))
        eq(s.totalXP,0,'never commits incomplete upgrade snapshot')
        eq(r.level,20,'never fabricates a level')
    end
    r.clock=2; S.XP(s,r,50,1200,21)
    eq(s.totalXP,150,'settled level delta')
    S.XP(s,r,50,1200,21)
    eq(s.totalXP,150,'duplicate XP notification')
    S.XP(s,r,150,1200,21)
    eq(s.totalXP,250,'later XP works after upgrade')
    eq(s.xpGaps,0,'ordinary upgrade has no gap')
end
s,r=S.New(),S.Runtime(); S.Baseline(r,900,1000,20,0)
S.XP(s,r,50,1000,20); r.clock=2; S.XP(s,r,50,1000,20)
eq(s.totalXP,0,'XP-first regression must not synthesize a level')
S.XP(s,r,50,1200,21); r.clock=3; S.XP(s,r,50,1200,21)
S.XP(s,r,150,1200,21)
eq(s.totalXP,250,'review regression expected 250 not 1150')
eq(r.level,21,'confirmed actual level retained')
s,r=S.New(),S.Runtime(); S.Baseline(r,900,1000,20,0)
S.XP(s,r,900,1200,21); r.clock=2; S.XP(s,r,900,1200,21)
eq(s.totalXP,0,'level/max before XP must not accept stale XP after 1 second')
S.XP(s,r,50,1200,21); r.clock=3; S.XP(s,r,50,1200,21)
eq(s.totalXP,150,'late XP settles without invented full level')
s,r=S.New(),S.Runtime(); S.Baseline(r,10,1000,20,0)
S.XP(s,r,500,1200,21); r.clock=1; S.XP(s,r,500,1200,21)
eq(s.totalXP,1490,'large but unambiguous one-level gain')
s,r=S.New(),S.Runtime(); S.Baseline(r,100,1000,20,0)
S.XP(s,r,100,1200,21); r.clock=5; S.XP(s,r,100,1200,21)
eq(s.totalXP,0,'equal old/new XP cannot establish field freshness')
eq(s.xpGaps,1,'ambiguous equal XP reported as gap')
s,r=S.New(),S.Runtime(); S.Baseline(r,900,1000,59,0)
S.XP(s,r,0,0,60); r.clock=1; S.XP(s,r,0,0,60)
eq(s.totalXP,100,'final level remaining XP')
s,r=S.New(),S.Runtime(); S.Baseline(r,900,1000,20,0)
S.XP(s,r,10,1800,24); r.clock=5; S.XP(s,r,10,1800,24)
eq(s.xpGaps,1,'multi-level gap explicitly flagged')
eq(s.totalXP,0,'unknown intermediate levels not fabricated')
S.XP(s,r,110,1800,24)
eq(s.totalXP,100,'recover after gap')
S.XP(s,r,secret,1800,24)
eq(r.xpUnavailable,true,'unreadable XP marked')
S.XP(s,r,210,1800,24)
eq(r.xpUnavailable,false,'XP readability recovers')
eq(s.totalXP,200,'preserves last readable baseline')
S.XP(s,r,2000,1800,24)
eq(r.xpUnavailable,true,'impossible XP rejected')

s,r=S.New(),S.Runtime(); S.Baseline(r,100,1000,20,1000)
S.XP(s,r,300,1000,20); S.Money(s,r,1500,true)
eq(s.totalXP,200,'preserved baseline captures loading XP')
eq(s.income,500,'loading money difference counted')
eq(s.moneyGaps,1,'loading money is net-only flagged')
S.Money(s,r,1500,true)
eq(s.moneyGaps,1,'unchanged balance is not extra gap')
S.Money(s,r,secret)
eq(r.moneyUnavailable,true,'money unreadable')
S.Baseline(r,300,1000,20,1500)
eq(r.moneyUnavailable,false,'baseline clears stale money flag')
S.Money(s,r,secret); S.Money(s,r,1200)
eq(r.moneyUnavailable,false,'poll clears unreadable flag')
eq(s.spending,300,'money after recovery')
eq(s.income-s.spending,200,'net income')

s,r=S.New(),S.Runtime()
S.Record(r,'xp',100); S.Record(r,'kills',1)
r.clock=59; eq(S.Recent(r).warmed,false,'warmup gating')
r.clock=60; eq(S.Recent(r).warmed,true,'warmup complete')
eq(S.Recent(r).xp,100,'recent XP retained')
r.clock=300; eq(S.Recent(r).xp,100,'5 minute exact boundary')
r.clock=305; eq(S.Recent(r).xp,0,'idle expires recent gains')
eq(S.Recent(r).seconds,300,'rolling denominator capped')
for i=1,10000 do r.clock=i; S.Record(r,'xp',1) end
local buckets=0; for _ in pairs(r.buckets) do buckets=buckets+1 end
eq(buckets,61,'bounded recent buckets')
eq(S.Recent(r).xp,301,'rolling 5-second boundary inclusive')
S.ChangeContext(s,r,'test'); eq(S.Recent(r).xp,0,'context clears recent rates')

s,r=S.New(),S.Runtime(); S.Baseline(r,0,1000,20,0)
S.Kill(s,r,message,1,20,p)
eq(S.Check(s,r),'等待数据同步','chat arrives before XP')
S.XP(s,r,100,1000,20); r.clock=2
eq(S.Check(s,r),'未发现差额异常','equal settled sources')
S.XP(s,r,600,1000,20); r.clock=4
eq(select(2,S.Check(s,r)),500,'other is difference not assigned quest')
S.Kill(s,r,'你获得了500点经验值。',2,20,p)
eq(S.Check(s,r),'未发现差额异常','normal nonkill does not warn')
S.Kill(s,r,'未识别',3,20,p)
eq(S.Check(s,r),'有未识别或不可读消息','unknown warns')
s.killXP=700
eq(S.Check(s,r),'经验不一致，请查看状态','negative difference warns')
s.killXP=100; s.xpGaps=1
eq(select(2,S.Check(s,r)),nil,'gap suppresses classification')
local legacy=S.Restore({schema=2,kills=12,totalXP=9999,skipped=7,samples={200}})
eq(legacy.kills,12,'migration retains old totals')
eq(legacy.legacy,true,'migration does not certify old totals')
eq(#legacy.samples,0,'reload drops stale samples')
eq(legacy.unknown,0,'old mixed skipped not promoted to unknown')
eq(S.Check(legacy,r),'含旧版数据，建议重置','old data labelled')
eq(S.Restore(legacy).legacy,true,'legacy marker survives another reload')
eq(S.Restore({schema=3,kills=-1,seconds='bad',totalXP=math.huge}).totalXP,0,'corrupt saved values sanitized')
eq(S.New().legacy,nil,'explicit reset removes legacy flag')

-- Per-wave totals are separate from saved totals and follow combat boundaries.
s,r=S.New(),S.Runtime()
S.Combat(r,false); eq(r.wave,nil,'idle login does not invent a wave')
S.Combat(r,true); eq(r.wave.xp,0,'combat entry starts empty wave')
S.Kill(s,r,message,1,20,p)
S.Kill(s,r,'野猪死了，你获得了200点经验值。（100点休息奖励）',2,20,p)
S.Kill(s,r,message,1,20,p)
S.Kill(s,r,'任务奖励500点经验。',3,20,p)
S.Kill(s,r,secret,4,20,p)
eq(r.wave.xp,300,'wave sums accepted main XP, not bonuses or quest')
eq(r.wave.kills,2,'wave excludes duplicates and unreadable messages')
S.Combat(r,true); eq(r.wave.xp,300,'repeated combat entry cannot clear a wave')
r.clock=10; S.Combat(r,false)
eq(r.wave.xp,300,'combat exit retains completed wave')
eq(r.wave.active,false,'completed wave marked inactive')
S.Kill(s,r,message,5,20,p); eq(r.wave.xp,400,'late XP stays in completed wave')
S.Combat(r,true)
eq(r.wave.xp,0,'next combat clears only wave XP')
eq(r.wave.kills,0,'next combat clears only wave kills')
eq(s.killXP,400,'combat entry preserves cumulative XP')
eq(s.kills,3,'combat entry preserves cumulative kills')
S.Kill(s,r,message,6,20,p); r.clock=100; S.Kill(s,r,message,7,20,p)
eq(r.wave.xp,200,'continuous combat is one wave even after idle')
S.StartWave(r,'manual'); eq(r.wave.xp,0,'manual split clears wave')
eq(s.kills,5,'manual split preserves cumulative stats')
eq(r.wave.active,true,'manual split preserves combat state')
S.Combat(r,secret); eq(r.inCombat,true,'secret combat state ignored')
s,r=S.New(),S.Runtime()
S.Kill(s,r,message,1,20,p); r.clock=0.5; S.Combat(r,true)
eq(r.wave.xp,100,'first message just before combat entry retained')
eq(r.wave.provisional,false,'provisional wave confirmed')
s,r=S.New(),S.Runtime()
S.Kill(s,r,message,1,20,p); r.clock=2; S.Combat(r,true)
eq(r.wave.xp,0,'older unengaged message not assigned to new combat')
eq(s.kills,1,'discarding provisional wave does not discard totals')

-- Strict API mock: undefined methods fail, unlike an all-methods no-op stub.
local frames,texts,methods={},{},{}
for _,name in ipairs({'ClearAllPoints','SetClampedToScreen','SetMovable','SetResizable','SetResizeBounds','EnableMouse','RegisterForDrag','SetBackdrop','SetBackdropColor','SetBackdropBorderColor','SetJustifyH','SetFrameStrata','SetOrientation','SetMinMaxValues','SetValueStep','SetThumbTexture','SetNormalTexture','StartMoving','StopMovingOrSizing','StartSizing'}) do methods[name]=function() end end
function methods:SetPoint(point,...) self.points[point]={...} end
function methods:ClearAllPoints() self.points={} end
function methods:SetScript(e,f) self.scripts[e]=f end
function methods:RegisterEvent(e)
    assert(e~='COMBAT_LOG_EVENT_UNFILTERED','restricted log must not be registered')
    self.events[e]=true
end
function methods:SetSize(w,h)
    self.w,self.h=w,h
    if self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self,w,h) end
end
function methods:SetHeight(h)
    self.h=h
    if self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self,self.w,h) end
end
function methods:SetResizeBounds(...) self.resizeBounds={...} end
function methods:GetWidth() return self.w or 1920 end
function methods:GetHeight() return self.h or 1080 end
function methods:SetScale(v) self.scale=v end
function methods:GetEffectiveScale() return self.scale or 1 end
function methods:GetCenter() return 960,540 end
function methods:SetText(t) self.text=t; texts[t]=true end
function methods:GetText() return self.text end
function methods:SetWordWrap(v) self.wordWrap=v end
function methods:SetShown(v) self.shown=v end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false end
function methods:IsShown() return self.shown end
function methods:SetChecked(v) self.checked=v end
function methods:GetChecked() return self.checked end
function methods:SetValue(v) self.value=v; if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self,v) end end
function CreateFrame(kind,name,parent,template)
    local f=setmetatable({scripts={},events={},points={},shown=true,kind=kind,parent=parent},{__index=methods})
    if name then _G[name]=f end
    frames[#frames+1]=f; return f
end
function methods:CreateFontString() return CreateFrame('FontString',nil,self) end
UIParent=CreateFrame('Frame'); UIParent:SetSize(1920,1080)
SlashCmdList={}
local xp,maxxp,level,money,combat=100,1000,20,10000,false
function UnitXP() return xp end
function UnitXPMax() return maxxp end
function UnitLevel() return level end
function GetMoney() return money end
function UnitAffectingCombat() return combat end
function GetBuildInfo() return '1.60.1','mock','date',16001 end
for k,v in pairs(globals) do _G[k]=v end
MageAOEHelperDB={frameWidth=380,frameScale=1,showFrame=true}
assert(loadfile('MageAOEHelper-Forever.lua'))('MageAOEHelper-Forever',ns)
local ef=frames[#frames]
local function event(e,...)
    assert(ef.events[e],e)
    if e=='PLAYER_REGEN_DISABLED' then combat=true end
    if e=='PLAYER_REGEN_ENABLED' then combat=false end
    ef.scripts.OnEvent(ef,e,...)
end
local function tick(seconds) ef.scripts.OnUpdate(ef,seconds) end
local function kill(id) event('CHAT_MSG_COMBAT_XP_GAIN',message,'','','','','',0,0,'',0,id) end
local function rowValue(label)
    for _,f in ipairs(frames) do
        if f.text==label and f.parent and f.parent.parent==MageAOEHelperFrame then
            for _,v in ipairs(frames) do if v.kind=='FontString' and v.parent==f.parent and v~=f then return v.text end end
        end
    end
end
local function row(label)
    for _,f in ipairs(frames) do
        if f.text==label and f.parent and f.parent.parent==MageAOEHelperFrame then return f.parent end
    end
end
local function shownRows()
    local count=0
    for _,f in ipairs(frames) do
        if f.kind=='Frame' and f.parent==MageAOEHelperFrame and f.h==22 and f.shown then count=count+1 end
    end
    return count
end
local function click(parent,label)
    for _,f in ipairs(frames) do
        if f.kind=='Button' and f.parent==parent and f.text==label then f.scripts.OnClick(f); return end
    end
    error('button not found: '..label)
end
GameTooltip=CreateFrame('Frame')
function GameTooltip:SetOwner(owner) self.owner=owner end
event('ADDON_LOADED','MageAOEHelper-Forever'); tick(10)
eq(MageAOEHelperForeverSession.seconds,0,'prelogin not counted')
event('PLAYER_ENTERING_WORLD',true,false)
eq(MageAOEHelperDB.frameWidth,380,'old valid width retained without forced widening')
eq(MageAOEHelperFrame.resizeBounds[1],260,'minimum width allows narrow windows')
eq(MageAOEHelperFrame.resizeBounds[3],650,'maximum width unchanged')
eq(MageAOEHelperFrame.h,260,'compact panel')
eq(shownRows(),7,'seven primary rows')
eq(row('本波经验（击杀数）').points.TOPLEFT[4],-42,'wave is first row')
eq(row('总经验').shown,false,'diagnostics initially collapsed')
eq(row('实时交战怪物'),nil,'unsupported mob row removed entirely')
local topBefore=MageAOEHelperDB.frameY+MageAOEHelperFrame.h/2
click(MageAOEHelperFrame,'展开详情')
eq(shownRows(),18,'expand all supported statistics')
eq(MageAOEHelperFrame.h,502,'expanded height fits rows')
eq(MageAOEHelperDB.frameY+MageAOEHelperFrame.h/2,topBefore,'expand preserves top edge')
click(MageAOEHelperFrame,'收起详情')
eq(shownRows(),7,'collapse returns to compact rows')
eq(MageAOEHelperDB.frameY+MageAOEHelperFrame.h/2,topBefore,'collapse preserves top edge')
MageAOEHelperFrame:SetSize(260,MageAOEHelperFrame.h)
local panelTitle
for _,f in ipairs(frames) do
    if f.parent==MageAOEHelperFrame and f.text and f.text:find('MAH%-Forever') then panelTitle=f end
end
eq(panelTitle~=nil,true,'narrow window uses short title')
eq(panelTitle.wordWrap,false,'narrow title stays on one line')
for _,f in ipairs(frames) do
    if f.kind=='FontString' and f.parent and f.parent.parent==MageAOEHelperFrame then
        eq(f.wordWrap,false,'row text cannot wrap onto adjacent rows')
        eq(f.points.LEFT~=nil and f.points.RIGHT~=nil,true,'row columns have bounded widths')
    end
end
local firstRow=row('本波经验（击杀数）')
local waveLabel,waveValue
for _,f in ipairs(frames) do
    if f.parent==firstRow then
        if f.text=='本波经验（击杀数）' then waveLabel=f else waveValue=f end
    end
end
eq(waveLabel.points.RIGHT[3],112,'narrow label gets readable width')
eq(waveValue.points.LEFT[3]-waveLabel.points.RIGHT[3],8,'columns retain separation')
firstRow.scripts.OnEnter(firstRow)
eq(GameTooltip.text:find('本波经验（击杀数）：0（0只）',1,true)~=nil,true,'tooltip includes full current value')
MageAOEHelperFrame:SetSize(420,MageAOEHelperFrame.h)
eq(panelTitle.text:find('MageAOEHelper%-Forever')~=nil,true,'widening restores full title')
MageAOEHelperFrame:SetSize(260,MageAOEHelperFrame.h)
for _,f in ipairs(frames) do
    if f.parent==MageAOEHelperFrame and f.kind=='Button' and f.w==16 then f.scripts.OnMouseUp(f) end
end
eq(MageAOEHelperDB.frameWidth,260,'resize saves narrow width')
click(MageAOEHelperFrame,'展开详情')
eq(MageAOEHelperFrame.resizeBounds[1],260,'expansion does not restore old minimum width')
eq(MageAOEHelperFrame.w,260,'expansion preserves chosen width')
click(MageAOEHelperFrame,'收起详情')
eq(MageAOEHelperForeverSession.kills,0,'resize does not alter statistics')
event('PLAYER_REGEN_DISABLED')
for i=1,5 do kill(i) end
xp=600; event('PLAYER_XP_UPDATE','player'); tick(60)
eq(MageAOEHelperForeverSession.kills,5,'actual payload ID position')
eq(MageAOEHelperForeverSession.totalXP,500,'integrated XP')
eq(MageAOEHelperForeverSession.seconds,60,'online clock')
eq(rowValue('本波经验（击杀数）'),'500（5只）','wave rendered as total and count')
event('PLAYER_REGEN_ENABLED')
eq(rowValue('本波经验（击杀数）'),'500（5只）','finished wave stays displayed')
eq(rowValue('近期总经验 / 小时'),'3.0万','rolling rate render')
eq(rowValue('按近期刷怪升级'),'约 1 分钟','kill-only ETA render')
eq(rowValue('其他 / 未归类经验'),'0','reconciliation render')
SlashCmdList.MAGEAOEHELPER('show')
money=11000; event('PLAYER_MONEY')
eq(MageAOEHelperForeverSession.income,1000,'hidden window still tracks')
event('PLAYER_LEAVING_WORLD'); tick(3600)
eq(MageAOEHelperForeverSession.seconds,60,'loading time excluded')
kill(6); xp=800; money=11500
event('PLAYER_ENTERING_WORLD',false,false); tick(1)
eq(MageAOEHelperForeverSession.totalXP,700,'loading XP reconciled not discarded')
eq(MageAOEHelperForeverSession.income,1500,'loading money reconciled')
eq(MageAOEHelperForeverSession.moneyGaps,1,'loading net warning')
eq(MageAOEHelperForeverSession.kills,6,'delivered loading kill message retained')
eq(MageAOEHelperForeverSession.seconds,60,'settle delay excluded')
money=secret; event('PLAYER_MONEY'); tick(0.5)
eq(rowValue('收入 / 小时'),'暂不可读','unavailable money render')
money=11600; tick(0.5)
eq(MageAOEHelperForeverSession.income,1600,'periodic recovery without money event')
eq(rowValue('收入 / 小时')~='暂不可读',true,'stale money warning cleared')
kill(7); kill(8); kill(9)
event('GROUP_ROSTER_UPDATE')
eq(#MageAOEHelperForeverSession.samples,0,'group change resamples')
kill(10); event('ZONE_CHANGED_NEW_AREA')
eq(#MageAOEHelperForeverSession.samples,0,'zone change resamples')
local before=MageAOEHelperForeverSession.kills
SlashCmdList.MAGEAOEHELPER('sample')
eq(MageAOEHelperForeverSession.kills,before,'manual resample retains session')
for _,f in ipairs(frames) do
    if f.kind=='Frame' and f.parent==MageAOEHelperFrame and f.h==22 and f.shown then
        eq(f.points.TOPLEFT[4],f.points.TOPRIGHT[4],'row corners share Y coordinate')
    end
end
for _,f in ipairs(frames) do
    if f.kind=='Frame' and f.parent==MageAOEHelperFrame and f.h==22 then
        f.scripts.OnEnter(f)
        eq(type(GameTooltip.text),'string','every row has a tooltip')
        eq(#GameTooltip.text>0,true,'tooltip is not empty')
    end
end
event('PLAYER_REGEN_DISABLED')
eq(rowValue('本波经验（击杀数）'),'0（0只）','next wave auto clears display')
eq(MageAOEHelperForeverSession.kills,before,'next wave does not clear cumulative kills')
kill(11); tick(0.5)
eq(rowValue('本波经验（击杀数）'),'100（1只）','new wave sums independently')
SlashCmdList.MAGEAOEHELPER('wave')
eq(rowValue('本波经验（击杀数）'),'0（0只）','manual wave command resets just wave')
eq(MageAOEHelperForeverSession.kills,before+1,'manual wave preserves kills')
kill(12); tick(0.5)
click(MageAOEHelperFrame,'重置')
eq(MageAOEHelperResetDialog.shown,true,'external reset requires confirmation')
eq(MageAOEHelperForeverSession.kills,before+2,'opening confirmation does not reset')
click(MageAOEHelperResetDialog,'取消')
eq(MageAOEHelperResetDialog.shown,false,'cancel closes confirmation')
eq(MageAOEHelperForeverSession.kills,before+2,'cancel preserves stats')
click(MageAOEHelperSettingsFrame,'重置统计')
eq(MageAOEHelperResetDialog.shown,true,'settings reset also requires confirmation')
click(MageAOEHelperResetDialog,'确认重置')
eq(MageAOEHelperForeverSession.kills,0,'confirmed reset clears totals')
eq(rowValue('本波经验（击杀数）'),'0（0只）','confirmed reset clears wave')
eq(MageAOEHelperDB.showDetails,false,'reset preserves display preferences')
kill(13); tick(0.5)
eq(rowValue('本波经验（击杀数）'),'100（1只）','counting resumes in same combat after reset')
SlashCmdList.MAGEAOEHELPER('settings'); SlashCmdList.MAGEAOEHELPER('lock')
SlashCmdList.MAGEAOEHELPER('status'); SlashCmdList.MAGEAOEHELPER('reset')
eq(MageAOEHelperForeverSession.kills,0,'reset counts')
eq(MageAOEHelperForeverSession.seconds,0,'reset time')
eq(MageAOEHelperForeverSession.unknown,0,'reset health diagnostics')
eq(rowValue('实时交战怪物'),nil,'no fabricated mob count')

-- Fresh /reload uses a new baseline, not offline or earlier-session gains.
local saved=MageAOEHelperForeverSession
saved.kills,saved.totalXP,saved.killXP=12,1200,1200
saved.samples={100,100,100}; saved.sampleLevel=20
xp,money=900,20000
local nsReload={}
assert(loadfile('Stats.lua'))('MageAOEHelper-Forever',nsReload)
assert(loadfile('MageAOEHelper-Forever.lua'))('MageAOEHelper-Forever',nsReload)
ef=frames[#frames]
event('ADDON_LOADED','MageAOEHelper-Forever'); event('PLAYER_ENTERING_WORLD',true,false)
eq(MageAOEHelperForeverSession.kills,12,'reload retains totals')
eq(MageAOEHelperForeverSession.totalXP,1200,'reload does not invent XP since last process')
eq(#MageAOEHelperForeverSession.samples,0,'reload recalibrates samples')
eq(MageAOEHelperDB.frameWidth,260,'reload preserves saved narrow width')
eq(MageAOEHelperFrame.w,260,'reload does not stretch narrow window')
eq(rowValue('本波经验（击杀数）'),'0（0只）','reload clears runtime wave only')
xp=950; tick(2)
eq(MageAOEHelperForeverSession.totalXP,1250,'reload resumes from fresh baseline')
level=60; tick(0.5)
eq(row('升级还需').shown,false,'max level hides remaining mobs')
SlashCmdList.MAGEAOEHELPER('details')
eq(row('按近期刷怪升级').shown,false,'max level hides ETA in details')
SlashCmdList.MAGEAOEHELPER('details'); level=20

-- Missing message event degrades gracefully without preventing XP/money UI.
local regularRegister=methods.RegisterEvent
function methods:RegisterEvent(e)
    if e=='CHAT_MSG_COMBAT_XP_GAIN' then error('unsupported event (mock)') end
    regularRegister(self,e)
end
local nsMissing={}
assert(loadfile('Stats.lua'))('MageAOEHelper-Forever',nsMissing)
assert(loadfile('MageAOEHelper-Forever.lua'))('MageAOEHelper-Forever',nsMissing)
ef=frames[#frames]
event('ADDON_LOADED','MageAOEHelper-Forever'); event('PLAYER_ENTERING_WORLD',true,false)
eq(texts['缺少击杀数据来源'],true,'missing event visible warning')
eq(row('本波经验（击杀数）').shown,false,'missing kill source hides wave')
eq(row('有经验击杀').shown,false,'missing kill source hides kills')
eq(shownRows(),3,'remaining supported core rows are shown')
SlashCmdList.MAGEAOEHELPER('status')
eq(MageAOEHelperForeverSession.totalXP,1250,'registration failure does not reset counters')

-- Missing combat boundary events require manual splitting, not guessed waves.
function methods:RegisterEvent(e)
    if e=='PLAYER_REGEN_DISABLED' or e=='PLAYER_REGEN_ENABLED' then error('unsupported combat event (mock)') end
    regularRegister(self,e)
end
local nsNoCombat={}
assert(loadfile('Stats.lua'))('MageAOEHelper-Forever',nsNoCombat)
assert(loadfile('MageAOEHelper-Forever.lua'))('MageAOEHelper-Forever',nsNoCombat)
ef=frames[#frames]
event('ADDON_LOADED','MageAOEHelper-Forever'); event('PLAYER_ENTERING_WORLD',true,false)
eq(texts['波次需用 /mah wave 手动分段 · /mah status'],true,'missing boundaries explicitly reported')
kill(1); tick(0.5)
eq(rowValue('本波经验（击杀数）'),'100（1只）','manual mode still counts wave')
SlashCmdList.MAGEAOEHELPER('wave')
eq(rowValue('本波经验（击杀数）'),'0（0只）','manual mode can split waves')
print('PASS: '..tests..' assertions (Lua 5.1, mocked WoW API; NOT an in-game test)')
