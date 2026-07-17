/* $Id: bemmesh.cpp,v 1.3 2008/01/28 07:26:21 canacar Exp $ */
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
#include <limits.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <assert.h>
#include "bemmesh.h"
//---------------------------------------------------------------------------
BEMesh::BEMesh(double defsig)
{
    m_bound=0;
    m_coords=0;
    m_elements=0;
    m_bndinfo=0;

    m_sigma[0]=0; // outside
    for(int n=1; n<NUM_SIG_TYPES; n++)
        m_sigma[n]=defsig;
}
//---------------------------------------------------------------------------
BEMesh::~BEMesh()
{
    if(m_bound!=0) delete[] m_bound;
    if(m_coords!=0) delete[] m_coords;
    if(m_elements!=0) delete[] m_elements;
    if(m_bndinfo!=0) delete[] m_bndinfo;
}
//---------------------------------------------------------------------------
double BEMesh::averageSigNode(int nd)
{
    assert(nd>=0 && nd<m_cnum);
    if(m_bnum==1) return (innerSigBnd(0)+outerSigBnd(0))/2.0;

    unsigned bi=m_bndinfo[nd];
    unsigned mask=1;
    int n;
    int c=0;
    double sum=0;

    for(n=0; n<m_bnum; n++){
        if(bi&mask){
            sum+=innerSigBnd(n)+outerSigBnd(n);
            c+=2;
        }
        mask<<=1;
    }
    return sum/c;
}
//---------------------------------------------------------------------------
double BEMesh::innerSigNode(int nd)
{
    assert(nd>=0 && nd<m_cnum);
    if(m_bnum==1) return innerSigBnd(0);

    unsigned bi=m_bndinfo[nd];
    unsigned mask=1;
    int n;
    for(n=0; n<m_bnum; n++){
        if(bi&mask) break;
        mask<<=1;
    }
    return innerSigBnd(n);
}
//---------------------------------------------------------------------------
double BEMesh::outerSigNode(int nd)
{
    assert(nd>=0 && nd<m_cnum);
    if(m_bnum==1) return outerSigBnd(0);
    unsigned bi=m_bndinfo[nd];
    unsigned mask=1;
    int n;
    for(n=0; n<m_bnum; n++){
        if(bi&mask) break;
        mask<<=1;
    }
    return outerSigBnd(n);
}
//---------------------------------------------------------------------------
double BEMesh::innerSigElem(int e)
{
    int b;
    for(b=0; b<m_bnum; b++){
        e-=m_bound[b].size;
        if(e<0) break;
    }
    return innerSigBnd(b);
}
//---------------------------------------------------------------------------
double BEMesh::outerSigElem(int e)
{
    int b;
    for(b=0; b<m_bnum; b++){
        e-=m_bound[b].size;
        if(e<0) break;
    }
    return outerSigBnd(b);
}
//---------------------------------------------------------------------------
double BEMesh::innerSigBnd(int b)
{
    assert(b<m_bnum && b>=0);
    return m_sigma[m_bound[b].sigin];
}
//---------------------------------------------------------------------------
double BEMesh::outerSigBnd(int b)
{
    assert(b<m_bnum && b>=0);
    return m_sigma[m_bound[b].sigout];
}
//---------------------------------------------------------------------------
int BEMesh::insertSigma(double sig)
{
	int i;

	for (i = 0; i < NUM_SIG_TYPES; i++)
		if (m_sigma[i] == sig)
			break;

	if (i < NUM_SIG_TYPES)
		return i;

	for (i = 0; i < NUM_SIG_TYPES; i++) {
		int b;
		for (b = 0; b < m_bnum; b++)
			if (m_bound[b].sigin == i ||
			    m_bound[b].sigout == i)
				break;
		// unused sigma slot
		if (b == m_bnum) {
			m_sigma[i] = sig;
			return i;
		}
	}

	return i;
}
//---------------------------------------------------------------------------
int BEMesh::setInnerSigBnd(int b, double sig)
{
	assert(b<m_bnum && b>=0);

	int i = insertSigma(sig);

	if (i < 0 || i >= NUM_SIG_TYPES)
		return 1;

	m_bound[b].sigin = i;

	return 0;
}
//---------------------------------------------------------------------------
int BEMesh::setOuterSigBnd(int b, double sig)
{
	assert(b<m_bnum && b>=0);

	int i = insertSigma(sig);

	if (i < 0 || i >= NUM_SIG_TYPES)
		return 1;

	m_bound[b].sigout = i;

	return 0;
}
//---------------------------------------------------------------------------
void BEMesh::getNodeCoord(int n, double &nx, double &ny, double &nz)
{
    assert(n>=0 && n<m_cnum);
    nx=(m_coords[n])[0];
    ny=(m_coords[n])[1];
    nz=(m_coords[n])[2];
}
//---------------------------------------------------------------------------
void BEMesh::getElemCoord(int e, double *x, double *y, double *z)
{
    assert(e>=0 && e<m_enum);
    assert(x && y && z);
    for(int n=0; n<m_node_per_elem; n++){
        x[n]=(m_coords[(m_elements[e])[n]])[0];
        y[n]=(m_coords[(m_elements[e])[n]])[1];
        z[n]=(m_coords[(m_elements[e])[n]])[2];
    }
}
//---------------------------------------------------------------------------
FILE *BEMesh::openFile(char *name, char *ext)
{
    char nname[PATH_MAX];
    FILE *f;

    if (name==0 || ext==0)
	return 0;
    snprintf(nname, sizeof(nname), "%s.%s", name, ext);
    f = fopen(nname, "r");
    return f;
}
//---------------------------------------------------------------------------
#define MAX_LINE 1024
char *BEMesh::getLine(FILE *f)
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
int BEMesh::loadInfo(FILE *f)
{
    int ind, neb, start, s1, s2;
    char *s=getLine(f);
    if(s==0) return 1;
    if(sscanf(s,"%d %d %d %d",&m_bnum, &m_enum, &m_cnum, &m_node_per_elem)!=4) return 2;
    if(m_bnum<1 || m_enum<1 || m_cnum<1) return 3;
    if(m_node_per_elem!=3 && m_node_per_elem!=6 && m_node_per_elem!=10) return 4;
    if(m_bnum>=MAX_BOUND) return 5;

    m_bound=new Boundary[m_bnum];
    m_coords=new Point[m_cnum];

    m_bndinfo=new unsigned[m_cnum];
    for(int n=0; n<m_cnum; n++)
        m_bndinfo[n]=0;

    m_elements=new int*[m_enum];
    for(int e=0; e<m_enum; e++)
        m_elements[e]=new int[m_node_per_elem];

    start=0;
    for(int i=0; i<m_bnum; i++){
        s=getLine(f);
        if(s==0) return 5;
        if(sscanf(s,"%d %d %d %d",&ind, &neb, &s1, &s2)!=4) return 6;
        if(ind!=i+1) return 7;
        if(neb<1) return 8;
        if(s1<0 || s1>=NUM_SIG_TYPES) return 9;
        if(s2<0 || s2>=NUM_SIG_TYPES) return 10;

        m_bound[i].start=start;
        m_bound[i].size=neb;
        m_bound[i].sigin=s1;
        m_bound[i].sigout=s2;

        start+=neb;
    }
    if(start!=m_enum) return 11;
    return 0;
}
//---------------------------------------------------------------------------
void BEMesh::markNode(int nd, int bnd)
{
    if(nd<0 || nd>=m_cnum) return;
    if(bnd<0 || bnd>=MAX_BOUND) return;
    m_bndinfo[nd]|=((unsigned)1)<<bnd;
}
//---------------------------------------------------------------------------
int BEMesh::loadElem(FILE *f)
{
    long ind, val;
    int bnd=-1;
    int bs=0;
    for(int i=0; i<m_enum; i++, bs--){
        while(bs<=0)
            bs=m_bound[++bnd].size;

        char *s=getLine(f);
        if(s==0) return 1;
        char *e;

        ind=strtol(s,&e,10);
        if(s==e) return 2;
        if(ind!=i+1) return 3;
        s=e;

        for(int n=0; n<m_node_per_elem; n++){
            val=strtol(s,&e,10);
            if(s==e) return 4;
            if(val<1 || val>m_cnum) return 5;
            (m_elements[i])[n]=val-1;
            markNode(val-1,bnd);
            s=e;
        }
    }
    return 0;
}
//---------------------------------------------------------------------------
int BEMesh::loadCoord(FILE *f)
{
    double ind;
    double x,y,z;
    for(int i=0; i<m_cnum; i++){
        char *s=getLine(f);
        if(s==0) return 1;
        if(sscanf(s,"%lf %lf %lf %lf",&ind, &x, &y, &z)!=4) return 2;
        if(ind!=i+1) return 3;
        (m_coords[i])[0]=x;
        (m_coords[i])[1]=y;
        (m_coords[i])[2]=z;
    }
    return 0;
}
//---------------------------------------------------------------------------
int BEMesh::loadMesh(char *name)
{
    FILE *f;
    f=openFile(name,"bei");
    if (f==NULL){
        printf("mesh: failed to open info file\n");
        return 1;
    }
    if(loadInfo(f)){
        printf("mesh: failed to load info file\n");
        fclose(f);
        return 1;
    }
    fclose(f);

    f=openFile(name,"bee");
    if (f==NULL){
        printf("mesh: failed to open element file\n");
        return 1;
    }
    if(loadElem(f)){
        printf("mesh: failed to load element file\n");
        fclose(f);
        return 1;
    }
    fclose(f);

    f=openFile(name,"bec");
    if (f==NULL){
        printf("mesh: failed to open coord. file\n");
        return 1;
    }
    if(loadCoord(f)){
        printf("mesh: failed to load coord. file\n");
        fclose(f);
        return 1;
    }
    fclose(f);

    return 0;
}
//---------------------------------------------------------------------------
//---------------------------------------------------------------------------
FILE *
BEMesh::openFileW(char *name, char *ext)
{
	char nname[PATH_MAX];
	FILE *f;

	if (name == NULL || ext == NULL)
		return 0;

	snprintf(nname, sizeof(nname), "%s.%s", name, ext);
	f = fopen(nname, "w");

	return f;
}
//---------------------------------------------------------------------------
int
BEMesh::saveInfo(FILE *f)
{
	fprintf(f, "%d %d %d %d\n", numBoundaries(), numElements(),
		numNodes(), numNodeElem());

	for (int i = 0; i < numBoundaries(); i++) {
		fprintf(f, "%d %d %d (%g) %d (%g)\n", i, numBndElem(i),
			m_bound[i].sigin, innerSigBnd(i),
			m_bound[i].sigout, outerSigBnd(i));
	}
	
	return 0;
}
//---------------------------------------------------------------------------
int
BEMesh::saveElem(FILE *f)
{
	for (int i = 0; i < numElements(); i++){
		fprintf(f, "%d", i);
		for (int j = 0; j < numNodeElem(); j++)
			fprintf(f, " %d", elemNode(i, j) + 1);
		fprintf(f, "\n");
	}
	return 0;
}
//---------------------------------------------------------------------------
int
BEMesh::saveCoord(FILE *f)
{
	double x,y,z;
	for(int i = 0; i<numNodes(); i++){
		getNodeCoord(i, x, y, z);
		fprintf(f, "%d %g %g %g\n", i, x, y, z);
	}
	return 0;
}
//---------------------------------------------------------------------------
int
BEMesh::saveMesh(char *name)
{
    FILE *f;
    f=openFileW(name,"bei");
    if (f==NULL){
        printf("mesh: failed to open info file\n");
        return 1;
    }
    if(saveInfo(f)){
        printf("mesh: failed to load info file\n");
        fclose(f);
        return 1;
    }
    fclose(f);

    f=openFileW(name,"bee");
    if (f==NULL){
        printf("mesh: failed to open element file\n");
        return 1;
    }
    if(saveElem(f)){
        printf("mesh: failed to load element file\n");
        fclose(f);
        return 1;
    }
    fclose(f);

    f=openFileW(name,"bec");
    if (f==NULL){
        printf("mesh: failed to open coord. file\n");
        return 1;
    }
    if(saveCoord(f)){
        printf("mesh: failed to load coord. file\n");
        fclose(f);
        return 1;
    }
    fclose(f);

    return 0;
}
//---------------------------------------------------------------------------
int BEMesh::elemNode(int el, int nd){
    assert(el>=0 && el<m_enum && nd>=0 && nd<m_node_per_elem);
    return (m_elements[el])[nd];
}
//---------------------------------------------------------------------------
int **BEMesh::getBndElem(int b)
{
    assert(b<m_bnum && b>=0);
    return m_elements+m_bound[b].start;
}
//---------------------------------------------------------------------------
int BEMesh::numBndNodes(int b)
{
    assert(b<m_bnum && b>=0);
    if(m_bnum==1) return m_cnum;
    int cnt=0;
    unsigned mask=(unsigned)1<<b;
    assert(m_bndinfo);
    for(int n=0; n<m_cnum; n++)
        if(m_bndinfo[n]&mask) cnt++;
    return cnt;
}
//---------------------------------------------------------------------------
int BEMesh::numBndElem(int b)
{
    assert(b<m_bnum && b>=0);
    return m_bound[b].size;
}
//---------------------------------------------------------------------------
int BEMesh::getBndNode(int &st, int b)
{
    assert(b<m_bnum && b>=0 && st>=0);
    if(m_bnum==1) return st<m_cnum ? st:-1;
    assert(m_bndinfo);
    unsigned mask=(unsigned)1<<b;
    for(; st<m_cnum; st++)
        if(m_bndinfo[st]&mask) return st;
    return -1;
}
//---------------------------------------------------------------------------
//---------------------------------------------------------------------------
BESubMesh::BESubMesh(BEMesh &base, int b1, int b2)
{
	m_cnum = 0;
	m_enum = 0;
	m_inum = base.numNodes();

	if (b1 < 0)
		b1 = 0;
	else if (b1 >= base.numBoundaries())
		b1 = base.numBoundaries() - 1;

	if (b2 < b1)
		b2 = b1;
	else if (b2 >= base.numBoundaries())
		b2 = base.numBoundaries() - 1;

	for (int n = b1; n <= b2; n++)
		m_enum += base.numBndElem(n);

	m_bnum = b2 - b1 + 1;
	m_base = &base;
	
	unsigned bmask = 1 << b1;
	for (int i = b1; i < b2; i++)
		bmask |= bmask << 1;

	for (int i = 0; i < m_inum; i++)
		if (base.m_bndinfo[i] & bmask)
			m_cnum++;

	m_coords = NULL;
	m_elements = base.getBndElem(b1);
	m_bound = new Boundary[m_bnum];

	for (int n = 0; n < m_bnum; n++) {
		m_bound[n] = base.m_bound[b1 + n];
		m_bound[n].start -= m_bound[0].start;
	}

	for (int n = 0; n < NUM_SIG_TYPES; n++)
		m_sigma[n] = base.getSigma(n);

	m_node_per_elem = base.numNodeElem();

	m_imap = new int[m_inum];
	for (int n = 0; n < m_inum; n++)
		m_imap[n]=-1;

	if (m_cnum == 0) {
		m_fmap = NULL;
		m_bndinfo = NULL;
		return;
	}

	m_fmap = new int[m_cnum];
	m_bndinfo = new unsigned[m_cnum];

	for (int i = 0, bi = 0; i < m_inum; i++) {
		unsigned mask = base.m_bndinfo[i] & bmask;
		if (mask == 0)
			continue;

		m_fmap[bi] = i;
		assert(m_imap[i] < 0);
		m_imap[i] = bi;
		m_bndinfo[bi] = mask >> b1;
		bi++;
	}
}
//---------------------------------------------------------------------------
BESubMesh::~BESubMesh()
{
    if(m_fmap) delete[] m_fmap;
    if(m_imap) delete[] m_imap;
    m_elements=0; // do not delete it
}
//---------------------------------------------------------------------------
int BESubMesh::loadMesh(char *name)
{
    return 1;
}
//---------------------------------------------------------------------------
void BESubMesh::getNodeCoord(int n, double &nx, double &ny, double &nz)
{
    assert(n>=0 && n<m_cnum);
    int nb=m_fmap[n];
    m_base->getNodeCoord(nb, nx, ny, nz);
}
//---------------------------------------------------------------------------
void BESubMesh::getElemCoord(int e, double *x, double *y, double *z)
{
    assert(e>=0 && e<m_enum);
    assert(x && y && z);
    for(int n=0; n<m_node_per_elem; n++){
        m_base->getNodeCoord((m_elements[e])[n], x[n], y[n], z[n]);
    }
}
//---------------------------------------------------------------------------
int BESubMesh::elemNode(int el, int nd)
{
    assert(el>=0 && el<m_enum && nd>=0 && nd<m_node_per_elem);
    int n=(m_elements[el])[nd];
    assert(nd>=0 && nd<m_inum);
    int nmap=m_imap[n];
    assert(nmap>=0 && nmap<m_cnum);
    return nmap;
}
//---------------------------------------------------------------------------
//    BEMesh *m_base;
//    int *m_bndmap;

