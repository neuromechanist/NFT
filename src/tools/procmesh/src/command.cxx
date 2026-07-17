// $Id: command.cxx,v 1.14 2008/04/16 08:11:27 canacar Exp $

#include <stdio.h>
#include <ctype.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include "command.h"
#include "procmesh.h"

int cmd_show (char *, int);
int cmd_sleep (char *, int);
int cmd_input (char *, int);
int cmd_echo (char *, int);
int cmd_eps_save(char *, int);
int cmd_quit (char *, int);
int cmd_capture (char *, int);
int cmd_animate (char *, int);
int cmd_load (char *, int);
int cmd_pload (char *, int);
int cmd_psave (char *, int);
int cmd_notimp (char *, int);
int cmd_refresh (char *, int);
int cmd_save(char *, int);
int cmd_smooth(char *, int);
int cmd_correct(char *, int);
int cmd_extract(char *, int);
int cmd_improve(char *, int);
int cmd_fill_holes(char *, int);
int cmd_split(char *, int);
int cmd_fix(char *, int);

int cmd_var_done = 0;
int cmd_var_echo = 1;
int cmd_display = 0;

struct comdef {
	const char *cmd;
	int (*run)(char *, int);
	int sel;
};

struct comdef root[] = {{"show", cmd_show, 0},
			{"hide", cmd_notimp, 0},
			{"set", cmd_notimp, 0},
			{"sleep", cmd_sleep, 0},
			{"load", cmd_load, 0},
			{"pload", cmd_notimp, 0},
			{"psave", cmd_notimp, 0},
			{"nfield", cmd_notimp, 0},
			{"save", cmd_save, 0},
			{"epssave", cmd_notimp, 0},
			{"smooth", cmd_smooth, 0},
			{"correct", cmd_correct, 0},
			{"improve", cmd_improve, 0},
			{"extract", cmd_extract, 0},
			{"fill", cmd_fill_holes, 0},
			{"fix", cmd_fix, 0},
			{"split", cmd_split, 0},
			{"echo", cmd_echo, 0},
			{"quit", cmd_quit, 0},
			{"capture", cmd_notimp, 0},
			{"animate", cmd_notimp, 0},
			{"input", cmd_input, 0},
			{"refresh", cmd_refresh, 0},
			{"script", cmd_input, 1},
			{"info", cmd_notimp, 0},
			{"mark", cmd_notimp, 0},
			{"unmark", cmd_notimp, 1},
			{0,0,0}};

ProcessMesh *cmd_window = NULL;

void
set_window(ProcessMesh *pm)
{
	cmd_window = pm;
	cmd_var_done = 0;
}

void
echo(int on)
{
	cmd_var_echo = on;
}

void
skip_ws(char **buf)
{
	assert(buf);
	assert (*buf);

	while (isspace(**buf)) (*buf)++;
}

void strip_ws(char *buf)
{
	assert(buf);

	for (int len = strlen(buf) - 1; len >= 0; len --)
		if (isspace(buf[len]))
			buf[len] = 0;
		else
			break;

}

#define MAX_TOKEN 16

int
get_token(char *tok, char **cmd)
{
	assert (tok);
	int len = 0;
	char *c = *cmd;

	
	for (int n = 0; n < MAX_TOKEN; n++) {
		if ( isalnum (*c) ) {
			*tok ++ = *c ++;
			len ++;
		} else {
			*tok = 0;
			*cmd = c;
			return len;
		}
	}

	tok[0] = 0;

	return 0;
}

int
command(char *cmd, struct comdef *def)
{
	char buf[MAX_TOKEN];

	if (cmd == NULL)
		return 1;
	if (def == NULL)
		return 1;

	skip_ws(&cmd);

	if ( *cmd == 0 || *cmd == '#' )
		return 0;

	if (get_token(buf, &cmd) == 0) {
		return 1;
	}

	for (struct comdef *c = def; c->cmd; c++) {
		if (strcmp(c->cmd, buf) == 0)
			return c->run(cmd, c->sel);
	}

	printf("Not found >%s< commands:", cmd);
	while (def->cmd)
		printf(" %s", (def++)->cmd);
	printf("\n");

	return 1;
}

int
execute(const char *cm)
{
	char *cmd;
	int ret;
	if (cm == NULL)
		return 1;

	cmd = strdup(cm);

	strip_ws(cmd);

	if (cmd_var_echo)
		printf (" > %s \n", cmd);

	ret = command(cmd, root);
	free(cmd);

	return ret;
}

#define MAX_DEPTH 10

