-- Tokenlist.lua
local setmetatable = setmetatable
local getfenv = getfenv
local assert = assert
local pairs = pairs
local ipairs = ipairs
local print = print
local tostring = tostring

local table = table
local string = string
local format = string.format

local printt = printt

module(...)


local C = {}
local M = setmetatable(getfenv(), C)
M.__index = M

function C:__call(init)
	init = init or {}
	local m = setmetatable(init, M)
	m.rules = {}
	m.tokens = {}

	return m
end

function M:clear()
	self.rules = {}
	self.tokens = {}
end

function M:append(tok, rule)
	for i=1, #self.tokens do
		if(
			self.tokens[i] == tok and 
			self.rules[i] == rule
		) then
			return
		end
	end
	self.tokens[#self.tokens+1] = tok
	self.rules[#self.rules+1] = rule
end

function M:remove(rule)
	for i=#self.rules, 1, -1 do
		if(self.rules[i] == rule) then
			table.remove(self.rules, i)
			table.remove(self.tokens, i)
		end
	end
end

function M:findtoken(tok)
	for i=1, #self.tokens do
		if(self.tokens[i] == tok) then
			return i
		end
	end
end

function M:token(idx)
	if(idx < 0) then
		return self.tokens[#self.tokens+idx+1]
	else
		return self.tokens[idx]
	end
end

function M:rule(idx)
	if(idx < 0) then
		return self.rules[#self.rules+idx+1]
	else
		return self.rules[idx]
	end
end

function M:print()
	local len = #self.rules
	local lenstr = tostring(len)
	for i=1, len do
		local istr = tostring(i)
		local str = string.rep(" ", lenstr:len() - istr:len())..istr
		str = str.."  "..self.tokens[i]
		str = str..string.rep(" ", 15-self.tokens[i]:len())
		str = str..self.rules[i]
		print(str)
	end
end