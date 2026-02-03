-- systems/world_generator.lua
--
-- System for procedurally generating the world map.

local Noise = require("util.noise")

local WorldGenerator = {}

local function classify_region(elevation, moisture)
	if elevation < 0.35 then
		return "water"
	end

	if elevation > 0.78 then
		return "mountain"
	end

	if moisture > 0.6 then
		return "forest"
	end

	return "plains"
end

function WorldGenerator.generate(seed, width, height)
	local world = {
		seed = seed or 1,
		width = width or 2048,
		height = height or 2048,
	}

	function world:sample(x, y)
		local elevation = Noise.sample2d(self.seed, x, y, 420)
		local moisture = Noise.sample2d(self.seed + 17, x, y, 300)
		local region = classify_region(elevation, moisture)
		return {
			elevation = elevation,
			moisture = moisture,
			region = region,
		}
	end

	return world
end

return WorldGenerator
