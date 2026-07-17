/* $Id: command.h,v 1.1.1.1 2007/12/30 04:44:24 canacar Exp $ */

#ifndef _COMMAND_H_
#define _COMMAND_H_

#define MAX_LINE 1024
#include "procmesh.h"

void set_window(ProcessMesh *sm);
int execute(const char *cmd);
int command_file (char *fn);
int command_script (char *fn);
int command_loop(ProcessMesh *sm);
int command_need_loop(void);
void echo(int on);

#endif
