--[[
    wdre9 RE9 Trainer v11.2
    Resident Evil 9 / BIOHAZARD requiem — REFramework Lua Mod
    简体中文 / English 双文 UI，一键切换
    Author: wdre9 (self-developed, API patterns verified against community trainers)
]]

local TITLE = "wdre9 RE9 Trainer"
local CFG_FILE = "marvis_re9_trainer.json"

-- ═══════════════════════════════════════════════════════════════════════
-- Config
-- ═══════════════════════════════════════════════════════════════════════

-- 状态表存 _G(跨脚本 Reset 保留): hook 回调与 UI 共享同一状态,
-- 避免 Reset 后旧 hook 持有旧状态导致功能失效或 hook 重复注册
local C = _G.__MARVIS_RE9_TRAINER_CFG__ or {
    lang = "zh",                 -- "zh" | "en"
    god = false,                 -- 无敌 / 无视伤害
    inf_hp = false,              -- 无限生命
    inf_ammo = false,            -- 无限弹药
    no_reload = false,           -- 无需换弹
    instant_reload = false,      -- 即时重载
    no_recoil = false,           -- 无后坐力
    rapid_fire = false,          -- 快速射击
    ohk = false,                 -- v10.14 一击必杀(伤害放大)
    inf_throw = false,           -- 无限投掷物
    cp_value = 0,                -- 编辑 CP
    dbg = false,                 -- v10 调试面板(纯显示, 不写日志)
}
_G.__MARVIS_RE9_TRAINER_CFG__ = C

-- ═══════════════════════════════════════════════════════════════════════
-- Localization
-- ═══════════════════════════════════════════════════════════════════════

local L = {
    zh = {
        title = "wdre9 RE9 修改器",
        lang_label = "语言",
        sec_battle = "战斗",
        sec_weapon = "武器",
        sec_economy = "经济",
        god = "无敌 / 无视伤害",
        inf_hp = "无限生命",
        inf_ammo = "无限弹药",
        no_reload = "无需换弹",
        instant_reload = "即时重载",
        no_recoil = "无后坐力",
        rapid_fire = "快速射击",
        ohk = "高伤害（两枪击杀）",
        inf_throw = "无限投掷物",
        cp = "CP 点数",
        apply = "应用",
        set_ok = "已设置",
        set_fail = "设置失败",
        saved = "设置已保存",
        cp_tip = "输入数值后点应用",
    },
    en = {
        title = "wdre9 RE9 Trainer",
        lang_label = "Language",
        sec_battle = "Combat",
        sec_weapon = "Weapon",
        sec_economy = "Economy",
        god = "God Mode / Ignore Hits",
        inf_hp = "Infinite Health",
        inf_ammo = "Infinite Ammo",
        no_reload = "No Reload",
        instant_reload = "Instant Reload",
        no_recoil = "No Recoil",
        rapid_fire = "Rapid Fire",
        ohk = "High Damage (2-shot kill)",
        inf_throw = "Infinite Throwables",
        cp = "CP Points",
        apply = "Apply",
        set_ok = "Applied",
        set_fail = "Failed",
        saved = "Settings saved",
        cp_tip = "Enter value and press Apply",
    },
}

local function T(k) return (L[C.lang] and L[C.lang][k]) or L.zh[k] or k end

-- ═══════════════════════════════════════════════════════════════════════
-- Runtime state
-- ═══════════════════════════════════════════════════════════════════════

local R = {
    hooks_ok = false,
    hp_ref = nil,
    god_orig = nil,        -- God 开启前原状态缓存(关闭时恢复, 不覆盖剧情/其他mod)
    reloading = false,     -- v10: 换弹进行中标志 (PlayerEquipment.startReload/execReload/endReload)
    reloading_ttl = 0,
    pending_hud = 0,
    pe = nil,              -- v10: 缓存的 PlayerEquipment 实例(来自 pctx, 不用 hook 实参)
    gun = nil,             -- v10: 缓存的 PlayerGun 实例
    in_cap = false,        -- v10: 防递归
    sig_done = false,
}

local _god_refresh = 0  -- God 引用刷新计数(独立于 hp, 避免同时开启时周期减半)
local _hp_refresh = 0   -- 每 600 帧强制刷新 hp_ref(防角色死亡/换图后引用失效)

-- ═══════════════════════════════════════════════════════════════════════
-- Helpers
-- ═══════════════════════════════════════════════════════════════════════

local function mgr(name)
    local ok, inst = pcall(sdk.get_managed_singleton, name)
    return ok and inst or nil
end

local function pctx()
    local m = mgr("app.CharacterManager")
    if not m then return nil end
    -- 途径1: getPlayerContextRef (v9 探针实证: 第1次尝试即成功)
    local ok, c = pcall(m.call, m, "getPlayerContextRef")
    if ok and c then return c end
    -- 途径1b: get_PlayerContextFast (M6: 审查建议补充官方已知途径)
    local ok2, c2 = pcall(m.call, m, "get_PlayerContextFast")
    if ok2 and c2 then return c2 end
    -- 途径2: CharacterManager 实例字段
    for _, fn in ipairs({ "PlayerContextFast", "_PlayerContextFast", "PlayerContextList" }) do
        local ok, v = pcall(function() return m:get_field(fn) end)
        if ok and v then return v end
    end
    return nil
end

local function php()
    local c = pctx()
    if not c then return nil end
    local ok, h = pcall(c.call, c, "get_HitPoint")
    return ok and h or nil
end

local function toast(msg, col)
    if log then log.info("[Trainer] " .. msg) end
end

-- ═══════════════════════════════════════════════════════════════════════
-- v10 诊断基础设施: 计数器 + 有界写盘(128 KB 硬上限) + 一次性签名 dump
-- 设计约束: 热路径只做整数自增, 零字符串分配; 写盘只在状态变化时发生
-- ═══════════════════════════════════════════════════════════════════════

local CNT = {}
local function bump(k)
    CNT[k] = (CNT[k] or 0) + 1
end

local DBG_KEYS = {
    "glac_call", "glac_cap", "empty_false",
    "setl_call", "setl_skip", "setl_pass_empty",
    "consume_call", "consume_skip", "consume_pass",
    "rl_start", "rl_end", "rl_end_pg",
    "dmg_call", "ohk_apply", "ohk_apply_fail", "ohk_skip_player",
}

