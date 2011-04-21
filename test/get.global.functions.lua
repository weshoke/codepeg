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

-- ignores local functions
local
function nodoc()
end

function test(x)
	return x^x
end

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

]=====]


local tokens = lexer:match(code)
--printt(tokens)

local no_collapse = {
	["function"] = true,
	funcname = true,
	var = true,
	varlist = true,
	explist = true,
}
local AST = parser:match(tokens)
AST = ast.remove_empty_rules(AST, no_collapse)


------------------------------
--- AST scenarios for global functions
-- block
-- [chunk]
--   stat
--     varlist
--       NAME, NAME
--   EQUALS
--   explist
--     function
--       funcbody
--     COMMA
--     function
--       funcbody

-- block
-- [chunk]
--   stat
--     NAME
--   EQUALS
--   function
--     FUNCTION
--     funcbody

-- block
-- [chunk]
--   stat
--     FUNCTION
--     NAME
--     funcbody
function get_global_functions(AST)
	local stats = ast.find_all_rules(AST, "stat")
	local global_functions = {}
	for i, stat in ipairs(stats) do
		local varlist = ast.find_rule(stat, "varlist")
		if(varlist) then
			-- get the list of varnames and expression
			local explist = ast.find_rule(stat, "explist")
			local vars = ast.find_all_rules(varlist, "var")
			local exps = {}
			for i=1, #explist, 2 do
				exps[#exps+1] = explist[i]
			end
			
			local names = {}
			for i, var in ipairs(vars) do
				local toks = ast.ast_to_tokens(var)
				local name = ""
				for _, tok in ipairs(toks) do
					name = name..tok[1]
				end
				names[#names+1] = name
			end
			
			for i, exp in ipairs(exps) do
				if(exp.rule == "function") then
					local name = names[i]
					if(name) then
						global_functions[#global_functions+1] = {
							name = name,
							body = exp[2]
						}
					end
				end
			end
		elseif(stat[1].token == "FUNCTION") then
			-- get the function definition (syntax sugar version)
			local fname = stat[2]
			local nametoks = ast.ast_to_tokens(fname)
			local name = ""
			for i, tok in ipairs(nametoks) do
				name = name..tok[1]
			end
			printt(stat)
			global_functions[#global_functions+1] = {
				name = name,
				body = stat[3],
			}
		end
	end
	return global_functions
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
local gfuncs = get_global_functions(AST)
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