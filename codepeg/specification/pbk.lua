module(...)

local specification = [=====[

--[[

int, int2, int3, int4
float, float2, float3, float4
float2x2, float3x3, float4x4
bool, bool2, bool3, bool4
strin
--]]

local keywords = {
	"void",
	"attribute", "const", "uniform", "varying",
	"break", "continue", "do", "for", "while",
	"if", "else",
	"void",	"true", "false",
	"return",
	
	"string",
	"bool", "bool2", "bool3", "bool4",
	"int", "int2", "int3", "int4",
	"float", "float2", "float3", "float4",
	"float2x2", "float3x3", "float4x4",
	"pixel1", "pixel2", "pixel3", "pixel4", 
	"image1", "image2", "image3", "image4", 
	"region",
	
	"kernel", "languageVersion", "parameter", 
	"dependent", "input", "output",
}

local identifier_ignore = {}

local operators = {
	left_op = "<<",
	right_op = ">>",
	inc_op = "++",
	dec_op = "--",
	le_op = "<=",
	ge_op = ">=",
	eq_op = "==",
	ne_op = "!=",
	and_op = "&&",
	or_op = "||",
	xor_op = "^^",
	mul_assign = "*=",
	div_assign = "/=",
	add_assign = "+=",
	mod_assign = "%=",
	left_assign = "<<=",
	right_assign = ">>=",
	and_assign = "&=",
	xor_assign = "^=",
	or_assign = "|=",
	sub_assign = "-=",

	left_paren = "(",
	right_paren = ")",
	left_bracket = "[",
	right_bracket = "]",
	left_brace = "{",
	right_brace = "}",
	dot = ".",
	comma = ",",
	colon = ":",
	equal = "=",
	semicolon = ";",
	bang = "!",
	dash = "-",
	tilde = "~",
	plus = "+",
	star = "*",
	slash = "/",
	percent = "%",
	left_angle = "<",
	right_angle = ">",
	vertical_bar = "|",
	caret = "^",
	ampersand = "&",
	question = "?",
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


-- constants
decimal_constant = nonzero_digit * (nonzero_digit + digit)^0
octal_constant = P"0" * (
			octal_digit +
			LexErr(decimal_constant+nondigit, "invalid octal constant")
		)^0
hexadecimal_constant = (P"0x" + P"0X") * 
						(
							hexadecimal_digit +
							LexErr(nondigit, "invalid hexadecimal constant")
						)^1

INTCONSTANT = Token(
					hexadecimal_constant + octal_constant + decimal_constant , 
					"INTCONSTANT",
					MAX_PRIORITY-1
				)

-- float annotations
digit_sequence = digit^1
exponent_part = ((S"eE" * P"-")^-1 + S"eE"^-1) * digit_sequence
sign = S"-+"
floating_suffix = S"fF"

fractional_constant =	digit_sequence * P"." * digit_sequence^-1 + 
						P"." * digit_sequence

FLOATCONSTANT = Token(
					(
						fractional_constant * exponent_part^-1 + 
						digit_sequence * exponent_part
					) * 
					floating_suffix^-1,
					
					"FLOATCONSTANT",
					MAX_PRIORITY
				)


endline = S"\n\r"
STRINGCONSTANT = Token(
	P[["]] * (P[[\"]]+(1 - (endline + P[["]])))^0 * (P[["]] + LexErr(P(1), [[string missing closing "]])),
	"STRINGCONSTANT",
	MAX_PRIORITY
)
			

IDENTIFIER = Token(
	Cmt(
		C(nondigit * (nondigit + digit)^0), 
		function(s, i, a)
			return not keyword_map[a]
		end), 
	"IDENTIFIER",
	MAX_PRIORITY
)

tokens = {IDENTIFIER = true, INTCONSTANT = true, FLOATCONSTANT = true}
for i, kw in ipairs(keywords) do
	tokens[kw:upper()] = true
end

