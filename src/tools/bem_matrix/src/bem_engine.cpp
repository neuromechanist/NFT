/* $Id: bem_engine.cpp,v 1.4 2008/04/21 06:22:01 canacar Exp $ */
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

#include "bem_engine.h"
//---------------------------------------------------------------------------


#define max(a,b) ((a) >= (b) ? (a) : (b))
#define min(a,b) ((a) <= (b) ? (a) : (b))

double gpd_13[][3]={{0.0651301029,0.0651301029,0.0533472356},
                    {0.8697297941,0.0651301029,0.0533472356},
                    {0.0651301029,0.8697297941,0.0533472356},
                    {0.3128654960,0.0486903154,0.0771137608},
                    {0.6384441885,0.3128654960,0.0771137608},
                    {0.0486903154,0.6384441885,0.0771137608},
                    {0.6384441885,0.0486903154,0.0771137608},
                    {0.3128654960,0.6384441885,0.0771137608},
                    {0.0486903154,0.3128654960,0.0771137608},
                    {0.2603459660,0.2603459660,0.1756152574},
                    {0.4793080678,0.2603459660,0.1756152574},
                    {0.2603459660,0.4793080678,0.1756152574},
                    {0.3333333333,0.3333333333,-0.1495700444}};

double gpd_3[][3]={{0.0, 0.5, 0.3333333333},
		    {0.5, 0.0, 0.3333333333},
		    {0.5, 0.5, 0.3333333333}};

static int num_gp = 13;
static double (*gpdata)[3];


#define MAX_FN 1024
static char fnbuf[MAX_FN];

void matSolve(matRow &mat, DFVector &xvec,
		 DFVector &rhs, int itmax, int tr = 0);

matFullRowStatic *loadMatTemp(matRow &mat, char *basefn, char *ext);
void addPotunbound(DFVector &pot, BEMesh &mesh, Dipole &d, double mul);
void addMultiLayerRHS(DFVector &rhs, DFVector &phi3, BEMesh &mesh,
		      BESubMesh &imesh, matRow &imat, matRow &Bsub,
		      Dipole &d, double s2, int inv);
void maxEdgeDist(int size, double pi, double pj, double di,
                 double dj, double &maxE, double &minR);
void ElemIntegral(matRow &Cmat, BEMesh &mesh, int node, int elem,
                  double pi, double pj, double di, double dj, int iter);
void fillBEMatrixNewInt(matRow &Cmat, BEMesh &mesh);
void fillBEMatrix(matRow &Cmat, BEMesh &mesh, GPStore &gps);
void setupMatrix(matRow &mat);


int *
loadSensors(const char *fname, int *ns)
{
	if (fname == NULL || ns == NULL)
		return NULL;

	FILE *f;
	if ((f = fopen(fname, "rb")) == NULL) {
		perror("Failed to open sensor file");
		return NULL;
	}

	int  nsn;
	int *sn;
	if ((sn = loadIntList(f, &nsn)) == NULL)
		return NULL;
	*ns = nsn;
	return sn;
}

Dipole *
loadDipoles(const char *fname, int *nd)
{
	if (fname == NULL || nd == NULL)
		return NULL;

	FILE *f;
	if ((f = fopen(fname, "rb")) == NULL) {
		perror("Failed to open sensor file");
		return NULL;
	}

	int  ndp;
	Dipole *dp;
	if ((dp = loadDipoleList(f, &ndp)) == NULL)
		return NULL;
	*nd = ndp;
	return dp;
}

int
saveVector(const char *fn, DFVector *p)
{
	if (fn == NULL || p == NULL)
		return 1;
	if (p->_size < 1)
		return 1;

	FILE *f = fopen(fn, "wt");
	if (f == NULL) {
		perror("fopen");
		return 1;
	}

	for(int i = 0; i < p->_size; i++)
		fprintf(f, "%g\n", (*p)[i]);
	
	fclose(f);

	return 0;
}

