//	$Id: main.cxx,v 1.3 2008/02/11 07:23:36 canacar Exp $
#include <string.h>
#include <stdio.h>

#include "procmesh.h"
#include "command.h"

extern "C" {
size_t strlcpy(char *dst, const char *src, size_t len);
}

int
main(int argc, char *argv[])
{
	static char fn[FILENAME_MAX+1];
	char *cmdfn = NULL;
	ProcessMesh pm;

	setvbuf(stdout, NULL, _IONBF, 0);
	setvbuf(stderr, NULL, _IONBF, 0);

	printf("ProcessMesh by Can Erkin Acar, 2001-2009\n");

	if (argc < 2) {
		printf("Enter filename:\n");
		fgets(fn, FILENAME_MAX, stdin);
		char *z = strchr(fn,'\n');
		if (z)
			*z = 0;
		pm.addMesh(fn);
	}

	if (argc >= 3 && strcmp(argv[1], "-c") == 0) {
		cmdfn = strdup(argv[2]);
		argv += 2;
		argc -= 2;
	}

	for (int n = 1; n < argc; n++) {
		strlcpy(fn, argv[n], FILENAME_MAX);
		pm.addMesh(fn);
	}

	if (pm.numMeshes() < 1 && cmdfn == NULL)
		printf ("Warning: Failed to load any mesh!\n");


	if (cmdfn != NULL) {
		printf("Running commands from %s\n", cmdfn);
		set_window(&pm);
		command_file(cmdfn);
	}

	return 0;
}
