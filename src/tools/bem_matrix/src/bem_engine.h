/* $Id: bem_engine.h,v 1.3 2008/01/28 07:34:51 canacar Exp $ */
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

#ifndef _BEM_ENGINE_H_
#define _BEM_ENGINE_H_

#include "bemmesh.h"
#include "matrow.h"
#include "shape.h"
#include "magnetic.h"
#include "hptimer.h"
#include "meshutil.h"


void singleLayer(BEMesh &mesh, matRow &Cmat, GPStore &gps,
		 char *loadfn, char *savefn);
void multiLayer(BEMesh &mesh, matRow &Cmat, GPStore &gps,
		int bnd, char *loadfn, char *savefn, int liflag);

void singleLayerRHS(BEMesh &mesh, DFVector &rhs, Dipole &d);
void multiLayerRHS(BEMesh &mesh, DFVector &rhs, DFVector &phi3, Dipole &d);

int setSigma(BEMesh &mesh, char *data);
GPStore *setupGPStore(const BEMesh &mesh, int ngp = 13);

void solveMatrix(matRow &mat, DFVector &xvec, DFVector &rhs, int itmax, int tr);

int *loadSensors(const char *fname, int *ns);
Dipole *loadDipoles(const char *fname, int *nd);

int loadVector(const char *fn, DFVector *p);
int saveVector(const char *fn, DFVector *p);

void loadMat(matRow &mat, char *basefn, char *ext);
void saveMat(const matRow &mat, char *basefn, char *ext);

#endif