int
loadVector(const char *fn, DFVector *p)
{
	if (fn == NULL || p == NULL)
		return 1;
	if (p->_size < 1)
		return 1;

	FILE *f = fopen(fn, "rt");
	if (f == NULL) {
		perror("fopen");
		return 1;
	}

	for(int i = 0; i < p->_size; i++) {
		double val;
		if (fscanf(f, "%lg\n", &val) != 1) {
			fclose(f);
			return 1;
		}
		(*p)[i] = val;
	}
	
	fclose(f);

	return 0;
}

void saveMat(const matRow &mat, char *basefn, char *ext)
{
        snprintf(fnbuf, MAX_FN, "%s.%s", basefn, ext);
        fnbuf[MAX_FN-1]=0;
        
        printf("Saving matrix to %s\n", fnbuf);
        FILE *f=fopen(fnbuf, "wt");
        if (f == NULL) {
                perror("Failed to open file");
                return;
        }
        if (mat.save(f))
                printf("Failed to save!\n");
        else
                printf("Matrix saved\n");
        fclose(f);
}

void loadMat(matRow &mat, char *basefn, char *ext)
{
        snprintf(fnbuf, MAX_FN, "%s.%s", basefn, ext);
        fnbuf[MAX_FN-1]=0;

        printf("Loading matrix from %s\n", fnbuf);
        FILE *f=fopen(fnbuf, "rt");
        if (f == NULL) {
                perror("Failed to open file");
                exit(1);
        }
        if (mat.load(f)) {
                printf("Failed to load!\n");
                exit (1);
        }
	printf("Matrix loaded\n");
	fclose(f);
}

matFullRowStatic *loadMatTemp(matRow &mat, char *basefn, char *ext)
{
        snprintf(fnbuf, MAX_FN, "%s.%s", basefn, ext);
        fnbuf[MAX_FN-1]=0;

        printf("Trying to load matrix from %s\n", fnbuf);
        FILE *f=fopen(fnbuf, "rt");
        if (f == NULL) {
                perror("Failed to open file");
		return NULL;
        }

	matFullRowStatic *m = new matFullRowStatic(mat.numRows(), mat.numCols());
	if (m == NULL) {
		fprintf(stderr, "Failed to allocate memory!\n");
		fclose(f);
		return NULL;
	}
        if (m->load(f)) {
                fprintf(stderr, "Failed to load!\n");
		delete m;
		fclose(f);
		return NULL;
        }

	fprintf(stderr, "Matrix loaded\n");
	fclose(f);
	return m;
}
//---------------------------------------------------------------------------

