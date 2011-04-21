module(...)

local specification = [=====[

local keywords = {
	"and", "break", "do", "else", "elseif",
	"end", "false", "for", "function", "if",
	"in", "local", "nil", "not", "or", "repeat",
	"return", "then", "true", "until", "while"
}

local operators = {
	concat = "..",
	lt = "<",
	lte = "<=",
	gt = ">",
	gte = ">=",
	eq = "==",
	neq = "~=",
	plus = "+",
	dash = "-",
	star = "*",
	slash = "/",
	carat = "^",
	percent = "%",
	hash = "#",
	elipses = "...",
	left_brace = "{",
	right_brace = "}",
	left_bracket = "[",
	right_bracket = "]",
	left_paren = "(",
	right_paren = ")",
	comma = ",",
	dot = ".",
	semicolon = ";",
	colon = ":",
	equals = "=",
	
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


local keyword_map = {}
for i, kw in ipairs(keywords) do
	keyword_map[kw] = true
end


-- 3   3.0   3.1416   314.16e-2   0.31416E1   0xff   0x56
nondigit = P"_" + R"az" + R"AZ"
badhex = nondigit+S".:"
hexadecimal_digit = R("09", "af", "AF")
nonzero_digit = R"19"
digit = P"0" + nonzero_digit

-- constants
decimal_constant = nonzero_digit * (nonzero_digit + digit)^0
hexadecimal_constant = P"0x" * 
						(
							hexadecimal_digit +
							LexErr(badhex, "invalid hexadecimal constant")
						)^1


exponent = S"eE"
digit_sequence = digit * (digit + LexErr(nondigit-exponent, "invalid numerical constant"))^0
exponent_part = (exponent * P"-" + exponent) * digit_sequence

fractional_constant =	digit_sequence * P"."^-1 * digit_sequence^-1 + 
						P"." * digit_sequence

NUMBER = Token(
		hexadecimal_constant + (
			fractional_constant * exponent_part^-1 + 
			digit_sequence * exponent_part
		),
		
		"NUMBER",
		MAX_PRIORITY
	)
	

NAME = Token(
	Cmt(
		C(nondigit * (nondigit + digit)^0), 
		function(s, i, a)
			return not keyword_map[a]
		end), 
	"NAME",
	MAX_PRIORITY
)


endline = S"\n\r"
single_quote_string = P[[']] * (P[[\']]+(1 - (endline + P[[']])))^0 * (P[[']] + LexErr(P(1), [[string missing closing ']]))
double_quote_string = P[["]] * (P[[\"]]+(1 - (endline + P[["]])))^0 * (P[["]] + LexErr(P(1), [[string missing closing "]]))


local neq
local function starteq(s, i, t)
	neq = t:len()
	return i
end
local function endeq(s, i, t)
	return t:len() == neq
end

multiline_start = P"[" * Cmt(P"="^0, starteq) * P"["
multiline_end = P"]" * Cmt(P"="^0, endeq) * P"]"
multiline_string = 
			multiline_start * 
			(1 - multiline_end)^0 * 
			(multiline_end + LexErr(P(-1), "string missing closing multi-line token"))

STRING = Token(
	 single_quote_string + double_quote_string + multiline_string,
	"STRING",
	MAX_PRIORITY
)



value = Rule(
	V"NIL" + 
	V"FALSE" + 
	V"TRUE" + 
	V"NUMBER" + 
	V"STRING" + 
	V"ELIPSES" + 
	V"function" + 
	V"tableconstructor" + 
	V"functioncall" + 
	V"var" +
	V"LEFT_PAREN" * V"exp" * V"RIGHT_PAREN",
	"value"
)


power_expression = Rule(
		V"value" * (
			V"CARAT" * V"value"
		)^0,
		
		"power_expression"
	)


unary_expression = Rule(
		V"power_expression" + 
		(V"NOT" + V"HASH" + V"DASH") * V"unary_expression",
		
		"unary_expression"
	)


multiplicative_expression = Rule(
		V"unary_expression" * (
			(V"STAR" + V"SLASH" + V"PERCENT") *
			V"unary_expression"
		)^0,
		
		"multiplicative_expression"
	)

additive_expression = Rule(
		V"multiplicative_expression" * (
			(V"PLUS" + V"DASH") * 
			V"multiplicative_expression"
		)^0,
		
		"additive_expression"
	)

concat_expression = Rule(
		V"additive_expression" * (
			V"CONCAT" * V"additive_expression"
		)^0,
		
		"concat_expression"
	)

relational_expression =  Rule(
		V"concat_expression" * (
			(
				V"LT" + V"GT" + V"LTE" + V"GTE" + 
				V"NEQ" + V"EQ"
			) * 
			V"concat_expression"
		)^0,
		
		"relational_expression"
	)

and_expression = Rule(
		V"relational_expression" * (
			V"AND" * V"relational_expression"
		)^0,
		"and_expression"
	)

