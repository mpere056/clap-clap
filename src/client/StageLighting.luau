--!strict
-- Per-stage lighting, applied locally (each player sees the lighting of their own stage).

local Lighting = game:GetService("Lighting")

local StageLighting = {}

type Preset = {
	ClockTime: number,
	Brightness: number,
	Ambient: Color3,
	OutdoorAmbient: Color3,
	ExposureCompensation: number,
	AtmosphereDensity: number,
	AtmosphereHaze: number,
	Bloom: number,
}

local PRESETS: { [number]: Preset } = {
	-- indoor hall: warm, no outdoor haze
	[1] = {
		ClockTime = 13,
		Brightness = 2,
		Ambient = Color3.fromRGB(95, 85, 80),
		OutdoorAmbient = Color3.fromRGB(120, 110, 105),
		ExposureCompensation = -0.15,
		AtmosphereDensity = 0,
		AtmosphereHaze = 0,
		Bloom = 0.35,
	},
	-- gym seen from above: bright, soft shadows
	[2] = {
		ClockTime = 14.5,
		Brightness = 2.2,
		Ambient = Color3.fromRGB(100, 92, 85),
		OutdoorAmbient = Color3.fromRGB(125, 118, 110),
		ExposureCompensation = 0,
		AtmosphereDensity = 0,
		AtmosphereHaze = 0,
		Bloom = 0.35,
	},
	-- aerial town: afternoon sun with distance haze
	[3] = {
		ClockTime = 15.5,
		Brightness = 2.6,
		Ambient = Color3.fromRGB(90, 95, 100),
		OutdoorAmbient = Color3.fromRGB(130, 135, 140),
		ExposureCompensation = 0,
		AtmosphereDensity = 0.3,
		AtmosphereHaze = 1.2,
		Bloom = 0.5,
	},
}

function StageLighting.apply(stageId: number)
	local preset = PRESETS[stageId] or PRESETS[3]
	Lighting.ClockTime = preset.ClockTime
	Lighting.Brightness = preset.Brightness
	Lighting.Ambient = preset.Ambient
	Lighting.OutdoorAmbient = preset.OutdoorAmbient
	Lighting.ExposureCompensation = preset.ExposureCompensation
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Density = preset.AtmosphereDensity
		atmosphere.Haze = preset.AtmosphereHaze
	end
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if bloom then
		bloom.Intensity = preset.Bloom
	end
	local dof = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
	if dof then
		dof.Enabled = false
	end
end

return StageLighting