int
command_file (char *fn)
{
	static int depth = 0;

	FILE *f = 0;

	if (strcmp(fn , "-") == 0)
		f=stdin;
	else	
		f = fopen(fn, "r");

	if (f == NULL) {
		perror ("Failed to open");
		return 1;
	}

	if (depth > MAX_DEPTH) {
		printf ("Max input depth exceeded!\n");
		return 1;
	}

	depth ++;

	char *buf = new char[MAX_LINE];

	int ret = 0;
	cmd_var_done = 0;

	while (!feof(f)) {
		if (fgets(buf, MAX_LINE, f) == NULL)
			break;

		strip_ws(buf);

		if (cmd_var_echo)
			printf (" > %s \n", buf);

		ret = command (buf, root);
		if (ret) break;
		if (cmd_var_done)
			break;

	}

	depth --;

	delete[] buf;
	fclose(f);
	return ret;
}

// show command

int
cmd_proc_sharp(char *arg, int sel)
{
	int nm = cmd_window->numMeshes();

	skip_ws(&arg);
	if (strncasecmp(arg, "all", 3) == 0) {
                for (int n=0; n<nm; n++)
			cmd_window->process_sharp_edges(n, sel);
                return 0;
        }

	int n = atoi(arg);
        if (n < 0 || n >= nm) {
                printf ("invalid mesh number %d\n", n);
                return 1;
        }

	cmd_window->process_sharp_edges(n, sel);

        return 0;
}

int
cmd_proc_intersect(char *arg, int sel)
{
	int nm = cmd_window->numMeshes();

	skip_ws(&arg);
	if (strncasecmp(arg, "all", 3) == 0) {
                for (int n=0; n<nm; n++)
			cmd_window->process_intersecting(n, sel);
                return 0;
        }

	int n = atoi(arg);
        if (n < 0 || n >= nm) {
                printf ("invalid mesh number %d\n", n);
                return 1;
        }

	cmd_window->process_intersecting(n, sel);

        return 0;
}

struct comdef cd_show[]={{"intersect", cmd_proc_intersect, 0},
                         {"sharp", cmd_proc_sharp, 0},
			 {0,0,0}};
int
cmd_show (char *arg, int sel)
{
	return command (arg, cd_show);
}


// fix command

struct comdef cd_fix[]={{"intersect", cmd_proc_intersect, 1},
                         {"sharp", cmd_proc_sharp, 1},
                         {"holes", cmd_fill_holes, 1},
			 {0,0,0}};
int
cmd_fix (char *arg, int sel)
{
	return command (arg, cd_fix);
}

// sleep command

int
cmd_sleep (char *arg, int sel)
{
	assert (arg);
	int del = atoi(arg);
	if (del < 1) return 1;
#ifdef __WIN32__ 
	printf ("Sleep not supported yet\n");
#else
	printf ("Sleeping %d seconds ...\n", del);
	sleep(del);
#endif
	return 0;
}

// input command

int
cmd_input (char *arg, int sel)
{
	assert (arg);
	skip_ws(&arg);
	strip_ws(arg);

	if (sel) {
		printf ("Running script from file >%s<\n", arg);
		if (command_script(arg)) {
			printf("Error!\n");
			return 1;
		}
	} else {
		printf ("Running commands from file >%s<\n", arg);
		if (command_file(arg)) {
			printf("Error!\n");
			return 1;
		}
	}
	printf ("Done.\n");
	return 0;
}

// load command

int
cmd_load (char *arg, int sel)
{
	assert (arg);
	skip_ws(&arg);
	strip_ws(arg);

	if (cmd_window->addMesh(arg) == NULL) {
		printf("Error!\n");
		return 1;
	}
	printf ("Done.\n");
	return 0;
}

int
cmd_save(char *arg, int sel)
{
	int fc;
	assert (arg);
	skip_ws(&arg);
	strip_ws(arg);

	if (sel) {
		fc = 0;
		printf("Saving first mesh first class as: %s\n", arg);
	} else {
		fc = -1;
		printf("Saving mesh as: %s\n", arg);
	}

	if (cmd_window->save_mesh(arg, 0, fc)) {
		printf("Error!\n");
		return 1;
	}

	printf ("Done.\n");
	return 0;
}

int
cmd_smooth(char *arg, int sel)
{
	assert(arg);
	skip_ws(&arg);
	strip_ws(arg);

	int cnt = atoi(arg);
	if (cnt <= 0)
		cnt = 1;

	printf("Smoothing first mesh %d times\n", cnt);
	if (cmd_window->smooth_mesh(0, cnt)) {
		printf("Error!\n");
		return 1;
	}
	printf ("Done.\n");
	return 0;
}

