local audio = require("audio")
local Def = require"audio.Def"
local random = math.random
local max = math.max

Def.globalize()

---[[
Mixer = Def{
	dry = 1,
	wet = 0.15,
	decay = 0.5,
	bandwidth = 0.299995,
	damping = 0.2,

	P"dry" * P"input" + 
	P"wet" * Reverb{ 
		Mono{ P"input" },
		bandwidth="bandwidth",
		damping="damping",
		decay="decay", 
	}
}

verbmix = audio.Bus("reverbmix", 2)
mixer = Mixer{ input = verbmix }
--]]


local synth = Def{
	dur = 0.1126,
	amp = 0.225,
	freq = 200,
	
	P"amp" * Env(P"dur") * 
		Lag(
			ATan(Saw( P"freq" * Square{freq=20}))
		, 0.4)
}


for i=1, 14 do
	synth{
		freq = 50*max(1., 2^(i/3)),--+random()*0.3),
		amp = 0.005,
		dur = 0.3,
		out = verbmix
	}
	wait(0.2)
end


---[=[
function testing()
	local x = 10
	--[[
	x = 10000
	--]]
	return x
end
--]=]