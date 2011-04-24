-- Stack.lua
local setmetatable = setmetatable
local getfenv = getfenv
local assert = assert
local pairs = pairs
local ipairs = ipairs
local print = print

local table = table
local string = string
local format = string.format

--local Stack = require("codepeg.Stack")

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