for name, op in pairs(operators) do
	tokens[name:upper()] = true
end

--	variable_identifier: 
--		IDENTIFIER 
variable_identifier = Rule(V"IDENTIFIER", "variable_identifier")


--	primary_expression: 
--		variable_identifier 
--		INTCONSTANT 
--		FLOATCONSTANT 
--		LEFT_PAREN expression RIGHT_PAREN 
primary_expression = Rule(
					V"variable_identifier" + 
					V"FLOATCONSTANT" +
					V"INTCONSTANT" +
					V"TRUE" + V"FALSE" + 
					V"LEFT_PAREN" * V"function_arguments"^-1 * V"RIGHT_PAREN"
					,
					
					"primary_expression"
				)

local function_constructor = 
			V"BOOL" + V"BOOL2" + V"BOOL3" + V"BOOL4" +
			V"INT" + V"INT2" + V"INT3" + V"INT4" +
			V"FLOAT" + V"FLOAT2" + V"FLOAT3" + V"FLOAT4" +
			V"FLOAT2X2" + V"FLOAT3X3" + V"FLOAT4X4" + 
			V"PIXEL1" + V"PIXEL2" + V"PIXEL3" + V"PIXEL4" + 
			V"REGION"

--	postfix_expression: 
--		primary_expression 
--		postfix_expression LEFT_BRACKET integer_expression RIGHT_BRACKET 
--		function_call 
--		postfix_expression DOT FIELD_SELECTION 
--		postfix_expression INC_OP 
--		postfix_expression DEC_OP
postfix_expression = Rule(
						V"primary_expression" * (
							V"LEFT_BRACKET" * V"integer_expression" * V"RIGHT_BRACKET" +
							V"function_call" +
							V"DOT"  * V"IDENTIFIER" +						
							V"INC_OP" + 
							V"DEC_OP"
						)^0 +
						function_constructor * V"function_call",
						
						"postfix_expression"
					)
					
					
--	integer_expression: 
--		expression 
integer_expression = --Rule(V"expression", "integer_expression")
		Rule(V"INTCONSTANT", "integer_expression")

--	function_call: 
--		function_call_or_method 
function_call = Rule(
				V"LEFT_PAREN" *
				V"function_arguments"^-1 *
				V"RIGHT_PAREN",
				
				"function_call"
			)

--	function_arguments: 
--		function_call_header VOID 
--		function_call_header
function_arguments = Rule(
					V"VOID" + 
					V"conditional_expression" * (V"COMMA" * V"conditional_expression")^0,
					
					"function_arguments"
				)

--	unary_expression: 
--		postfix_expression 
--		INC_OP unary_expression 
--		DEC_OP unary_expression 
--		unary_operator unary_expression 
unary_expression = Rule(
				V"postfix_expression" + 
				V"INC_OP" * V"unary_expression" + 
				V"DEC_OP" * V"unary_expression" + 
				V"unary_operator" * V"unary_expression",
				
				"unary_expression"
			)

--	unary_operator: 
--		PLUS 
--		DASH 
--		BANG 
--		TILDE // reserved
unary_operator = Rule(V"PLUS" + V"DASH" + V"BANG", "unary_operator")

--	multiplicative_expression: 
--		unary_expression 
--		multiplicative_expression STAR unary_expression 
--		multiplicative_expression SLASH unary_expression 
--		multiplicative_expression PERCENT unary_expression   // reserved 
multiplicative_expression = Rule(
								V"unary_expression" * (
									V"STAR" * V"unary_expression" + 
									V"SLASH" * V"unary_expression"
								)^0,
								
								"multiplicative_expression"
							)

--	additive_expression: 
--		multiplicative_expression 
--		additive_expression PLUS multiplicative_expression 
--		additive_expression DASH multiplicative_expression			
additive_expression = Rule(
							V"multiplicative_expression" * (
								V"PLUS" * V"multiplicative_expression" +
								V"DASH" * V"multiplicative_expression"
							)^0,
							
							"additive_expression"
						)

