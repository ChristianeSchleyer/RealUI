local nibRealUI = LibStub("AceAddon-3.0"):GetAddon("nibRealUI")
local db, ndb, ndbc

local MODNAME = "AngleStatusBar"
local AngleStatusBar = nibRealUI:NewModule(MODNAME)
local oUF = oUFembed

local min, max, abs, floor = math.min, math.max, math.abs, math.floor

local dontSmooth
local smoothing = {}
local function SetBarPosition(bar, per)
    bar.value = per
    local reverse = bar.reverse
    local value = bar.value
    local maxWidth
    if bar.info then
        maxWidth = bar.info.maxWidth
        bar = bar.bar
    else
        maxWidth = bar.fullWidth
    end
    if not reverse then
        bar:SetWidth(maxWidth * (1 - value))
    else
        bar:SetWidth(maxWidth * value)
    end

    per = floor(per * 100) / 100
    --print("Floored", bar:GetParent():GetParent().unit, reverse, per)
    bar:SetShown((not(reverse) and (per < 1)) or (reverse and (per > 0)))
end

local function SetBarValue(bar, per)
    local maxWidth = bar.info and bar.info.maxWidth or bar.fullWidth
    per = per + (1 / maxWidth)
    if per ~= bar.value then
        smoothing[bar] = per
    else
        SetBarPosition(bar, per)
        smoothing[bar] = nil
    end
end

local smoothUpdateFrame = CreateFrame("Frame")
smoothUpdateFrame:SetScript("OnUpdate", function()
    local limit = 30 / GetFramerate()
    for bar, per in next, smoothing do
        local maxWidth = bar.info and bar.info.maxWidth or bar.fullWidth
        local setPer = per * maxWidth
        local setCur = bar.value * maxWidth
        local new = setCur + min((setPer - setCur) / 2, max(setPer - setCur, limit * maxWidth))
        if new ~= new then
            new = per * maxWidth
        end
        SetBarPosition(bar, new / maxWidth)
        if setCur == setPer or abs(new - setPer) < 2 then
            SetBarPosition(bar, setPer / maxWidth)
            smoothing[bar] = nil
        end
    end
end)

function AngleStatusBar:SetValue(bar, per, ignoreSmooth)
    if bar.smooth and not(dontSmooth) and not(ignoreSmooth) then
        SetBarValue(bar, per)
    else
        SetBarPosition(bar, per)
    end
end

function AngleStatusBar:SetBarColor(bar, r, g, b, a)
    if type(r) == "table" then
        r, g, b, a = r[1], r[2], r[3], r[4]
    end
    for i = 1, #bar.row do
        bar.row[i]:SetTexture(r, g, b, a or 1)
    end
end

function AngleStatusBar:ReverseBarDirection(bar, val, x, y)
    if val then
        bar.direction = (bar.direction == "LEFT") and "RIGHT" or "LEFT"
        bar:ClearAllPoints()
        bar:SetPoint(bar.endPoint, bar.parent, bar.endPoint, x, y)
    else
        bar.direction = bar.origDirection
        bar:ClearAllPoints()
        bar:SetPoint(bar.startPoint, bar.parent, bar.startPoint, bar.x, bar.y)
    end
end

function AngleStatusBar:SetReverseFill(bar, reverse)    -- Reverse fill style (reverse: 100% = full)
    bar.reverse = reverse
    self:SetValue(bar, bar.value, true)
end

function AngleStatusBar:NewBar(parent, x, y, width, height, typeStart, typeEnd, direction, smooth)
    local bar = CreateFrame("Frame", nil, parent)
    bar.fullWidth, bar.typeStart, bar.typeEnd, bar.direction, bar.value, bar.smooth = width, typeStart, typeEnd, direction, 1, smooth, true
    bar.origDirection = bar.direction

    -- Growth direction of Bar Start and End
    local startAngle, endAngle  -- / <-- LEFT   RIGHT --> \
    startAngle = (typeStart == "LEFT") and -1 or (typeStart == "RIGHT") and 1 or 0
    endAngle = (typeEnd == "LEFT") and -1 or (typeEnd == "RIGHT") and 1 or 0

    -- Start and End positions
    local startPoint, endPoint
    startPoint = (direction == "LEFT") and "TOPRIGHT" or "TOPLEFT"
    endPoint = (startPoint == "TOPRIGHT") and "TOPLEFT" or "TOPRIGHT"
    bar:SetPoint(startPoint, parent, startPoint, x, y)

    bar.parent = parent
    bar.startPoint = startPoint
    bar.endPoint = endPoint
    bar.x = x
    bar.y = y

    -- Create pixel lines for the actual bar
    bar:SetHeight(height)
    bar.row = {}
    local rX, rY, endX = 0, 0, 0
    for r = 1, height do
        bar.row[r] = parent:CreateTexture(nil, "ARTWORK")
        bar.row[r]:SetPoint(startPoint, bar, startPoint, rX, rY)
        bar.row[r]:SetPoint(endPoint, bar, endPoint, endX, rY)
        bar.row[r]:SetHeight(1)
        rX = rX + startAngle
        endX = endX + endAngle
        rY = rY - 1
        if r > height then
            bar.row[r]:Hide()
        end
    end

    bar:SetScript("OnHide", function()
        for r = 1, #bar.row do
            bar.row[r]:Hide()
        end
    end)
    bar:SetScript("OnShow", function()
        for r = 1, #bar.row do
            bar.row[r]:Show()
        end
    end)

    bar:SetWidth(1)
    bar:Hide()
    self:SetValue(bar, 0, true)

    return bar