/*dont forget to buy me forget me nots*/
void addPotunbound(DFVector &pot, BEMesh &mesh, Dipole &d, double mul)
{
	double Rx, Ry, Rz, MagR, sa;
	assert(pot._size==mesh.numNodes());

	for(int c=0; c<mesh.numNodes(); c++){
		mesh.getNodeCoord(c, Rx, Ry, Rz);
		Rx-=d.x;
		Ry-=d.y;
		Rz-=d.z;
		MagR=pow(Rx*Rx+Ry*Ry+Rz*Rz,1.5);
		sa=mesh.averageSigNode(c);
		assert(sa);
		pot[c]+=1/sa/(4*M_PI)*(d.px*Rx+d.py*Ry+d.pz*Rz)/MagR*mul;
	}
}
//---------------------------------------------------------------------------
void addMultiLayerRHS(DFVector &rhs, DFVector &phi3, BEMesh &mesh,
		      BESubMesh &imesh, matRow &imat, matRow &Bsub,
		      Dipole &d, double s2, int inv)
{
	assert(rhs._size == mesh.numNodes());
	assert(phi3._size == mesh.numNodes());
	assert(imesh.numNodes() == imat.numRows());
	assert(imat.numCols() == imat.numRows());
	assert(mesh.numBoundaries() > 1 && imesh.numBoundaries() >= 1);
	assert(Bsub.numRows() == mesh.numNodes());
	assert(Bsub.numCols() == imesh.numBndNodes(0));

	double s3 = imesh.innerSigBnd(0);
	double beta = s2/s3;
	double mod;

	if (beta == 1) {	/* XXX check (beta > 0.99) instead? */
		// prevent divide by zero
		fprintf(stderr, "Beta == 1, not using modified equations\n");
		addPotunbound(rhs, mesh, d, beta);
		return;
	}

	DFVector irhs(imesh.numNodes());
	irhs.clear();
	addPotunbound(irhs, imesh, d, 1);

	// now obtain inner sol (using imat and imesh)
	DFVector ipot(imesh.numNodes());

	if (inv) {
		for(int n = 0; n < imesh.numNodes(); n++)
			ipot[n] = imat.iprod_row(n, irhs._vector);
		
	} else {
		for(int n = 0; n < imesh.numNodes(); n++)
			ipot[n] = irhs[n];
		solveMatrix(imat, ipot, irhs, 1000, 0);
	}

	// ok, now we have ipot containing inner sol
	// modify rhs with ipot

	/* multiply with Bsub */
        mod = beta/(beta - 1);
        for (int n = 0; n < mesh.numNodes(); n++)
		/* XXX assume outer nodes are at the beginning of ipot */
		rhs[n] += mod * Bsub.iprod_row(n, ipot._vector);
	
	/* add w03 */
        mod = beta/(beta + 1);
	int n = 0;
	for (; n < imesh.numBndNodes(0); n++) {
		int m = imesh.getForwardMapping(n);
		rhs[m] -= mod * ipot[n];
		phi3[m] += ipot[n];
	}
	
	for (; n < imesh.numNodes(); n++) {
		int m = imesh.getForwardMapping(n);
		phi3[m] += ipot[n];
	}
}
//---------------------------------------------------------------------------
#define MAX_ITER 5
// global variables used in ElemIntegral, set by fillBEMatrixNewInt
double *eintX=0;
double *eintY=0;
double *eintZ=0;
double eintC1=0;
double eintC2=0;
double eintNx=0;
double eintNy=0;
double eintNz=0;

