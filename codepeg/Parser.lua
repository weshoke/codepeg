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
	m.token_stack = {idx = 0}
	m.rule_stack = {last_token = 0}
	m.matched = {}
	m.tried = {}
	m.rule_network = {}
	m.trace = optbool(m.trace, false)
	m.tracetokens = optbool(m.tracetokens, false)
	
	m:load_specification()
	return m
end

function M:set_rule_network(i, name, toname)
	local node = self.rule_network[i]
	if(not node) then
		node = {start_tokens = {}}
		self.rule_network[i] = node
		
		local prevnode = self.rule_network[i-1]
		if(toname and prevnode) then
			for j=1, #prevnode do
				local pname = prevnode[j]
				node[#node+1] = pname
				local pos = #node
				node.start_tokens[pos] = prevnode.start_tokens[j]

				if(pname == toname) then
					break
				end
			end
		end
	end
	if(name) then
		node[#node+1] = name
		local pos = #node
		node.start_tokens[pos] = i
	end
end

function M:remove_rule_network(imax, imin, name)
	for j=imax, imin, -1 do
		local node = self.rule_network[j]
		if(node) then
			if(node[#node] == name) then
				local pos = #node
				node[#node] = nil
				node.start_tokens[pos] = nil
			end
		end
	end
end

function M:remove_token_stack(imax, imin, name)
	for j=imax, imin, -1 do
		local slot = self.token_stack[j]
		if(slot) then
			for i=#slot, 1, -1 do
				local e = slot[i]
				if(e.rule == name) then
					table.remove(slot, i)
				end
			end
		end
	end
end

local
function slot_has_token(slot, idx, token, rule)
	for i, e in ipairs(slot) do
		if(e.idx == idx and e.token == token and e.rule == rule) then
			return true
		end
	end
	return false
end

function M:push_token(i, name, tok)
	local last_rule = assert(self.rule_stack[#self.rule_stack])
	local slot = self.token_stack[i]
	if(not slot) then
		slot = {}
		self.token_stack[i] = slot
	end
	if(not slot_has_token(slot, i, name, last_rule.name)) then
		slot[#slot+1] = {
			idx = i,
			token = name,
			rule = last_rule.name
		}
	end
	
	if(tok and tok.token == name) then
		if(
			(self.token_stack.last_matched_token and
			self.token_stack.last_matched_token.idx < i) 
			or not self.token_stack.last_matched_token
		) then
			self.token_stack.last_matched_token = {
				idx = i,
				tok,
				rule = last_rule.name,
			}
		end
	end
	self.token_stack.idx = i
	
	if(self.tracetokens) then
		print(i.."\t\t\tToken: "..name .."\tactual: "..(tok and tok.token or "nil"))
	end
	
	self:set_rule_network(i, nil, last_rule.name)
end

function M:print_token_slot(i)
	local slot = self.token_stack[i]
	if(slot) then
		local msg = ""
		for i, v in ipairs(slot) do
			msg = msg .. " "..format("%s:%s", v.token, v.rule)
		end
		print("", i.." "..msg)
	elseif(self.matched[i]) then
		print("", i.." <matched>:"..self.matched[i])
	else
		print("", i.." <no slot>")
	end
end

function M:print_token_stack()
	for idx=self.token_stack.idx, 1, -1 do
		self:print_token_slot(idx)
	end
end

function M:push_rule(i, name)
	local last_rule = self.rule_stack[#self.rule_stack]
	
	self.rule_stack[#self.rule_stack+1] = {
		idx = i,
		name = name
	}
	
	---[[
	if(last_rule) then
		self:set_rule_network(i, name, last_rule.name)
	else
		self:set_rule_network(i, name)
	end
	
	
	if(self.tried[i]) then
		self.tried[i] = format("%s\n\t\t%s", self.tried[i], name)
	else
		self.tried[i] = name
	end
	local ntabs = 3 - floor((name:len()-14)/4)
	if(self.trace) then
		print(
			i..string.rep(" ", #self.rule_stack)..#self.rule_stack, 
		"->", format("%s%s", name, " ", last_rule and last_rule.name or ""))
		--self:print_rule_stack()
	end
end

function M:print_rule_stack()
	for i=#self.rule_stack, 1, -1 do
		local rule = self.rule_stack[i]
		print("", i, rule.name, rule.idx)
	end
	print("")
	--[[
	print("----")
	for i=#self.tried, 1, -1 do
		print("", i, self.tried[i])
	end
	--]]
end

function M:pop_rule(i, name)
	local last_rule = assert(self.rule_stack[#self.rule_stack])
	local match = false

	if(
		--last_rule.idx <= i and 
		last_rule.name == name
	) then
		match = true
		self.rule_stack[#self.rule_stack] = nil
		
		for idx=last_rule.idx, i do
			if(self.matched[idx]) then
				self.matched[idx] = format("%s\n\t\t%s", self.matched[idx], name)
			else
				self.matched[idx] = "\n\t\t"..name
			end
		end
	else
		print(last_rule.name, name)
		print(last_rule.idx, i)
		assert(false)
	end

	
	self.rule_stack.last_token = i
	
	self:remove_rule_network(self.token_stack.idx, i+1, name)
	self:remove_token_stack(self.token_stack.idx, i+1, name)
	
	if(self.trace) then
		print(i..string.rep(" ", #self.rule_stack+1)..#self.rule_stack+1, 
			"<-", name, self.token_stack.idx, match and "MATCH" or false)
		--self:print_rule_stack()
	end
end

function M:remove_rule(i, name)
	local last_rule = assert(self.rule_stack[#self.rule_stack])
	assert(last_rule.name == name)
	self.rule_stack[#self.rule_stack] = nil
	
	if(self.trace) then
		print(i..string.rep(" ", #self.rule_stack+1)..#self.rule_stack+1, "<-:", name)
	end

	self:remove_rule_network(last_rule.idx, last_rule.idx, name)
end

function M:token_stack_err_msg()
	local slot = self.token_stack[#self.token_stack]
	local msg = "looking for tokens:"
	for i, e in ipairs(slot) do
		msg = format("%s %s", msg, e.token)
	end
	return msg
end

function M:last_token_err_msg()
	local last_token = self.token_stack.last_matched_token
	local ltok = last_token[1]
	local ntok = self.tokens[last_token.idx+1]
	local msg = format("parse err at token %s: %s %s", 
		last_token.idx, ltok[1], ntok and ntok[1] or "<end of code>"
	)
	return msg
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
	local Rule = function(patt, name)
		---[[
		local rule = listlpeg.Ct(
			markrule(name) * (
				patt * 
				listlpeg.Cg(
					listlpeg.Cc(name), 
					"rule"
				) * poprule(name)
				
				+ endrule(name)
			) 
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
					local rule_err = ""
					
					print("tokens:")
					ast.print_tokens(self.tokens)
					--printt(self.token_stack)
					
					--print("rule stack")
					--printt(self.rule_network)
					error("error parsing tokens:\n"..self:token_stack_err_msg().."\n"..self:last_token_err_msg())
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
	self.token_stack = {idx = 0}
	self.rule_stack = {last_token = 0}
	self.matched = {}
	self.tried = {}
	self.rule_network = {}
	self.tokens = s

	local res, x = self.patt:match(s)
	return res
end