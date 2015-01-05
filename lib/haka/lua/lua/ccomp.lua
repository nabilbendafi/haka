-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

local class = require('class')

local log = haka.log_section("grammar")

local module = class.class("CComp")

local suffix = "_grammar"

function module.method:__init(name, _debug)
	self._swig = haka.config.ccomp.swig
	self._name = name..suffix
	self._nameid = self._name.."_"..haka.genuuid():gsub('-', '_')
	self._debug = _debug or false
	self._cfile = haka.config.ccomp.runtime_dir..self._nameid..".c"
	self._sofile = haka.config.ccomp.runtime_dir..self._nameid..".so"
	self._store = {} -- Store some lua object to access it from c
	self._parser = nil -- Current parser
	self._parsers = {}

	-- Open and init c file
	log.debug("generating c code at '%s'", self._cfile)
	self._fd = assert(io.open(self._cfile, "w"))

	-- Create c grammar
	self._tmpl = require("grammar_c")
	self:write(self._tmpl.render({ name = name }))

	if self._swig then
		self:write[[
extern void *lua_get_swigdata(void *ptr);
]]
	end

	self.waitcall = self:store(function (ctx)
		ctx.iter:wait()
	end)
end

local function traverse(ccomp, node)
	if ccomp._parser.written_nodes[node] then
		ccomp:_jumpto(node)
		return
	end

	local nexts = node:ccomp(ccomp)
	if #nexts == 0 then
		-- Reach one end of the graph
		ccomp:jumptoend()
	end
	for _, iter in pairs(nexts) do
		traverse(ccomp, iter)
	end
end

function module.method:create_parser(name, dgraph)
	self:_start_parser(name)

	traverse(self, dgraph)

	self:_end_parser()
end

