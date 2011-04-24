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
	trace = true,			-- print the rules visited by the parser
	--tracetokens = true,	-- print the tokens visited by the parser
	--tracematch = true,		-- print the matched tokens
}

-- error
local code = [[
	function x()
		x = y[10].
	end
]]

local code = [[
	x, y = 10, 20
]]

local code = [[
	t = {
		name = "fixed",
		idx = 10,
	}
]]

local code = [[
	t"argument"
]]

local code = [[
	if(x) then
		test()
	end
]]


local code = [==[
	local
	function zebra()
		return [[stripes]]
	end
]==]


local code = [==[
	function name(x, y, z)
		x
	end
]==]


local tokens = lexer:match(code)
local ok, AST = pcall(parser.match, parser, tokens)
if(not ok) then
	print("********************************")
	print("Rule Stack:")
	printt(parser:lastrulestack())
	
	print("********************************")
	print("Attempted Tokens List:")
	printt(parser:tokenlist())
	
	print("********************************")
	print("Last Matched Token:")
	printt(parser:lastoken())
else
	ast.print_nodes(AST)
end