end


-- New Status bars WIP

-- This should except a percentage or discrete value.
-- If SetMinMaxValues (NYI) is not called, default to min = 0, max = 1.
local function SetValue(self, value, ignoreSmooth)
    print("SetValue", value, ignoreSmooth)
    if self.info.smooth and not(dontSmooth) and not(ignoreSmooth) then
        SetBarValue(self, value)
    else
        SetBarPosition(self, value)
    end
end

local function CreateAngleBG(self, width, height, parent, info)
    print("CreateAngleBG", self.unit, info)
    local bg = CreateFrame("Frame", nil, parent)
    bg:SetSize(width, height)

    local test = bg:CreateTexture(nil, "BACKGROUND", nil, -8)
    test:SetTexture(1, 1, 1, 0.5)
    test:SetAllPoints(bg)

    local leftX, rightX = 0, 0
    -- These conditions keep the textures within the frame.
    -- Doing this removes the need to make a bunch of offsets elsewhere.
    leftX = (info.leftAngle == [[/]]) and height - 1 or 0
    rightX = (info.rightAngle == [[\]]) and -(height - 1) or 0

    print("CreateBG", leftX, rightX)
    bg.top = bg:CreateTexture(nil, "BACKGROUND")
    bg.top:SetTexture(0, 0, 0)
    bg.top:SetHeight(1)
    bg.top:SetPoint("TOPLEFT", leftX, 0)
    bg.top:SetPoint("TOPRIGHT", rightX, 0)

    local left, right
    for i = 1, height - 2 do
        -- Left side
        local left = bg:CreateTexture(nil, "BACKGROUND")
        left:SetTexture(0, 0, 0)
        left:SetSize(1, 1)
        left:SetPoint("TOPLEFT", bg.top, "BOTTOMLEFT", -i, 1 - i)

        -- Right side
        local right = bg:CreateTexture(nil, "BACKGROUND")
        right:SetTexture(0, 0, 0)
        right:SetSize(1, 1)
        right:SetPoint("TOPRIGHT", bg.top, "TOPRIGHT", -i, -i)

        -- Middle
        local tex = bg:CreateTexture(nil, "BACKGROUND")
        --tex:SetTexture(1, 1, 1, 0.5)
        tex:SetTexture(nibRealUI.media.background[1], nibRealUI.media.background[2], nibRealUI.media.background[3], nibRealUI.media.background[4])
        tex:SetHeight(1)
        tex:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
        tex:SetPoint("TOPRIGHT", right, "TOPLEFT", 0, 0)
    end

    bg.bottom = bg:CreateTexture(nil, "BACKGROUND")
    bg.bottom:SetTexture(0, 0, 0)
    bg.bottom:SetHeight(1)
    bg.bottom:SetPoint("BOTTOMLEFT", rightX, 0)
    bg.bottom:SetPoint("BOTTOMRIGHT", -leftX, 0)

    return bg, leftX, rightX
end
oUF:RegisterMetaFunction("CreateAngleBG", CreateAngleBG) -- oUF magic

local function CreateAngleStatusBar(self, width, height, parent, info)
    print("CreateAngleStatusBar", self.unit, info)
    local status, leftX, rightX = CreateAngleBG(self, width, height, parent, info)

    info.maxWidth, info.minWidth, info.origDirection = width - 4, height - 2, info.growDirection
    info.startPoint = (info.growDirection == "LEFT") and "TOPRIGHT" or "TOPLEFT"
    info.endPoint = (info.startPoint == "TOPRIGHT") and "TOPLEFT" or "TOPRIGHT"

    local bar = CreateFrame("Frame", nil, status)
    bar:SetPoint(info.startPoint, status, -2, -1)
    bar:SetHeight(info.minWidth)

    local test = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
    test:SetTexture(1, 1, 1, 0.5)
    test:SetAllPoints(bar)

    if info.growDirection == "LEFT" then
        --
    else
        --\
    end

    bar.row = {}
    for i = 1, info.minWidth do
        bar.row[i] = bar:CreateTexture(nil, "BACKGROUND")
        bar.row[i]:SetHeight(1)
        bar.row[i]:SetPoint("TOPLEFT", abs(leftX), 1 - i)
        bar.row[i]:SetPoint("TOPRIGHT", rightX, 1 - i)
    end

    status.info = info
    status.bar = bar
    
    -- StatusBar API
    status.SetValue = SetValue

    status:SetValue(1, true)
    return status
end
oUF:RegisterMetaFunction("CreateAngleStatusBar", CreateAngleStatusBar) -- oUF magic

-------------
function AngleStatusBar:OnInitialize()
    ndb = nibRealUI.db.profile
    ndbc = nibRealUI.db.char

    if ndb.settings.powerMode == 2 then
        dontSmooth = true
    end
end
