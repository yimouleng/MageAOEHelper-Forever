-- Independent implementation of XP-message-driven farming statistics.
-- Reference approach (not copied): https://github.com/fkleindev/WombatLog/blob/main/KillAlert.lua
-- and https://github.com/fkleindev/WombatLog/blob/main/Stats.lua
local _, ns = ...
local S = {}
ns.Stats = S

function S.Safe(v)
    -- Check secrecy BEFORE comparison, indexing, conversion or arithmetic.
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

function S.Number(v, fallback, low, high)
    v = S.Safe(v)
    if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then return fallback end
    if low and v < low or high and v > high then return fallback end
    return v
end

local function escape(s)
    return (s:gsub("([%%%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"))
end

-- Compile CLIENT format strings, never player chat. Capture argument #2 (XP)
-- even when the translation reorders positional placeholders such as %2$d.
function S.Compile(fmt)
    fmt = S.Safe(fmt)
    if type(fmt) ~= "string" or #fmt > 1024 then return nil end
    local parts, args, pos, nextArg = {"^"}, {}, 1, 1
    while pos <= #fmt do
        local first = fmt:find("%", pos, true)
        if not first then parts[#parts + 1] = escape(fmt:sub(pos)); break end
        parts[#parts + 1] = escape(fmt:sub(pos, first - 1))
        local tail = fmt:sub(first)
        if tail:sub(1, 2) == "%%" then
            parts[#parts + 1] = "%%"
            pos = first + 2
        else
            local token, arg, kind = tail:match("^(%%(%d+)%$([sd]))")
            if not token then
                token, kind = tail:match("^(%%([sd]))")
                arg = nextArg
                nextArg = nextArg + 1
            end
            if not token then return nil end
            args[#args + 1] = { index = tonumber(arg), kind = kind }
            if #args > 12 then return nil end
            parts[#parts + 1] = kind == "s" and "(.-)" or "(%d+)"
            pos = first + #token
        end
    end
    -- Allow a documented bonus annotation following the first-person message.
    parts[#parts + 1] = "(.*)$"
    return {pattern = table.concat(parts), args = args}
end

function S.BuildPatterns(globals)
    local result = {}
    for key, value in pairs(globals) do
        if type(key) == "string" and (key:match("^COMBATLOG_XPGAIN_FIRSTPERSON") or key:match("^COMBATLOG_XPGAIN_EXHAUSTION") or key == "COMBATLOG_XPGAIN_QUEST") then
            local p = S.Compile(value)
            if p then
                p.nonKill = key:find("UNNAMED", 1, true) ~= nil or key == "COMBATLOG_XPGAIN_QUEST"
                result[#result + 1] = p
                if not p.nonKill then result.killCount = (result.killCount or 0) + 1 end
            end
            if #result >= 32 then break end
        end
    end
    return result
end

function S.Parse(message, patterns)
    if issecretvalue and issecretvalue(message) then return nil, "unreadable" end
    message = S.Safe(message)
    if type(message) ~= "string" or #message > 4096 then return nil, "unknown" end
    local nonKill = false
    for _, p in ipairs(patterns) do
        local captures = {message:match(p.pattern)}
        if #captures > 0 then
            if p.nonKill then nonKill = true else
            local name, xp
            for i, spec in ipairs(p.args) do
                if spec.index == 1 and spec.kind == "s" then name = captures[i] end
                if spec.index == 2 and spec.kind == "d" then xp = tonumber(captures[i]) end
            end
            if name and name ~= "" and xp and xp > 0 and xp < 1000000000 then return xp, "kill" end
            end
        end
    end
    return nil, nonKill and "excluded" or "unknown"
end

function S.New()
    return {schema = 3, seconds = 0, kills = 0, totalXP = 0, killXP = 0,
        income = 0, spending = 0, samples = {}, excluded = 0, unknown = 0,
        unreadable = 0, duplicates = 0, xpGaps = 0, moneyGaps = 0}
end

function S.Restore(saved)
    if type(saved) ~= "table" or (saved.schema ~= 2 and saved.schema ~= 3) then return S.New() end
    local clean = S.New()
    for _, k in ipairs({"seconds", "kills", "totalXP", "killXP", "income", "spending", "excluded", "unknown", "unreadable", "duplicates", "xpGaps", "moneyGaps"}) do
        clean[k] = S.Number(saved[k], 0, 0, 1e15)
    end
    -- Keep history, but do not certify totals computed by the previous XP algorithm.
    clean.legacy = saved.schema == 2 or saved.legacy == true
    -- Recalibrate samples after reload/login instead of retaining stale farm conditions.
    return clean
end

function S.Runtime()
    return {seen = {}, order = {}, clock = 0, buckets = {}, sampleTimes = {}, recentStart = 0}
end

-- Sixty-one 5-second buckets bound memory; all clocks exclude offline/loading time.
function S.Record(r, field, amount)
    local slot = math.floor(r.clock / 5)
    local index = slot % 61 + 1
    local b = r.buckets[index]
    if not b or b.slot ~= slot then b = {slot = slot}; r.buckets[index] = b end
    b[field] = (b[field] or 0) + amount
    r.changedAt = r.clock
end

function S.Recent(r)
    local result = {xp = 0, kills = 0, killXP = 0, income = 0, spending = 0}
    local oldest = r.clock - 300
    for _, b in pairs(r.buckets) do
        if b.slot * 5 >= oldest then
            for field in pairs(result) do result[field] = result[field] + (b[field] or 0) end
        end
    end
    result.seconds = math.min(300, math.max(0, r.clock - r.recentStart))
    result.warmed = result.seconds >= 60
    return result
end

function S.ClearSamples(s, r, reason)
    s.samples, s.sampleLevel, r.sampleTimes = {}, nil, {}
    r.sampleReason = reason
end

function S.PruneSamples(s, r)
    while #s.samples > 0 and (not r.sampleTimes[1] or r.clock - r.sampleTimes[1] >= 600) do
        table.remove(s.samples, 1); table.remove(r.sampleTimes, 1)
    end
end

function S.ChangeContext(s, r, reason)
    S.ClearSamples(s, r, reason)
    r.buckets, r.recentStart = {}, r.clock
end

function S.Kill(session, runtime, message, lineID, level, patterns)
    -- Do not deduplicate by time or text: simultaneous identical mobs are distinct kills.
    lineID = S.Number(lineID, nil, 1, 1e15)
    if lineID then
        if runtime.seen[lineID] then session.duplicates = session.duplicates + 1; return false end
        runtime.seen[lineID] = true
        runtime.order[#runtime.order + 1] = lineID
        if #runtime.order > 256 then runtime.seen[table.remove(runtime.order, 1)] = nil end
    end
    local xp, kind = S.Parse(message, patterns)
    if not xp then session[kind] = session[kind] + 1; return false end
    session.kills = session.kills + 1
    session.killXP = session.killXP + xp
    S.Record(runtime, "kills", 1)
    S.Record(runtime, "killXP", xp)
    level = S.Number(level, nil, 1, 1000)
    if not level then return true end
    if level ~= session.sampleLevel then S.ClearSamples(session, runtime, "等级变化"); session.sampleLevel = level end
    S.PruneSamples(session, runtime)
    session.samples[#session.samples + 1] = xp
    runtime.sampleTimes[#runtime.sampleTimes + 1] = runtime.clock
    if #session.samples > 30 then table.remove(session.samples, 1); table.remove(runtime.sampleTimes, 1) end
    return true
end

function S.Baseline(runtime, xp, maximum, level, money)
    runtime.xp = S.Number(xp, nil, 0, 1e12)
    runtime.maximum = S.Number(maximum, nil, 0, 1e12)
    runtime.level = S.Number(level, nil, 1, 1000)
    runtime.money = S.Number(money, nil, 0, 1e15)
    runtime.xpUnavailable = runtime.xp == nil or runtime.maximum == nil or runtime.level == nil
    runtime.moneyUnavailable = runtime.money == nil
    runtime.pending = nil
end

function S.XP(session, r, xp, maximum, level)
    xp, maximum, level = S.Number(xp, nil, 0, 1e12), S.Number(maximum, nil, 0, 1e12), S.Number(level, nil, 1, 1000)
    if not xp or not maximum or not level or (maximum > 0 and xp > maximum) then r.xpUnavailable = true; return end
    r.xpUnavailable = false
    local delta = 0
    if r.xp and r.maximum and r.level then
        if level == r.level and maximum == r.maximum and xp >= r.xp then
            delta, r.pending = xp - r.xp, nil
        else
            -- Never synthesize a level. Retain the confirmed baseline while the
            -- client publishes XP, maximum and level in separate updates.
            local p = r.pending
            if not p then p = {since = r.clock}; r.pending = p end
            if p.xp ~= xp or p.maximum ~= maximum or p.level ~= level then
                p.xp, p.maximum, p.level, p.changed = xp, maximum, level, r.clock
            end
            local stable = r.clock - p.changed >= 1
            -- An unchanged XP field may still be the previous level's value.
            -- An exactly equal legitimate new-level value is ambiguous too;
            -- prefer a reported gap to inventing a full level of experience.
            if stable and level == r.level + 1 and maximum ~= r.maximum and xp ~= r.xp then
                delta = math.max(0, r.maximum - r.xp) + xp
            elseif stable and r.clock - p.since >= 5 then
                session.xpGaps = session.xpGaps + 1 -- ambiguous/multilevel snapshot: rebaseline, flag loss
                r.changedAt = r.clock
            else
                return
            end
            r.pending = nil
        end
    end
    if delta > 0 then session.totalXP = session.totalXP + delta; S.Record(r, "xp", delta) end
    r.xp, r.maximum, r.level = xp, maximum, level
end

function S.Money(session, r, money, afterLoading)
    money = S.Number(money, nil, 0, 1e15)
    if not money then r.moneyUnavailable = true; return end
    r.moneyUnavailable = false
    if r.money then
        local delta = money - r.money
        if afterLoading and delta ~= 0 then session.moneyGaps = session.moneyGaps + 1 end
        if delta > 0 then session.income = session.income + delta; S.Record(r, "income", delta)
        elseif delta < 0 then session.spending = session.spending - delta; S.Record(r, "spending", -delta) end
    end
    r.money = money
end

function S.SampleInfo(session, r, level)
    S.PruneSamples(session, r)
    if level ~= session.sampleLevel then return {count = 0, state = "等待当前等级样本"} end
    local n = #session.samples
    if n < 3 then return {count = n, state = "样本不足"} end
    local total = 0
    for _, xp in ipairs(session.samples) do total = total + xp end
    local mean, squares = total / n, 0
    for _, xp in ipairs(session.samples) do squares = squares + (xp - mean)^2 end
    local cv = math.sqrt(squares / n) / mean
    return {count = n, mean = mean, cv = cv, state = cv > 0.35 and "波动较大" or n < 10 and "样本较少" or "样本较稳定"}
end

function S.Estimate(session, remaining, level, r)
    local info = S.SampleInfo(session, r, level)
    if not info.mean then return nil, info end
    return math.ceil(math.max(0, remaining) / info.mean), info
end

function S.Check(session, r)
    if r.pending then return "等待升级数据稳定", nil end
    if r.xpUnavailable then return "经验暂不可读", nil end
    if r.clock - (r.changedAt or 0) < 2 then return "等待数据同步", nil end
    if session.legacy then return "含旧版数据，建议重置", nil end
    local difference = session.totalXP - session.killXP
    if difference < 0 then return "经验不一致，请查看状态", nil end
    if session.xpGaps > 0 then return "存在经验缺口", nil end
    if session.unknown + session.unreadable > 0 then return "有未识别或不可读消息", difference end
    return "未发现差额异常", difference
end
