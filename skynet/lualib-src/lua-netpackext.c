#define LUA_LIB

#include "skynet_malloc.h"

#include "skynet_socket.h"

#include <lua.h>
#include <lauxlib.h>

#include <assert.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define QUEUESIZE 1024
#define HASHSIZE 4096
#define SMALLSTRING 2048

#define TYPE_DATA 1
#define TYPE_MORE 2
#define TYPE_ERROR 3
#define TYPE_OPEN 4
#define TYPE_CLOSE 5
#define TYPE_WARNING 6

/*
	Each package is uint16 + data , uint16 (serialized in big-endian) is the number of bytes comprising the data .
 */

//自定义消息结构体
//注意：不要用内存映射访问，用toprotolhead来访问
#pragma pack(1)
typedef struct protocolhead
{
	uint8_t head;
	uint8_t version;
	int length;
	short checksum;
	int serial;
	short cmd;
	uint64_t session;
} protocolhead;

#pragma pack(1)
typedef struct netprotocol
{
	protocolhead head;
	uint8_t *protobuf;
} netprotocol;

protocolhead toprotocolhead(uint8_t *buffer)
{
	protocolhead head;
	head.head = buffer[0];
	head.version = buffer[1];
	head.length = (uint32_t)buffer[2] << 24 | (uint32_t)buffer[3] << 16 | (uint32_t)buffer[4] << 8 | (uint32_t)buffer[5];
	head.checksum = (uint16_t)buffer[6] << 8 | (uint16_t)buffer[7];
	head.serial = (uint32_t)buffer[8] << 24 | (uint32_t)buffer[9] << 16 | (uint32_t)buffer[10] << 8 | (uint32_t)buffer[11];
	head.cmd = (uint16_t)buffer[12] << 8 | (uint16_t)buffer[13];
	head.session = (uint64_t)buffer[14] << 56 | (uint64_t)buffer[15] << 48 | (uint64_t)buffer[16] << 40 | (uint64_t)buffer[17] << 32 | (uint64_t)buffer[18] << 24 | (uint64_t)buffer[19] << 16 | (uint64_t)buffer[20] << 8 | (uint64_t)buffer[21];
	return head;
}

void setbuffer_session(uint8_t *buffer, int fd)
{
	buffer[18] = (fd & 0xFF) >> 24;
	buffer[19] = (fd & 0xFF) >> 16;
	buffer[20] = (fd & 0xFF) >> 8;
	buffer[21] = (fd & 0xFF);
}

struct netpackext
{
	int id;
	int size;
	void *buffer;
};

struct uncomplete
{
	struct netprotocol protocol;
	struct uncomplete *next;
	int read;
	int fd;
};

struct queue
{
	int cap;
	int head;
	int tail;
	struct uncomplete *hash[HASHSIZE];
	struct netpackext queue[QUEUESIZE];
};

static void
clear_list(struct uncomplete *uc)
{
	while (uc)
	{
		if (uc->protocol.protobuf)
		{
			skynet_free(uc->protocol.protobuf);
		}
		void *tmp = uc;
		uc = uc->next;
		skynet_free(tmp);
	}
}

static int
lclear(lua_State *L)
{
	struct queue *q = lua_touserdata(L, 1);
	if (q == NULL)
	{
		return 0;
	}
	int i;
	for (i = 0; i < HASHSIZE; i++)
	{
		clear_list(q->hash[i]);
		q->hash[i] = NULL;
	}
	if (q->head > q->tail)
	{
		q->tail += q->cap;
	}
	for (i = q->head; i < q->tail; i++)
	{
		struct netpackext *np = &q->queue[i % q->cap];
		skynet_free(np->buffer);
	}
	q->head = q->tail = 0;

	return 0;
}

static inline int
hash_fd(int fd)
{
	int a = fd >> 24;
	int b = fd >> 12;
	int c = fd;
	return (int)(((uint32_t)(a + b + c)) % HASHSIZE);
}

static struct uncomplete *
find_uncomplete(struct queue *q, int fd)
{
	if (q == NULL)
		return NULL;
	int h = hash_fd(fd);
	struct uncomplete *uc = q->hash[h];
	if (uc == NULL)
		return NULL;
	if (uc->fd == fd)
	{
		q->hash[h] = uc->next;
		return uc;
	}
	//hash冲突，可能不同fd对应同一个slot，根据id == fd区分
	struct uncomplete *last = uc;
	while (last->next)
	{
		uc = last->next;
		if (uc->fd == fd)
		{
			last->next = uc->next;
			return uc;
		}
		last = uc;
	}
	return NULL;
}

