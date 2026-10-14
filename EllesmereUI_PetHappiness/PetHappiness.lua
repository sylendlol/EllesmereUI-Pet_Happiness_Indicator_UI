if EUI_CLIENT_BLOCKED then return end -- pre-12.1 client failsafe (EllesmereUI_ClientGate.lua)
-------------------------------------------------------------------------------
--  EllesmereUI_PetHappiness \ PetHappiness.lua   (standalone add-on)
--
--  Restyles the WoW Forever pet happiness indicator that EllesmereUI Unit
--  Frames draws beside the pet frame (EUI_UnitFrames_ForeverExtras.lua).
--  No EllesmereUI file is modified: ns.UF_ApplyPetHappiness and
--  ns.UF_RefreshPetHappiness are wrapped, the stock icon frame (pf._petHappy)
--  is kept as the holder (so its tooltip, alpha and visibility rules stay),
--  and our layers are drawn inside it.
--
--  Styles (db.profile.pet.phStyle):
--    icon  - the original Blizzard face (default, unchanged look)
--    dot   - flat colored circle
--    bar   - colored strip along the chosen frame edge
--    pips  - 3 / 2 / 1 filled pips
--    text  - "Happy 125%" in the state color
--  Extras: Bottom position, Only When Not Happy, Pulse When Unhappy,
--  per-state colors. Options: PetHappiness_Options.lua.
-------------------------------------------------------------------------------
local EllesmereUI = _G.EllesmereUI
local ns = EllesmereUI and EllesmereUI._ModuleNS and EllesmereUI._ModuleNS["EllesmereUIUnitFrames"]
if not ns then return end

local issecretvalue = issecretvalue or function() return false end

local PH = {}
ns.PetHappyStyle = PH

PH.STYLES      = { icon = "Icon (Blizzard)", dot = "Dot", bar = "Bar", pips = "Pips", text = "Text" }
PH.STYLE_ORDER = { "icon", "dot", "bar", "pips", "text" }

PH.DEFAULTS = {
    phStyle        = "icon",
    phOnlyUnhappy  = false,
    phPulse        = false,
    phSize_dot     = 10,
    phSize_bar     = 4,
    phSize_pips    = 14,
    phSize_text    = 12,
    phBarLength    = 100,
    phShowDmg      = true,
    phColorHappy   = { r = 0.24, g = 0.81, b = 0.31 },
    phColorContent = { r = 0.90, g = 0.76, b = 0.16 },
    phColorUnhappy = { r = 0.89, g = 0.25, b = 0.23 },
}

local CIRCLE = "Interface\\AddOns\\EllesmereUIUnitFrames\\Media\\circle-mask.png"
local WHITE  = "Interface\\Buttons\\WHITE8X8"
local SAMPLE_DMG = { 75, 100, 125 }

