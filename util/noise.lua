-- util/noise.lua
--
-- Utility functions for noise generation.

local Noise = {}

function Noise.sample2d(seed, x, y, scale)
	local noise_scale = scale or 256
	local offset = seed * 1000
	return love.math.noise((x + offset) / noise_scale, (y + offset) / noise_scale)
end

return Noise
