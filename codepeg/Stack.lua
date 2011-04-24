-- Stack.lua
local setmetatable = setmetatable
local getfenv = getfenv
local assert = assert
local pairs = pairs
local ipairs = ipairs
local print = print

local table = table


module(...)


local C = {}
local M = setmetatable(getfenv(), C)
M.__index = M

function C:__call(init)
	init = init or {}
	local m = setmetatable(init, M)
	m.idx = 0
	return m
end

function M:push(v)
	self.idx = self.idx+1
	self[self.idx] = v
end

function M:pop()
	self[self.idx] = nil
	self.idx = self.idx-1
end

function M:set(idx)
	assert(idx <= self.idx)
	for i=self.idx, idx+1, -1 do
		self[i] = nil
	end
	self.idx = idx
end