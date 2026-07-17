/* $Id: bem_solve.cpp,v 1.8 2008/04/21 06:28:04 canacar Exp $ */
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
		"Usage: bem_solve [-m] [-l load_file] [-s save_file] [-o mod] \n"
		"               [-p potential_file] [-r sensor_file]\n"
		"               [-d dipole_file] meshname [s=sig ...]\n\n"
		"       -l: load matrices from matname.[ci]mat\n"
		"       -s: save matrices to matname.[ci]mat\n"
		"       -m: load Cmat only from matname.cmat\n"
		"       -d: load dipoles from file\n"
		"       -p: potential filename (base)\n"
		"       -r: list of nodes to invert for reciprocity\n"
		"           saved to save_file.inv\n"
		"       -o: interface to use with modified equations\n"
		"           (-1 to disable)\n");
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

static char fnbuf[MAX_PATH];

//---------------------------------------------------------------------------
// Main
int main(int argc, char* argv[])
{
	BEMesh mesh; // initialize with default cond. profile
	char *sname = NULL, *lname = NULL, *dname = NULL;
	char *rname = NULL, *pname = NULL;
	int ch, mod = 1, loadimat = 1;
	
	while ((ch = getopt(argc, argv, "md:i:l:m:o:p:r:s:")) != -1) {
		switch (ch) {
		case 'd':
			dname = optarg;
			break;
		case 'l':
			lname = optarg;
			break;
		case 'm':
			loadimat = 0;
			break;
		case 'o':
			mod = atoi(optarg);
			break;
		case 'p':
			pname = optarg;
			break;
		case 'r':
			rname = optarg;
			break;
		case 's':
			sname = optarg;
			break;
		default:
			usage();
		}
	}

	argc -= optind;
	argv += optind;

	if (argc <= 0)
		usage();
    
	if(mesh.loadMesh(argv[0])){
		printf("Error loading mesh!\n");
		return 1;
	}

	printf("Mesh loaded: %d nodes, %d elements, "
	       "%d nodes/element, %d boundaries\n",
	       mesh.numNodes(), mesh.numElements(),
	       mesh.numNodeElem(), mesh.numBoundaries());
	
	Dipole *dipoles;
	int num_dipoles = 0;

	if (dname != NULL) {
		dipoles = loadDipoles(dname, &num_dipoles);
		if (dipoles == NULL || num_dipoles < 1) {
			printf("Failed to load dipoles\n");
			return 1;
		}
		printf("%d dipoles loaded\n", num_dipoles);
	}

	for(int n=1; n<argc; n++){
		if(setSigma(mesh, argv[n])){
			printf("Failed to set sigma for argument: %s\n",
			       argv[n]);
			return 1;
		}
	}

	atexit(report_callback);

	GPStore *gps = setupGPStore(mesh);

	DFVector rhs(mesh.numNodes());
	DFVector phi3(mesh.numNodes());
	DFVector pot(mesh.numNodes());

	matFullRowStatic Cmat(mesh.numNodes(), mesh.numNodes());
    
	HPTimer *t1=HPTimerMgr::getTimer("Potential time (matrix filling)");
	t1->start();

	Cmat.clear();
	if (mesh.numBoundaries() < 2 || mod < 0){
		if (mesh.numBoundaries() < 2)
			printf("Single layer\n");
		else
			printf("Multi layer, not modified\n");
		singleLayer(mesh, Cmat, *gps, lname, sname);
	} else {
		printf("Multi layer, layer %d modified\n",mod);
		multiLayer(mesh, Cmat, *gps, mod-1, lname, sname, loadimat);
	}
	t1->stop();

	
	HPTimer *tr=HPTimerMgr::getTimer("Potential time (create RHS)");
	HPTimer *t2=HPTimerMgr::getTimer("Potential time (solution)");
	HPTimer *ti=HPTimerMgr::getTimer("Invert matrix row");
	
	int num_sensors = 0;
	int *sensors = 0;
	DFVector **sinv = NULL;

	if (rname != NULL) {
		// XXX solve for sensors in rname
		sensors = loadSensors(rname, &num_sensors);
		if (sensors == 0 || num_sensors < 1) {
			printf("Could not load sensors!\n");
			return 1;
		}
		// validate sensors
		for (int s = 0; s < num_sensors; s++) {
			if (s < 0 || s >= mesh.numNodes()) {
				printf("Invalid sensor %d (%d)\n",
				       s, sensors[s]);
				return 1;
			}
		}

		printf("%d sensors loaded\n", num_sensors);
		sinv = new DFVector*[num_sensors];

		for (int s = 0; s < num_sensors; s++) {
			sinv[s] = new DFVector(mesh.numNodes());
			int loaded = 0;
			if (lname != NULL) {
				snprintf(fnbuf, sizeof(fnbuf),
					 "%s%04d.rf", lname, s);
				printf("loading row from %s ...\n", fnbuf);

				if (loadVector(fnbuf, sinv[s]))
					printf("Failed to load!\n");
				else
					loaded = 1;
			}

			if (! loaded) {
				printf("solving for row %d\n", sensors[s]);
				pot.clear();
				pot[sensors[s]] = 1;
				sinv[s]->clear();
				(*(sinv[s]))[sensors[s]] = 1;

				ti->start();
				// XXX must clear rhs too?
				solveMatrix(Cmat, *(sinv[s]), pot, 1000, 1);
				ti->stop();

				if (sname != NULL) {
					snprintf(fnbuf, sizeof(fnbuf),
						 "%s%04d.rf", sname, s);
					printf("Saving to %s ...\n", fnbuf);
					saveVector(fnbuf, sinv[s]);
				}
			}
		}
	}

	for (int n = 0; n < num_dipoles; n++) {
		printf("Computing RHS for dipole %d\n", n);
		tr->start();
		
		if (mesh.numBoundaries()<2 || mod < 0)
			singleLayerRHS(mesh, rhs, dipoles[n]);
		else
			multiLayerRHS(mesh, rhs, phi3, dipoles[n]);
		tr->stop();
	
		if (sinv) {
			printf("Solving dipole %d for sensors\n", n);
			DFVector sv(num_sensors);
			t2->start();
			for (int s = 0; s < num_sensors; s++) {
				sv[s] = DSIProd(sinv[s], &rhs);
			}
  			t2->stop();

			snprintf(fnbuf, sizeof(fnbuf), "%s%03d.spot",
				 pname, n);
			printf("Saving to %s ...\n", fnbuf);
			saveVector(fnbuf, &sv);
		} else {
			for(int i = 0; i < mesh.numNodes(); i++)
				pot[i] = rhs[i];
	
			printf("Solving for dipole %d\n", n);
	
			t2->start();
  			
			solveMatrix(Cmat,pot,rhs,1000, 0);
			
			t2->stop();

			if (mesh.numBoundaries() > 1 && mod >= 0) { 
				for(int i = 0; i < mesh.numNodes(); i++)
					pot[i] += phi3[i];
			}

			snprintf(fnbuf, sizeof(fnbuf), "%s%03d.pot",
				 pname ? pname : "pot", n);
			printf("Saving to %s ...\n", fnbuf);
			saveVector(fnbuf, &pot);
		}
	}

	return 0;
}


