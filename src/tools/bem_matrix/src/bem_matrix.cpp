/* $Id: bem_matrix.cpp,v 1.5 2008/04/21 06:22:16 canacar Exp $ */
/* 
 * This file is part of the EMSI Tools Package developed at the
 * Brain Research Laboratory, Middle East Technical University
 * Department of Electrical and Electronics Engineering.
 *
 * Copyright (C) 2008 Zeynep Akalin Acar
 * Copyright (C) 2008 Can Erkin Acar
 * Copyright (C) 2008 Nevzat G. Gencer
 * 
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

/* 28.2.2001 */
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "bemmesh.h"
#include "matrow.h"
#include "shape.h"
#include "magnetic.h"
#include "hptimer.h"
#include "meshutil.h"
#include "bem_engine.h"

//---------------------------------------------------------------------------
void
usage(void)
{
	fprintf(stderr,
		"\nGenerate BEM coefficient matrices, including"
		" inner matrices for IPA\n\n"
		"Usage: bem_matrix [-f matname] [-m magsens] [-o mod] \n"
		"               meshname [s=sig ...]\n"
		"       -f: save matrices to matname.[ci]mat\n"
		"	    (default meshname)\n"
		"       -m: magnetic sensor file name\n"
		"       -o: interface to use with modified equations\n"
		"           (1: outer, 0: to disable)\n"
		"	s=sig:	s:region (1: outer), sig: conductivity\n"
		"           (default conductivity: 0.2 for all regions)\n");
	exit(1);
}

#ifndef MAX_PATH
#define MAX_PATH 1024
#endif

void
report_callback(void)
{
    HPTimerMgr::report();
}

//---------------------------------------------------------------------------
// Main
int
main(int argc, char* argv[])
{
	BEMesh mesh; // initialize with default cond. profile
	matFullRowStatic *Hmat = NULL;
	matRow *magsens = NULL;
	char *sname = NULL;
	char *sensfn = NULL;
	int ch, mod = 0;
	
	while ((ch = getopt(argc, argv, "f:o:m:")) != -1) {
		switch (ch) {
		case 'f':
			sname = optarg;
			break;
		case 'm':
			sensfn = optarg;
			break;
		case 'o':
			mod = atoi(optarg);
			break;
		default:
			usage();
		}
	}

	argc -= optind;
	argv += optind;

	if (argc <= 0)
		usage();
    
	if (mesh.loadMesh(argv[0])){
		printf("Error loading mesh!\n");
		return 1;
	}

	printf("Mesh loaded: %d nodes, %d elements, "
	       "%d nodes/element, %d boundaries\n",
	       mesh.numNodes(), mesh.numElements(),
	       mesh.numNodeElem(), mesh.numBoundaries());

	if (sname == NULL)
		sname = argv[0];

	if (sensfn != NULL) {
		FILE *f = fopen(sensfn, "r");
		if (f == NULL) {
			perror("Loading sensor file");
			return 1;
		}
		magsens = mag_loadSens(f);
		fclose(f);
		if (magsens == NULL) {
			printf("Failed to load magnetic sensors\n");
			return 1;
		}
		Hmat = new matFullRowStatic(mesh.numNodes(),
		    magsens->numRows() * 3);
		if (Hmat == NULL) {
			printf("Failed to allocate H matrix\n");
			return 1;
		}
	}
		
	for (int n = 1; n < argc; n++){
		if (setSigma(mesh, argv[n])){
			printf("Failed to set sigma for argument: %s\n",
			       argv[n]);
			return 1;
		}
	}

	atexit(report_callback);

	GPStore *gps = setupGPStore(mesh);

	if (Hmat == NULL) {
		/* Generate BEM matrices */

		matFullRowStatic Cmat(mesh.numNodes(), mesh.numNodes());
    
		HPTimer *t1 = HPTimerMgr::getTimer("Matrix Computation time");

		t1->start();

		Cmat.clear();

		if (mesh.numBoundaries() < 2 || mod <= 0){
			if (mesh.numBoundaries() < 2)
				printf("Single layer\n");
			else
				printf("Multi layer, not modified\n");
			singleLayer(mesh, Cmat, *gps, NULL, sname);
		} else {
			printf("Multi layer, layer %d modified\n",mod);
			multiLayer(mesh, Cmat, *gps, mod-1, NULL, sname, 0);
		}

		t1->stop();
	} else {
		/* Generate BEM matrix for secondary magnetic field */

		HPTimer *t2 = HPTimerMgr::getTimer(
		    "Magnetic matrix Computation time");
		t2->start();

		mag_secondary(mesh, *gps, magsens, *Hmat);

		saveMat(*Hmat, sname, "Hmt");
		
		t2->stop();
	}

	return 0;
}