-- shift_expression: 
--		additive_expression 
--		shift_expression LEFT_OP additive_expression   // reserved 
--		shift_expression RIGHT_OP additive_expression   // reserved 
shift_expression = Rule(V"additive_expression", "shift_expression")

--	relational_expression: 
--		shift_expression 
--		relational_expression LEFT_ANGLE shift_expression 
--		relational_expression RIGHT_ANGLE shift_expression 
--		relational_expression LE_OP shift_expression 
--		relational_expression GE_OP shift_expression
relational_expression = Rule(
							V"shift_expression" * (
								V"LEFT_ANGLE" * V"shift_expression" +
								V"RIGHT_ANGLE" * V"shift_expression" +
								V"LE_OP" * V"shift_expression" +
								V"GE_OP" * V"shift_expression"
							)^0,
							
							"relational_expression"
						)

--	equality_expression: 
--		relational_expression 
--		equality_expression EQ_OP relational_expression 
--		equality_expression NE_OP relational_expression
equality_expression =  Rule(
							V"relational_expression" * (
								V"EQ_OP" * V"relational_expression" +
								V"NE_OP" * V"relational_expression"
							)^0,
							
							"equality_expression"
						)

--	and_expression: 
--		equality_expression 
--		and_expression AMPERSAND equality_expression   // reserved 
and_expression =  Rule(V"equality_expression", "and_expression")

--	exclusive_or_expression: 
--		and_expression 
--		exclusive_or_expression CARET and_expression   // reserved 
exclusive_or_expression =  Rule(V"and_expression", "exclusive_or_expression")

--	inclusive_or_expression: 
--		exclusive_or_expression 
--		inclusive_or_expression VERTICAL_BAR exclusive_or_expression   // reserved 
inclusive_or_expression = Rule(V"exclusive_or_expression", "inclusive_or_expression")

--	logical_and_expression: 
--		inclusive_or_expression 
--		logical_and_expression AND_OP inclusive_or_expression 
logical_and_expression = Rule(
							V"inclusive_or_expression" * (
								V"AND_OP" * V"inclusive_or_expression"
							)^0,
							
							"logical_and_expression"
						)

--	logical_xor_expression: 
--		logical_and_expression 
--		logical_xor_expression XOR_OP logical_and_expression 
logical_xor_expression = Rule(
							V"logical_and_expression" * (
								V"XOR_OP" * V"logical_and_expression"
							)^0,
							
							"logical_xor_expression"
						)

--	logical_or_expression: 
--		logical_xor_expression 
--		logical_or_expression OR_OP logical_xor_expression 
logical_or_expression = Rule(
							V"logical_xor_expression" * (
								V"OR_OP" * V"logical_xor_expression"
							)^0,
							
							"logical_or_expression"
						)

--	conditional_expression: 
--		logical_or_expression 
--		logical_or_expression QUESTION expression COLON assignment_expression 
conditional_expression = Rule(
							V"logical_or_expression" * (
								V"QUESTION" * V"expression" * V"COLON" * V"assignment_expression"
							)^0,
						
							"conditional_expression"
						)

--	assignment_expression: 
--		conditional_expression 
--		unary_expression assignment_operator assignment_expression 
assignment_expression = Rule(
			V"postfix_expression" * V"assignment_operator" * V"assignment_expression" + 
			V"conditional_expression",
			
			"assignment_expression"
		)
			

--	assignment_operator: 
--		EQUAL 
--		MUL_ASSIGN
--		DIV_ASSIGN 
--		MOD_ASSIGN   // reserved 
--		ADD_ASSIGN 
--		SUB_ASSIGN 
--		LEFT_ASSIGN   // reserved 
--		RIGHT_ASSIGN   // reserved 
--		AND_ASSIGN   // reserved 
--		XOR_ASSIGN   // reserved 
--		OR_ASSIGN   // reserved
assignment_operator = Rule(
			V"EQUAL" + V"MUL_ASSIGN" + V"DIV_ASSIGN" + V"ADD_ASSIGN" + V"SUB_ASSIGN",
			"assignment_operator"
		)

