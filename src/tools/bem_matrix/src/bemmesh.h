/* $Id: bemmesh.h,v 1.3 2008/01/28 07:06:07 canacar Exp $ */
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
#ifndef bemmeshH
#define bemmeshH
#include <stdio.h>
#include <assert.h>
//---------------------------------------------------------------------------
typedef double Point[3];
typedef struct{
    int start;
    int size;
    int sigin;
    int sigout;
} Boundary;

#define NUM_SIG_TYPES 20
#define MAX_BOUND 32

struct Dipole{
    double x,y,z;
    double px,py,pz;
};
//---------------------------------------------------------------------------
class BEMesh{
public:
    BEMesh(double defsig=0.2);
    virtual ~BEMesh();

    virtual int loadMesh(char *name);
    int saveMesh(char *name);


    int numNodes(void) const {return m_cnum;}
    int numElements(void) const {return m_enum;}
    int numNodeElem(void) const {return m_node_per_elem;}
    int numBoundaries(void) const {return m_bnum;}

    void setSigma(int n, double sig){
        if(n>=0 && n<NUM_SIG_TYPES) m_sigma[n]=sig;
    }

    double getSigma(int n) const {
        if(n>=0 && n<NUM_SIG_TYPES)
		return m_sigma[n];
	else
		return 0;
    }

//    int *getElement(int e);
//    int *getNode(int n);

    double innerSigNode(int n);
    double outerSigNode(int n);
    double averageSigNode(int n);
    double innerSigElem(int e);
    double outerSigElem(int e);
    double innerSigBnd(int b);
    double outerSigBnd(int b);

    // This is a hack to make IPA work
    int setInnerSigBnd(int b, double sig);
    int setOuterSigBnd(int b, double sig);

    int numBndNodes(int b);
    int numBndElem(int b);

    int **getBndElem(int bnd);
    int getBndNode(int &st, int b);

    virtual void getNodeCoord(int n, double &nx, double &ny, double &nz);
    virtual void getElemCoord(int e, double *x, double *y, double *z);

    virtual int elemNode(int el, int nd);

private:
    FILE *openFile(char *name, char *ext);
    char *getLine(FILE *f);
    int loadInfo(FILE *f);
    int loadElem(FILE *f);
    int loadCoord(FILE *f);
    void markNode(int nd, int bnd);
    int insertSigma(double sig);

    FILE *openFileW(char *name, char *ext);
    int saveInfo(FILE *f);
    int saveElem(FILE *f);
    int saveCoord(FILE *f);

protected:    
    int m_bnum, m_enum, m_cnum;
    int m_node_per_elem;
    double m_sigma[NUM_SIG_TYPES];

    Boundary *m_bound;
    Point *m_coords;
    int **m_elements;
    unsigned *m_bndinfo;

    friend class BESubMesh;
};

class BESubMesh:public BEMesh{
public:
    BESubMesh(BEMesh &base, int b1, int b2);
    BESubMesh(BEMesh &base, int bnd) {
	    BESubMesh(base, bnd, bnd);
    }
    virtual ~BESubMesh();

    virtual int loadMesh(char *name);
    virtual void getNodeCoord(int n, double &nx, double &ny, double &nz);
    virtual void getElemCoord(int e, double *x, double *y, double *z);
    virtual int elemNode(int el, int nd);

    int getForwardMapping(int n){
        assert(n>=0 && n<m_cnum);
        return m_fmap[n];
    }
    int getInverseMapping(int n){
        assert(n>=0 && n<m_base->numNodes());
        return m_imap[n];
    }

private:
    BEMesh *m_base;
    int *m_fmap, *m_imap; // forward and inverse maps
    int m_inum;
};

#endif
