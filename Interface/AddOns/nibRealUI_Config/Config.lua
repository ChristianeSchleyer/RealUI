local ADDON_NAME, private = ...
local options = {}
private.options = options

-- Lua Globals --
local next = _G.next

-- Libs --
local ACR = _G.LibStub("AceConfigRegistry-3.0")
local ACD = _G.LibStub("AceConfigDialog-3.0")
local F, C = _G.Aurora[1], _G.Aurora[2]
local r, g, b = C.r, C.g, C.b

-- RealUI --
local RealUI = _G.RealUI
local L = RealUI.L
local Scale = RealUI.Scale
--local round = RealUI.Round

local _, MOD_NAME = _G.strsplit("_", ADDON_NAME)
local initialized = false
local isHuDShown = false

local debug = RealUI.GetDebug(MOD_NAME)
private.debug = debug

local RavenTimer
_G.hooksecurefunc(_G.ZoneAbilityFrame, "Hide", function(self)
    if self._show then
        self:Show()
    end
end)
function RealUI:HuDTestMode(doTestMode)
    -- Toggle Test Modes
    -- Raven
    local Raven = _G.Raven
    if Raven then
        if doTestMode then
            Raven:TestBarGroups()
            RavenTimer = _G.C_Timer.NewTicker(51, function()
                Raven:TestBarGroups()
            end)
        else
            if self.isInTestMode then
                RavenTimer:Cancel()
                RavenTimer = nil
                Raven:TestBarGroups()
            end
        end
    end

    RealUI:ToggleGridTestMode(doTestMode)

    -- RealUI Modules
    for k, mod in next, RealUI.configModeModules do
        debug("Config Test", mod.moduleName)
        if mod:IsEnabled() then
            debug("Is enabled")
            mod:ToggleConfigMode(doTestMode)
        end
    end

    if not _G.ObjectiveTrackerFrame.collapsed then
        _G.ObjectiveTrackerFrame:SetShown(not doTestMode)
    end
    -- Boss Frames
    RealUI:BossConfig(doTestMode)

    -- Spell Alerts
    local sAlert = {
        id = 17941,
        texture = [[TEXTURES\SPELLACTIVATIONOVERLAYS\NIGHTFALL]],
        positions = "Left + Right (Flipped)",
        scale = 1,
        r = 255, g = 255, b = 255,
    }
    if doTestMode then
        _G.SpellActivationOverlay_ShowAllOverlays(_G.SpellActivationOverlayFrame, sAlert.id, sAlert.texture, sAlert.positions, sAlert.scale, sAlert.r, sAlert.g, sAlert.b);
    else
        _G.SpellActivationOverlay_HideOverlays(_G.SpellActivationOverlayFrame, sAlert.id)
    end

    -- Extra Action Button
    local EABFrame = _G.ExtraActionBarFrame
    if not _G.HasExtraActionBar() then
        if doTestMode then
            EABFrame.button:Show()
            EABFrame:Show()
            EABFrame.outro:Stop()
            EABFrame.intro:Play()
            if not EABFrame.button.icon:GetTexture() then
                EABFrame.button.icon:SetTexture([[Interface\ICONS\ABILITY_SEAL]])
                EABFrame.button.icon:Show()
            end
        else
            EABFrame:Hide()
            EABFrame.button:Hide()
            EABFrame.intro:Stop()
            EABFrame.outro:Play()
        end
    end

    -- Zone Ability Button
    local ZAFFrame = _G.ZoneAbilityFrame
    if not _G.HasZoneAbility() then
        if doTestMode then
            ZAFFrame:Show()
            ZAFFrame.SpellButton:Disable()
            ZAFFrame._show = true
            ZAFFrame.SpellButton.Icon:SetTexture([[Interface\ICONS\ABILITY_SEAL]])
        else
            ZAFFrame._show = false
            ZAFFrame.SpellButton:Enable()
            ZAFFrame:Hide()
        end
    end
    self.isInTestMode = doTestMode
end

_G.StaticPopupDialogs["RUI_ChangeHuDSize"] = {
    text = L["HuD_AlertHuDChangeSize"],
    button1 = _G.OKAY,
    OnAccept = function()
        RealUI:ReloadUIDialog()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    notClosableByLogout = false,
}