--	expression: 
--		assignment_expression 
--		expression COMMA assignment_expression 
expression = Rule(
				V"assignment_expression" * (
					V"COMMA" * V"assignment_expression"
				)^0,
				
				"expression"
			)

--	constant_expression: 
--		conditional_expression 
constant_expression = Rule(
						V"conditional_expression",
						"constant_expression"
					)

--	declaration: 
--		function_prototype SEMICOLON 
--		init_declarator_list SEMICOLON
declaration = Rule(
				V"function_prototype" +
				V"single_declaration", -- +  
				--V"init_declarator_list",
				
				"declaration"
			)


--	function_prototype: 
--		function_declarator RIGHT_PAREN 
function_prototype = Rule(
						V"fully_specified_type" * 
						V"IDENTIFIER" * 
						V"LEFT_PAREN" * 
						V"function_parameter_list"^-1 *
						V"RIGHT_PAREN",
			
						"function_prototype"
					)
					
function_parameter_list = Rule(
						V"parameter_declaration" * (V"COMMA" * V"parameter_declaration")^0,
					
						"function_parameter_list"
					)
					
function_parameter = Rule(
						V"VOID" + 
						V"parameter_declaration",
						
						"function_parameter"
					)

--	parameter_declaration:
--		type_qualifier parameter_qualifier parameter_declarator 
--		parameter_qualifier parameter_declarator 
--		type_qualifier parameter_qualifier parameter_type_specifier 
--		parameter_qualifier parameter_type_specifier
parameter_declaration = Rule(
						V"fully_specified_type" * V"IDENTIFIER" * (
							V"LEFT_BRACKET" * V"constant_expression" * V"RIGHT_BRACKET"
						)^-1,
						
						"parameter_declaration"
					)

--	parameter_type_specifier: 
--		type_specifier 
parameter_type_specifier = Rule(V"type_specifier", "parameter_type_specifier")

--	init_declarator_list: 
--		single_declaration 
init_declarator_list = Rule(
							V"fully_specified_type" * V"IDENTIFIER" * (V"COMMA" * V"IDENTIFIER")^0,
							"init_declarator_list"
						)

--	single_declaration: 
--		fully_specified_type 
--		fully_specified_type IDENTIFIER 
--		fully_specified_type IDENTIFIER EQUAL initializer 
single_declaration = Rule(
						V"fully_specified_type" * V"IDENTIFIER" *
							(
								V"COMMA" * V"IDENTIFIER" * (V"COMMA" * V"IDENTIFIER")^0 +
								(V"EQUAL" * V"initializer")^-1
							)
						,
						
						"single_declaration"
					)

--	fully_specified_type:
--		type_specifier 
--		type_qualifier type_specifier
fully_specified_type = Rule(
					V"type_qualifier"^-1 * V"type_specifier",

					"fully_specified_type"
				)

--	type_qualifier: 
--		CONST 
--		ATTRIBUTE   // Vertex only. 
--		VARYING 
--		UNIFORM 
type_qualifier = Rule(V"CONST" + V"ATTRIBUTE" + V"VARYING" + V"UNIFORM", "type_qualifier")


--	type_specifier: 
--		type_specifier_nonarray 
type_specifier = Rule(
					V"type_specifier_nonarray",
					
					"type_specifier"
				)

