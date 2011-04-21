local ipairs = ipairs
local print = print
local assert = assert


module(...)


function remove_empty_rules(ast, no_collapse)
	no_collapse = no_collapse or {}
	
	for i, n in ipairs(ast) do
		while(
			ast[i].rule and 
			#ast[i] <= 1 and
			not no_collapse[ast[i].rule]
		) do
			local v = ast[i][1]
			if(not v) then
				break
			end
			ast[i] = v
		end
		if(n.rule) then		
			remove_empty_rules(n, no_collapse)
		end
	end
	return ast
end


function find_rule(ast, rule)
	if(ast.rule == rule) then
		return ast
	end

	for i, n in ipairs(ast) do
		if(n.rule == rule) then
			return n
		elseif(n.rule) then
			local r = find_rule(n, rule)
			if(r) then
				return r
			end
		end
	end
end

function find_all_rules(ast, rule, rules)
	rules = rules or {}
	if(ast.token) then
		return rules
	end
	
	if(ast.rule == rule) then
		rules[#rules+1] = ast
	end

	for i, n in ipairs(ast) do
		if(n.rule == rule) then
			find_all_rules(n, rule, rules)
		elseif(n.rule) then
			find_all_rules(n, rule, rules)
		end
	end
	
	return rules
end

function find_all_tokens(ast, token, tokens)
	tokens = tokens or {}
	if(ast.token) then
		if(ast.token == token) then
			tokens[#tokens+1] = ast
		end
		return tokens
	end

	for i, n in ipairs(ast) do
		if(n.rule) then
			find_all_tokens(n, token, tokens)
		elseif(n.token == token) then
			tokens[#tokens+1] = n
		end
	end
	
	return tokens
end

function ast_to_tokens(ast, tokens)
	tokens = tokens or {}
	for i, n in ipairs(ast) do
		if(n.token) then
			tokens[#tokens+1] = n
		else
			ast_to_tokens(n, tokens)
		end
	end
	return tokens
end