-- v10.1: 改用 json.dump_file(本 build 已验证可用), 不再依赖被沙箱限制的 io
local PROBE_JSON = "marvis_probe.json"      -- 落在 reframework/data/ 下
local PROBE_MAX_LINES = 800                 -- 硬上限(约 100 KB), 写满即停
local _probe_lines = {}
local _probe_dirty = 0
local _probe_last = 0
local _plog_ts   = {}
local _plog_full = false

local function probe_flush()
    if json and json.dump_file then
        pcall(json.dump_file, PROBE_JSON, { v = "10.1", lines = _probe_lines })
    end
    _probe_dirty = 0
    _probe_last = os.time()
end

local function raw_write(line)
    -- v11.2: 诊断日志默认完全不落盘, 只有手动开 C.dbg 才写
    if not C.dbg then return end
    if _plog_full then return end
    if #_probe_lines >= PROBE_MAX_LINES then
        _plog_full = true
        probe_flush()
        return
    end
    _probe_lines[#_probe_lines + 1] = tostring(line)
    _probe_dirty = _probe_dirty + 1
    -- v10.29: 立即落盘。之前攒 8 行才写, 单条记录(如 [CP])永远等不到下一次写入
    probe_flush()
end

local function plog(key, msg)
    local now = os.time()
    local last = _plog_ts[key]
    if last and (now - last) < 1 then return end
    _plog_ts[key] = now
    raw_write(string.format("[%s][%s] %s", os.date("%H:%M:%S"), tostring(key), tostring(msg)))
end

local function plog_once(key, msg)
    if _plog_ts[key] then return end
    _plog_ts[key] = os.time()
    raw_write(string.format("[%s][%s] %s", os.date("%H:%M:%S"), tostring(key), tostring(msg)))
end

local function type_name(obj)
    if not obj then return "nil" end
    local ok, tn = pcall(function() return obj:get_type_definition():get_full_name() end)
    return ok and tn or "?"
end

local function get_component(typename)
    local pc = pctx()
    if not pc then return nil end
    local ok, comp = pcall(function()
        local go = pc:call("get_GameObject")
        if not go then return nil end
        local st = sdk.typeof and sdk.typeof(typename)
        if not st then
            local td = sdk.find_type_definition(typename)
            st = td and td:get_runtime_type()
        end
        if not st then return nil end
        return go:call("getComponent(System.Type)", st)
    end)
    return ok and comp or nil
end

local function get_pe() return get_component("app.PlayerEquipment") end
local function get_gun() return get_component("app.PlayerGun") end

local function dump_sig()
    raw_write("==== SIG DUMP " .. tostring(os.date("%Y-%m-%d %H:%M:%S")) .. " ====")
    local groups = {
        {"app.PlayerEquipment", {"getLoadedAmmoCount", "getLoadedAmmoCapacity", "isAmmoEmpty", "isAmmoFull",
                                 "consumeLoading", "startReload", "execReload", "endReload", "isEnableReload"}},
        {"app.PlayerGun", {"setLoadedAmmoCount", "notifyAmmoCountOnFire", "setupEndReload",
                           "get_AmmoStockCountForReload", "get_AmmoCapacityCountForReload"}},
        {"app.HitPoint", {"addDamageHitPoint", "invalidateHitPoint", "decreaseMaxHitPoint",
                          "addDamageReactionHP", "set_CurrentHitPoint", "forceDead"}},
    }
    for _, g in ipairs(groups) do
        local tn, names = g[1], g[2]
        local td = sdk.find_type_definition(tn)
        if not td then
            raw_write(tn .. " :: TYPE NOT FOUND")
        else
            for _, mn in ipairs(names) do
                local m = td:get_method(mn)
                if not m then
                    raw_write(tn .. "." .. mn .. " :: MISSING")
                else
                    local np, pt, rt = "?", {}, "?"
                    pcall(function() np = m:get_num_params() end)
                    pcall(function()
                        for _, t in ipairs(m:get_param_types()) do
                            local ok2, s = pcall(function() return t:get_full_name() end)
                            table.insert(pt, ok2 and s or "?")
                        end
                    end)
                    pcall(function() rt = m:get_return_type():get_full_name() end)
                    raw_write(string.format("%s.%s :: params=%s (%s) ret=%s",
                        tn, mn, tostring(np), table.concat(pt, ","), tostring(rt)))
                end
            end
        end
    end
    raw_write("==== SIG END ====")
end

-- v10 自检: 读档后第一次拿到 PE 时写一次(PlayerGun 拿不到也照写)
local function selftest()
    if R.selftest_done then return end
    R.selftest_try = (R.selftest_try or 0) + 1
    if R.selftest_try > 600 then
        R.selftest_done = true
        raw_write("[SELFTEST] aborted: PE 一直拿不到")
        return
    end
    local pc = pctx()
    if not pc then return end
    local pe = get_pe()
    if not pe then return end
    local gun = get_gun()
    raw_write("==== SELFTEST " .. tostring(os.date("%H:%M:%S")) .. " ====")
    raw_write("[PC] " .. type_name(pc))
    raw_write("[PE] " .. type_name(pe))
    local okc, cap = pcall(function() return pe:call("getLoadedAmmoCapacity") end)
    raw_write("[CAP] ok=" .. tostring(okc) .. " val=" .. tostring(cap))
    local okl, loaded = pcall(function() return pe:call("getLoadedAmmoCount") end)
    raw_write("[LOADED] ok=" .. tostring(okl) .. " val=" .. tostring(loaded))
    local okr, en = pcall(function() return pe:call("isEnableReload") end)
    raw_write("[CANRELOAD] ok=" .. tostring(okr) .. " val=" .. tostring(en))
    if gun then
        raw_write("[GUN] " .. type_name(gun))
        local oks, stock = pcall(function() return gun:get_field("_AmmoStockCountForReload") end)
        local okg, gcap = pcall(function() return gun:get_field("_AmmoCapacityCountForReload") end)
        raw_write("[STOCK] ok=" .. tostring(oks) .. " val=" .. tostring(stock)
            .. " | [GCAP] ok=" .. tostring(okg) .. " val=" .. tostring(gcap))
    else
        raw_write("[GUN] nil (PlayerGun 不在玩家 GameObject 上)")
    end
    raw_write("==== SELFTEST END ====")
    R.selftest_done = true
end

-- v10 快照: 调试面板打开时每 300 帧写一行计数(约 5 秒一条, 受 128 KB 上限保护)
local function snapshot()
    local keys = {"glac_call", "glac_cap", "setl_call", "setl_skip", "setl_pass_empty",
                  "consume_call", "consume_skip", "consume_pass", "rl_start", "rl_end", "rl_end_pg",
                  "dmg_call", "ohk_apply", "ohk_apply_fail", "ohk_skip_player"}
    local parts = {}
    for _, k in ipairs(keys) do
        parts[#parts + 1] = k .. "=" .. tostring(CNT[k] or 0)
    end
    raw_write("[SNAP] " .. table.concat(parts, " "))
end

-- ═══════════════════════════════════════════════════════════════════════
-- Feature: God Mode (per-frame)
-- ═══════════════════════════════════════════════════════════════════════

local function god_tick()
    _god_refresh = _god_refresh + 1
    if _god_refresh % 600 == 0 then R.hp_ref = nil end
    local h = R.hp_ref or php()
    if not h then return end
    R.hp_ref = h
    -- M12: 首次开启时缓存原状态, 关闭时恢复(不覆盖剧情/其他mod设置)
    -- v7: 移除 set_NoDamage/set_NoDeath(本 build 每帧 invoke 抛异常刷爆日志, 实测未生效);
    --     无敌由 set_Invincible + setNoDieCharacter + 每帧回满血 提供(已验证有效)
    if not R.god_orig then
        R.god_orig = {}
        pcall(function() R.god_orig.inv = h:call("get_Invincible") end)
        pcall(function() R.god_orig.nodc = h:call("getNoDieCharacter") end)
    end
    pcall(h.call, h, "set_Invincible", true)
    pcall(h.call, h, "setNoDieCharacter", true)
    local c, m
    pcall(function() c = h:call("get_CurrentHitPoint") end)
    pcall(function() m = h:call("get_CurrentMaximumHitPoint") end)
    if c and m and m > 0 and c < m then
        pcall(h.call, h, "resetHitPoint", m)
    end
end

local function god_off()
    local h = R.hp_ref or php()
    if not h then return end
    -- M12: 恢复开启前原状态(有缓存用缓存, 无缓存回退 false)
    -- v7: 不再设置 NoDamage/NoDeath(见 god_tick 注释)
    local orig = R.god_orig or {}
    pcall(h.call, h, "set_Invincible", orig.inv ~= nil and orig.inv or false)
    pcall(h.call, h, "setNoDieCharacter", orig.nodc ~= nil and orig.nodc or false)
    R.god_orig = nil
end

-- ═══════════════════════════════════════════════════════════════════════
-- Feature: Infinite Health (per-frame)
-- ═══════════════════════════════════════════════════════════════════════

local function hp_tick()
    _hp_refresh = _hp_refresh + 1
    if _hp_refresh % 600 == 0 then R.hp_ref = nil end
    local h = R.hp_ref or php()
    if not h then return end
    R.hp_ref = h
    local c, m
    pcall(function() c = h:call("get_CurrentHitPoint") end)
    pcall(function() m = h:call("get_CurrentMaximumHitPoint") end)
    if c and m and m > 0 and c < m then
        pcall(h.call, h, "set_CurrentHitPoint", m)
    end
end

-- ═══════════════════════════════════════════════════════════════════════
-- Feature: Rapid Fire / Instant Reload (per-frame, field-based)
-- ═══════════════════════════════════════════════════════════════════════
-- 快速射击: 每帧把 PlayerEquipment 的射击间隔字段清零
-- 即时重载: 每帧把 PlayerGun 的装填速度字段拉到极大
-- 字段经 type probe 确认: _ShotInterval/_ExcessShotInterval/_ReloadSpeed/_BoltActionSpeed/_ShootMotionSpeed

local _rapid_pe = nil
local _reload_gun = nil
local _rf_refresh = 0
-- H4/H5: 原值缓存按实例地址保存; 刷新引用时不清空未恢复的原值
local _rapid_orig = {}    -- {addr=<pe地址>, fields={_ShotInterval=...}}
local _reload_orig = {}   -- {addr=<gun地址>, fields={_ReloadSpeed=...}}

local function obj_addr(o)
    local ok, a = pcall(function() return sdk.to_int64(o:get_address()) end)
    return ok and a or nil
end

local function rapid_reload_tick()
    if not (C.rapid_fire or C.instant_reload) then return end
    local pc = pctx()
    if not pc then return end
    _rf_refresh = _rf_refresh + 1
    -- 每 300 帧刷新一次组件引用(应对切换武器/地图); 原值表保留, 切换实例时才重缓存
    if _rf_refresh % 300 == 0 then
        _rapid_pe = nil
        _reload_gun = nil
    end
    if C.rapid_fire then
        local pe = _rapid_pe
        if not pe then
            pcall(function() pe = pc:call("get_PlayerEquipment") end)
            _rapid_pe = pe
        end
        if pe then
            -- 首次写入前缓存原值(按实例地址), 关闭/切枪时还原
            local addr = obj_addr(pe)
            if _rapid_orig.addr ~= addr then
                _rapid_orig = { addr = addr, fields = {} }
                for _, fn in ipairs({"_ShotInterval", "_ExcessShotInterval", "_AddShotInterVal"}) do
                    pcall(function() _rapid_orig.fields[fn] = pe:get_field(fn) end)
                end
            end
            pcall(function() pe:set_field("_ShotInterval", 0.0) end)
            pcall(function() pe:set_field("_ExcessShotInterval", 0.0) end)
            pcall(function() pe:set_field("_AddShotInterVal", 0.0) end)
        end
    end
    if C.instant_reload then
        local gun = _reload_gun
        if not gun then
            pcall(function()
                local go = pc:call("get_GameObject")
                if go then
                    -- H4: getComponent 需要 System.Type, RETypeDefinition 不可用
                    local st = sdk.typeof and sdk.typeof("app.PlayerGun")
                    if not st then
                        local gun_td = sdk.find_type_definition("app.PlayerGun")
                        if gun_td then st = gun_td:get_runtime_type() end
                    end
                    if st then gun = go:call("getComponent(System.Type)", st) end
                end
            end)
            _reload_gun = gun
        end
        if gun then
            -- 原值缓存(按实例地址): 换枪时缓存新枪原值, 同枪沿用
            local addr = obj_addr(gun)
            if _reload_orig.addr ~= addr then
                _reload_orig = { addr = addr, fields = {} }
                for _, fn in ipairs({"_ReloadSpeed", "_BoltActionSpeed", "_ShootMotionSpeed"}) do
                    pcall(function() _reload_orig.fields[fn] = gun:get_field(fn) end)
                end
            end
            for _, fn in ipairs({"_ReloadSpeed", "_BoltActionSpeed", "_ShootMotionSpeed"}) do
                pcall(function() gun:set_field(fn, 9999.0) end)
            end
        end
    end
end

-- 快速射击关闭时还原射击间隔字段(H5)
local function restore_rapid_orig()
    local pe = _rapid_pe
    if pe and _rapid_orig.fields then
        for fn, v in pairs(_rapid_orig.fields) do
            pcall(function() pe:set_field(fn, v) end)
        end
    end
    _rapid_orig = {}
end

-- 即时重载关闭时还原装填速度字段(缓存丢失则跳过, 避免写死值)
local function restore_reload_orig()
    local gun = _reload_gun
    if gun and _reload_orig.fields then
        for fn, v in pairs(_reload_orig.fields) do
            pcall(function() gun:set_field(fn, v) end)
        end
    end
    _reload_orig = {}
end

-- ═══════════════════════════════════════════════════════════════════════
-- Feature: Edit CP
-- ═══════════════════════════════════════════════════════════════════════

local function apply_cp()
    -- M9: 写入后读回验证, 记录具体管理器/字段
    local done, mgr_name, field_name = false, nil, nil
    pcall(function()
        local am = mgr("app.AchievementManager")
        if am then
            -- v10.28 探针: 记录字段真实类型与读写前后的值
            local ftype, before = "?", nil
            pcall(function()
                local f = am:get_type_definition():get_field("_TotalClearPoint")
                if f then ftype = f:get_type():get_full_name() end
            end)
            pcall(function() before = am:get_field("_TotalClearPoint") end)
            am:set_field("_TotalClearPoint", C.cp_value)
            local rv = am:get_field("_TotalClearPoint")
            raw_write("[CP] type=" .. tostring(ftype) .. " before=" .. tostring(before)
                .. " after=" .. tostring(rv) .. " target=" .. tostring(C.cp_value))
            if rv ~= nil and tostring(rv) == tostring(C.cp_value) then
                done, mgr_name, field_name = true, "AchievementManager", "_TotalClearPoint"
            end
        end
    end)
    if not done then
        for _, mn in ipairs({"app.RecordManager", "app.BonusManager", "app.GameDataManager"}) do
            pcall(function()
                local m = mgr(mn)
                if m then
                    for _, fn in ipairs({"_TotalClearPoint", "_ClearPoint", "_ReceivedClearPoint"}) do
                        local ok2 = pcall(function() m:set_field(fn, C.cp_value) end)
                        if ok2 then
                            local rv = m:get_field(fn)
                            if rv ~= nil and tostring(rv) == tostring(C.cp_value) then
                                done, mgr_name, field_name = true, mn, fn
                                return
                            end
                        end
                    end
                end
            end)
            if done then break end
        end
    end
    if done then
        toast(T("set_ok") .. " CP=" .. C.cp_value .. " (" .. (mgr_name or "?") .. "." .. (field_name or "?") .. ")")
    else
        toast(T("set_fail") .. " CP")
    end
end

-- ═══════════════════════════════════════════════════════════════════════
-- Hooks (installed once)
-- ═══════════════════════════════════════════════════════════════════════

local HOOK_GEN = 26  -- v11.0 clean release

local function install_hooks()
    -- H1: 逐块注册状态表(pending/installed/missing/failed), 重试只处理 failed;
    --     类型/方法缺失记为 missing(不重复重试); 实际 sdk.hook 成功才写 installed, 消除假成功
    local reg = _G.__MARVIS_TRAINER_HOOK_REG__ or {}
    _G.__MARVIS_TRAINER_HOOK_REG__ = reg
    local function _reg(name, fn)
        if reg[name] == "installed" then return end
        local ok, err = pcall(fn)
        if ok then
            reg[name] = "installed"
        else
            reg[name] = "failed"
            if log then log.warn("[Trainer] Hook block failed: " .. name .. " (" .. tostring(err) .. ")") end
        end
    end
    -- 块内类型/方法缺失时调用: 标记 missing, 不重复重试
    local function _missing(name)
        if reg[name] ~= "installed" then reg[name] = "missing" end
    end
    -- 版本化全局标记: 仅当标记等于当前世代才考虑跳过注册;
    -- 若存在 failed 块则继续补装(避免永久假成功)
    if _G.__MARVIS_TRAINER_HOOKED__ == HOOK_GEN then
        local all_ok = true
        for _, st in pairs(reg) do
            if st == "failed" then all_ok = false break end
        end
        if all_ok then
            R.hooks_ok = true
            return
        end
    end
    if R.hooks_ok then return end

    -- God mode: v10.17 改为纯 tick 实现(set_Invincible + setNoDieCharacter + 每帧回血)
    -- 不再挂 任何 HitPoint 方法 —— 之前的地址判定会误伤, 把怪物伤害/致死一起拦掉
    _reg("god", function()
        -- 无 hook; 实际逻辑在 god_tick / god_off
    end)

    -- One-hit kill: v10.20 hook 里只登记目标, 所有游戏函数调用都延后到 on_frame,
    -- 避免在 hook 内重入被 hook 的函数(REFramework 会判定递归并抛异常, 连带毁掉正常伤害)
    _reg("ohk", function()
        local hp_td = sdk.find_type_definition("app.HitPoint")
        if not hp_td then _missing("ohk") return end
        local m = hp_td:get_method("addDamageHitPoint")
        if not m then _missing("ohk") return end
        local gen = HOOK_GEN
        sdk.hook(m,
            function(args)
                if _G.__MARVIS_TRAINER_HOOKED__ ~= gen then return sdk.PreHookResult.CALL_ORIGINAL end
                if not C.ohk or R.ohk_applying then return sdk.PreHookResult.CALL_ORIGINAL end
                -- v10.21: 这个函数对玩家也会触发, 必须先排除玩家, 否则会把玩家血量清零(无敌失效/倒地)
                if not R.hp_ref then pcall(function() R.hp_ref = php() end) end
                local is_player = false
                if R.hp_ref then
                    local pa = nil
                    pcall(function() pa = sdk.to_int64(R.hp_ref:get_address()) end)
                    if pa then
                        local ok1, a1 = pcall(function() return sdk.to_int64(args[1]) end)
                        local ok2, b1 = pcall(function() return sdk.to_int64(args[2]) end)
                        if (ok1 and a1 and a1 == pa) or (ok2 and b1 and b1 == pa) then
                            is_player = true
                        end
                    end
                end
                if is_player then
                    bump("ohk_skip_player")
                    return sdk.PreHookResult.CALL_ORIGINAL
                end
                bump("dmg_call")
                local hp = nil
                pcall(function() hp = sdk.to_managed_object(args[2]) end)
                if hp then
                    local b4, b5 = true, true
                    pcall(function() b4 = (sdk.to_int64(args[4]) ~= 0) end)
                    pcall(function() b5 = (sdk.to_int64(args[5]) ~= 0) end)
                    R.ohk_q = R.ohk_q or {}
                    R.ohk_q[hp] = { b4 = b4, b5 = b5 }
                    bump("ohk_hit")
                end
                return sdk.PreHookResult.CALL_ORIGINAL
            end,
            function(rv) return rv end)
        if log then log.info("[Trainer] OHK queue hook installed (v10.20)") end
    end)

    -- Infinite ammo / No reload: hook PlayerEquipment 弹药查询方法(只读, 不写状态机)
    -- getLoadedAmmoCount 恒返回弹匣容量 => 弹匣永远满 => 弹药不消耗且永不换弹
    -- isAmmoEmpty 恒 false 双保险
    _reg("ammo", function()
        local pe_td = sdk.find_type_definition("app.PlayerEquipment")
        if not pe_td then _missing("ammo") return end
        local m_count = pe_td:get_method("getLoadedAmmoCount")
        local m_empty = pe_td:get_method("isAmmoEmpty")
        local gen = HOOK_GEN
        -- v10: 不再用 hook 实参当 this(那是第一个实参, 不是接收者), 改用 pctx 解析出的 PE 实例
        if m_count then
            sdk.hook(m_count,
                function(args)
                    if _G.__MARVIS_TRAINER_HOOKED__ ~= gen then return sdk.PreHookResult.CALL_ORIGINAL end
                    bump("glac_call")
                    return sdk.PreHookResult.CALL_ORIGINAL
                end,
                function(rv)
                    if _G.__MARVIS_TRAINER_HOOKED__ ~= gen then return rv end
                    if not (C.inf_ammo or C.no_reload) then return rv end
                    if R.in_cap then return rv end          -- 防递归
                    local pe = R.pe
                    if not pe then
                        pe = get_pe()
                        R.pe = pe
                        if pe then plog_once("pe_ok", "PE=" .. type_name(pe)) end
                    end
                    if not pe then return rv end
                    local cap
                    R.in_cap = true
                    local ok, r = pcall(function() return pe:call("getLoadedAmmoCapacity") end)
                    R.in_cap = false
                    if ok then cap = r end
                    if cap and cap > 0 and cap <= 9999 then
                        bump("glac_cap")
                        -- v10: int 返回直接给 Lua number(官方自动转换), 不用 sdk.to_ptr
                        return cap
                    end
                    plog("glac_nocap", "cap=" .. tostring(cap) .. " rv=" .. tostring(rv))
                    return rv
                end)
        end
        if m_empty then
            sdk.hook(m_empty,
                function(args) return sdk.PreHookResult.CALL_ORIGINAL end,
                function(rv)
                    if _G.__MARVIS_TRAINER_HOOKED__ ~= gen then return rv end
                    if C.inf_ammo or C.no_reload then
                        bump("empty_false")
                        return false                         -- bool 返回: 直接 false
                    end
                    return rv
                end)
        end
        if log then log.info("[Trainer] Ammo hooks (getLoadedAmmoCount/isAmmoEmpty) installed (v10)") end
    end)

    -- 源头拦截弹药扣减: 开启时 SKIP setLoadedAmmoCount, 阻止计数写入 -> HUD 恒显弹匣容量且无需换弹;
    -- 保留上方 getLoadedAmmoCount/isAmmoEmpty 作为判断层 (扩容后仍正确显示)。
    -- v10: 源头拦截。SKIP 不需要解析实参布局(直接不执行原函数) => 计数与 HUD 字段都不写。
    --      换弹期间(R.reloading)放行, 否则装填链写不回弹数。
    _reg("setLoaded", function()
        local pg_td = sdk.find_type_definition("app.PlayerGun")
        if not pg_td then _missing("setLoaded") return end
        local m_set = pg_td:get_method("setLoadedAmmoCount")
        if m_set then
            local gen = HOOK_GEN
            sdk.hook(m_set,
                function(args)
                    if _G.__MARVIS_TRAINER_HOOKED__ ~= gen then return sdk.PreHookResult.CALL_ORIGINAL end
                    if not (C.inf_ammo or C.no_reload) then return sdk.PreHookResult.CALL_ORIGINAL end
                    bump("setl_call")
                    if R.reloading then return sdk.PreHookResult.CALL_ORIGINAL end
                    -- v10: 只在"弹匣当前不为空"时拦写入, 避免把换枪/初始装填(0 -> 满)也拦掉导致开不了枪
                    local gun = R.gun
                    if not gun then
                        gun = get_gun()
                        R.gun = gun
                    end
                    local cur = nil
                    if gun then
                        local ok, v = pcall(function() return gun:get_field("_AmmoStockCountForReload") end)
                        if ok then cur = v end
                    end
                    if cur and cur > 0 then
                        bump("setl_skip")
                        return sdk.PreHookResult.SKIP_ORIGINAL
                    end
                    bump("setl_pass_empty")
                    return sdk.PreHookResult.CALL_ORIGINAL
                end,
                function(rv) return rv end)
            if log then log.info("[Trainer] Ammo source hook (setLoadedAmmoCount SKIP v10) installed") end
        end
    end)

    -- v10: consumeLoading 只做 SKIP, 不再回写任何字段
    --      (旧版回写的对象是 PlayerEquipment, 没有 PlayerGun 的 _AmmoStockCountForReload, 必然失败)
    _reg("hud_consume", function()
        local pe_td = sdk.find_type_definition("app.PlayerEquipment")
        if not pe_td then _missing("hud_consume") return end
        local m_c = pe_td:get_method("consumeLoading")
        if m_c then
            local gen = HOOK_GEN
            sdk.hook(m_c,
                function(args)
                    if _G.__MARVIS_TRAINER_HOOKED__ ~= gen then return sdk.PreHookResult.CALL_ORIGINAL end
                    if not (C.inf_ammo or C.no_reload) then return sdk.PreHookResult.CALL_ORIGINAL end
                    bump("consume_call")
                    if R.reloading then
                        bump("consume_pass")
                        return sdk.PreHookResult.CALL_ORIGINAL
                    end
                    bump("consume_skip")
                    return sdk.PreHookResult.SKIP_ORIGINAL
                end)
            if log then log.info("[Trainer] consumeLoading SKIP hook installed (v10)") end
        end
    end)

    -- v10: 换弹标志改挂 PlayerEquipment 的 startReload/execReload/endReload
    --      (setupBeginReload 在本 build 的 PlayerGun 上不存在, 导致 R.reloading 永远是 false)
    _reg("hud_reload", function()
        local pe_td = sdk.find_type_definition("app.PlayerEquipment")
        if not pe_td then _missing("hud_reload") return end
        local gen = HOOK_GEN
        local hooked = 0
        local function pre_none(args) return sdk.PreHookResult.CALL_ORIGINAL end
        local function hook_one(m, pre, post)
            if not m then return false end
            local ok = pcall(function() sdk.hook(m, pre or pre_none, post) end)
            if ok then hooked = hooked + 1 end
            return ok
        end
        local function pre_begin(args)
            if _G.__MARVIS_TRAINER_HOOKED__ ~= gen then return sdk.PreHookResult.CALL_ORIGINAL end
            R.reloading = true
            R.reloading_ttl = 0
            bump("rl_start")
            return sdk.PreHookResult.CALL_ORIGINAL
        end
        local function post_end(rv)
            if _G.__MARVIS_TRAINER_HOOKED__ ~= gen then return rv end
            R.reloading = false
            bump("rl_end")
            return rv
        end
        hook_one(pe_td:get_method("startReload"), pre_begin, nil)
        hook_one(pe_td:get_method("execReload"), nil, post_end)
        hook_one(pe_td:get_method("endReload"), nil, post_end)
        -- PlayerGun.setupEndReload 兜底清标志(它确实存在, 日志里一直在触发)
        local pg_td = sdk.find_type_definition("app.PlayerGun")
        local m_pg = pg_td and pg_td:get_method("setupEndReload")
        if m_pg then
            pcall(function()
                sdk.hook(m_pg, pre_none, function(rv)
                    R.reloading = false
                    bump("rl_end_pg")
                    return rv
                end)
            end)
        end
        if log then log.info("[Trainer] Reload-flag hooks installed: " .. tostring(hooked) .. " (v10)") end
    end)

    -- No reload: 不再 hook consumeLoading 的 SKIP (SKIP 会中断换弹状态机导致 R 换弹失效、角色卡持枪姿态)。
    -- 备注: 静态探针确认 PlayerGun 实例静态路径不可达; v8 改用 sdk.to_managed_object(args) 捕获 this 回写,
    --       避开 consumeLoading/setupEndReload 的 args[1] 裸 userdata 陷阱。
    -- 无需换弹复用游戏自身的无限弹机制(弹药不消耗 => 无需换弹)

    -- Infinite throwables: skip stock consumption
    _reg("throwables", function()
        local td = sdk.find_type_definition("app.Inventory")
        if not td then _missing("throwables") return end
        local warned = false
        local gen = HOOK_GEN
        local hook_fn = function(args)
            if _G.__MARVIS_TRAINER_HOOKED__ ~= gen then return sdk.PreHookResult.CALL_ORIGINAL end
            if C.inf_throw then
                -- H7: 当前为通用入口拦截, 范围可能波及治疗/材料等; 实机验证后需按物品类型收窄
                if not warned then
                    warned = true
                    if log then log.info("[Trainer] consumeStock SKIP hit (inf_throw) - verify item scope") end
                end
                return sdk.PreHookResult.SKIP_ORIGINAL
            end
            return sdk.PreHookResult.CALL_ORIGINAL
        end
        local m1 = td:get_method("consumeStock(app.ItemID, System.Int32, app.ItemStockChangedEventType)")
        local m2 = td:get_method("consumeStock(app.Inventory.PanelKey, System.Int32, app.ItemStockChangedEventType)")
        if m1 then sdk.hook(m1, hook_fn, nil) end
        if m2 then sdk.hook(m2, hook_fn, nil) end
    end)

    -- No recoil / no sway (仅保留相机后坐力控制, 瞄准晃动控制器 onUpdate SKIP 有锁定瞄准态风险, 已移除)
    _reg("no_recoil", function()
        local classes = {
            {"app.CameraRecoilController", {"addRecoil", "updateRecoil"}},
        }
        local hooked = 0
        local gen = HOOK_GEN
        local function hook_one(meth)
            local ok, err = pcall(function()
                sdk.hook(meth,
                    function(args)
                        if _G.__MARVIS_TRAINER_HOOKED__ ~= gen then return sdk.PreHookResult.CALL_ORIGINAL end
                        if C.no_recoil then return sdk.PreHookResult.SKIP_ORIGINAL end
                        return sdk.PreHookResult.CALL_ORIGINAL
                    end,
                    function(rv) return rv end)
            end)
            -- H1: 仅实际注册成功才计数, 失败不进入"已命中"统计
            if ok then hooked = hooked + 1 end
        end
        -- 精确匹配方法名, 避免子串误 hook 到无关方法(M6)
        for _, entry in ipairs(classes) do
            local td = sdk.find_type_definition(entry[1])
            if td then
                for _, meth in ipairs(td:get_methods()) do
                    local mn = meth:get_name()
                    for _, target in ipairs(entry[2]) do
                        if mn and mn:lower() == target:lower() then
                            hook_one(meth)
                            break
                        end
                    end
                end
            end
        end
        -- 兜底: 一个都没精确命中时退回子串匹配, 避免功能静默失效
        if hooked == 0 then
            for _, entry in ipairs(classes) do
                local td = sdk.find_type_definition(entry[1])
                if td then
                    for _, meth in ipairs(td:get_methods()) do
                        local mn = meth:get_name()
                        for _, target in ipairs(entry[2]) do
                            if mn and mn:lower():find(target:lower()) then
                                hook_one(meth)
                                break
                            end
                        end
                    end
                end
            end
            if log then log.warn("[Trainer] No-recoil exact match miss, fell back to substring") end
        end
    end)

    -- H1: 依据逐块状态判断整体完成; 有 failed 块下帧重试, missing 视为环境不可用(不阻塞其他功能)
    local has_failed, has_missing = false, false
    for _, st in pairs(reg) do
        if st == "failed" then has_failed = true end
        if st == "missing" then has_missing = true end
    end
    if has_failed then
        R.hooks_ok = false
        if log then log.info("[Trainer] Hooks partial fail, will retry next frame") end
        return
    end
    _G.__MARVIS_TRAINER_HOOKED__ = HOOK_GEN
    R.hooks_ok = true
    if log then
        if has_missing then
            log.info("[Trainer] Hooks installed (v10.0, some blocks missing)")
        else
            log.info("[Trainer] Hooks installed (v10.0)")
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════
-- Frame loop
-- ═══════════════════════════════════════════════════════════════════════

re.on_frame(function()
    if not R.hooks_ok then
        pcall(install_hooks)
    end
    if not R.pctx_logged then
        local pc = pctx()
        if pc then
            R.pctx_logged = true
            if log then log.info("[Trainer] Player context ready") end
        end
    end
    if C.god then
        pcall(god_tick)
        _G.__MARVIS_TRAINER_GOD_PREV__ = true
    else
        -- 仅在从开→关的瞬间清一次残留, 避免功能关闭时每帧写 4 个 HitPoint setter 干扰游戏
        if _G.__MARVIS_TRAINER_GOD_PREV__ then
            pcall(god_off)
            _G.__MARVIS_TRAINER_GOD_PREV__ = false
        end
    end
    if C.inf_hp then
        pcall(hp_tick)
    end
    -- H4/H5: 开→关 边沿先于 tick 处理; 关闭当帧先恢复原值, tick 检测到功能关闭直接返回
    if not C.rapid_fire and _G.__MARVIS_TRAINER_RF_PREV__ then
        pcall(restore_rapid_orig)
        _G.__MARVIS_TRAINER_RF_PREV__ = false
    end
    if not C.instant_reload and _G.__MARVIS_TRAINER_IR_PREV__ then
        pcall(restore_reload_orig)
        _G.__MARVIS_TRAINER_IR_PREV__ = false
    end
    if C.rapid_fire then _G.__MARVIS_TRAINER_RF_PREV__ = true end
    if C.instant_reload then _G.__MARVIS_TRAINER_IR_PREV__ = true end
    if C.rapid_fire or C.instant_reload then
        pcall(rapid_reload_tick)
    end
    -- v10: 一次性签名 dump(只写一次, 文件有 128 KB 硬上限)
    if not R.sig_done then
        R.sig_done = true
        pcall(dump_sig)
    end
    -- v10: 自检(读档后拿到 PE/Gun 时写一次) + 调试面板打开时的计数快照
    R.selftest_tick = (R.selftest_tick or 0) + 1
    if R.selftest_tick % 60 == 0 then
        pcall(selftest)
    end
    -- v10.26 稳定版: 高伤害(两枪击杀)。单次伤害被钳在 1 点, 这是引擎行为;
    -- 第一枪压到临界, 第二枪由游戏自身逻辑击杀, 死亡表现正常。
    if C.ohk and R.ohk_q then
        local processed = 0
        for hp, info in pairs(R.ohk_q) do
            R.ohk_q[hp] = nil
            processed = processed + 1
            pcall(function()
                if not sdk.is_managed_object(hp) then return end
                -- v10.28 二次保险: 结算前再确认一次不是玩家
                if R.hp_ref then
                    local okA, addrA = pcall(function() return sdk.to_int64(hp:get_address()) end)
                    local okB, addrB = pcall(function() return sdk.to_int64(R.hp_ref:get_address()) end)
                    if okA and okB and addrA and addrB and addrA == addrB then
                        bump("ohk_skip_player")
                        return
                    end
                end
                local before, after = nil, nil
                pcall(function() before = hp:call("get_CurrentHitPoint") end)
                R.ohk_applying = true
                local ok = pcall(function()
                    hp:call("addDamageHitPoint", 999999, info.b4, info.b5)
                end)
                R.ohk_applying = false
                if ok then
                    bump("ohk_apply")
                else
                    bump("ohk_apply_fail")
                end
                pcall(function() after = hp:call("get_CurrentHitPoint") end)
                if (R.ohk_log or 0) < 10 then
                    R.ohk_log = (R.ohk_log or 0) + 1
                    raw_write("[OHK] applied=" .. tostring(ok) .. " before=" .. tostring(before)
                        .. " after=" .. tostring(after))
                end
            end)
            if processed >= 4 then break end
        end
    end
    -- v10.12: 制作界面打开后的 6 秒窗口内, 确保 8 种材料在背包里各有 >= 5
    if C.dbg then
        R.snap_tick = (R.snap_tick or 0) + 1
        if R.snap_tick % 300 == 0 then
            pcall(snapshot)
        end
    end
    -- v10: 组件引用每 600 帧刷新(换角色/换图/读档后旧引用会失效)
    R.com_refresh = (R.com_refresh or 0) + 1
    if R.com_refresh % 600 == 0 then
        R.pe = nil
        R.gun = nil
    end
    if (C.inf_ammo or C.no_reload) and not R.gun then
        R.gun = get_gun()
    end
    -- v10: 换弹标志超时兜底 —— 换弹被打断(移动/受击取消)可能不触发 endReload, 10 秒强制清除,
    --      防止 consumeLoading/setLoadedAmmoCount 一直放行导致真扣弹
    if R.reloading then
        R.reloading_ttl = (R.reloading_ttl or 0) + 1
        if R.reloading_ttl > 600 then
            R.reloading = false
            R.reloading_ttl = 0
            plog("rl_timeout", "reloading cleared by timeout")
        end
    else
        R.reloading_ttl = 0
    end
end)

-- ═══════════════════════════════════════════════════════════════════════
-- Config persistence
-- ═══════════════════════════════════════════════════════════════════════

local function cfg_save()
    if json then
        local ok, err = pcall(json.dump_file, CFG_FILE, C)
        if not ok and log then log.info("[Trainer] cfg_save ERR: " .. tostring(err)) end
    end
end

local function cfg_load()
    if json then
        local ok, d = pcall(json.load_file, CFG_FILE)
        if ok and type(d) == "table" then
            for k, v in pairs(d) do
                if C[k] ~= nil and type(C[k]) == type(v) then C[k] = v end
            end
        end
    end
end

pcall(cfg_load)
re.on_config_save(cfg_save)


-- ═══════════════════════════════════════════════════════════════════════
-- UI
-- ═══════════════════════════════════════════════════════════════════════

-- UI: on_draw_ui 阶段绘制(ImGui 帧内, 本机 nightly 实测有效)
re.on_draw_ui(function()
    -- 回归 v1-v5 实测可显示写法: begin_window 第二参数必须传 0(传 true 时本机 nightly 下窗口不渲染)
    local visible, _ = imgui.begin_window(T("title"), 0)
    -- 绑定特性: visible=false 时 begin_window 内部已自动 End, 不得再调 end_window()
    if not visible then return end

    -- Language switcher
    imgui.text(T("lang_label") .. ":")
    imgui.same_line()
    if imgui.button("简体中文") then C.lang = "zh" end
    imgui.same_line()
    if imgui.button("English") then C.lang = "en" end
    imgui.separator()

    -- Combat
    imgui.text_colored(T("sec_battle"), 0xFF00DDFF)
    local _, god_v = imgui.checkbox(T("god"), C.god)
    C.god = god_v
    local _, hp_v = imgui.checkbox(T("inf_hp"), C.inf_hp)
    C.inf_hp = hp_v
    local _, th_v = imgui.checkbox(T("inf_throw"), C.inf_throw)
    C.inf_throw = th_v

    -- Weapon
    imgui.text_colored(T("sec_weapon"), 0xFF00DDFF)
    local _, am_v = imgui.checkbox(T("inf_ammo"), C.inf_ammo)
    C.inf_ammo = am_v
    local _, nr_v = imgui.checkbox(T("no_reload"), C.no_reload)
    C.no_reload = nr_v
    local _, ir_v = imgui.checkbox(T("instant_reload"), C.instant_reload)
    C.instant_reload = ir_v
    -- 未实现的开关不再暴露到 UI
    local _, nrc_v = imgui.checkbox(T("no_recoil"), C.no_recoil)
    C.no_recoil = nrc_v
    local _, rf_v = imgui.checkbox(T("rapid_fire"), C.rapid_fire)
    C.rapid_fire = rf_v
    local _, ohk_v = imgui.checkbox(T("ohk"), C.ohk)
    C.ohk = ohk_v

    -- Economy: 仅保留 CP(RE9 没有黄金货币, 相关 UI 已移除)
    imgui.text_colored(T("sec_economy"), 0xFF00DDFF)
    if imgui.input_text then
        local cp_buf = tostring(C.cp_value)
        local cp_ok, cp_str = imgui.input_text(T("cp") .. "##cp", cp_buf, 0)
        if cp_ok and cp_str then
            local n = tonumber(cp_str:match("^%s*(.-)%s*$"))
            if n and n >= 0 and n == math.floor(n) then C.cp_value = n end
        end
    else
        imgui.text(T("cp") .. ": " .. C.cp_value)
        imgui.same_line()
        if imgui.button("-1k##cp") then C.cp_value = math.max(0, C.cp_value - 1000) end
        imgui.same_line()
        if imgui.button("+1k##cp") then C.cp_value = C.cp_value + 1000 end
    end
    -- v10.31: 应用按钮单独一行, 避免被窗口宽度裁掉(之前的 same_line 布局点不到)
    imgui.spacing()
    if imgui.button(T("apply") .. " CP##cp") then
        pcall(apply_cp)
    end

    imgui.end_window()

    -- v11.1: 调试面板不在 UI 暴露; 需要时在 marvis_re9_trainer.json 里加 "dbg": true 即可打开
    if C.dbg then
        local vis, _ = imgui.begin_window("wdre9 DEBUG", 0)
        if vis then
            imgui.text("gen=" .. tostring(_G.__MARVIS_TRAINER_HOOKED__) .. "  hooks_ok=" .. tostring(R.hooks_ok))
            imgui.text("reloading=" .. tostring(R.reloading) .. "  pe=" .. type_name(R.pe))
            imgui.text("gun=" .. type_name(R.gun) .. "  probe_full=" .. tostring(_plog_full))
            imgui.separator()
            for _, k in ipairs(DBG_KEYS) do
                imgui.text(k .. " = " .. tostring(CNT[k] or 0))
            end
            imgui.separator()
            if imgui.button("重置计数") then
                for k in pairs(CNT) do CNT[k] = 0 end
            end
            imgui.end_window()
        end
    end
end)

-- Reset 时保留 hook(_G 标记防重复)与语言选择, 仅清运行时引用
-- H5: Reset 时清理已修改字段与引用(快速射击/即时重载原值恢复; God 引用失效)
re.on_script_reset(function()
    pcall(restore_rapid_orig)
    pcall(restore_reload_orig)
    R.hp_ref = nil
    R.god_orig = nil
end)

pcall(raw_write, "==== SESSION " .. tostring(os.date("%Y-%m-%d %H:%M:%S")) .. " v11.2 ====")
if log then log.info("[Trainer] wdre9 RE9 Trainer v11.2 loaded") end