or_expression = Rule(
		V"and_expression" * (
			V"OR" * V"and_expression"
		)^0,
		"or_expression"
	)




namelist = Rule(
	V"NAME" * (V"COMMA" * V"NAME")^0,
	"namelist"
)

fieldsep = Rule(
	V"COMMA" + V"SEMICOLON",
	"fieldsep"
)

funcname = Rule(
	V"NAME" * (V"DOT" * V"NAME")^0 * (V"COLON" * V"NAME")^-1,
	"funcname"
)

exp = Rule(
	V"or_expression" + 
	V"unary_expression",
	"exp"
)

explist = Rule(
	(V"exp" * V"COMMA")^0 * V"exp",
	"explist"
)

prefix = Rule(
	V"LEFT_PAREN" * V"exp" * V"RIGHT_PAREN" + 
	V"NAME",
	"prefix"
)

index = Rule(
	V"LEFT_BRACKET" * V"exp" * V"RIGHT_BRACKET" + 
	V"DOT" * V"NAME",
	"index"
)

call = Rule(
	V"args" + 
	V"COLON" * V"NAME" * V"args",
	"call"
)

suffix = Rule(
	V"call" + 
	V"index",
	"suffix"
)

var = Rule(
	V"prefix" * (V"suffix" * #V"suffix")^0 * V"index" + 
	V"NAME",
	"var"
)

varlist = Rule(
	V"var" * (V"COMMA" * V"var")^0,
	"varlist"
)

functioncall = Rule(
	V"prefix" * (V"suffix" * #V"suffix")^0 * V"call",
	"functioncall"
)

args = Rule(
	V"LEFT_PAREN" * V"explist"^-1 * V"RIGHT_PAREN" + 
	V"tableconstructor" + 
	V"STRING",
	"args"
)

tableconstructor = Rule(
	V"LEFT_BRACE" * V"fieldlist"^-1 * V"RIGHT_BRACE",
	"tableconstructor"
)

field = Rule(
	V"LEFT_BRACKET" * V"exp" * V"RIGHT_BRACKET" * V"EQUALS" * V"exp" + 
	V"NAME" * V"EQUALS" * V"exp" + 
	V"exp",
	"field"
)

fieldlist = Rule(
	V"field" * (V"fieldsep" * V"field")^0 * V"fieldsep"^-1,
	"fieldlist"
)

_function = Rule(
	V"FUNCTION" * V"funcbody",
	"function"
)

funcbody = Rule(
	V"LEFT_PAREN" * V"parlist"^-1 * V"RIGHT_PAREN" * V"block" * V"END",
	"funcbody"
)

parlist = Rule(
	V"namelist" * (V"COMMA" * V"ELIPSES")^-1 + 
	V"ELIPSES",
	"parlist"
)

block = Rule(
	V"chunk",
	"block"
)
		
chunk = Rule(
	(V"stat" * V"SEMICOLON"^-1)^0 * (V"laststat" * V"SEMICOLON"^-1)^-1,
	"chunk"
)

stat = Rule(
	V"varlist" * V"EQUALS" * V"explist" + 
	V"functioncall" +
	V"DO" * V"block" * V"END" + 
	V"WHILE" * V"exp" * V"DO" * V"block" * V"END" + 
	V"REPEAT" * V"block" * V"UNTIL" * V"exp" + 
	V"IF" * V"exp" * V"THEN" * V"block" * 
		(V"ELSEIF" * V"exp" * V"THEN" * V"block")^0 * 
		(V"ELSE" * V"block")^-1 * 
		V"END" + 
	V"FOR" * V"NAME" * V"EQUALS" * V"exp" * V"COMMA" * V"exp" * (V"COMMA" * V"exp")^-1 * 
		V"DO" * V"block" * V"END" +
	V"FOR" * V"namelist" * V"IN" * V"explist" * V"DO" * V"block" * V"END" + 
	V"FUNCTION" * V"funcname" * V"funcbody" + 
	V"LOCAL" * V"FUNCTION" * V"NAME" * V"funcbody" +
	V"LOCAL" * V"namelist" * (V"EQUALS" * V"explist")^-1,
	"stat"
)

laststat = Rule(
	V"RETURN" * V"explist"^-1 + 
	V"BREAK",
	"laststat"
)


local comment_neq
local function comment_starteq(s, i, t)
	comment_neq = t:len()
	return i
end
local function comment_endeq(s, i, t)
	return t:len() == comment_neq
end

comment_multiline_start = P"[" * Cmt(P"="^0, comment_starteq) * P"["
comment_multiline_end = P"]" * Cmt(P"="^0, comment_endeq) * P"]"
		
single_line_comment = Comment(P"--" * (1 - S"\n\r")^0, "single_line_comment")

multi_line_comment = Comment(
	P"--" * comment_multiline_start * 
	(1 - comment_multiline_end)^0 * 
	(comment_multiline_end + LexErr(P(-1), "comment missing closing multi-line token")), 
	
	"multi_line_comment"
)
]=====]

function get_specification()
	return specification
end