function module.method:_start_parser(name)
	assert(not self._parser, "parser already started")
	self._parser = {
		name = name,
		fname = "parse_"..name,
		nodes = {}, -- Store all encountered nodes
		nodes_count = 0, -- Count of encountered nodes
		written_nodes = {}, -- Store written nodes
	}
	self._parsers[#self._parsers + 1] = self._parser

	self:write([[
	static const struct node_debug *node_debug_%s;
]], self._parser.name)

	if self._swig then
		self:write([[
int parse_%s(lua_State *L)
{
	void *_ctx;
	struct parse_ctx *ctx;
	assert(lua_isuserdata(L, 1));
	_ctx = lua_touserdata(L, 1);
	ctx = (struct parse_ctx *)lua_get_swigdata(_ctx);
]], name)
	else
		self:write([[
int parse_%s(struct parse_ctx *ctx)
{]], name)
	end

	self:write([[
	ctx->node_debug_data = node_debug_%s;

	if (ctx->error.isset) {
		if (parse_ctx_catch(ctx)) {
#ifdef HAKA_DEBUG
			char dump[101];
			char dump_safe[401];
			struct vbuffer_sub sub;
			vbuffer_sub_create_from_position(&sub, &ctx->error.iter, 100);
			safe_string(dump_safe, dump, vbuffer_asstring(&sub, dump, 101));

			LOG_DEBUG(grammar, "catched: parse error at byte %%d for field %%s in %%s: %%s",
			ctx->error.iter.meter, ctx->node_debug_data[ctx->error.node-1].id, ctx->node_debug_data[ctx->error.node-1].rule, ctx->error.desc);
			LOG_DEBUG(grammar, "parse error context: %%s...", dump_safe);
#endif
		} else {
			char dump[101];
			char dump_safe[401];
			struct vbuffer_sub sub;
			vbuffer_sub_create_from_position(&sub, &ctx->error.iter, 100);
			safe_string(dump_safe, dump, vbuffer_asstring(&sub, dump, 101));

			LOG_DEBUG(grammar, "parse error at byte %%d for field %%s in %%s: %%s",
			ctx->error.iter.meter, ctx->node_debug_data[ctx->error.node-1].id, ctx->node_debug_data[ctx->error.node-1].rule, ctx->error.desc);
			LOG_DEBUG(grammar, "parse error context: %%s...", dump_safe);
			ctx->run = false;
		}
	}

	int call = 0;
	while(ctx->run) {
		if (call != 0) break;

		switch(ctx->next) {
]], self._parser.name)
end

function module.method:_end_parser()
	assert(self._parser, "parser not started")
	self:write[[
		default: /* node 0 is default and is also exit */
		{
			ctx->run = false;
		}
		}
	}
]]

	if self._swig then
		self:write[[
	lua_pushinteger(L, call);
	return 1;
}
]]
	else
		self:write[[
	return call;
}
]]
	end

	-- Expose node debug information
	self:write([[
static const struct node_debug node_debug_%s_init[] = {
]], self._parser.name)

	local id2node = {}

	for node, id in pairs(self._parser.nodes) do
		id2node[id] = node
	end

	for id=1,self._parser.nodes_count do
		local node = id2node[id]

		self:write([[
	{ .id = "%s", .rule = "%s" }, /* id: %d, gid: %d */
]], node.name or node.id or "<unknown>", node.rule or "<unknown>", id, node.gid)
	end

	self:write[[
};
]]

	self._parser = nil
end

function module.method:store(func)
	assert(func, "cannot store nil")
	assert(type(func) == 'function', "cannot store non function type")
	local id = #self._store + 1

	self._store[id] = func
	return id
end

function module.method:call(id, name)
	self:write([[
			call = %d;                                /* %s */
]], id, name)
end

function module.method:register(node)
	self._parser.nodes_count = self._parser.nodes_count + 1
	self._parser.nodes[node] = self._parser.nodes_count
	return self._parser.nodes_count
end

function module.method:start_node(node)
	assert(self._parser, "parser not started")
	local rule = node.rule or "<unknown>"
	local field = node.id
	if node.name then
		field = string.format("'%s'", node.name)
	end
	local type = class.classof(node).name
	-- Register node if it is not
	local id = self._parser.nodes[node]
	if not id then
		id = self:register(node)
	end

	-- Mark as written
	self._parser.written_nodes[node] = true

	self:write([[

		/* gid %d */
		case %d: /* in rule '%s' field %s <%s> */
		{
			/* Register next node */
			ctx->next = %d;
			/* Call required lua */
			if (call != 0) break;

			/* Node start */
			ctx->current = %d;
]], node.gid, id, rule, field, type, id, id)
end

function module.method:finish_node()
	assert(self._parser, "parser not started")
	self:write[[
		}
]]
end

local function escape_string(str)
	local esc = str:gsub("([\\%%\'\"])", "\\%1")
	return esc
end

function module.method:trace_node(node, desc)
	local id = self._parser.nodes[node]

	self:write([[
#ifdef HAKA_DEBUG_GRAMMAR
			{
				char dump[21];
				char dump_safe[81];
				struct vbuffer_sub sub;
				vbuffer_sub_create_from_position(&sub, ctx->iter, 20);
				safe_string(dump_safe, dump, vbuffer_asstring(&sub, dump, 21));

				LOG_DEBUG(grammar, "in rule '%%s' field %%s gid %d: %%s\n\tat byte %%d: %%s...",
					node_debug_%s[%d-1].rule, node_debug_%s[%d-1].id, "%s", ctx->iter->meter, dump_safe);
			}
#endif
]], node.gid, self._parser.name, id, self._parser.name, id, escape_string(desc))
end

function module.method:_jumpto(node)
	assert(self._parser, "parser not started")
	assert(self._parser.nodes[node], "unknown node to jump to")
	self:write([[
		/* jump to gid %d */
		ctx->next = %d; break;
]], node.gid, self._parser.nodes[node])
end

function module.method:jumptoend(node)
	assert(self._parser, "parser not started")
	self:write[[
			ctx->next = FINISH; break;
]]
end

function module.method:apply_node(node)
	assert(self._parser, "cannot apply node without started parser")
	assert(node)

	self:call(self:store(function (ctx)
		node:_apply(ctx)
	end), "node:_apply(ctx)")
end

function module.method:mark(readonly)
	readonly = readonly and "true" or "false"
	self:write([[
			parse_ctx_mark(ctx, %s);
]], readonly)
end

function module.method:unmark()
	self:write([[
			parse_ctx_unmark(ctx);
]])
end

local numtab={}
for i=0,255 do
	numtab[string.char(i)]=("%3d,"):format(i)
end

local function lua2c(lua)
	local content = string.dump(assert(load(lua)))
	return (content:gsub(".", numtab):gsub(("."):rep(80), "%0\n"))
end

function module.method:compile()
	assert(not self._parser, "unfinished parser ", self._parsers[#self._parsers].name)

	local binding = [[
local parse_ctx = require("parse_ctx")
]]
	if haka.config.ccomp.ffi then

		binding = binding..[[
local ffibinding = require("ffibinding")
local lib = ffibinding.load[[
]]

		-- Expose all parser
		for _, value in pairs(self._parsers) do
			binding = binding..string.format("int parse_%s(struct parse_ctx *ctx);\n", value.name)
		end

		binding = binding.."]]"
	else
		binding = binding..[[
local lib = unpack({...})
]]
	end

	binding = binding..[[

return { ctx = parse_ctx, grammar = lib }
]]

	local luacode = lua2c(binding)

	-- Luaopen
	self:write([[

/**
 * Generated lua byte code from:

%s
 */
static const char luabc_%s[] = {
	%s
};

inline void lua_load_%s(lua_State *L)
{
	luaL_loadbuffer(L, luabc_%s, sizeof(luabc_%s), "%s");
}


LUA_BIND_INIT(%s)
{
	LUA_LOAD(%s, L);
]], binding, self._name, luacode, self._name, self._name, self._name, self._name, self._nameid, self._name)

	for _, value in pairs(self._parsers) do
		self:write([[
	node_debug_%s = node_debug_%s_init;
]], value.name, value.name)
	end

	if self._swig then
		self:write[[
	lua_newtable(L);
]]

		-- Expose all parser
		for _, value in pairs(self._parsers) do
			self:write([[
	lua_pushstring(L, "parse_%s");
	lua_pushcfunction(L, parse_%s);
	lua_settable(L, -3);
]], value.name, value.name)
		end
		self:write[[
	lua_call(L, 1, 1);

	return 1;
}
]]

	else
		self:write[[
	lua_call(L, 0, 1);

	return 1;
}
]]
	end

	self._fd:close()

	-- Compile c grammar
	local flags = string.format("%s -I%s -I%s/haka/lua/", haka.config.ccomp.flags, haka.config.ccomp.include_path, haka.config.ccomp.include_path)
	if self._debug then
		flags = flags.." -DHAKA_DEBUG_GRAMMAR"
	end
	local compile_command = string.format("%s %s -o %s %s", haka.config.ccomp.cc, flags, self._sofile, self._cfile)
	log.info("compiling grammar '%s'", self._name)
	log.debug(compile_command)
	local ret = os.execute(compile_command)
	if not ret then
		error("grammar compilation failed `"..compile_command.."`")
	end

	return self._nameid
end

function module.method:write(string, ...)
	assert(self._fd, "uninitialized template")
	assert(self._fd:write(string.format(string, ...)))
end

return module