--	type_specifier_nonarray: 
--		VOID 
--		FLOAT 
--		VEC2 
--		VEC3 
--		VEC4 
--		MAT2 
--		MAT3 
--		MAT4 
--		SAMPLER2D 
--		SAMPLER2DRECT 
--		TYPE_NAME
type_specifier_nonarray = Rule(
						V"VOID" + 						
						V"BOOL" + V"BOOL2" + V"BOOL3" + "BOOL4" +
						V"INT" + V"INT2" + V"INT3" + "INT4" +
						V"FLOAT" + V"FLOAT2" + V"FLOAT3" + "FLOAT4" +
						V"FLOAT2X2" + V"FLOAT3X3" + V"FLOAT4X4" +
						V"PIXEL1" + V"PIXEL2" + V"PIXEL3" + V"PIXEL4" +
						V"REGION",
						
						"type_specifier_nonarray"
					)

--	initializer: 
--		assignment_expression 
initializer = Rule(V"assignment_expression", "initializer")

--	declaration_statement: 
--		declaration 
declaration_statement = Rule(V"declaration" * V"SEMICOLON", "declaration_statement")

--	statement: 
--		compound_statement 
--		simple_statement 
--		// Grammar Note:  No labeled statements; 'goto' is not supported. 
statement = Rule(V"compound_statement" + V"simple_statement", "statement")

--	simple_statement: 
--		declaration_statement 
--		expression_statement 
--		selection_statement 
--		iteration_statement 
--		jump_statement 
simple_statement = Rule(
						V"declaration_statement" + V"expression_statement" + 
						V"selection_statement" + V"iteration_statement" + 
						V"jump_statement",
						
						"simple_statement"
					)

--	compound_statement: 
--		LEFT_BRACE RIGHT_BRACE 
--		LEFT_BRACE statement_list RIGHT_BRACE 
compound_statement = Rule(
						V"LEFT_BRACE" * V"RIGHT_BRACE" + 
						V"LEFT_BRACE" * V"statement_list" * V"RIGHT_BRACE",
																	
						"compound_statement"
					)

--	statement_list: 
--		statement 
--		statement_list statement 	
statement_list = Rule(V"statement"^1, "statement_list")

--	expression_statement: 
--		SEMICOLON 
--		expression SEMICOLON 
expression_statement = Rule(
							V"SEMICOLON" +
							V"expression" * V"SEMICOLON",
												
							"expression_statement"
						)

--	selection_statement: 
--		IF LEFT_PAREN expression RIGHT_PAREN selection_rest_statement 		
selection_statement = Rule(
							V"IF" * V"LEFT_PAREN" * V"expression" * 
							V"RIGHT_PAREN" * 
							V"selection_rest_statement",
							
							"selection_statement"
						)

--	selection_rest_statement: 
--		statement ELSE statement 
--		statement 
--		// Grammar Note:  No 'switch'.  Switch statements not supported. 
selection_rest_statement = Rule(
								V"statement" * (V"ELSE" * V"statement")^-1,
								"selection_rest_statement"
							)

--	condition: 
--		expression 
--		fully_specified_type IDENTIFIER EQUAL initializer 		
condition = Rule(
				V"expression" + 
				V"fully_specified_type" * V"IDENTIFIER" * V"EQUAL" * 
						V"initializer",
						
				"condition"
			)

--	iteration_statement: 
--		WHILE LEFT_PAREN condition RIGHT_PAREN statement_no_new_scope 
--		DO statement WHILE LEFT_PAREN expression RIGHT_PAREN SEMICOLON 
--		FOR LEFT_PAREN for_init_statement for_rest_statement RIGHT_PAREN statement_no_new_scope 
iteration_statement = Rule(
					V"WHILE" *  V"LEFT_PAREN" * V"condition" * 
								V"RIGHT_PAREN" * 
								V"statement" +
					V"DO" * V"statement" * V"WHILE" * V"LEFT_PAREN" * 
								V"expression" * 
								V"RIGHT_PAREN" * 
								V"SEMICOLON" +
					V"FOR" * V"LEFT_PAREN" * V"for_init_statement" * 
								V"for_rest_statement" * 
								V"RIGHT_PAREN" *
								V"statement"
					,
							
					"iteration_statement"
				)