void maxEdgeDist(int size, double pi, double pj, double di,
                 double dj, double &maxE, double &minR)
{
        GPoint gp0(size, pi+di/3, pj+dj/3, 0);
        GPoint gp1(size, pi, pj+dj, 0);
        GPoint gp2(size, pi+di, pj, 0);
        GPoint gp3(size, pi, pj, 0);

        double x0=gp0.global(eintX);
        double y0=gp0.global(eintY);
        double z0=gp0.global(eintZ);

        double Rx=x0-eintNx;
        double Ry=y0-eintNy;
        double Rz=z0-eintNz;
        double Rm0=sqrt(Rx*Rx+Ry*Ry+Rz*Rz);

        double x1=gp1.global(eintX);
        double y1=gp1.global(eintY);
        double z1=gp1.global(eintZ);

        Rx=x1-eintNx;
        Ry=y1-eintNy;
        Rz=z1-eintNz;
        double Rm1=sqrt(Rx*Rx+Ry*Ry+Rz*Rz);

        double x2=gp2.global(eintX);
        double y2=gp2.global(eintY);
        double z2=gp2.global(eintZ);

        Rx=x2-eintNx;
        Ry=y2-eintNy;
        Rz=z2-eintNz;
        double Rm2=sqrt(Rx*Rx+Ry*Ry+Rz*Rz);

        double x3=gp3.global(eintX);
        double y3=gp3.global(eintY);
        double z3=gp3.global(eintZ);

        Rx=x3-eintNx;
        Ry=y3-eintNy;
        Rz=z3-eintNz;
        double Rm3=sqrt(Rx*Rx+Ry*Ry+Rz*Rz);

        minR=min(min(min(Rm0, Rm1),Rm2),Rm3);

        Rx=x2-x1;
        Ry=y2-y1;
        Rz=z2-z1;
        double e1=sqrt(Rx*Rx+Ry*Ry+Rz*Rz);

        Rx=x2-x3;
        Ry=y2-y3;
        Rz=z2-z3;
        double e2=sqrt(Rx*Rx+Ry*Ry+Rz*Rz);

        Rx=x1-x3;
        Ry=y1-y3;
        Rz=z1-z3;
        double e3=sqrt(Rx*Rx+Ry*Ry+Rz*Rz);

        maxE=max(max(e1,e2),e3);
}
// pi pj are the local coordinates of the origin of the triangle
// di dj are signed length values along i and j axis
void ElemIntegral(matRow &Cmat, BEMesh &mesh, int node, int elem,
                  double pi, double pj, double di, double dj, int iter)
{
	int ok=0;
	if (iter > MAX_ITER) {
		ok=1;
	} else {
		double maxE, minR;
		maxEdgeDist(mesh.numNodeElem(), pi, pj, di, dj, maxE, minR);
		if (minR > maxE * 1.2) {
			ok = 1;
		}
	}

	if (ok) {
		for(int i=0; i< num_gp; i++){
			double gi, gj, gw;
			gi=gpdata[i][0] * di + pi;
			gj=gpdata[i][1] * dj + pj;
			gw=gpdata[i][2] * fabs(di * dj);

			GPoint gp(mesh.numNodeElem(), gi, gj, gw);

			double gx=gp.global(eintX);
			double gy=gp.global(eintY);
			double gz=gp.global(eintZ);

			double jx,jy,jz;
			gp.calcJacob(eintX,eintY,eintZ,jx,jy,jz);

			double Rx=gx-eintNx;
			double Ry=gy-eintNy;
			double Rz=gz-eintNz;
			double Rmag=pow(Rx*Rx+Ry*Ry+Rz*Rz,1.5);

			for(int l=0; l<mesh.numNodeElem(); l++) {
				double val=1/(2*M_PI)*eintC1/eintC2*gp.shape(l)*gp.weight()*
					(Rx*jx+Ry*jy+Rz*jz)/Rmag;
				Cmat.add(node,mesh.elemNode(elem,l),val);
			}
		}
	} else {
//                split ...
		iter++;
		ElemIntegral(Cmat, mesh, node, elem, pi, pj, di/2, dj/2, iter);
		ElemIntegral(Cmat, mesh, node, elem, pi+di/2, pj, di/2, dj/2, iter);
		ElemIntegral(Cmat, mesh, node, elem, pi, pj+dj/2, di/2, dj/2, iter);
		ElemIntegral(Cmat, mesh, node, elem, pi+di/2, pj+dj/2, -di/2, -dj/2, iter);
	}
}
//---------------------------------------------------------------------------
void fillBEMatrixNewInt(matRow &Cmat, BEMesh &mesh)
{
	HPTimer *tf = HPTimerMgr::getTimer("Fill Matrix");

	eintX=new double[mesh.numNodeElem()];
	eintY=new double[mesh.numNodeElem()];
	eintZ=new double[mesh.numNodeElem()];

	tf->start();

	for(int k=0; k<mesh.numNodes(); k++){
		eintC2=mesh.innerSigNode(k)+mesh.outerSigNode(k);
		mesh.getNodeCoord(k,eintNx, eintNy, eintNz);
		if ((k % 25) == 0) {
			printf("processing node %d of %d ...    \r",k,mesh.numNodes());
			fflush(stdout);
		}

		for(int m=0; m<mesh.numElements(); m++){
			eintC1=mesh.innerSigElem(m)-mesh.outerSigElem(m);
			mesh.getElemCoord(m,eintX, eintY, eintZ);
			ElemIntegral(Cmat, mesh, k, m, 0, 0, 1, 1, 0);
		}
	}
	tf->stop();

	printf("\n");
	delete[] eintX;
	delete[] eintY;
	delete[] eintZ;
}
//---------------------------------------------------------------------------
void fillBEMatrix(matRow &Cmat, BEMesh &mesh, GPStore &gps)
{
	double *x=new double[mesh.numNodeElem()];
	double *y=new double[mesh.numNodeElem()];
	double *z=new double[mesh.numNodeElem()];

	for(int k=0; k<mesh.numNodes(); k++){
		double c2=mesh.innerSigNode(k)+mesh.outerSigNode(k);
		double nx,ny,nz;
		mesh.getNodeCoord(k,nx,ny,nz);
		printf("processing node %d of %d ...    \r",k,mesh.numNodes());

		for(int m=0; m<mesh.numElements(); m++){
			double c1=mesh.innerSigElem(m)-mesh.outerSigElem(m);
			mesh.getElemCoord(m,x,y,z);
			for(int i=0; i<gps.count(); i++){
				GPoint *gp=gps.getGP(i);

				double gx=gp->global(x);
				double gy=gp->global(y);
				double gz=gp->global(z);
				double jx,jy,jz;
				gp->calcJacob(x,y,z,jx,jy,jz);

				double Rx=gx-nx;
				double Ry=gy-ny;
				double Rz=gz-nz;
				double Rmag=pow(Rx*Rx+Ry*Ry+Rz*Rz,1.5);

				for(int l=0; l<mesh.numNodeElem(); l++){
					double val=1/(2*M_PI)*c1/c2*gp->shape(l)*gp->weight()*
						(Rx*jx+Ry*jy+Rz*jz)/Rmag;
					Cmat.add(k,mesh.elemNode(m,l),val);
				}
			}
		}
	}
}
//---------------------------------------------------------------------------
void setupMatrix(matRow &mat)
{
	int nn=mat.numRows();
	assert(nn==mat.numCols());
	/* Deflation */
	double mod=-1.0/(double)nn;
	for(int i=0; i<nn; i++)
		for(int j=0; j<nn; j++)
			mat.add(i,j,mod);

	/* Equation */
	for(int i=0; i<nn; i++)
		for(int j=0; j<nn; j++)
			mat.set(i,j,(i==j ? 1:0)-mat.get(i,j));
}
//---------------------------------------------------------------------------
static BESubMesh *imesh = NULL;
static matFullRowStatic *Imat = NULL; 
static matFullRowStatic *Bsub = NULL; 
static matFullRowStatic *iImat = NULL; 
double sig2;

