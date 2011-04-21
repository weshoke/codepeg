if(LuaAV) then
	addmodulepath = LuaAV.addmodulepath
else
	---------------------------------------------------------------
	-- Bootstrapping functions required to coalesce paths
	local
	function exec(cmd, echo)
		echo = echo or true
		if(echo) then
			print(cmd)
			print("")
		end
		local res = io.popen(cmd):read("*a")
		return res:sub(1, res:len()-1)
	end
	
	local
	function stripfilename(filename)
		return string.match(filename, "(.+)/[^/]*%.%w+$")
	end
	
	local
	function strippath(filename)
		return string.match(filename, ".+/([^/]*%.%w+)$")
	end
	
	local
	function stripextension(filename)
		local idx = filename:match(".+()%.%w+$")
		if(idx) then
			return filename:sub(1, idx-1)
		else
			return filename
		end
	end
	
	function addmodulepath(path)
		-- add to package paths (if not already present)
		if not string.find(package.path, path, 0, true) then
			package.path = string.format("%s/?.lua;%s", path, package.path)
			package.path = string.format("%s/?/init.lua;%s", path, package.path)
			package.cpath = string.format("%s/?.so;%s", path, package.cpath)
		end
	end
	
	local
	function setup_path()
	
		local pwd = exec("pwd")
		local root = arg[0]
		if(root and stripfilename(root)) then 
			root = stripfilename(root) .. "/"
		else 
			root = "" 
		end
		
		local script_path
		local path
	
		if(root:sub(1, 1) == "/") then
			script_path = root
			path = string.format("%s%s", root, "modules")
		else
			script_path = string.format("%s/%s", pwd, root)
			path = string.format("%s/%s%s", pwd, root, "modules")
		end
		return script_path:sub(1, script_path:len()-1)
	end
	---------------------------------------------------------------
	-- Script Initialization
	script = {}
	script.path = setup_path()
end


---------------------------------------------------------------
-- Useful functions
local format = string.format

local function keysorter(a, b) 
	if type(a) == type(b) and (type(a) == "number" or type(a) == "string") then 
		return a<b 
	end
	return type(a) > type(b) 
end

local function table_tostring(tt, indent, done)
	done = done or {}
	indent = indent or 0
	if type(tt) == "table" then
		if done[tt] then
			return format("<memoized: %s>", tostring(tt))
		else
			--done[tt] = true
			
			-- sort keys:
			local keys = {}
			for k, v in pairs(tt) do table.insert(keys, k) end
			table.sort(keys, keysorter)
			
			local kt = {}
			for i, key in ipairs(keys) do	
				if type(key) == "string" then
					keystr = format("%s", tostring(key))
				else
					keystr = format("[%s]", tostring(key))
				end
				local value=tt[key]
				table.insert(kt, 
					format("%s%s = %s,\n", 
						string.rep(" ", indent+2), 
						keystr, 
						table_tostring(value, indent+2, done))
				)
			end
			return format("{\n%s%s}", table.concat(kt), string.rep(" ", indent))
		end
	else
		if type(tt) == "string" then
			return format("%q", tt)
		else
			return format("%s", tostring(tt))
		end
 	end
end
printt = function(t) print(table_tostring(t)) end


---------------------------------------------------------------
-- now the actual script
addmodulepath(script.path.."/..")

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
local Cp = listlpeg.Cp

local Lexer = require("codepeg.Lexer")
local Parser = require("codepeg.Parser")
local luaspec = require("codepeg.specification.lua")
local ast = require("codepeg.ast")

local lexer = Lexer{
	specification = luaspec:get_specification()
}

local parser = Parser{
	specification = luaspec:get_specification(),
	root = "block",
}

local code = [=====[

--[[
-- ignores local functions
local
function nodoc()
end
--]]

t1.meth.x = 1
--t1, t2 = function() end, 1
--t1, t2 = function() end, function() end
--t1, t2 = 1, function() end
--function t1() end


---[====[
-- var lists get detected
x, y = function() return random() end, 
	function(a, b) return a..b end


-- assignment gets detected
find_rule = function(ast, rule)
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


function counter()
	local v = 0
	
	return
	function()
		local v = v+1
		return v
	end
end

function code()
	return [==[
	[[something]]
	[===[other
	
	here]===]
	]==]
end

-- OO syntax sugar
function obj:method()
	return self.value
end

-- nested OO syntax sugar
function obj.subobj:method()
	return self.value
end
--]====]

]=====]



local no_collapse = {
	["function"] = true,
	funcname = true,
	var = true,
	varlist = true,
	explist = true,
}


-- lex / parse / simplify
local tokens = lexer:match(code)
local AST = parser:match(tokens)
AST = ast.remove_empty_rules(AST, no_collapse)
ast.print_nodes(AST)

-- patterns for grabbing global functions
--[[
example pattern:
	FUNCTION
      funcname
        NAME
      funcbody
        END
--]]
local gfsugar = Ct(ast.Lrule(
	"stat", 
	ast.Ptoken"FUNCTION" * 
	Ct(Cg(
		ast.Lrule(
			"funcname", 		
			C(
				ast.Ptoken"NAME" * ((ast.Ptoken"DOT" + ast.Ptoken"COLON") * ast.Ptoken"NAME")^0
			) / 
				-- extract values from token
				function(toks)
					if(toks.token) then
						return toks[1]
					else
						local name = ""
						for i, tok in ipairs(toks) do
							name = name..tok[1]
						end
						return name
					end
				end
		), 
		"name"
	) * Cg(C(ast.Prule"funcbody"), "body"))
))


