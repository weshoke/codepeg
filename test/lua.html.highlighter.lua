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
local luaspec = require("codepeg.specification.lua")

local lexer = Lexer{
	specification = luaspec:get_specification()
}

local code = io.open(script.path.."/testfile.lua"):read("*a")
local tokens = lexer:match(code)
--printt(tokens)

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
local html_code = tokens_to_html(code, tokens)
local filename = "test.html"
local f = io.open(script.path.."/"..filename, "w")
f:write(format(HTML_template, html_code:gsub("\t", "   ")))
f:close()