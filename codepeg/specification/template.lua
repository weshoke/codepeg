module(...)

local specification = [=====[

local keywords = {
	"true", "false", "null",
}

local identifier_ignore = {}

local operators = {
	left_brace = "{",
	right_brace = "}",
	dot = ".",
	comma = ",",
	colon = ":",
	dollar = "$",
	at = "@",
}


for i, kw in ipairs(keywords) do
	Token(
		P(kw), kw:upper(), kw:len()
	)
end

for name, op in pairs(operators) do
	Token(
		P(op), name:upper(),
		op:len()
	)
end

space = S" \t\n\r"
SS = space^0



local neq = {}
local function starteq(s, i, t)
	neq[#neq+1] = t:len()
	return i
end
local function endeq(s, i, t)
	local v = neq[#neq]
	if(t:len() == v) then
		neq[#neq] = nil
	end
	return t:len() == v
end

local function testendeq(s, i, t)
	local v = neq[#neq]
	return t:len() == v
end


MULTILINE_START = Token(
	P"[" * Cmt(P"="^0, starteq) * P"[",
	"MULTILINE_START",
	MAX_PRIORITY
)

MULTILINE_END = Token(
	P"]" * Cmt(P"="^0, endeq) * P"]",
	"MULTILINE_END",
	MAX_PRIORITY
)


--------------------------------------------------------
--- Variable Tokens
nondigit = P"_" + R"az" + R"AZ"


--------------------------
--- Numerical Tokens

-- digits
octal_digit = R"07"
hexadecimal_digit = R("09", "af", "AF")
nonzero_digit = R"19"
digit = P"0" + nonzero_digit

IDENTIFIER = Token(
	nondigit * (nondigit + digit)^0,
	
	"IDENTIFIER",
	MAX_PRIORITY
)

SPACE = Token(
	space^1,
	"SPACE",
	MAX_PRIORITY
)

TEXT = Token(
	(
		P"$$" + P"@@" + C(
			1- P"@" - P"$" - (
				P"]" * Cmt(P"="^0, testendeq) * P"]"
			)
		)
	)^1,
	"TEXT"
)

arguments = Rule(
	V"LEFT_BRACE" * V"SPACE"^-1 *
	(V"name" * V"SPACE"^-1 * (V"COMMA" * V"SPACE"^-1 * V"name" * V"SPACE"^-1)^0)^-1 *
	V"SPACE"^-1 * V"RIGHT_BRACE",
	"arguments"
)

name = Rule(
	V"DOLLAR" * V"IDENTIFIER",
	"name"
)

rest = Rule(
	V"SPACE" + V"TEXT" + V"IDENTIFIER",
	"rest"
)

body = Rule(
	V"MULTILINE_START" *
		(V"name" + V"event" + V"rest")^1 * 
	V"MULTILINE_END",
	"body"
)

event = Rule(
	V"AT" * V"IDENTIFIER" * V"arguments" * V"body" * (V"COMMA" * V"body")^-1,
	"event"
)

leftover = Rule(
	C(1 - V"name" - V"event")^1,
	"leftover"
)

template = Rule(
	(V"name" + V"event" + V"leftover")^1,
	"template"
)

]=====]

function get_specification()
	return specification
end