static struct queue *
get_queue(lua_State *L)
{
	struct queue *q = lua_touserdata(L, 1);
	//栈顶是空
	if (q == NULL)
	{
		q = lua_newuserdata(L, sizeof(struct queue)); //这时候栈排列是 nil queue *
		q->cap = QUEUESIZE;
		q->head = 0;
		q->tail = 0;
		int i;
		for (i = 0; i < HASHSIZE; i++)
		{
			q->hash[i] = NULL;
		}
		lua_replace(L, 1); //执行之后就变成 queue *
	}
	return q;
}

static void
expand_queue(lua_State *L, struct queue *q)
{
	struct queue *nq = lua_newuserdata(L, sizeof(struct queue) + q->cap * sizeof(struct netpackext));
	nq->cap = q->cap + QUEUESIZE;
	nq->head = 0;
	nq->tail = q->cap;
	memcpy(nq->hash, q->hash, sizeof(nq->hash));
	memset(q->hash, 0, sizeof(q->hash));
	int i;
	for (i = 0; i < q->cap; i++)
	{
		int idx = (q->head + i) % q->cap;
		nq->queue[i] = q->queue[idx];
	}
	q->head = q->tail = 0;
	lua_replace(L, 1);
}

static void
push_data(lua_State *L, int fd, void *buffer, int size, int clone)
{
	//clone下一个包到buff头部
	if (clone)
	{
		void *tmp = skynet_malloc(size);
		memcpy(tmp, buffer, size);
		buffer = tmp;
	}
	//获取buff队列
	struct queue *q = get_queue(L);
	struct netpackext *np = &q->queue[q->tail];
	if (++q->tail >= q->cap)
		q->tail -= q->cap;
	np->id = fd;
	np->buffer = buffer;
	np->size = size;
	if (q->head == q->tail)
	{
		expand_queue(L, q);
	}
}

static struct uncomplete *
save_uncomplete(lua_State *L, int fd)
{
	struct queue *q = get_queue(L);
	int h = hash_fd(fd);
	struct uncomplete *uc = skynet_malloc(sizeof(struct uncomplete));
	memset(uc, 0, sizeof(*uc));
	uc->next = q->hash[h];
	uc->fd = fd;
	q->hash[h] = uc;
	return uc;
}

static int
push_more(lua_State *L, int fd, uint8_t *buffer, int size)
{
	if (size == 0)
	{
		return 0;
	}
	//收到数据不足判断头部数据
	if (size < sizeof(protocolhead))
	{
		struct uncomplete *uc = save_uncomplete(L, fd);
		uc->read = size;
		memcpy(&uc->protocol.head, buffer, size);
		return 1;
	}
	//收到数据超过头部数据
	setbuffer_session(buffer, fd);
	protocolhead head = toprotocolhead(buffer);
	//需要加入检测长度
	int pack_size = head.length + sizeof(protocolhead);
	if (size < pack_size)
	{
		struct uncomplete *uc = save_uncomplete(L, fd);
		uc->read = size;
		memcpy(&uc->protocol.head, buffer, sizeof(protocolhead));
		if(head.length)
		{
			uc->protocol.protobuf = skynet_malloc(head.length);
		}
		buffer += sizeof(protocolhead);
		memcpy(uc->protocol.protobuf, buffer, size - sizeof(protocolhead));
		return 1;
	}
	push_data(L, fd, buffer, pack_size, 1);

	buffer += pack_size;
	size -= pack_size;
	if (size > 0)
	{
		return push_more(L, fd, buffer, size);
	}
	return 0;
}

static void
close_uncomplete(lua_State *L, int fd)
{
	struct queue *q = lua_touserdata(L, 1);
	struct uncomplete *uc = find_uncomplete(q, fd);
	if (uc)
	{
		if (uc->protocol.protobuf)
		{
			skynet_free(uc->protocol.protobuf);
		}
		skynet_free(uc);
	}
}

