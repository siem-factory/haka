/* File automatically generated by Haka. DO NOT EDIT */
#include <assert.h>

#include <haka/error.h>
#include <haka/log.h>
#include <haka/string_utils.h>
#include <haka/lua/lua.h>
#include <haka/lua/state.h>
#include <haka/lua/parse_ctx.h>
#include <haka/luabinding.h>

/* grammar from {{name}} */

static REGISTER_LOG_SECTION(grammar);

{% if _swig then %}
extern void *lua_get_swigdata(void *ptr);
{% end %}

{% for _, parser in ipairs(_parsers) do %}
static const struct node_debug *node_debug_{{ parser.name }};

int parse_{{ parser.name }}
{% if _swig then %}
(lua_State *L)
{
	void *_ctx;
	struct parse_ctx *ctx;
	assert(lua_isuserdata(L, 1));
	_ctx = lua_touserdata(L, 1);
	ctx = (struct parse_ctx *)lua_get_swigdata(_ctx);
{% else %}
(struct parse_ctx *ctx)
{
{% end %}

	ctx->node_debug_data = node_debug_{{ parser.name }};

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

{%
local node = parser.dgraph
local stack = { node }
while node do
	table.remove(stack, 1)
	local gid = node.gid
%}

{% if parser.written_nodes[gid] then %}
{% assert(parser.nodes[node], "unknown node to jump to") %}
		/* jump to gid {{ gid }} */
		ctx->next = {{ parser.nodes[node] }};
		break;
{% else %}
{%
local id = parser:register(node)
parser.written_nodes[gid] = true
%}
		/* gid {{ gid }} */
		case {{ id }}: /* in rule '{{ node.rule or "<unknown>"}}' field '{{ node.name or node.id }}' <{{ class.classof(node).name }}> */
		{
			/* Register next node */
			ctx->next = {{ id }};
			/* Call required lua */
			if (call != 0) break;

			/* Node start */
			ctx->current = {{ id }};
{% end %}
		/* TODO */
		}

{%
local nexts = node:getnexts()
if #nexts == 0 then
%}
		ctx->next = FINISH; break;
{%
end

	table.prepend(stack, nexts)
	node = stack[1]
%}

{% end %}
		default: /* node 0 is default and is also exit */
		{
			ctx->run = false;
		}
		}
	}

{% if _swig then %}
	lua_pushinteger(L, call);
	return 1;
{% else %}
	return call;
{% end %}
}

static const struct node_debug node_debug_{{ parser.name }}_init[] = {
{%
local id2node = {}

for node, id in pairs(parser.nodes) do
	id2node[id] = node
end

for id=1, parser.nodes_count do
	local node = id2node[id]
%}
	{ .id = "{{ node.name or node.id or "<unknown>" }}", .rule = "{{ node.rule or "<unknown>" }}" }, /* id: {{ id }}, gid: {{ node.gid }} */
{% end %}
};

{% end %}

/**
 * Generated lua byte code from:

{{ binding_code }}
 */
static const char luabc_{{ name }}[] = {
	{{ binding_bytecode }}
};

inline void lua_load_{{ name }}(lua_State *L)
{
	luaL_loadbuffer(L, luabc_{{ name }}, sizeof(luabc_{{ name }}), "{{ name }}");
}


LUA_BIND_INIT({{ nameid }})
{
	LUA_LOAD({{ name }}, L);

{% for _, parser in ipairs(_parsers) do %}
	node_debug_{{ parser.name }} = node_debug_{{ parser.name }}_init;
{% end %}

{% if _swig then %}
	lua_newtable(L);

	{% for _, parser in pairs(_parsers) do %}
	lua_pushstring(L, "parse_{{ parser.name }}");
	lua_pushcfunction(L, parse_{{ parser.name }});
	lua_settable(L, -3);
	{% end %}

	lua_call(L, 1, 1);
{% else %}
	lua_call(L, 0, 1);
{% end %}

	return 1;
}