--	for_init_statement: 
--		expression_statement 
--		declaration_statement 
for_init_statement = Rule(
						V"declaration_statement" + V"expression_statement",
						"for_init_statement"
					)

--	conditionopt: 
--		condition 
--		/* empty */ 
conditionopt = Rule(V"condition" + P(-1), "conditionopt")

--	for_rest_statement: 
--		conditionopt SEMICOLON 
--		conditionopt SEMICOLON expression 
for_rest_statement = Rule(
						V"conditionopt" * V"SEMICOLON" * V"expression"^-1,
						"for_rest_statement"
					)

--	jump_statement: 
--		CONTINUE SEMICOLON 
--		BREAK SEMICOLON 
--		RETURN SEMICOLON 
--		RETURN expression SEMICOLON 
--		DISCARD SEMICOLON   // Fragment shader only. 
--		// Grammar Note:  No 'goto'.  Gotos are not supported. 
jump_statement = Rule(
					(
						V"CONTINUE" +
						V"BREAK" +
						V"RETURN" * V"expression" +
						V"RETURN"
					) * V"SEMICOLON",
					
					"jump_statement"
				)


--	translation_unit: 
--		external_declaration 
--		translation_unit external_declaration 
translation_unit = Rule((V"kernel_declaration" + V"function_definition")^1, "translation_unit")

--	function_definition: 
--		function_prototype compound_statement_no_new_scope 
function_definition = Rule(
						V"function_prototype" * 
						V"compound_statement",
						
						"function_definition"
					)

value = Rule(
	function_constructor * V"function_call" + 
		V"STRINGCONSTANT" + V"DASH" * (V"FLOATCONSTANT" + V"INTCONSTANT") +
		V"FLOATCONSTANT" + V"INTCONSTANT" + 
		V"TRUE" + V"FALSE",
	"value"
)

name_value = Rule(
	V"IDENTIFIER" * V"COLON" * V"value" * V"SEMICOLON",
	"name_value"
)

metadata = Rule(
	V"LEFT_ANGLE" * V"name_value"^0 * V"RIGHT_ANGLE",
	"metadata"
)

kernel_metadata = Rule(
	V"KERNEL" * V"IDENTIFIER" * V"metadata",
	"kernel_metadata"
)

language_version_statement = Rule(
	V"LEFT_ANGLE" * V"LANGUAGEVERSION" * V"COLON" * V"value" * V"SEMICOLON" * V"RIGHT_ANGLE",
	"language_version_statement"
)

parameter = Rule(
	V"PARAMETER" * V"type_specifier_nonarray" * V"IDENTIFIER" * 
		V"metadata"^-1,
	"parameter"
)

dependent = Rule(
	V"DEPENDENT" * V"type_specifier_nonarray" * V"IDENTIFIER" * (V"COMMA" * V"IDENTIFIER")^0,
	"dependent"
)

input = Rule(
	V"INPUT" * (V"IMAGE1" + V"IMAGE2" + V"IMAGE3" + V"IMAGE4") * V"IDENTIFIER",
	"input"
)

output = Rule(
	V"OUTPUT" * (V"PIXEL1" + V"PIXEL2" + V"PIXEL3" + V"PIXEL4") * V"IDENTIFIER",
	"output"
)

kernel_declaration = Rule(
	(V"dependent" + V"parameter" + V"input" + V"output") * V"SEMICOLON",
	"kernel_declaration"
)

pbk = Rule(
	V"language_version_statement" * 
	V"kernel_metadata" * 
	V"LEFT_BRACE" * 
	V"translation_unit" *
	V"RIGHT_BRACE",
	"pbk"
)
					
single_line_comment = Comment(P"//"*(1 - S"\n\r")^0, "single_line_comment")
multi_line_comment = Comment(P"/*"*(1 - P"*/")^0*P"*/", "multi_line_comment")
]=====]

function get_specification()
	return specification
end