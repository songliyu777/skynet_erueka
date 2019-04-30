#include "skynet.h"

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

struct logger
{
	FILE *handle;
	char *filename;
	int close;
};

struct logger *
logger_create(void)
{
	struct logger *inst = skynet_malloc(sizeof(*inst));
	inst->handle = NULL;
	inst->close = 0;
	inst->filename = NULL;

	return inst;
}

void logger_release(struct logger *inst)
{
	if (inst->close)
	{
		fclose(inst->handle);
	}
	skynet_free(inst->filename);
	skynet_free(inst);
}

// echo -e "\033[30m 黑色字 \033[0m"
// echo -e "\033[31m 红色字 \033[0m"
// echo -e "\033[32m 绿色字 \033[0m"
// echo -e "\033[33m 黄色字 \033[0m"
// echo -e "\033[34m 蓝色字 \033[0m"
// echo -e "\033[35m 紫色字 \033[0m"
// echo -e "\033[36m 天蓝字 \033[0m"
// echo -e "\033[37m 白色字 \033[0m"

// echo -e "\033[40;37m 黑底白字 \033[0m"
// echo -e "\033[41;37m 红底白字 \033[0m"
// echo -e "\033[42;37m 绿底白字 \033[0m"
// echo -e "\033[43;37m 黄底白字 \033[0m"
// echo -e "\033[44;37m 蓝底白字 \033[0m"
// echo -e "\033[45;37m 紫底白字 \033[0m"
// echo -e "\033[46;37m 天蓝底白字 \033[0m"
// echo -e "\033[47;30m 白底黑字 \033[0m"

static int
logger_cb(struct skynet_context *context, void *ud, int type, int session, uint32_t source, const void *msg, size_t sz)
{
	struct logger *inst = ud;
	switch (type)
	{
	case PTYPE_SYSTEM:
		if (inst->filename)
		{
			inst->handle = freopen(inst->filename, "a", inst->handle);
		}
		break;
	case PTYPE_TEXT:
		if (sz > 1 && *(char *)msg == 'I' && *((char *)msg + 1) == '[')
		{
			//绿色
			fprintf(inst->handle, "\033[32m");
		}
		else if (sz > 1 && *(char *)msg == 'W' && *((char *)msg + 1) == '[')
		{
			//黄色
			fprintf(inst->handle, "\033[33m");
		}
		else if (sz > 1 && *(char *)msg == 'E' && *((char *)msg + 1) == '[')
		{
			//红色
			fprintf(inst->handle, "\033[31m");
		}
		else
		{
			//白色
			fprintf(inst->handle, "\033[37m");
		}
		fprintf(inst->handle, "[:%08x] ", source);
		fwrite(msg, sz, 1, inst->handle);
		fprintf(inst->handle, "\033[0m\n");
		fflush(inst->handle);
		break;
	}

	return 0;
}

int logger_init(struct logger *inst, struct skynet_context *ctx, const char *parm)
{
	if (parm)
	{
		inst->handle = fopen(parm, "w");
		if (inst->handle == NULL)
		{
			return 1;
		}
		inst->filename = skynet_malloc(strlen(parm) + 1);
		strcpy(inst->filename, parm);
		inst->close = 1;
	}
	else
	{
		inst->handle = stdout;
	}
	if (inst->handle)
	{
		skynet_callback(ctx, inst, logger_cb);
		return 0;
	}
	return 1;
}
