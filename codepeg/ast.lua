local pairs = pairs
local ipairs = ipairs
local print = print
local assert = assert
local tostring = tostring
local format = string.format

local listlpeg = require("listlpeg")
local P = listlpeg.P
local R = listlpeg.R
local S = listlpeg.S
local L = listlpeg.L
local V = listlpeg.V
local C = listlpeg.C
local Cmt = listlpeg.Cmt
local Ct = listlpeg.Ct
local Cg = listlpeg.Cg
local Cc = listlpeg.Cc

local string = string


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

function print_nodes(ast, lvl)
	lvl = lvl or 0
	print(string.rep("  ", lvl)..(ast.rule or ast.token or "<nothing>"))
	if(not ast.token) then
		for i, n in ipairs(ast) do
			print_nodes(n, lvl+1)
		end
	end
end

local tablen = 4
function print_tokens(tokens)
	for i, tok in ipairs(tokens) do
		local tlen = tok.token:len()
		local n = tostring(i)
		local spcs = n:len()
		local str = format("%s%s%s %s %s", 
			n, string.rep(" ", 6 - spcs),
			tok.token, 
			string.rep(".", 16-tlen),
			tok[1]
		)
		print(str)
	end
end


function depthfirst(patt)
	return P{
		[1] = "depth_first",
		patt = patt,
		-- (the pattern) + (the pattern down one level in the list) + (look in the next element)
		depth_first = (V"patt" + L(V"depth_first") + P(1))^0
	}
end

function Crule(name)
	return Cmt(C(1), function(s, i, t)
		return t.rule == name, t
	end)
end

function Prule(name)
	return Cmt(C(1), function(s, i, t)
		--print("Prule", t.rule, name)
		if(name) then
			return t.rule == name
		else
			return true
		end
	end)
end

function Lrule(name, patt)
	return Cmt(C(L(patt)), function(s, i, t, ...)
		--print("Lrule", t.rule, name)
		return t.rule == name, ...
	end)
end

function Ctoken(name)
	return Cmt(C(1), function(s, i, t)
		return t.token == name, t
	end)
end

function Ptoken(name)
	return Cmt(C(1), function(s, i, t)
		--print("Ptoken", i, t.token, name)
		if(name) then
			return t.token == name
		else
			return true
		end
	end)
end