-------------------------------------------------------------------------------
--  Settings
-------------------------------------------------------------------------------
local db
if ns._internals and ns._internals.dbSetters then
    local list = ns._internals.dbSetters
    list[#list + 1] = function(v) db = v end
end

function PH.Settings()
    local d = db or ns.db
    return d and d.profile and d.profile.pet
end

function PH.Get(s, k)
    local v = s and s[k]
    if v == nil then v = PH.DEFAULTS[k] end
    return v
end

function PH.Style(s)
    local st = PH.Get(s, "phStyle")
    return PH.STYLES[st] and st or "icon"
end

-- Size of the current style (icon keeps EllesmereUI's own happinessSize).
function PH.GetSize(s)
    local st = PH.Style(s)
    if st == "icon" then return (s and s.happinessSize) or 20 end
    return PH.Get(s, "phSize_" .. st)
end

function PH.SetSize(s, v)
    if not s then return end
    local st = PH.Style(s)
    if st == "icon" then s.happinessSize = v else s["phSize_" .. st] = v end
end

function PH.Color(s, happiness)
    local key = (happiness == 3 and "phColorHappy") or (happiness == 2 and "phColorContent") or "phColorUnhappy"
    local c = PH.Get(s, key)
    return c.r or 1, c.g or 1, c.b or 1
end

local function StateText(happiness)
    return (happiness == 1 and (PET_HAPPINESS1 or "Unhappy"))
        or (happiness == 2 and (PET_HAPPINESS2 or "Content"))
        or (PET_HAPPINESS3 or "Happy")
end

-------------------------------------------------------------------------------
--  Layers (built once per holder: the live icon frame and the options preview)
-------------------------------------------------------------------------------
local function Circle(parent, layer, sub)
    local t = parent:CreateTexture(nil, layer, nil, sub)
    t:SetTexture(WHITE)
    local m = parent:CreateMaskTexture()
    m:SetTexture(CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    m:SetAllPoints(t)
    t:AddMaskTexture(m)
    return t
end

local function Build(h)
    if h._ph then return h._ph end
    if not h._tex then
        -- Options preview: its face texture is the holder's only region.
        h._tex = h:GetRegions()
    end
    local L = CreateFrame("Frame", nil, h)
    L:SetAllPoints(h)
    h._ph = L

    L.dotBorder = Circle(L, "ARTWORK", 1)
    L.dotBorder:SetVertexColor(0, 0, 0, 0.9)
    L.dot = Circle(L, "ARTWORK", 2)
    L.dot:SetPoint("TOPLEFT", L.dotBorder, "TOPLEFT", 1, -1)
    L.dot:SetPoint("BOTTOMRIGHT", L.dotBorder, "BOTTOMRIGHT", -1, 1)

    L.barBg = L:CreateTexture(nil, "ARTWORK", nil, 1)
    L.barBg:SetTexture(WHITE)
    L.barBg:SetVertexColor(0, 0, 0, 0.9)
    L.barBg:SetAllPoints(L)
    L.bar = L:CreateTexture(nil, "ARTWORK", nil, 2)
    L.bar:SetTexture(WHITE)
    L.bar:SetPoint("TOPLEFT", 1, -1)
    L.bar:SetPoint("BOTTOMRIGHT", -1, 1)

    L.pips = {}
    for i = 1, 3 do
        local bg = L:CreateTexture(nil, "ARTWORK", nil, 1)
        bg:SetTexture(WHITE)
        bg:SetVertexColor(0, 0, 0, 0.9)
        local fill = L:CreateTexture(nil, "ARTWORK", nil, 2)
        fill:SetTexture(WHITE)
        fill:SetPoint("TOPLEFT", bg, "TOPLEFT", 1, -1)
        fill:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", -1, 1)
        L.pips[i] = { bg = bg, fill = fill }
    end

    L.text = L:CreateFontString(nil, "OVERLAY")
    L.text:SetPoint("CENTER")

    -- Pulse (Unhappy only): animates our layer frame or the face texture.
    local function Pulse(target)
        local ag = target:CreateAnimationGroup()
        ag:SetLooping("BOUNCE")
        local a = ag:CreateAnimation("Alpha")
        a:SetFromAlpha(1)
        a:SetToAlpha(0.25)
        a:SetDuration(0.6)
        a:SetSmoothing("IN_OUT")
        return ag
    end
    L.pulse = Pulse(L)
    if h._tex then h._phTexPulse = Pulse(h._tex) end
    return L
end

local function HideLayers(L)
    L.dot:Hide(); L.dotBorder:Hide()
    L.bar:Hide(); L.barBg:Hide()
    for i = 1, 3 do L.pips[i].bg:Hide(); L.pips[i].fill:Hide() end
    L.text:Hide()
end

local function SetPulse(h, on, style)
    local L = h._ph
    local wantLayer = on and style ~= "icon"
    local wantTex = on and style == "icon"
    if L and L.pulse then
        if wantLayer then
            if not L.pulse:IsPlaying() then L.pulse:Play() end
        elseif L.pulse:IsPlaying() then
            L.pulse:Stop(); L:SetAlpha(1)
        end
    end
    local tp = h._phTexPulse
    if tp then
        if wantTex then
            if not tp:IsPlaying() then tp:Play() end
        elseif tp:IsPlaying() then
            tp:Stop(); h._tex:SetAlpha(1)
        end
    end
end

-------------------------------------------------------------------------------
--  Paint: geometry + state. anchor = the frame the indicator sits beside
--  (live: the pet frame; preview: its bar area). Returns false when the
--  indicator should be hidden ("only when not happy" with a happy pet).
-------------------------------------------------------------------------------
function PH.Paint(h, anchor, s, happiness, dmg)
    if not (h and anchor and s) then return true end
    if issecretvalue(happiness) then happiness = nil end
    happiness = happiness or 3
    local L = Build(h)
    local style = PH.Style(s)
    local align = s.happinessAlign or "right"
    local x, y = s.happinessX or 0, s.happinessY or 0
    local sz = PH.GetSize(s)
    local r, g, b = PH.Color(s, happiness)

    HideLayers(L)
    if h._tex then h._tex:SetShown(style == "icon") end

    local w, hh = sz, sz
    if style == "dot" then
        L.dotBorder:ClearAllPoints()
        L.dotBorder:SetPoint("CENTER")
        L.dotBorder:SetSize(sz + 2, sz + 2)
        L.dot:SetVertexColor(r, g, b, 1)
        L.dotBorder:Show(); L.dot:Show()
        w, hh = sz + 2, sz + 2
    elseif style == "bar" then
        local len = (PH.Get(s, "phBarLength") or 100) / 100
        if align == "top" or align == "bottom" then
            w, hh = math.max(4, (anchor:GetWidth() or 100) * len), sz + 2
        else
            w, hh = sz + 2, math.max(4, (anchor:GetHeight() or 30) * len)
        end
        L.bar:SetVertexColor(r, g, b, 1)
        L.barBg:Show(); L.bar:Show()
    elseif style == "pips" then
        local pw = math.max(3, math.floor(sz * 0.5 + 0.5))
        local gap = math.max(1, math.floor(sz / 7 + 0.5))
        for i = 1, 3 do
            local p = L.pips[i]
            p.bg:ClearAllPoints()
            p.bg:SetSize(pw, sz)
            p.bg:SetPoint("LEFT", L, "LEFT", (i - 1) * (pw + gap), 0)
            if i <= happiness then
                p.fill:SetVertexColor(r, g, b, 1)
            else
                p.fill:SetVertexColor(0.2, 0.2, 0.2, 1)
            end
            p.bg:Show(); p.fill:Show()
        end
        w, hh = 3 * pw + 2 * gap, sz
    elseif style == "text" then
        local fs = L.text
        local path = (EllesmereUI.GetFontPath and EllesmereUI.GetFontPath("unitFrames"))
            or "Interface\\AddOns\\EllesmereUI\\media\\fonts\\Expressway.TTF"
        if fs._phFont ~= path or fs._phSize ~= sz then
            fs:SetFont(path, sz, "OUTLINE")
            fs._phFont, fs._phSize = path, sz
        end
        local str = StateText(happiness)
        if PH.Get(s, "phShowDmg") and dmg and not issecretvalue(dmg) then
            str = str .. " " .. dmg .. "%"
        end
        fs:SetText(str)
        fs:SetTextColor(r, g, b, 1)
        fs:Show()
        w, hh = math.ceil(fs:GetStringWidth() or 40) + 2, math.ceil(fs:GetStringHeight() or sz) + 2
    end

    h:SetSize(w, hh)
    h:ClearAllPoints()
    if align == "left" then
        h:SetPoint("RIGHT", anchor, "LEFT", x, y)
    elseif align == "top" then
        h:SetPoint("BOTTOM", anchor, "TOP", x, y)
    elseif align == "bottom" then
        h:SetPoint("TOP", anchor, "BOTTOM", x, y)
    else
        h:SetPoint("LEFT", anchor, "RIGHT", x, y)
    end

    local show = not (PH.Get(s, "phOnlyUnhappy") and happiness == 3)
    SetPulse(h, show and PH.Get(s, "phPulse") and happiness == 1, style)
    return show
end

-------------------------------------------------------------------------------
--  Live frame: wrap EllesmereUI's refresh and apply
-------------------------------------------------------------------------------
local origRefresh = ns.UF_RefreshPetHappiness
local origApply = ns.UF_ApplyPetHappiness
if type(origRefresh) ~= "function" or type(origApply) ~= "function" then return end

local function Refresh(h)
    origRefresh(h)
    if not h:IsShown() then
        SetPulse(h, false, "icon"); SetPulse(h, false, "dot")
        return
    end
    local s = PH.Settings()
    local happiness, dmg = C_PetInfo.GetPetHappiness()
    if not PH.Paint(h, h:GetParent(), s, happiness, dmg) then
        SetPulse(h, false, "icon"); SetPulse(h, false, "dot")
        h:Hide()
    end
end

ns.UF_RefreshPetHappiness = Refresh

ns.UF_ApplyPetHappiness = function(...)
    origApply(...)
    local pf = ns._internals and ns._internals.frames and ns._internals.frames.pet
    local h = pf and pf._petHappy
    if h then
        -- The holder may predate this wrap: point its events at ours.
        if h:GetScript("OnEvent") ~= Refresh then h:SetScript("OnEvent", Refresh) end
        if h:IsEventRegistered("UNIT_HAPPINESS") then Refresh(h) end
    end
end

-------------------------------------------------------------------------------
--  Options preview: restyle the sample after every preview Update. The sample
--  is Happy, or Unhappy when "only when not happy" is on (so it still shows).
-------------------------------------------------------------------------------
function PH.HookPreview()
    if PH.previewHooked then return true end
    local origBuild = ns.UFO_BuildUnitPreview
    if type(origBuild) ~= "function" then return false end
    PH.previewHooked = true
    ns.UFO_BuildUnitPreview = function(...)
        local pf = origBuild(...)
        if type(pf) == "table" and pf._happyInd and type(pf.Update) == "function" and not pf._phHooked then
            pf._phHooked = true
            local origUpdate = pf.Update
            pf.Update = function(self, ...)
                local r1, r2, r3 = origUpdate(self, ...)
                local hInd = self._happyInd
                local s = PH.Settings()
                if hInd and s and s.happinessEnabled ~= false then
                    local sample = PH.Get(s, "phOnlyUnhappy") and 1 or 3
                    PH.Paint(hInd, self._barArea or self, s, sample, SAMPLE_DMG[sample])
                    hInd:Show()
                end
                return r1, r2, r3
            end
        end
        return pf
    end
    return true
end

local IsLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
if not (IsLoaded and IsLoaded("EllesmereUIOptions") and PH.HookPreview()) then
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(self, _, name)
        if name == "EllesmereUIOptions" then
            PH.HookPreview()
            self:UnregisterAllEvents()
        end
    end)
end