local var = ast.Lrule(
	"var",
	
		Ct(C(ast.Ptoken"NAME") * 
		ast.Lrule(
			"index",
			C(ast.Ptoken"DOT") * C(ast.Ptoken"NAME")
		)^0)
	/ 
		function(toks)
			local name = ""
			for i, tok in ipairs(toks) do
				name = name..tok[1]
			end
			return name
		end
)

local f = ast.Lrule(
	"function",
	ast.Ptoken"FUNCTION" * 
	C(ast.Prule"funcbody")
)

--[[
-- example pattern:
	stat
      varlist
        var
          NAME
      EQUALS
      explist
        function
          FUNCTION
          funcbody
            END
--]]
local gflist = ast.Lrule(
	"stat", 
	(
		Ct(ast.Lrule(
			"varlist",
			var * (ast.Ptoken"COMMA" * var)^0
		)) * 
		ast.Ptoken"EQUALS" * 
		Ct(ast.Lrule(
			"explist",
			(f + P(1)*Cc(nil)) * (ast.Ptoken"COMMA" * (f + P(1)*Cc(nil)))^0
		))
	) / function(names, exps)
		local funcs = {}
		for idx, exp in pairs(exps) do
			local name = names[idx]
			funcs[#funcs+1] = {
				name = name,
				body = exp
			}
		end
		return funcs
	end
)

local gfpatt = gfsugar + gflist


-- get all of the global statements in the AST
local patt = ast.Crule"stat"
patt = Ct(ast.depthfirst(patt))
local stats = patt:match(AST)

local gfuncs = {}
for i, stat in ipairs(stats) do
	local gfs = gfpatt:match{stat}
	for i, gf in ipairs(gfs) do
		gfuncs[#gfuncs+1] = gf
	end
end


local HTML_template = [==[
<html>
<head>
<style type="text/css">
<!--
body {
	background: #ffffff;
	font-family: Arial, sans-serif;
	font-size: 12px;
	color: #000000;
}

pre {
	border: 1px dotted #666;
	padding: 8px;
}

span {
	font-family: 'Bitstream Vera Sans Mono','Courier', monospace;
/*	font-size: 115%%; */
}

span.comment 	{ color: #998;  font-style: italic; }
span.identifier { color: #000000; }
span.keyword 	{ color: #000000; font-weight: bold; }
span.function_name 	{ color: #900; font-weight: bold; }
span.library 	{ color: #0086B3; }
span.number 	{ color: #099; }
span.operator 	{ color: #000000; }
span.string  	{ color: #D14; }

-->
</style>
</head>
<body>
<pre>
%s
</pre>

%s
</body>
</html>
]==]


local library = {
	string = true, xpcall = true, package = true, tostring = true, print = true,
	os = true, unpack = true, require = true, getfenv = true, setmetatable = true,
	next = true, assert = true, tonumber = true, io = true, rawequal = true,
	collectgarbage = true, getmetatable = true, module = true, rawset = true,
	math = true, debug = true, pcall = true, table = true, newproxy = true, type = true,
	coroutine = true, _G = true, select = true, gcinfo = true, pairs = true, rawget = true,
	loadstring = true, ipairs = true, _VERSION = true, dofile = true, setfenv = true,
	load = true, error = true, loadfile = true,
}

function keyword(tok)
	return 
		tok.token ~= "NAME" and 
		tok[1]:match("^([%w_]+)$") ~= nil
end

function op(tok)
	return tok[1]:match("^([^%w_%d]+)$") ~= nil
end

function tokens_to_html(code, tokens)
	local html_code = code
	for i=#tokens, 1, -1 do
		local tok = tokens[i]
		local class
		
		if(tok.token == "NAME") then
			if(library[ tok[1] ]) then
				class = "library"
			else
				local ptok = tokens[i-1]
				if(ptok and ptok.token == "FUNCTION") then
					class = "function_name"
				else
					class = "identifier"
				end
			end
		elseif(tok.token == "NUMBER") then
			class = "number"
		elseif(tok.token == "STRING") then
			class = "string"
		elseif(tok.token == "COMMENT") then
			class = "comment"
		elseif(keyword(tok)) then
			class = "keyword"
		elseif(op(tok)) then
			class = "operator"
		end
		local html = string.format("<span class=%s>%s</span>", class, tok[1])
		html_code = html_code:sub(0, tok.start_idx-1)..html..html_code:sub(tok.end_idx)
	end
	return html_code
end


-- write to file
local function_code = "<br/><h2>Global Functions</h2> <ol>"
local prefix = "<span class=keyword>function</span> <span class=function_name>%s</span>"
--local gfuncs = get_global_functions(AST)
for i, gfunc in ipairs(gfuncs) do
	-- get the function body tokens
	local bodytokens = ast.ast_to_tokens(gfunc.body)
	-- get the code string until just after the function body
	local codelet = code:sub(0, bodytokens[#bodytokens].end_idx-1)
	-- apply HTML-ization
	local html_codelet = tokens_to_html(codelet, bodytokens):sub(bodytokens[1].start_idx)
	-- append to HTML list of global functions
	function_code = function_code..format([[
	<li><h4>%s:</h4><pre>
%s
	</pre></li>
	]], gfunc.name, format(prefix, gfunc.name)..html_codelet)
end
function_code = function_code.."</ol>"


local html_code = tokens_to_html(code, tokens)
local filename = "gfuncs.html"
local f = io.open(script.path.."/"..filename, "w")
f:write(format(HTML_template, html_code:gsub("\t", "   "), function_code:gsub("\t", "   ")))
f:close()