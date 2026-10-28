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
	Space: boolean?, -- night sky full of stars
	AtmosphereColor: Color3?,
	AtmosphereDecay: Color3?,
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
	-- satellite city: hazy midday from very high up
	[4] = {
		ClockTime = 12.5,
		Brightness = 2.6,
		Ambient = Color3.fromRGB(95, 100, 105),
		OutdoorAmbient = Color3.fromRGB(140, 140, 145),
		ExposureCompensation = 0,
		AtmosphereDensity = 0.25,
		AtmosphereHaze = 2,
		Bloom = 0.4,
	},
	-- region: low, dusty orange evening light
	[5] = {
		ClockTime = 17.4,
		Brightness = 2.2,
		Ambient = Color3.fromRGB(110, 85, 70),
		OutdoorAmbient = Color3.fromRGB(150, 115, 95),
		ExposureCompensation = 0.1,
		AtmosphereDensity = 0.3,
		AtmosphereHaze = 1.6,
		Bloom = 0.6,
		AtmosphereColor = Color3.fromRGB(215, 175, 135),
		AtmosphereDecay = Color3.fromRGB(170, 110, 75),
	},
	-- country from the edge of space: bright, thin haze
	[6] = {
		ClockTime = 11,
		Brightness = 3,
		Ambient = Color3.fromRGB(100, 110, 130),
		OutdoorAmbient = Color3.fromRGB(140, 150, 170),
		ExposureCompensation = 0,
		AtmosphereDensity = 0.12,
		AtmosphereHaze = 0.5,
		Bloom = 0.4,
	},
	-- space stages: black sky full of stars, the planet lit from the side
	[7] = {
		ClockTime = 0,
		Brightness = 1,
		Ambient = Color3.fromRGB(120, 125, 140),
		OutdoorAmbient = Color3.fromRGB(110, 115, 130),
		ExposureCompensation = 0,
		AtmosphereDensity = 0,
		AtmosphereHaze = 0,
		Bloom = 0.8,
		Space = true,
	},
	[8] = {
		ClockTime = 0,
		Brightness = 1,
		Ambient = Color3.fromRGB(140, 110, 100),
		OutdoorAmbient = Color3.fromRGB(130, 100, 90),
		ExposureCompensation = 0,
		AtmosphereDensity = 0,
		AtmosphereHaze = 0,
		Bloom = 1,
		Space = true,
	},
	[9] = {
		ClockTime = 0,
		Brightness = 0.6,
		Ambient = Color3.fromRGB(110, 105, 120),
		OutdoorAmbient = Color3.fromRGB(100, 95, 110),
		ExposureCompensation = 0.1,
		AtmosphereDensity = 0,
		AtmosphereHaze = 0,
		Bloom = 1,
		Space = true,
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
		atmosphere.Color = preset.AtmosphereColor or Color3.fromRGB(199, 199, 199)
		atmosphere.Decay = preset.AtmosphereDecay or Color3.fromRGB(106, 112, 125)
	end
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if bloom then
		bloom.Intensity = preset.Bloom
	end
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if sky then
		sky.StarCount = if preset.Space then 5000 else 3000
		sky.CelestialBodiesShown = not preset.Space
	end
	local dof = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
	if dof then
		dof.Enabled = false
	end
end

return StageLighting