int
cmd_correct(char *arg, int sel)
{
	printf("Correcting first mesh\n");
	if (cmd_window->correct_mesh(0)) {
		printf("Error!\n");
		return 1;
	}
	printf ("Done.\n");
	return 0;
}

int
cmd_fill_holes(char *arg, int sel)
{
	printf("Correcting first mesh\n");
	if (cmd_window->fill_holes(0)) {
		printf("Error!\n");
		return 1;
	}
	printf ("Done.\n");
	return 0;
}

int
cmd_improve(char *arg, int sel)
{
	int cnt, na;
	double aspect, esize;
	assert (arg);
	skip_ws(&arg);
	strip_ws(arg);

	na = sscanf(arg, "%d %lg %lg", &cnt, &aspect, &esize);
	if (na < 1 || cnt < 1)
		cnt = 1;
	if (na < 2 || aspect < 0)
		aspect = 0.001;
	if (na < 3 || esize < 0)
		esize = 0.001;
	printf("Improving first mesh %d times\n", cnt);
	printf(" Element Aspect: %g, Size Ratio: %g \n", aspect, esize);
	if (cmd_window->improve_mesh(0, cnt, aspect, esize)) {
		printf("Error!\n");
		return 1;
	}
	printf ("Done.\n");
	return 0;
}

int
cmd_extract(char *arg, int sel)
{
	assert (arg);
	skip_ws(&arg);
	strip_ws(arg);

	int cls;

	if (*arg == '\0')
		cls = -1;
	else
		cls = atoi(arg);

	printf("Extracting class %d from the first mesh\n", cls);
	if (cmd_window->extract_class(0, cls)) {
		printf("Error!\n");
		return 1;
	}
	printf ("Done.\n");
	return 0;
}

int
cmd_split(char *arg, int sel)
{
	assert (arg);
	skip_ws(&arg);
	strip_ws(arg);

	if (strncmp(arg, "edges", 5) == 0) {
		arg += 5;
		skip_ws(&arg);

		double thresh = atof(arg);
		if (thresh <= 0)
			thresh = 1;

		printf("Splitting edges with threshold %g\n", thresh);
		if (cmd_window->split_mesh(0, thresh)) {
			printf("Error!\n");
			return 1;
		}
	} else if (strncmp(arg, "intersect", 9) == 0){
		printf("Splitting intersecting elements\n");
		if (cmd_window->split_intersecting(0)) {
			printf("Error!\n");
			return 1;
		}
	} else {
		printf("'split edges <thresh>' or 'split intersect'\n");
		return 1;
	}

	printf ("Done.\n");
	return 0;
}


// command not implemented

int
cmd_notimp (char *arg, int sel)
{
	printf ("Not implemented!\n");
	return 0;
}

// echo command

int
cmd_echo (char *arg, int sel)
{
	printf (">> %s\n", arg);
	return 0;
}

// refresh command

int
cmd_refresh (char *arg, int sel)
{
	printf ("refresh\n");
        cmd_display = 1;
	return 0;
}

// quit command

int
cmd_quit (char *arg, int sel)
{
	printf ("Quit command ...\n");
	cmd_var_done = 1;
	return 0;
}

FILE *command_fd = 0;

int command_script(char *fn)
{
        if (fn == NULL) return 1;

        if (command_fd) {
                printf("Stopping already running script\n");
                fclose(command_fd);
        }
        command_fd = fopen(fn, "r");
        if (command_fd == NULL) {
                printf ("Failed to open script file %s\n", fn);
                return 1;
        }
        return 0;
}

int
command_need_loop(void)
{
	int loop = command_fd && !cmd_var_done;

	printf("need_loop: %s\n", loop ? "yes" : "no");

	return loop;
}

int
command_loop(ProcessMesh *pm)
{
	static char buf[MAX_LINE];
	printf("Command loop!\n");

	if (cmd_window == NULL)
		cmd_window = pm;

	if (cmd_window != pm)
		return 0;

        if (command_fd == NULL)
                return 0;

	if (fgets(buf, MAX_LINE, command_fd) == NULL) {
		fclose(command_fd);
                command_fd = NULL;
                return 0;
        }

	strip_ws(buf);

	if (cmd_var_echo)
		printf (" > %s \n", buf);

        cmd_display = 0;
	int ret = command (buf, root);
        if (ret) {
                printf ("Error!\n");
                return 0;
        }

        return cmd_display;
}
