/* $Id: magnetic.cpp,v 1.3 2008/01/28 07:26:21 canacar Exp $ */
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

//---------------------------------------------------------------------------
#include <math.h>
#include "magnetic.h"
//---------------------------------------------------------------------------
#define MAX_LINE 1024
char *
getLine(FILE *f)
{
	static char buf[MAX_LINE];
	if(f==NULL) return 0;
	while(1){
		char *s=fgets(buf,MAX_LINE,f);
		if(s==NULL) return 0;
		if(*s!='\n' && *s!='\r' && *s!='#') break;
	}
	return buf;
}
//---------------------------------------------------------------------------
matRow *
mag_loadSens(FILE *f)
{
	assert(f);
	int n;
	double ind;
	double x,y,z;

	long pos=ftell(f);
	if(pos<0) return 0;

	for(n=0; ; n++){
		char *s=getLine(f);
		if(s==0) break;
		if(sscanf(s,"%lf %lf %lf %lf",&ind, &x, &y, &z)!=4)
			return 0;
//        if(ind!=n+1) return 0;
	}
	int len=n;
	if(len==0) return 0;

	if(fseek(f,pos,SEEK_SET)) return 0;

	matRow *sens=new matFullRowStatic(len,3);
	if(sens==0) return 0;

	for(n=0; n<sens->numRows(); n++){
		char *s=getLine(f);
		if(s==0) break;
		if(sscanf(s,"%lf %lf %lf %lf",&ind, &x, &y, &z)!=4) break;
//        if(ind!=n+1)break;
		sens->set(n,0,x);
		sens->set(n,1,y);
		sens->set(n,2,z);
	}
	if(n!=len){
		delete sens;
		sens=0;
	}
	return sens;
}
//---------------------------------------------------------------------------
void
mag_primary(Dipole &d, matRow *sens, matRow &B)
{
	double carpan=(1.0/(4.0*M_PI));

	assert(sens->numCols()==3);
	assert(B.numCols()==3);

	/* Analytic Magnetic Field Distribution Z dipole along X only! */
	for (int c=0; c<sens->numRows(); c++){
		double Rx=sens->get(c,0)-d.x;
		double Ry=sens->get(c,1)-d.y;
		double Rz=sens->get(c,2)-d.z;

		double MagR= sqrt(Rx*Rx+Ry*Ry+Rz*Rz);

//    	B.add(c,0,0.0);     // Bx
		B.add(c,1,-1.0*Rz*carpan/(pow(MagR,3)));  // By
		B.add(c,2,Ry*carpan/(pow(MagR,3)));       // Bz
	}
}
//---------------------------------------------------------------------------
void
mag_secondary(BEMesh &mesh, GPStore &gps, matRow *sens, matRow &H)
{
	assert(sens->numCols() == 3);
	assert(H.numCols() == 3 * sens->numRows());
	assert(H.numRows() == mesh.numNodes());

	double *x = new double[mesh.numNodeElem()];
	double *y = new double[mesh.numNodeElem()];
	double *z = new double[mesh.numNodeElem()];

	for (int m = 0; m < mesh.numElements(); m++) {
		double c1 = mesh.innerSigElem(m) - mesh.outerSigElem(m);
		mesh.getElemCoord(m, x, y, z);

		printf("processing element %d of %d ...    \r",
		       m, mesh.numElements());

		for (int i=0; i<gps.count(); i++) {
			GPoint *gp = gps.getGP(i);

			double gx = gp->global(x);
			double gy = gp->global(y);
			double gz = gp->global(z);
			double jx, jy, jz;

			gp->calcJacob(x, y, z, jx, jy, jz);

			for (int l = 0; l < mesh.numNodeElem(); l++) {
				int nd = mesh.elemNode(m, l);

				double m0 = gp->weight() * gp->shape(l) * c1 / (4 * M_PI);

				for (int k = 0; k < sens->numRows(); k++) {

					double Rx = sens->get(k, 0) - gx;
					double Ry = sens->get(k, 1) - gy;
					double Rz = sens->get(k, 2) - gz;
					double Rmag = pow(Rx * Rx + Ry * Ry + Rz * Rz, 1.5);
					double mul = m0 / Rmag;
						
					H.add(nd, 3 * k + 0, mul * (Ry * jz - Rz * jy));
					H.add(nd, 3 * k + 1, mul * (Rz * jx - Rx * jz));
					H.add(nd, 3 * k + 2, mul * (Rx * jy - Ry * jx));
				}
			}
		}
	}

	delete[] x;
	delete[] y;
	delete[] z;
}
//---------------------------------------------------------------------------