HPTimer *tc = HPTimerMgr::getTimer("Compute Coefficient Matrix");

void
multiLayer(BEMesh &mesh, matRow &Cmat, GPStore &gps,
	   int bnd, char *loadfn, char *savefn, int liflag)
{
	HPTimer *ti = HPTimerMgr::getTimer("Compute Inner Matrix");

	if (imesh != NULL) {
		printf("Already initialized!\n");
		return;
	}

	imesh = new BESubMesh(mesh, bnd, mesh.numBoundaries());
	
	printf("Inner boundary: %d nodes, %d elements, "
	       "%d nodes/element, %d boundaries\n",
	       imesh->numNodes(), imesh->numElements(),
	       imesh->numNodeElem(), imesh->numBoundaries());

	sig2 = imesh->outerSigBnd(0);
	imesh->setOuterSigBnd(0, 0);
	
	Imat = new matFullRowStatic(imesh->numNodes(),
				    imesh->numNodes());
	Bsub = new matFullRowStatic(mesh.numNodes(),
				    imesh->numBndNodes(0));
		
	int a,u,b;

	tc->start();

	if (loadfn != NULL) {
		loadMat(Cmat, loadfn, "cmt");
		loadMat(*Bsub, loadfn, "dmt");
	} else {
		Cmat.clear();
		Bsub->clear();
		fillBEMatrixNewInt(Cmat, mesh);

		for (int j = 0; j < imesh->numBndNodes(0); j++) {
			/* XXX assume outer nodes are at the beginning */
			int c = imesh->getForwardMapping(j);
			/* XXX slow */
			for (int i = 0; i < mesh.numNodes(); i++)
				Bsub->set(i, j, Cmat.get(i, c));
		}

		setupMatrix(Cmat);
		if (savefn != NULL) {
			saveMat(Cmat, savefn, "cmt");
			saveMat(*Bsub, savefn, "dmt");
		}
	}
	tc->stop();

	a=u=b=0;
	Cmat.mem(a,u,b);
	printf("Cmat: %d/%d entries in %d bytes\n",u,a,b);
	
	ti->start();
	if (liflag && loadfn != NULL) {
		loadMat(*Imat, loadfn, "imt");
		iImat = loadMatTemp(*Imat, loadfn, "iinv");
	} else {
		Imat->clear();
		fillBEMatrixNewInt(*Imat, *imesh);
		setupMatrix(*Imat);
		if (savefn != NULL)
			saveMat(*Imat, savefn, "imt");
	}
	ti->stop();

	a=u=b=0;
	Imat->mem(a,u,b);
	printf("Imat: %d/%d entries in %d bytes\n",u,a,b);
}
//---------------------------------------------------------------------------
void
multiLayerRHS(BEMesh &mesh, DFVector &rhs, DFVector &phi3, Dipole &d)
{
	double s2 = sig2;

	if (imesh == NULL) {
		printf("Mesh not initialized!\n");
		return;
	}

	rhs.clear();
	phi3.clear();

	if (iImat != NULL)
		addMultiLayerRHS(rhs, phi3, mesh, *imesh, *iImat, *Bsub, d, s2, 1);
	else if (Imat != NULL)
		addMultiLayerRHS(rhs, phi3, mesh, *imesh, *Imat, *Bsub, d, s2, 0);
	else
		printf("No inner matrix or inverse\n");
}
//---------------------------------------------------------------------------
// Single Layer
void
singleLayer(BEMesh &mesh, matRow &Cmat, GPStore &gps,
	    char *loadfn, char *savefn)
{
	int a,u,b;
	static int initialized = 0;
	
	if (initialized) {
		printf("Already initialized!\n");
		return;
	}

	tc->start();
	if (loadfn != NULL) {
		loadMat(Cmat, loadfn, "cmt");
	} else {
		Cmat.clear();
		fillBEMatrixNewInt(Cmat, mesh);
		setupMatrix(Cmat);
		if (savefn != NULL)
			saveMat(Cmat, savefn, "cmt");
	}
	tc->stop();

	a=u=b=0;
	Cmat.mem(a,u,b);
	printf("Cmat: %d/%d entries in %d bytes\n",u,a,b);
}
//---------------------------------------------------------------------------
void
singleLayerRHS(BEMesh &mesh, DFVector &rhs, Dipole &d)
{
	rhs.clear();
	addPotunbound(rhs, mesh, d, 1);
}
//---------------------------------------------------------------------------
#define SSBUFLEN 1023
int setSigma(BEMesh &mesh, char *data)
{
	assert(data);
	static char buf[SSBUFLEN+1];

	strncpy(buf, data, SSBUFLEN);
	buf[SSBUFLEN] = 0;

	char *t = strchr(buf,'=');
	if (t == 0)
		return 1;
	*t++ = 0;

	double val = atof(t);
	int sig = atoi(buf);

	if (sig < 0 || sig >= NUM_SIG_TYPES)
		return 1;
	if (val <= 0)
		return 1;

	printf("Setting Sigma %d to %g\n", sig, val);
	mesh.setSigma(sig, val);

	return 0;
}
//---------------------------------------------------------------------------
GPStore *
setupGPStore(const BEMesh &mesh, int ngp)
{
	if (ngp == 3)
		gpdata = gpd_3;
	else {
		gpdata = gpd_13;
		ngp = 13;
	}

	GPStore *gps = new GPStore(13, mesh.numNodeElem());
	for(int n = 0; n < 13; n++)
		gps->addGP(gpdata[n][0],gpdata[n][1],gpdata[n][2]);

	num_gp = ngp;

	return gps;
}
//---------------------------------------------------------------------------
