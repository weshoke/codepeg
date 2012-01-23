-- parser.lua
local setmetatable = setmetatable
local getfenv = getfenv
local assert = assert
local loadstring = loadstring
local setfenv = setfenv
local pairs = pairs
local ipairs = ipairs
local print = print
local error = error
local tostring = tostring
local type = type

local floor = math.floor
local format = string.format
local table = table
local string = string
local listlpeg = require("listlpeg")

local ast = require("codepeg.ast")
local Rulestack = require("codepeg.Rulestack")

local printt = printt
local DEBUG = false


module(...)


local C = {}
local M = setmetatable(getfenv(), C)
M.__index = M

local
function optbool(v, def)
	if(type(v) == "nil") then
		return def
	else
		return v
	end
end

local
function Ignore(patt)
	return #patt/function()end
end

function C:__call(init)
	assert(init.specification)
	assert(init.root)
	
	local m = setmetatable(init, M)
	m.trace = optbool(m.trace, false)
	m.tracetokens = optbool(m.tracetokens, false)
	m.tracematch = optbool(m.tracematch, false)
	m.rulestack = Rulestack()
	
	m:load_specification()
	return m
end

function M:push_token(i, name, tok)
	local lastrule = self.rulestack:top()
	self.rulestack:tokentry(i, name)
	
	if(tok and tok.token == name) then
		if(self.tracematch) then
			print(i.."\t\t\tMatch: "..name.."  Rule: "..lastrule)
		end
		
		self.rulestack:tokenmatch(i, name, tok)
	end
	
	if(self.tracetokens) then
		print(i.."\t\t\tToken: "..name .."\tactual: "..(tok and tok.token or "nil"))
	end
end

function M:push_rule(i, name)
	self.rulestack:push(i, name)
	
	if(self.trace) then
		print(
			i..string.rep(" ", self.rulestack.stackidx)..self.rulestack.stackidx..
		" -> ".. format("%s%s", name, " ", self.rulestack:top() or ""))
	end
end

function M:pop_rule(i, name)
	assert(self.rulestack:top() == name)
	self.rulestack:popmatch(i, name)
	
	if(self.trace) then
		print(i..string.rep(" ", self.rulestack.stackidx)..self.rulestack.stackidx ..
			" <- "..name.." "..self.rulestack.toklistidx.. " MATCH")
	end
end

function M:remove_rule(i, name)
	assert(self.rulestack:top() == name)
	self.rulestack:popfail(i, name)
	
	if(self.trace) then
		print(i..string.rep(" ", self.rulestack.stackidx)..self.rulestack.stackidx .." <-: "..name)
	end
end

function M:tokenlist()
	return self.rulestack.tokenlist
end

function M:lasttoken()
	return self.rulestack.lastmatch
end

function M:lastrulestack()
	return self.rulestack:laststack()
end

function M:load_specification()
	local MAX_PRIORITY = 10000000
	local marktoken = function(name)
		return listlpeg.P(function(s, i, t)
			local tok = s[i]
			self:push_token(i, name, tok)
			if(DEBUG) then
				print("\ttoken:", i, name)
			end
			return i
		end)
	end
	
	local tokens = {}
	local Token = function(patt, name)
		local tok = listlpeg.Cmt(
			-- order is important here so that markrule gets called *before* marktoken
			listlpeg.C(1) * marktoken(name), 
			function(s, i, t)
				-- handle comments as part of the token stream
				while(t.token == "COMMENT") do
					i = i+1
					t = s[i]
					if(not t) then
						return false
					end
				end
			
				if(t.token == name) then
					return i, t
				else
					return false
				end
			end
		)
		tokens[name] = tok
		return tok
	end
	
	local markrule = function(name)
		return listlpeg.P(function(s, i, t)
			if(DEBUG) then
				print("rule:", i, name)
			end
			self:push_rule(i+1, name)
			return i
		end)
	end
	
	local endrule = function(name)
		return listlpeg.P(function(s, i, t)
			if(DEBUG) then
				print("ENDRULE", i, name)
			end
			self:remove_rule(i+1, name)
		end)
	end
	
	local poprule = function(name)
		return listlpeg.P(function(s, i, t)
			if(DEBUG) then
				print("pop rule:", i, name)
			end
			self:pop_rule(i, name)
			return i
		end)
	end
	
	local rules = {}
	local Rule = function(patt, name, collapsable)
		local rule = listlpeg.Cmt(
			markrule(name) * (
				patt * 
				listlpeg.Cg(
					listlpeg.Cc(name), 
					"rule"
				) * poprule(name)
				
				+ endrule(name)
			) , function(s, i, ...)
				local args = {...}
				if(collapsable and #args == 1) then
					return i, args[1]
				else
					args.rule = name
					return i, args
				end
			end
		)
		
		rules[name] = rule
		return rule
	end
	
	local check = function(patt)
		return patt * listlpeg.Cmt(
				listlpeg.C(1), function(s, i, t)
					return t.token == "COMMENT"
				end
			)^0 *
			
			listlpeg.P(-1) + 
			
			listlpeg.Cmt(
				listlpeg.P(1), 
				function()
					error("error parsing tokens")
				end
			)
	end
	
	local Comment = function(patt) 
		return patt
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
		LexErr = function(patt)
			return patt
		end,
		
		-- general functions
		ipairs = ipairs,
		pairs = pairs,
		
		-- constants
		MAX_PRIORITY = MAX_PRIORITY,
	}
	api.__index = api
	
	local env = setmetatable({}, api)
	
	-- env functions
	api.set = function(k, v)
		env[k] = v
	end
	
	local f = assert(loadstring(self.specification))
	setfenv(f, env)
	
	f()
	
	local grammar = {}
	for k, v in pairs(tokens) do
		grammar[k] = v
	end
	for k, v in pairs(rules) do
		grammar[k] = v
	end
	grammar[1] = self.root
	self.patt = check(listlpeg.P(grammar))
end

function M:set_root(root)
	self.root = root
	self:load_specification()
end

function M:match(s)
	self.tokens = s
	self.rulestack = Rulestack()

	local res, x = self.patt:match(s)
	return res
end