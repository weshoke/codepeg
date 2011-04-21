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

local table = table
local format = string.format

local listlpeg = require("listlpeg")


module(...)

-- no-op
local
function Rule()
end

local
function search(patt)
	return (patt + listlpeg.P(1))^0
end


local C = {}
local M = setmetatable(getfenv(), C)
M.__index = M


function C:__call(init)
	assert(init.specification)
	
	local m = setmetatable(init, M)
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
			error(msg)
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

	self.patt = listlpeg.Ct(search(tokens_patt))
end

function M:match(s)
	return self.patt:match(s)
end