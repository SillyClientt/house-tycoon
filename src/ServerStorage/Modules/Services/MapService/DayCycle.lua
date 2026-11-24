--!strict
-- Moves the sun, blends the lighting between the day and night looks,
-- and turns the street lamps / shop windows on at night.
local DayCycle = {}

local RPS = game:GetService('ReplicatedStorage')
local LGT = game:GetService('Lighting')
local TWS = game:GetService('TweenService')

local MAP_CONFIGS = require(RPS.Modules.Configs.MapConfigs)

local UPDATE_RATE = 1 -- seconds between lighting updates (smooth enough, cheap to replicate)

local nightLights: {Light} = {}
local glowParts: {BasePart} = {}
local isNight: boolean? = nil

-- 0 at night, 1 in full daylight, smooth at dawn and dusk
local function getDaylight(Clock: number): number
	local dawn = MAP_CONFIGS.DayCycle.NightEnd
	local dusk = MAP_CONFIGS.DayCycle.NightStart

	if Clock < dawn - 1 or Clock > dusk + 1 then
		return 0
	elseif Clock < dawn + 1 then
		return (Clock - (dawn - 1)) / 2
	elseif Clock > dusk - 1 then
		return 1 - (Clock - (dusk - 1)) / 2
	end

	return 1
end

-- find a Lighting effect, or make it when the place doesn't have one
local function getEffect(ClassName: string, Name: string): Instance
	local effect = LGT:FindFirstChild(Name) or LGT:FindFirstChildOfClass(ClassName)

	if effect then
		return effect
	end

	local newEffect = Instance.new(ClassName)
	newEffect.Name = Name
	newEffect.Parent = LGT

	return newEffect
end

-- switch every registered light on or off
local function setNight(Night: boolean)
	if isNight == Night then
		return
	end

	isNight = Night

	for _, light in nightLights do
		light.Enabled = Night
	end

	for _, part in glowParts do
		part.Material = if Night then Enum.Material.Neon else Enum.Material.SmoothPlastic
	end
end

-- blend the day and night looks
local function applyLook(Daylight: number)
	local day = MAP_CONFIGS.DayLook
	local night = MAP_CONFIGS.NightLook

	local tint = getEffect('ColorCorrectionEffect', 'MapTint') :: ColorCorrectionEffect
	local atmosphere = getEffect('Atmosphere', 'Atmosphere') :: Atmosphere

	local goals = {
		Ambient = night.Ambient:Lerp(day.Ambient, Daylight),
		OutdoorAmbient = night.OutdoorAmbient:Lerp(day.OutdoorAmbient, Daylight),
		Brightness = night.Brightness + (day.Brightness - night.Brightness) * Daylight,
	}

	local info = TweenInfo.new(UPDATE_RATE, Enum.EasingStyle.Linear)

	TWS:Create(LGT, info, goals):Play()
	TWS:Create(tint, info, {
		TintColor = night.ColorTint:Lerp(day.ColorTint, Daylight),
		Saturation = night.Saturation + (day.Saturation - night.Saturation) * Daylight,
	}):Play()
	TWS:Create(atmosphere, info, {
		Color = night.AtmosphereColor:Lerp(day.AtmosphereColor, Daylight),
		Decay = night.AtmosphereDecay:Lerp(day.AtmosphereDecay, Daylight),
	}):Play()
end

-- lights that come on at night (Glow parts turn neon at night)
function DayCycle:AddNightLight(Light: Light, Glow: BasePart?)
	table.insert(nightLights, Light)

	if Glow then
		table.insert(glowParts, Glow)
	end

	if isNight ~= nil then
		Light.Enabled = isNight

		if Glow then
			Glow.Material = if isNight then Enum.Material.Neon else Enum.Material.SmoothPlastic
		end
	end
end

-- start the clock
function DayCycle:Start()
	local config = MAP_CONFIGS.DayCycle

	LGT.ClockTime = config.StartTime

	local hoursPerSecond = 24 / (config.MinutesPerDay * 60)

	task.spawn(function()
		while true do
			if config.Enabled then
				LGT.ClockTime = (LGT.ClockTime + hoursPerSecond * UPDATE_RATE) % 24
			end

			local clock = LGT.ClockTime

			applyLook(getDaylight(clock))
			setNight(clock >= config.NightStart or clock < config.NightEnd)

			task.wait(UPDATE_RATE)
		end
	end)
end

return DayCycle
