-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

local class = require('class')
local check = require('check')

local types = {}
local dissector = {}
local log = haka.log_section("dissector")
local log_lua = haka.log_section("lua")

haka.dissectors = {}
local mt = {
	__index = function(t, k)
		log.error("unknown dissector %s", k)
	end
}
setmetatable(haka.dissectors, mt)

--
-- Dissector base class
--

types.Dissector = class.class('Dissector')

local event_mt = {
	__index = function (self, name)
		check.error(string.format("unkown event '%s'", name))
	end
}

local policies_mt = {
	__index = function (self, name)
		check.error(string.format("unkown policy '%s'", name))
	end
}

function types.Dissector.__class_init(self, cls)
	self.super:__class_init(cls)

	cls.events = {}
	setmetatable(cls.events, event_mt)
	self.inherit_events(cls)
	cls.options = {}
	cls.connections = haka.event.StaticEventConnections:new()
	cls.policies = {}
	setmetatable(cls.policies, policies_mt)
	cls.policies.next_dissector = haka.policy.new(string.format("%s next dissector", cls.name))
end

function types.Dissector.method:install_criterion()
	return {}
end

function types.Dissector.stream_wrapper(f, options, self, stream, current, ...)
	if options and options.streamed then
		self:streamed(stream, f, self, current, ...)
	else
		if (not current or not current:check_available(1)) and
		   not stream.isfinished then
			return
		end

		if current then
			local sub = current:copy():sub('available')
			if sub then
				f(self, sub, ...)
			end
		end
	end
end

function types.Dissector.register_event(cls, name, continue, signal, options)
	continue = continue or function (self) return self:continue() end
	cls.events[name] = haka.event.Event:new(string.format('%s:%s', cls.name, name), continue, signal, options)
end

function types.Dissector.register_streamed_event(cls, name, continue, options)
	types.Dissector.register_event(cls, name, continue, types.Dissector.stream_wrapper, options)
end

function types.Dissector.inherit_events(cls)
	local parent_events = cls.super.events
	if parent_events then
		local events = cls.events
		for name, event in pairs(parent_events) do
			events[name] = event:clone()
			events[name].name = string.format('%s:%s', cls.name, name)
		end
	end
end

function types.Dissector.create(cls, parent, ...)
	local obj = cls:new(parent)
	obj:create(parent, ...)
	return obj
end

types.Dissector.auto_state_machine = true

function types.Dissector.method:__init(parent)
	local cls = class.classof(self)

	if cls.state_machine and cls.auto_state_machine then
		self._state = cls.state_machine:instanciate(self)
	end

	haka.context:register_connections(self:connections())

	self._parent = parent
end

types.Dissector.property.name = {
	get = function (self) return class.classof(self).name end
}

types.Dissector.property.state = {
	get = function (self)
		if self._state then
			return self._state.current
		end
	end
}

function types.Dissector.method:parent(arg)
	if arg == nil then
		return self._parent
	elseif type(arg) == 'number' then
		local iter = self
		while iter do
			if arg == 0 then
				return iter
			end

			iter = iter._parent
			arg = arg-1
		end
	else
		local iter = self
		while iter do
			if iter.name == arg then
				return iter
			end

			iter = iter._parent
		end
	end
end

function types.Dissector.method:__index(name)
	if name:sub(1, 1) ~= '_' then
		parent = self._parent
		if parent then
			return parent[name]
		else
			error(string.format("unknown field '%s' on dissector '%s'", name, self.name))
		end
	end
end

function types.Dissector.method:trigger(signal, ...)
	haka.context:signal(self, class.classof(self).events[signal], ...)
end

function types.Dissector.method:send()
	error("not implemented")
end

function types.Dissector.method:drop()
	error("not implemented")
end

function types.Dissector.method:alert(alert)
	haka.alert(alert)
end

function types.Dissector.method:can_continue()
	error("not implemented")
end

function types.Dissector.method:continue()
	if not self:can_continue() then
		haka.abort()
	end
end

function types.Dissector.method:connections()
	local connections = class.classof(self).connections
	if #connections > 0 then
		return haka.event.ObjectEventConnections:new(self, connections)
	end
end

function types.Dissector.activate(cls, parent)
	-- Default create a new instance for each receive
	return cls:new(parent)
end

function types.Dissector.method:activate_next_dissector()
	if self._next_dissector then
		if class.isclass(self._next_dissector) then
			self._next_dissector = self._next_dissector:activate(self)
		end
		return self._next_dissector
	else
		return nil
	end
end

function types.Dissector.method:select_next_dissector(dissector)
	self._next_dissector = dissector
end

function types.Dissector.method:error()
	self:drop()
end