local width, height = 65, 50
local hudConfig, hudToggle do
    -- The HuD Config bar
    hudConfig = _G.CreateFrame("Frame", "RealUIHuDConfig", _G.UIParent)
    Scale.Point(hudConfig, "BOTTOM", _G.UIParent, "TOP", 0, 1)
    hudConfig:SetScript("OnEvent", function(self, event, ...)
        if event == "PLAYER_REGEN_DISABLED" then
            hudToggle(true)
        end
    end)

    local slideAnim = hudConfig:CreateAnimationGroup()
    slideAnim:SetScript("OnFinished", function(self)
        local _, y = self.slide:GetOffset()
        hudConfig:ClearAllPoints()
        if y < 0 then
            Scale.Point(hudConfig, "TOP", _G.UIParent, "TOP", 0, 0)
        else
            Scale.Point(hudConfig, "BOTTOM", _G.UIParent, "TOP", 0, 1)
        end
    end)
    hudConfig.slideAnim = slideAnim

    local slide = slideAnim:CreateAnimation("Translation")
    slide:SetDuration(1)
    slide:SetSmoothing("OUT")
    slideAnim.slide = slide

    -- Highlight frame
    local highlight = _G.CreateFrame("Frame", "RealUIHuDConfig", hudConfig)
    F.CreateBD(highlight, 0.0)
    highlight:SetBackdropColor(r, g, b, 0.3)
    highlight:SetBackdropBorderColor(r, g, b)
    highlight:Hide()
    hudConfig.highlight = highlight

    local hlAnim = highlight:CreateAnimationGroup()
    highlight.hlAnim = hlAnim
    local hl = hlAnim:CreateAnimation("Translation")
    hl:SetDuration(0.2)
    hl:SetSmoothing("OUT")
    hlAnim.hl = hl

    local CloseHuDWindow = function()
        -- hide highlight
        highlight:Hide()
        highlight.hover = nil
        highlight.clicked = nil

        ACD:Close("HuD")
    end
    private.CloseHuDWindow = CloseHuDWindow
    hudToggle = function(skipAnim)
        if isHuDShown then
            CloseHuDWindow()

            -- slide out
            if skipAnim then
                hudConfig:ClearAllPoints()
                Scale.Point(hudConfig, "BOTTOM", _G.UIParent, "TOP", 0, 0)
            else
                slide:SetOffset(0, Scale.Value(height))
                slideAnim:Play()
            end
            RealUI:HuDTestMode(false)
            hudConfig:UnregisterEvent("PLAYER_REGEN_DISABLED")
            isHuDShown = false
        else
            -- slide in
            if skipAnim then
                hudConfig:ClearAllPoints()
                Scale.Point(hudConfig, "TOP", _G.UIParent, "TOP", 0, 0)
            else
                slide:SetOffset(0, Scale.Value(-height))
                slideAnim:Play()
            end
            hudConfig:RegisterEvent("PLAYER_REGEN_DISABLED")
            isHuDShown = true
        end
    end

    F.CreateBD(hudConfig)
    Scale.Point(_G.RealUIUINotifications, "TOP", hudConfig, "BOTTOM")
    RealUI.RegisterModdedFrame(hudConfig)
end