static int
filter_data_(lua_State *L, int fd, uint8_t *buffer, int size)
{
	//获取lua传入的队列，tcpserver.lua 里
	//netpackext.filter( queue, msg, sz)
	struct queue *q = lua_touserdata(L, 1);
	//查找未完成的包，粘包过程
	struct uncomplete *uc = find_uncomplete(q, fd);
	if (uc)
	{
		// 包头还没有获取完全
		if (uc->read + size < sizeof(protocolhead))
		{
			memcpy((uint8_t *)&uc->protocol.head + uc->read, buffer, size);
			uc->read += size;
			return 1;
		}
		//包头还没读取完全
		if (uc->read < sizeof(protocolhead))
		{
			int need = sizeof(protocolhead) - uc->read;
			memcpy((uint8_t *)&uc->protocol.head + uc->read, buffer, need);
			buffer += need;
			size -= need;
			uc->read += need;
		}
		//需要加入检测长度,出问题要释放掉UC
		setbuffer_session((uint8_t *)&uc->protocol.head, fd);
		protocolhead head = toprotocolhead((uint8_t *)&uc->protocol.head);
		int pack_size = head.length + sizeof(protocolhead);
		if (head.length && !uc->protocol.protobuf)
		{
			uc->protocol.protobuf = skynet_malloc(head.length);
		}
		int protobuf_read = uc->read - sizeof(protocolhead);
		// 包体还没接受完
		if (uc->read + size < pack_size)
		{
			memcpy(uc->protocol.protobuf + protobuf_read, buffer, size);
			uc->read += size;
			return 1;
		}
		if (uc->read + size == pack_size)
		{
			memcpy(uc->protocol.protobuf + protobuf_read, buffer, size);
			uc->read += size;
			lua_pushvalue(L, lua_upvalueindex(TYPE_DATA));
			lua_pushinteger(L, fd);
			uint8_t *result = skynet_malloc(pack_size);
			memcpy(result, (uint8_t *)&uc->protocol.head, sizeof(protocolhead));
			if(head.length)
			{
				memcpy(result + sizeof(protocolhead), uc->protocol.protobuf, head.length);
			}
			lua_pushlightuserdata(L, result);
			lua_pushinteger(L, pack_size);
			skynet_free(uc);
			return 5;
		}
		//更多的包信息
		push_data(L, fd, buffer, pack_size, 1);
		skynet_free(uc);
		buffer += pack_size;
		size -= pack_size;
		int ret = push_more(L, fd, buffer, size);
		if (ret)
		{
			//加入包大小异常判断
		}
		lua_pushvalue(L, lua_upvalueindex(TYPE_MORE));
		return 2;
	}
	else
	{
		//收到数据不足判断头部数据
		if (size < sizeof(protocolhead))
		{
			struct uncomplete *uc = save_uncomplete(L, fd);
			uc->read = size;
			memcpy(&uc->protocol.head, buffer, size);
			return 1;
		}
		//收到数据超过头部数据
		setbuffer_session(buffer, fd);
		protocolhead head = toprotocolhead(buffer);
		//需要加入检测长度
		int pack_size = head.length + sizeof(protocolhead);
		if (size == pack_size)
		{
			lua_pushvalue(L, lua_upvalueindex(TYPE_DATA));
			lua_pushinteger(L, fd);
			void *result = skynet_malloc(pack_size);
			memcpy(result, buffer, size);
			lua_pushlightuserdata(L, result);
			lua_pushinteger(L, size);
			return 5;
		}
		else if (size < pack_size)
		{
			struct uncomplete *uc = save_uncomplete(L, fd);
			uc->read = size;
			memcpy(&uc->protocol.head, buffer, sizeof(protocolhead));
			uc->protocol.protobuf = skynet_malloc(uc->protocol.head.length);
			buffer += sizeof(protocolhead);
			memcpy(&uc->protocol.protobuf, buffer, size - sizeof(protocolhead));
			return 1;
		}
		//更多的包信息
		push_data(L, fd, buffer, pack_size, 1);
		buffer += pack_size;
		size -= pack_size;
		int ret = push_more(L, fd, buffer, size);
		if (ret)
		{
			//加入包大小异常判断
		}
		lua_pushvalue(L, lua_upvalueindex(TYPE_MORE));
		return 2;
	}
}

static inline int
filter_data(lua_State *L, int fd, uint8_t *buffer, int size)
{
	int ret = filter_data_(L, fd, buffer, size);
	// buffer is the data of socket message, it malloc at socket_server.c : function forward_message .
	// it should be free before return,
	skynet_free(buffer);
	return ret;
}

static void
pushstring(lua_State *L, const char *msg, int size)
{
	if (msg)
	{
		lua_pushlstring(L, msg, size);
	}
	else
	{
		lua_pushliteral(L, "");
	}
}

/*
	userdata queue
	lightuserdata msg
	integer size
	return
		userdata queue
		integer type
		integer fd
		string msg | lightuserdata/integer
 */

