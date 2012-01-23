module(...)

local specification = [=====[

local keywords = {
	"true", "false", "null",
}

local identifier_ignore = {}

local operators = {
	left_bracket = "[",
	right_bracket = "]",
	left_brace = "{",
	right_brace = "}",
	dot = ".",
	comma = ",",
	colon = ":",
}


for i, kw in ipairs(keywords) do
	Token(
		P(kw), kw:upper(), kw:len()
	)
end

for name, op in pairs(operators) do
	Token(
		P(op), name:upper(),
		op:len(),
		true
	)
end


local keyword_map = {}
for i, kw in ipairs(keywords) do
	keyword_map[kw] = true
end
for i, kw in ipairs(identifier_ignore) do
	keyword_map[kw] = nil
end


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


endline = S"\n\r"
STRING = Token(
	P[["]] * (P[[\"]]+(1 - (endline + P[["]])))^0 * (P[["]] + LexErr(P(1), [[string missing closing "]])),
	"STRING",
	MAX_PRIORITY
)


NUMBER = Token(
	P"-"^-1 * (
		nonzero_digit * digit^0 +
		P"0"
	) * 
	(P"." * digit^0)^-1 *
	(
		S"eE" * S"-+"^-1 * 
		digit^1
	)^-1,
	
	"NUMBER",
	MAX_PRIORITY
)

value = Rule(
	V"STRING" + V"NUMBER" + V"object" + V"array" + V"TRUE" + V"FALSE" + V"NULL",
	"value",
	true
)

array = Rule(
	V"LEFT_BRACKET" * V"value"^-1 * (V"COMMA" * V"value")^0 * V"RIGHT_BRACKET",
	"array"
)

object = Rule(
	V"LEFT_BRACE" * 
		(V"STRING" * V"COLON" * V"value")^-1 * 
		(V"COMMA" * V"STRING" * V"COLON" * V"value")^0 *
	V"RIGHT_BRACE",
	"object"
)
					
single_line_comment = Comment(P"//"*(1 - S"\n\r")^0, "single_line_comment")
multi_line_comment = Comment(P"/*"*(1 - P"*/")^0*P"*/", "multi_line_comment")
]=====]

function get_specification()
	return specification
end