local function InitializeOptions()
    debug("InitializeOptions", options.RealUI, options.HuD)
    if not (options.RealUI and options.HuD) then
        -- Not sure how people are getting this....
        return _G.print("Options initialization failed. Please notify the developer.")
    end
    local slideAnim = hudConfig.slideAnim
    local highlight = hudConfig.highlight
    local hlAnim = highlight.hlAnim
    local hl = hlAnim.hl

    ACR:RegisterOptionsTable("RealUI", options.RealUI)
    ACD:SetDefaultSize("RealUI", 800, 600)

    ACR:RegisterOptionsTable("HuD", options.HuD)
    ACD:SetDefaultSize("HuD", 620, 480)
    initialized = true

    -- Buttons
    local tabs = {}
    for slug, tab in next, options.HuD.args do
        debug("init tabs", slug, tab.order)
        _G.tinsert(tabs, tab.order + 2, {
            slug = slug,
            name = tab.name,
            icon = tab.icon,
            onclick = tab.order == -1 and function(self, ...)
                debug("OnClick", self.slug, ...)
                highlight:Hide()
                hudToggle()
            end or nil,
        })
    end
    _G.tinsert(tabs, _G.tremove(tabs, 1)) -- Move close to the end
    local function tabOnClick(self, ...)
        debug("OnClick", self.slug, ...)
        if highlight.clicked and tabs[highlight.clicked].frame then
            tabs[highlight.clicked].frame:Hide()
        end
        local widget = ACD.OpenFrames["HuD"]
        if widget and highlight.clicked == self.ID then
            highlight.clicked = nil
            Scale.Point(widget.titlebg, "TOP", 0, 12)
            ACD:Close("HuD")
        else
            highlight.clicked = self.ID
            ACD:Open("HuD", self.slug)
            widget = ACD.OpenFrames["HuD"]
            widget:ClearAllPoints()
            Scale.Point(widget, "TOP", hudConfig, "BOTTOM")
            widget:SetTitle(self.text:GetText())
            Scale.Point(widget.titlebg, "TOP", 0, 0)
            -- the position will get reset via SetStatusTable, so we need to set our new positions there too.
            local status = widget.status or widget.localstatus
            status.top = widget.frame:GetTop()
            status.left = widget.frame:GetLeft()
        end
    end
    local prevFrame
    debug("size", width, height)
    for i = 1, #tabs do
        local tab = tabs[i]
        debug("iter tabs", i, tab.slug)
        local btn = _G.CreateFrame("Button", "$parentBtn"..i, hudConfig)
        btn.ID = i
        btn.slug = tab.slug
        Scale.Size(btn, width, height)
        btn:SetScript("OnEnter", function(self, ...)
            if slideAnim:IsPlaying() then return end
            debug("OnEnter", tab.slug)
            if highlight:IsShown() then
                debug(highlight.hover, highlight.clicked)
                if highlight.hover ~= self.ID then
                    hl:SetOffset(Scale.Value(width) * (self.ID - highlight.hover), 0)
                    hlAnim:SetScript("OnFinished", function(anim)
                        highlight.hover = i
                        highlight:SetAllPoints(self)
                    end)
                    hlAnim:Play()
                elseif hlAnim:IsPlaying() then
                    debug("Stop Playing")
                    hlAnim:Stop()
                end
            else
                highlight.hover = i
                highlight:SetAllPoints(self)
                highlight:Show()
            end
        end)
        btn:SetScript("OnLeave", function(self, ...)
            if hudConfig:IsMouseOver() then return end
            debug("OnLeave hudConfig", ...)
            if highlight.clicked then
                debug(highlight.hover, highlight.clicked)
                if highlight.hover ~= highlight.clicked then
                    hl:SetOffset(Scale.Value(width) * (highlight.clicked - highlight.hover), 0)
                    hlAnim:SetScript("OnFinished", function(anim)
                        highlight.hover = highlight.clicked
                        highlight:SetAllPoints(hudConfig[highlight.clicked])
                    end)
                    hlAnim:Play()
                elseif hlAnim:IsPlaying() then
                    debug("Stop Playing")
                    hlAnim:Stop()
                end
            else
                highlight:Hide()
            end
        end)

        if i == 1 then
            Scale.Point(btn, "TOPLEFT")
            local check = _G.CreateFrame("CheckButton", nil, btn, "SecureActionButtonTemplate, UICheckButtonTemplate")
            check:SetHitRectInsets(-10, -10, -1, -21)
            Scale.Point(check, "CENTER", 0, 10)
            check:SetAttribute("type1", "macro")
            F.ReskinCheck(check)
            _G.SecureHandlerWrapScript(check, "OnClick", check, [[
                if self:GetID() == 1 then
                    self:SetAttribute("macrotext", format("/cleartarget\n/focus\n/run RealUI:HuDTestMode(false)"))
                    self:SetID(0)
                else
                    self:SetAttribute("macrotext", format("/target player\n/focus\n/run RealUI:HuDTestMode(true)"))
                    self:SetID(1)
                end
            ]])
        else
            Scale.Point(btn, "TOPLEFT", prevFrame, "TOPRIGHT")
            btn:SetScript("OnClick", tab.onclick or tabOnClick)

            local icon = btn:CreateTexture(nil, "ARTWORK")
            icon:SetTexture(tab.icon)
            Scale.Size(icon, 32, 32)
            Scale.Point(icon, "CENTER", 0, 4)
        end

        local text = btn:CreateFontString()
        text:SetFontObject(_G.Game16Font)
        Scale.Point(text, "BOTTOMLEFT", 0, 5)
        Scale.Point(text, "BOTTOMRIGHT", 0, 5)
        text:SetText(tab.name)
        btn.text = text

        _G.tinsert(hudConfig, btn)
        prevFrame = btn
    end
    Scale.Size(hudConfig, #hudConfig * width, height)
end

function RealUI.ToggleConfig(app, section, ...)
    debug("Toggle", app, section, ...)
    if not initialized then InitializeOptions() end
    if app == "HuD" then
        if not isHuDShown then
            hudToggle(section)
        end
        if section then
            debug("Highlight", section, #hudConfig)
            for i = 1, #hudConfig do
                local tab = hudConfig[i]
                if tab.slug == section then
                    tab:GetScript("OnClick")(tab)
                    hudConfig.highlight.hover = i
                    hudConfig.highlight:SetAllPoints(tab)
                    hudConfig.highlight:Show()
                end
            end
        end
    end
    --if not app:match("RealUI") then app = "RealUI" end
    if ACD.OpenFrames[app] and not section then
        ACD:Close(app)
    elseif section or app ~= "HuD" then
        ACD:Open(app, section)
    end

    if ... then
        ACD:SelectGroup(app, section, ...)
    end
end
