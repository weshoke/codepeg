-- lexer.lua
local setmetatable = setmetatable
local getfenv = getfenv
local assert = assert
local loadstring = loadstring
local setfenv = setfenv
local pairs = pairs
local ipairs = ipairs
local print = print
local error = error
local type = type

local table = table
local format = string.format

local listlpeg = require("listlpeg")


module(...)

-- no-op
local
function Rule()
end

local space = listlpeg.S('\r\n\f\t ')

local
function Ignore(patt)
	return #patt/function()end
end

local
function optbool(v, def)
	if(type(v) == "nil") then
		return def
	else
		return v
	end
end


local C = {}
local M = setmetatable(getfenv(), C)
M.__index = M


function C:__call(init)
	assert(init.specification)
	
	local m = setmetatable(init, M)
	m.line_numbers = optbool(init.line_numbers, false)
	m:load_specification()
	return m
end

function M:load_specification()
	local MAX_PRIORITY = 10000000
	local tokens = {}
	local token_priority = {}
	local Token = function (patt, name, priority)
		priority = priority or 0
		token_priority[name] = priority
		local tok = listlpeg.Ct(
			
			listlpeg.Cg(
				listlpeg.Cp(),
				"start_idx"
			) *
			listlpeg.C(patt) * 
			listlpeg.Cg(
				listlpeg.Cc(name), 
				"token"
			) *
			listlpeg.Cg(
				listlpeg.Cp(),
				"end_idx"
			)
		)

		tokens[name] = tok
		return tok
	end
	
	local comments = {}
	local Comment = function(patt, name)
		local cmt = listlpeg.Cmt(
			listlpeg.Ct(listlpeg.Cg(
				listlpeg.Cp(),
				"start_idx"
			) *
			
			listlpeg.C(patt) * 
			listlpeg.Cg(
				listlpeg.Cc"COMMENT", 
				"token"
			) *
			
			listlpeg.Cg(
				listlpeg.Cp(),
				"end_idx"
			)), 
			function(s, i, t)
				return i, t
			end
		)
		comments[name] = cmt
		return cmt
	end
	
	local
	function LexErr(patt, msg)
		return listlpeg.Cmt(patt, function(s, i, t)
			self.erridx = i
			self.errmsg = msg
			error(msg, 0)
		end)
	end

	local api = {
		-- PEG functions
		P = listlpeg.P,
		R = listlpeg.R,
		S = listlpeg.S,
		V = listlpeg.V,
		C = listlpeg.C,
		Cmt = listlpeg.Cmt,
		Ct = listlpeg.Ct,
		Cg = listlpeg.Cg,
		Cc = listlpeg.Cc,

		-- AST functions
		Comment = Comment,
		Token = Token,
		Rule = Rule,
		Ignore = Ignore,
		LexErr = LexErr,
		
		-- general functions
		ipairs = ipairs,
		pairs = pairs,
		print = print,
		
		-- constants
		MAX_PRIORITY = MAX_PRIORITY,
	}
	api.__index = api
	
	local env = setmetatable({}, api)
	--[[
	-- env functions
	api.set = function(k, v)
		env[k] = v
	end
	--]]
	
	local f = assert(loadstring(self.specification))
	setfenv(f, env)
	
	f()
	
	local priorities = {}
	local sorted_tokens = {}
	for name, priority in pairs(token_priority) do
		local list = sorted_tokens[priority]
		if(not list) then
			list = {}
			sorted_tokens[priority] = list
			priorities[#priorities+1] = priority
		end
		list[#list+1] = name
	end
	
	table.sort(priorities)
	
	local tokens_patt
	for i=#priorities, 1, -1 do
		local priority = priorities[i]
		local list = sorted_tokens[priority]
		for j, name in ipairs(list) do
			local tok = tokens[name]
			
			if(tokens_patt) then
				tokens_patt = tokens_patt + tok
			else
				tokens_patt = tok
			end
		end
	end
	
	for k, v in pairs(comments) do
		tokens_patt = v + tokens_patt
	end
	
	local
	function search(patt)
		return (patt + listlpeg.Cmt(
			listlpeg.C(listlpeg.P(1)),
			function(s, i, c)
				if(not space:match(c)) then
					self.erridx = i
					self.errmsg = "invalid character '"..c.."'"
					error(self.errmsg, 0)
				end
				return true
			end)
		)^0
	end

	self.patt = listlpeg.Ct(search(tokens_patt))
end

function M:add_line_numbers_to_tokens(tokens, code)
	local line = 1
	local charidx = 0
	local tokidx = 1
	for linecode in code:gmatch("([^\n]*\n?)") do
		if(linecode:len() > 0) then
			local sidx = charidx
			local eidx = sidx+linecode:len()
			
			local tok = tokens[tokidx]
			while(tok and tok.start_idx <= eidx) do
				tok.line_number = line
				tok.start_col = tok.start_idx - sidx
				tokidx = tokidx+1
				tok = tokens[tokidx]
			end
			
			charidx = eidx
			line = line+1
		end
	end
end

function M:match(s)
	local tokens = self.patt:match(s)
	if(self.line_numbers) then
		self:add_line_numbers_to_tokens(tokens, s)
	end
	return tokens
end