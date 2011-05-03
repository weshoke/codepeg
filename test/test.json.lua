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

local ast = require("codepeg.ast")
local Lexer = require("codepeg.Lexer")
local Parser = require("codepeg.Parser")
local pbkspec = require("codepeg.specification.json")

local lexer = Lexer{
	specification = pbkspec:get_specification()
}
local parser = Parser{
	specification = pbkspec:get_specification(),
	root = "object",
--	root = "expression",
--	trace = true,
--	tracematch = true,
--	tracetokens = true,
}

local code = [=[
{
	"donkey" : [ 1, 2, 3, 4, "SDFSDF"],
	"horse" : {
		"hoof" : true,
		"brain" : 4
	}
}
]=]

local tokens = lexer:match(code)
print("#tokens:", #tokens)
local ok, AST = pcall(parser.match, parser, tokens)

local json_to_table

local
function json_value(v)
	if(v.token) then
		if(v.token == "TRUE") then
			return true
		elseif(v.token == "FALSE") then
			return false
		elseif(v.token == "NULL") then
			return nil
		elseif(v.token == "NUMBER") then
			return tonumber(v[1])
		else
			return v[1]
		end
	else
		return json_to_table(v)
	end
end

function json_to_table(AST)
	local t = {}
	if(AST.rule == "object") then
		local i=1
		while(i <= #AST) do
			local a = AST[i]
			local k = a[1]
			if(a.token == "STRING") then
				t[k] = json_value(AST[i+2])
				i = i+4
			else
				i = i+1
			end
		end
	elseif(AST.rule == "array") then
		for i=2, #AST, 2 do
			t[i/2] = json_value(AST[i])
		end
	end
	return t
end

ast.print_tokens(tokens)
---[[
if(not ok) then
	print("*****************")
	print("ERROR:")
	printt(parser:lastrulestack())
	printt(parser:lasttoken())
else
	print("SUCCESS")
	--printt(AST)
	AST = ast.remove_empty_rules(AST)
	ast.print_nodes(AST)
	local data = json_to_table(AST)
	printt(data)
end
--]]