if EUI_CLIENT_BLOCKED then return end -- pre-12.1 client failsafe (EllesmereUI_ClientGate.lua)
-------------------------------------------------------------------------------
--  EllesmereUI_PetHappiness \ PetHappiness_Options.lua   (standalone add-on)
--
--  Unit Frames > Pet > PET HAPPINESS, without touching EllesmereUI files:
--  ns.UFO_BuildPetOptions is wrapped. While it builds, W.DualRow is wrapped
--  for that one call to
--    * make the stock "Size" slider follow the selected style
--      (Icon keeps happinessSize; Dot / Bar / Pips / Text have their own),
--    * add "Bottom" to the stock "Position" dropdown.
--  Our rows are built inside PET HAPPINESS, under the Position row (since
--  EUI 9.5.4 BUFFS AND DEBUFFS follows that section): Style (next to
--  Position), Only When Not Happy, Pulse When Unhappy, colors.
-------------------------------------------------------------------------------
local EllesmereUI = _G.EllesmereUI
local ns = EllesmereUI and EllesmereUI._ModuleNS and EllesmereUI._ModuleNS["EllesmereUIUnitFrames"]
local PH = ns and ns.PetHappyStyle
if not PH then return end

local function Install()
    if PH.optionsHooked then return true end
    local orig = ns.UFO_BuildPetOptions
    if type(orig) ~= "function" then return false end
    PH.optionsHooked = true

    ns.UFO_BuildPetOptions = function(W, parent, y, ...)
        if EllesmereUI.IS_FOREVER ~= true or type(W) ~= "table" then
            return orig(W, parent, y, ...)
        end
        local env = ns._UFO_OptEnv
        local P = PH.Settings()
        local function apply()
            if ns.UF_ApplyPetHappiness then ns.UF_ApplyPetHappiness() end
            if env and env.UpdatePreview then env.UpdatePreview() end
        end

        local function off() return P and P.happinessEnabled == false end
        local function iconStyle() return off() or PH.Style(P) == "icon" end
        local function Set(k, v) P[k] = v; apply() end
        local function ColorCfg(text, key)
            return { type = "colorpicker", text = text, hasAlpha = false,
                disabled = iconStyle, disabledTooltip = "a Style other than Icon",
                getValue = function()
                    local c = PH.Get(P, key)
                    return c.r, c.g, c.b, 1
                end,
                setValue = function(r, g, b)
                    P[key] = { r = r, g = g, b = b }
                    apply()
                end }
        end

        -- Patch the stock PET HAPPINESS rows while the page builds (one call).
        -- Our rows go INSIDE that section: Style takes the blank slot next to
        -- Position, the rest are built right under it and their height is
        -- added to the Position row's, so the stock code (and BUFFS AND
        -- DEBUFFS in 9.5.4+) continues below them.
        local rawDual = rawget(W, "DualRow")
        local baseDual = W.DualRow
        W.DualRow = function(self, pp, yy, a, b, ...)
            if not (P and type(a) == "table") then
                return baseDual(self, pp, yy, a, b, ...)
            end
            if a.type == "toggle" and a.text == "Show Happiness"
                and type(b) == "table" and b.type == "slider" then
                b.min, b.max = 1, 64
                b.tooltip = "Size of the selected style: icon / dot size, bar thickness, pip height or text size."
                b.getValue = function() return PH.GetSize(P) end
                b.setValue = function(v) PH.SetSize(P, v); apply() end
                return baseDual(self, pp, yy, a, b, ...)
            end
            if not (a.type == "dropdown" and a.text == "Position"
                and type(a.values) == "table" and a.values.top and a.values.left) then
                return baseDual(self, pp, yy, a, b, ...)
            end

            -- Position (+ Bottom) | Style
            local vals = {}
            for k, v in pairs(a.values) do vals[k] = v end
            vals.bottom = "Bottom"
            a.values = vals
            a.order = { "left", "right", "top", "bottom" }
            local styleCfg = { type = "dropdown", text = "Style",
                values = PH.STYLES, order = PH.STYLE_ORDER,
                disabled = off, disabledTooltip = "Show Happiness",
                getValue = function() return PH.Style(P) end,
                setValue = function(v) Set("phStyle", v); EllesmereUI:RefreshPage() end }
            local posRow, total = baseDual(self, pp, yy, a, styleCfg)
            total = total or 0
            if not EllesmereUI._prebuilding and posRow and posRow._rightRegion then
                EllesmereUI.BuildInlineCog(posRow._rightRegion, {
                    disabled = iconStyle, disabledTooltip = "This option requires a Style other than Icon.",
                    title = "Happiness Style",
                    rows = {
                        { type = "slider", label = "Bar Length %", min = 10, max = 100, step = 5,
                          get = function() return PH.Get(P, "phBarLength") end,
                          set = function(v) Set("phBarLength", v) end },
                        { type = "toggle", label = "Text: Show Damage %",
                          get = function() return PH.Get(P, "phShowDmg") and true or false end,
                          set = function(v) Set("phShowDmg", v and true or false) end },
                    },
                })
            end

            local _, rh
            -- Only When Not Happy | Pulse When Unhappy
            _, rh = baseDual(self, pp, yy - total,
                { type = "toggle", text = "Only When Not Happy",
                  tooltip = "Hides the indicator while your pet is Happy; it appears when the pet drops to Content or Unhappy.",
                  disabled = off, disabledTooltip = "Show Happiness",
                  getValue = function() return PH.Get(P, "phOnlyUnhappy") and true or false end,
                  setValue = function(v) Set("phOnlyUnhappy", v and true or false) end },
                { type = "toggle", text = "Pulse When Unhappy",
                  tooltip = "The indicator slowly pulses while your pet is Unhappy.",
                  disabled = off, disabledTooltip = "Show Happiness",
                  getValue = function() return PH.Get(P, "phPulse") and true or false end,
                  setValue = function(v) Set("phPulse", v and true or false) end });  total = total + (rh or 0)
            -- Happy Color | Content Color
            _, rh = baseDual(self, pp, yy - total,
                ColorCfg("Happy Color", "phColorHappy"),
                ColorCfg("Content Color", "phColorContent"));  total = total + (rh or 0)
            -- Unhappy Color | blank
            _, rh = baseDual(self, pp, yy - total,
                ColorCfg("Unhappy Color", "phColorUnhappy"),
                EllesmereUI.BlankRowCfg());  total = total + (rh or 0)

            -- The stock code subtracts this from its y: covers all four rows.
            return posRow, total
        end
        local ok, res = pcall(orig, W, parent, y, ...)
        W.DualRow = rawDual
        if not ok then error(res, 0) end
        return res
    end
    return true
end

local IsLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
if not (IsLoaded and IsLoaded("EllesmereUIOptions") and Install()) then
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(self, _, name)
        if name == "EllesmereUIOptions" then
            Install()
            self:UnregisterAllEvents()
        end
    end)
end
