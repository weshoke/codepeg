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

local code = [==[
{
	"patcher" : 	{
		"fileversion" : 1,
		"rect" : [ 25.0, 69.0, 1153.0, 543.0 ],
		"bglocked" : 0,
		"defrect" : [ 25.0, 69.0, 1153.0, 543.0 ],
		"openrect" : [ 0.0, 0.0, 0.0, 0.0 ],
		"openinpresentation" : 0,
		"default_fontsize" : 12.0,
		"default_fontface" : 0,
		"default_fontname" : "Arial",
		"gridonopen" : 0,
		"gridsize" : [ 15.0, 15.0 ],
		"gridsnaponopen" : 0,
		"toolbarvisible" : 1,
		"boxanimatetime" : 200,
		"imprint" : 0,
		"enablehscroll" : 1,
		"enablevscroll" : 1,
		"devicewidth" : 0.0,
		"boxes" : [ 			{
				"box" : 				{
					"id" : "obj-22",
					"maxclass" : "jit.pwindow",
					"numinlets" : 1,
					"numoutlets" : 2,
					"outlettype" : [ "", "" ],
					"patching_rect" : [ 745.0, 171.0, 80.0, 60.0 ]
				}

			}
, 			{
				"box" : 				{
					"id" : "obj-23",
					"maxclass" : "jit.pwindow",
					"numinlets" : 1,
					"numoutlets" : 2,
					"outlettype" : [ "", "" ],
					"patching_rect" : [ 641.0, 171.0, 80.0, 60.0 ]
				}

			}
, 			{
				"box" : 				{
					"id" : "obj-24",
					"maxclass" : "jit.pwindow",
					"numinlets" : 1,
					"numoutlets" : 2,
					"outlettype" : [ "", "" ],
					"patching_rect" : [ 555.0, 171.0, 80.0, 60.0 ]
				}

			}
, 			{
				"box" : 				{
					"id" : "obj-25",
					"maxclass" : "jit.pwindow",
					"numinlets" : 1,
					"numoutlets" : 2,
					"outlettype" : [ "", "" ],
					"patching_rect" : [ 465.0, 171.0, 80.0, 60.0 ]
				}

			}
, 			{
				"box" : 				{
					"fontname" : "Arial",
					"fontsize" : 12.0,
					"id" : "obj-26",
					"maxclass" : "newobj",
					"numinlets" : 1,
					"numoutlets" : 2,
					"outlettype" : [ "jit_matrix", "" ],
					"patching_rect" : [ 658.0, 123.0, 432.0, 20.0 ],
					"text" : "jit.matrix 1 float32 4 4 1 @usesrcdim 1 @srcdimstart 0 0 3 @srcdimend 3 3 3"
				}

			}
, 			{
				"box" : 				{
					"fontname" : "Arial",
					"fontsize" : 12.0,
					"id" : "obj-27",
					"maxclass" : "newobj",
					"numinlets" : 1,
					"numoutlets" : 2,
					"outlettype" : [ "jit_matrix", "" ],
					"patching_rect" : [ 635.0, 95.0, 432.0, 20.0 ],
					"text" : "jit.matrix 1 float32 4 4 1 @usesrcdim 1 @srcdimstart 0 0 2 @srcdimend 3 3 2"
				}

			}
, 			{
				"box" : 				{
					"fontname" : "Arial",
					"fontsize" : 12.0,
					"id" : "obj-28",
					"maxclass" : "newobj",
					"numinlets" : 1,
					"numoutlets" : 2,
					"outlettype" : [ "jit_matrix", "" ],
					"patching_rect" : [ 620.0, 68.0, 432.0, 20.0 ],
					"text" : "jit.matrix 1 float32 4 4 1 @usesrcdim 1 @srcdimstart 0 0 1 @srcdimend 3 3 1"
				}

			}
, 			{
				"box" : 				{
					"fontname" : "Arial",
					"fontsize" : 12.0,
					"id" : "obj-29",
					"maxclass" : "newobj",
					"numinlets" : 1,
					"numoutlets" : 2,
					"outlettype" : [ "jit_matrix", "" ],
					"patching_rect" : [ 599.0, 42.0, 432.0, 20.0 ],
					"text" : "jit.matrix 1 float32 4 4 1 @usesrcdim 1 @srcdimstart 0 0 0 @srcdimend 3 3 0"
				}

			}
, 			{
				"box" : 				{
					"id" : "obj-21",
					"maxclass" : "button",
					"numinlets" : 1,
					"numoutlets" : 1,
					"outlettype" : [ "bang" ],
					"patching_rect" : [ 295.0, 27.0, 20.0, 20.0 ]
				}

			}
, 			{
				"box" : 				{
					"id" : "obj-19",
					"maxclass" : "jit.pwindow",
					"numinlets" : 1,
					"numoutlets" : 2,
					"outlettype" : [ "", "" ],
					"patching_rect" : [ 406.0, 375.0, 80.0, 60.0 ]
				}

			}
, 			{
				"box" : 				{
					"id" : "obj-18",
					"maxclass" : "jit.pwindow",
					"numinlets" : 1,
					"numoutlets" : 2,
					"outlettype" : [ "", "" ],
					"patching_rect" : [ 302.0, 375.0, 80.0, 60.0 ]
				}

			}
, 			{
				"box" : 				{
					"id" : "obj-17",
					"maxclass" : "jit.pwindow",
					"numinlets" : 1,
					"numoutlets" : 2,
					"outlettype" : [ "", "" ],
					"patching_rect" : [ 216.0, 375.0, 80.0, 60.0 ]
				}

			}
, 			{
				"box" : 				{
					"id" : "obj-16",
					"maxclass" : "jit.pwindow",
					"numinlets" : 1,
					"numoutlets" : 2,
					"outlettype" : [ "", "" ],
					"patching_rect" : [ 126.0, 375.0, 80.0, 60.0 ]
				}

			}
, 			{
				"box" : 				{
					"fontname" : "Arial",
					"fontsize" : 12.0,
					"id" : "obj-15",
					"maxclass" : "newobj",
					"numinlets" : 1,
					"numoutlets" : 2,
					"outlettype" : [ "jit_matrix", "" ],
					"patching_rect" : [ 319.0, 327.0, 432.0, 20.0 ],
					"text" : "jit.matrix 1 float32 4 4 1 @usesrcdim 1 @srcdimstart 0 0 3 @srcdimend 3 3 3"
				}

			}
, 			{
				"box" : 				{
					"fontname" : "Arial",
					"fontsize" : 12.0,
					"id" : "obj-14",
					"maxclass" : "newobj",
					"numinlets" : 1,
					"numoutlets" : 2,
					"outlettype" : [ "jit_matrix", "" ],
					"patching_rect" : [ 296.0, 299.0, 432.0, 20.0 ],
					"text" : "jit.matrix 1 float32 4 4 1 @usesrcdim 1 @srcdimstart 0 0 2 @srcdimend 3 3 2"
				}

			}
, 			{
				"box" : 				{
					"fontname" : "Arial",
					"fontsize" : 12.0,
					"id" : "obj-13",
					"maxclass" : "newobj",
					"numinlets" : 1,
					"numoutlets" : 2,
					"outlettype" : [ "jit_matrix", "" ],
					"patching_rect" : [ 281.0, 272.0, 432.0, 20.0 ],
					"text" : "jit.matrix 1 float32 4 4 1 @usesrcdim 1 @srcdimstart 0 0 1 @srcdimend 3 3 1"
				}

			}
, 			{
				"box" : 				{
					"fontname" : "Arial",
					"fontsize" : 12.0,
					"id" : "obj-12",
					"maxclass" : "newobj",
					"numinlets" : 1,
					"numoutlets" : 2,
					"outlettype" : [ "jit_matrix", "" ],
					"patching_rect" : [ 260.0, 246.0, 432.0, 20.0 ],
					"text" : "jit.matrix 1 float32 4 4 1 @usesrcdim 1 @srcdimstart 0 0 0 @srcdimend 3 3 0"
				}

			}
, 			{
				"box" : 				{
					"fontname" : "Arial",
					"fontsize" : 12.0,
					"id" : "obj-11",
					"maxclass" : "newobj",
					"numinlets" : 2,
					"numoutlets" : 2,
					"outlettype" : [ "jit_matrix", "" ],
					"patching_rect" : [ 295.0, 110.0, 132.0, 20.0 ],
					"text" : "jit.expr @expr norm[2]"
				}

			}
, 			{
				"box" : 				{
					"fontname" : "Arial",
					"fontsize" : 12.0,
					"id" : "obj-10",
					"maxclass" : "newobj",
					"numinlets" : 1,
					"numoutlets" : 2,
					"outlettype" : [ "jit_matrix", "" ],
					"patching_rect" : [ 295.0, 83.0, 138.0, 20.0 ],
					"text" : "jit.matrix 1 float32 4 4 4"
				}

			}
, 			{
				"box" : 				{
					"fontname" : "Arial",
					"fontsize" : 12.0,
					"id" : "obj-9",
					"maxclass" : "newobj",
					"numinlets" : 1,
					"numoutlets" : 2,
					"outlettype" : [ "jit_matrix", "" ],
					"patching_rect" : [ 295.0, 176.0, 43.0, 20.0 ],
					"text" : "jit.gen"
				}

			}
 ],
		"lines" : [ 			{
				"patchline" : 				{
					"destination" : [ "obj-11", 0 ],
					"hidden" : 0,
					"midpoints" : [  ],
					"source" : [ "obj-10", 0 ]
				}

			}
, 			{
				"patchline" : 				{
					"destination" : [ "obj-26", 0 ],
					"hidden" : 0,
					"midpoints" : [  ],
					"source" : [ "obj-11", 0 ]
				}

			}
, 			{
				"patchline" : 				{
					"destination" : [ "obj-27", 0 ],
					"hidden" : 0,
					"midpoints" : [  ],
					"source" : [ "obj-11", 0 ]
				}

			}
, 			{
				"patchline" : 				{
					"destination" : [ "obj-28", 0 ],
					"hidden" : 0,
					"midpoints" : [  ],
					"source" : [ "obj-11", 0 ]
				}

			}
, 			{
				"patchline" : 				{
					"destination" : [ "obj-29", 0 ],
					"hidden" : 0,
					"midpoints" : [  ],
					"source" : [ "obj-11", 0 ]
				}

			}
, 			{
				"patchline" : 				{
					"destination" : [ "obj-9", 0 ],
					"hidden" : 0,
					"midpoints" : [  ],
					"source" : [ "obj-11", 0 ]
				}

			}
, 			{
				"patchline" : 				{
					"destination" : [ "obj-16", 0 ],
					"hidden" : 0,
					"midpoints" : [  ],
					"source" : [ "obj-12", 0 ]
				}

			}
, 			{
				"patchline" : 				{
					"destination" : [ "obj-17", 0 ],
					"hidden" : 0,
					"midpoints" : [  ],
					"source" : [ "obj-13", 0 ]
				}

			}
, 			{
				"patchline" : 				{
					"destination" : [ "obj-18", 0 ],
					"hidden" : 0,
					"midpoints" : [  ],
					"source" : [ "obj-14", 0 ]
				}

			}
, 			{
				"patchline" : 				{
					"destination" : [ "obj-19", 0 ],
					"hidden" : 0,
					"midpoints" : [  ],
					"source" : [ "obj-15", 0 ]
				}

			}
, 			{
				"patchline" : 				{
					"destination" : [ "obj-10", 0 ],
					"hidden" : 0,
					"midpoints" : [  ],
					"source" : [ "obj-21", 0 ]
				}

			}
, 			{
				"patchline" : 				{
					"destination" : [ "obj-22", 0 ],
					"hidden" : 0,
					"midpoints" : [  ],
					"source" : [ "obj-26", 0 ]
				}

			}
, 			{
				"patchline" : 				{
					"destination" : [ "obj-23", 0 ],
					"hidden" : 0,
					"midpoints" : [  ],
					"source" : [ "obj-27", 0 ]
				}

			}
, 			{
				"patchline" : 				{
					"destination" : [ "obj-24", 0 ],
					"hidden" : 0,
					"midpoints" : [  ],
					"source" : [ "obj-28", 0 ]
				}

			}
, 			{
				"patchline" : 				{
					"destination" : [ "obj-25", 0 ],
					"hidden" : 0,
					"midpoints" : [  ],
					"source" : [ "obj-29", 0 ]
				}

			}
, 			{
				"patchline" : 				{
					"destination" : [ "obj-12", 0 ],
					"hidden" : 0,
					"midpoints" : [  ],
					"source" : [ "obj-9", 0 ]
				}

			}
, 			{
				"patchline" : 				{
					"destination" : [ "obj-13", 0 ],
					"hidden" : 0,
					"midpoints" : [  ],
					"source" : [ "obj-9", 0 ]
				}

			}
, 			{
				"patchline" : 				{
					"destination" : [ "obj-14", 0 ],
					"hidden" : 0,
					"midpoints" : [  ],
					"source" : [ "obj-9", 0 ]
				}

			}
, 			{
				"patchline" : 				{
					"destination" : [ "obj-15", 0 ],
					"hidden" : 0,
					"midpoints" : [  ],
					"source" : [ "obj-9", 0 ]
				}

			}
 ]
	}

}

]==]

local tokens = lexer:match(code)
print("#tokens:", #tokens)
local ok, AST = pcall(parser.match, parser, tokens)

local json_to_table

local
function trim_string(s)
	return s:sub(2, s:len()-1)
end

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
		elseif(v.token == "STRING") then
			return trim_string(v[1])
		else
			error("invalid value "..v.token)
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
			local k = trim_string(a[1])
			if(a.token == "STRING") then
				t[k] = json_value(AST[i+2])
				i = i+4
			else
				i = i+1
			end
		end
	elseif(AST.rule == "array") then
		for i=2, #AST-1, 2 do
			t[i/2] = json_value(AST[i])
		end
	end
	return t
end

--ast.print_tokens(tokens)
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
	--ast.print_nodes(AST)
	local data = json_to_table(AST)
	printt(data)
end
--]]