static int
lfilter(lua_State *L)
{
	struct skynet_socket_message *message = lua_touserdata(L, 2);
	int size = luaL_checkinteger(L, 3);
	char *buffer = message->buffer;
	if (buffer == NULL)
	{
		buffer = (char *)(message + 1);
		size -= sizeof(*message);
	}
	else
	{
		size = -1;
	}

	lua_settop(L, 1);

	switch (message->type)
	{
	case SKYNET_SOCKET_TYPE_DATA:
		// ignore listen id (message->id)
		assert(size == -1); // never padding string
		return filter_data(L, message->id, (uint8_t *)buffer, message->ud);
	case SKYNET_SOCKET_TYPE_CONNECT:
		// ignore listen fd connect
		return 1;
	case SKYNET_SOCKET_TYPE_CLOSE:
		// no more data in fd (message->id)
		close_uncomplete(L, message->id);
		lua_pushvalue(L, lua_upvalueindex(TYPE_CLOSE));
		lua_pushinteger(L, message->id);
		return 3;
	case SKYNET_SOCKET_TYPE_ACCEPT:
		lua_pushvalue(L, lua_upvalueindex(TYPE_OPEN));
		// ignore listen id (message->id);
		lua_pushinteger(L, message->ud);
		pushstring(L, buffer, size);
		return 4;
	case SKYNET_SOCKET_TYPE_ERROR:
		// no more data in fd (message->id)
		close_uncomplete(L, message->id);
		lua_pushvalue(L, lua_upvalueindex(TYPE_ERROR));
		lua_pushinteger(L, message->id);
		pushstring(L, buffer, size);
		return 4;
	case SKYNET_SOCKET_TYPE_WARNING:
		lua_pushvalue(L, lua_upvalueindex(TYPE_WARNING));
		lua_pushinteger(L, message->id);
		lua_pushinteger(L, message->ud);
		return 4;
	default:
		// never get here
		return 1;
	}
}

/*
	userdata queue
	return
		integer fd
		lightuserdata msg
		integer size
 */
static int
lpop(lua_State *L)
{
	struct queue *q = lua_touserdata(L, 1);
	if (q == NULL || q->head == q->tail)
		return 0;
	struct netpackext *np = &q->queue[q->head];
	if (++q->head >= q->cap)
	{
		q->head = 0;
	}
	lua_pushinteger(L, np->id);
	lua_pushlightuserdata(L, np->buffer);
	lua_pushinteger(L, np->size);

	return 3;
}

/*
	string msg | lightuserdata/integer

	lightuserdata/integer
 */

static const char *
tolstring(lua_State *L, size_t *sz, int index)
{
	const char *ptr;
	if (lua_isuserdata(L, index))
	{
		ptr = (const char *)lua_touserdata(L, index);
		*sz = (size_t)luaL_checkinteger(L, index + 1);
	}
	else
	{
		ptr = luaL_checklstring(L, index, sz);
	}
	return ptr;
}

static inline void
write_size(uint8_t *buffer, int len)
{
	buffer[0] = (len >> 8) & 0xff;
	buffer[1] = len & 0xff;
}

static int
lpack(lua_State *L)
{
	size_t len;
	const char *ptr = tolstring(L, &len, 1);
	if (len >= 0x10000)
	{
		return luaL_error(L, "Invalid size (too long) of data : %d", (int)len);
	}

	uint8_t *buffer = skynet_malloc(len + 2);
	write_size(buffer, len);
	memcpy(buffer + 2, ptr, len);

	lua_pushlightuserdata(L, buffer);
	lua_pushinteger(L, len + 2);

	return 2;
}

static int
ltostring(lua_State *L)
{
	void *ptr = lua_touserdata(L, 1);
	int size = luaL_checkinteger(L, 2);
	if (ptr == NULL)
	{
		lua_pushliteral(L, "");
	}
	else
	{
		lua_pushlstring(L, (const char *)ptr, size);
		skynet_free(ptr);
	}
	return 1;
}

LUAMOD_API int
luaopen_skynet_netpackext(lua_State *L)
{
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{"pop", lpop},
		{"pack", lpack},
		{"clear", lclear},
		{"tostring", ltostring},
		{NULL, NULL},
	};
	luaL_newlib(L, l);

	// the order is same with macros : TYPE_* (defined top)
	lua_pushliteral(L, "data");
	lua_pushliteral(L, "more");
	lua_pushliteral(L, "error");
	lua_pushliteral(L, "open");
	lua_pushliteral(L, "close");
	lua_pushliteral(L, "warning");

	lua_pushcclosure(L, lfilter, 6);
	lua_setfield(L, -2, "filter");

	return 1;
}
