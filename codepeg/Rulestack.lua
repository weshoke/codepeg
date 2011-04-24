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

local Stack = require("codepeg.Stack")
local Tokenlist = require("codepeg.Tokenlist")

local printt = printt

module(...)


local C = {}
local M = setmetatable(getfenv(), C)
M.__index = M

function C:__call(init)
	init = init or {}
	local m = setmetatable(init, M)
	
	m.stacks = {
		Stack(),
		Stack(),
	}
	m.stackidx = 0
	m.tokidxs = {
		0, 0
	}
	m.matched = false
	
	m.tokenlist = Tokenlist()
	m.toklistidx = 0
	m.lastmatch = {
		idx = 0
	}
	
	return m
end

function M:push(idx, name)
	self:checkidx(idx, name)
	
	-- set the position of the stack and push the new rule
	self.stacks[1]:set(self.stackidx)
	self.stacks[1]:push(name)
	self.stackidx = self.stacks[1].idx
	self.tokidxs[1] = idx
end

function M:popfail(idx, name)
	self:checkidx(idx, name)
	self.stackidx = self.stackidx-1
end

function M:popmatch(idx, name)
	self.stackidx = self.stackidx-1
	self.tokidxs[1] = idx
	--print("remove:", idx, self.toklistidx)
	if(idx >= self.toklistidx) then
		self.tokenlist:remove(name)
	end
end

function M:tokentry(idx, name)
	if(idx > self.toklistidx) then
		--print("tok CLEAR", idx)
		self.tokenlist:clear()
		self.toklistidx = idx
	end
	if(idx == self.toklistidx) then
		--print("tok APPEND", idx, name)
		self.tokenlist:append(name, self:top())
	end
end

function M:tokenmatch(idx, name, tok)
	self.matched = true
	local lastmatch = self.lastmatch
	if(idx >= lastmatch.idx) then
		lastmatch.idx = idx
		lastmatch.tok = tok
		lastmatch.rule = self:top()
	end
end

function M:checkidx(idx, name)
	if(self.matched) then
		if(idx < self.tokidxs[1]) then
			if(self.tokidxs[2] < self.tokidxs[1]) then
				self:swap(idx, name)
			else
				self.tokidxs[1] = idx
			end
		else
			self:swap(idx, name)
		end
	end
end

function M:swap(idx, name)
	--print("swap:", idx, name)
	self.stacks[1], self.stacks[2] = self.stacks[2], self.stacks[1]
	self.tokidxs[1], self.tokidxs[2] = self.tokidxs[2], self.tokidxs[1]
	
	if(not (self.stackidx > self.stacks[1].idx)) then
		self.stacks[1]:set(self.stackidx)
	end
	
	for i=1, self.stackidx do
		self.stacks[1][i] = self.stacks[2][i]
		self.stacks[1].idx = self.stackidx
	end
	self.matched = false
	
	--printt(self.stacks[1])
end

function M:top()
	return self.stacks[1][self.stackidx]
end

function M:laststack()
	if(self.tokidxs[1] > self.tokidxs[2]) then
		return self.stacks[1]
	else
		return self.stacks[2]
	end
end

function M:print()
	local tok
	local stack
	if(self.tokidxs[1] >= self.tokidxs[2]) then
		stack = self.stacks[1]
		tok = self.tokidxs[1]
		print("\t___ 1 is equal or further")
	else
	--	stack = self.stacks[2]
	--	tok = self.tokidxs[2]
		stack = self.stacks[1]
		tok = self.tokidxs[1]
		print("\t___ 2 is further")
	end
	
	print(format("\t___ tok: %d  idx: %d", tok, stack.idx))
	for i, v in ipairs(stack) do
		print("\t___ "..i.." "..v..string.rep(" ", 24-v:len())..(i==self.stackidx and "<----------" or ""))
	end
	print("")
end