function types.Dissector.method:streamed(stream, f, this, current, ...)
	if (not current or not current:check_available(1)) and
	   not stream.isfinished then
		return
	end

	local cur
	if current then
		cur = current:copy()
	else
		cur = stream.data:pos('end')
	end

	local comanager = stream:getcomanager()
	-- unique id for the function to execute
	local id = comanager.hash(f, this)

	if not comanager:has(id) then
		local args = {...}
		comanager:start(id, function (iter) return f(this, iter, unpack(args)) end)
	end

	comanager:process(id, cur)
end

function dissector.pcall(self, f)
	local ret, err = xpcall(f, debug.format_error)

	if not ret then
		if err then
			log_lua.error("%s: %s", self.name, err)
			return self:error()
		end
	end

	-- return the result of f
	return err
end


--
-- Packet based type
--

types.PacketDissector = class.class('PacketDissector', types.Dissector)

types.PacketDissector:register_event('receive_packet')
types.PacketDissector:register_event('send_packet')

local npkt

local function preceive()
	npkt:receive()
end

function types.PacketDissector.method:preceive()
	-- JIT optim
	npkt = self
	return dissector.pcall(npkt, preceive)
end

function types.PacketDissector.method:receive()
	self:parse(self._parent)

	self:trigger('receive_packet')

	class.classof(self).policies.next_dissector:apply{
		values = self:install_criterion(),
		ctx = self,
	}

	-- Dirty workaround to avoid changing {tcp,udp}_connection right now
	if self._next_dissector and self._next_dissector.receive then
		return self._next_dissector:receive(self)
	else
		local next_dissector = self:activate_next_dissector()
		if next_dissector then
			return next_dissector:preceive()
		else
			return self:send()
		end
	end
end

function types.PacketDissector.method:__init(parent)
	class.super(types.PacketDissector).__init(self, parent)
end

function types.PacketDissector.method:parse(pkt)
	self._select, self._payload = pkt.payload:sub(0, 'all'):select()
	self:parse_payload(pkt, self._payload)
end

function types.PacketDissector.method:parse_payload(pkt, payload)
	local unique_export = class.classof(self).grammar.unique_export
	if unique_export == nil then
		error("not implemented for grammar exporting more than 1 element")
	end

	local res = unique_export:parse(payload:pos("begin"))
	table.merge(self, res)
end

function types.PacketDissector.method:create(pkt, init, size)
	if size then
		pkt.payload:pos(0):insert(haka.vbuffer_allocate(size))
	end
	self._select, self._payload = pkt.payload:sub(0, 'all'):select()
	self:create_payload(pkt, self._payload, init)
end

function types.PacketDissector.method:create_payload(pkt, payload, init)
	local unique_export = class.classof(self).grammar.unique_export
	if unique_export == nil then
		error("not implemented for grammar exporting more than 1 element")
	end

	local res = unique_export:create(payload:pos("begin"), init)
	table.merge(self, res)
end

function types.PacketDissector.method:forge(pkt)
	self:forge_payload(pkt, self._payload)
	self._select:restore(self._payload)
	self._payload = nil
	self._select = nil
end

function types.PacketDissector.method:forge_payload(pkt, payload)
	error("not implemented")
end

function types.PacketDissector.method:can_continue()
	return self._parent:can_continue()
end

function types.PacketDissector.method:drop()
	return self._parent:drop()
end

function types.PacketDissector.method:send()
	self:trigger('send_packet')

	self:forge(self._parent)
	self._parent:send()
	self._parent = nil
end

function types.PacketDissector.method:inject()
	self:forge(self._parent)
	self._parent:inject()
	self._parent = nil
end

--
-- Flow based dissector
--

types.FlowDissector = class.class('FlowDissector', types.Dissector)

--
-- Utility functions
--

function dissector.new(args)
	check.assert(args.type, string.format("no type defined for dissector '%s'", args.name))

	local cls = class.class(args.name, args.type)

	if haka.mode ~= 'console' then
		log.info("register new dissector '%s'", cls.name)
	end

	if rawget(haka.dissectors, cls.name) ~= nil then
		error(string.format("dissector '%s' already defined", cls.name))
	end

	local public = {
		policies = cls.policies,
		events = cls.events,
		create = function (...) return cls:create(...) end,
		install = function (policy, ctx, values, desc)
			return ctx:select_next_dissector(cls)
		end
	}

	haka.dissectors[cls.name] = public
	return cls
end

local other_direction = {
	up = 'down',
	down = 'up'
};

function dissector.opposite_direction(dir)
	return other_direction[dir]
end

function haka.console.events()
	local ret = {}
	local event = {}
	for _, dissector in pairs(haka.dissectors) do
		for _, event in pairs(dissector.events) do
			local er = { event=event.name, listener=0 }
			table.insert(ret, er)
			event[event.name] = er
		end
	end
	for event, listeners in pairs(haka.context.connections) do
		event[event.name].listener = #listeners
	end
	return ret
end


haka.dissector = dissector
table.merge(haka.helper, types)
