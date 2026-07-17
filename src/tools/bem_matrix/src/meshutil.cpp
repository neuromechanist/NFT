/* $Id: meshutil.cpp,v 1.2 2008/01/28 06:27:00 canacar Exp $ */
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
/*! \file meshutil.cpp
  \brief Mesh Utility functions.
  Contains MeshUtil class implementation.
*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "meshutil.h"
//---------------------------------------------------------------------------
static char m_buf[MMGR_BUFSIZE];

int
readIntList(FILE *f, int *lst, int start, int size)
{
	int n,i,v;

	for (n=0; n<size; n++) {
		if (fgets(m_buf, MMGR_BUFSIZE, f)==NULL)
			return 1;
		if (sscanf(m_buf, "%d %d",&i, &v)!=2)
			return 1;
		if (i!=(n+start))
			return 1;
		lst[n]=v;
	}

	return 0;
}


int
readDipoleList(FILE *f, Dipole *lst, int start, int size)
{
	int n,i;
	double x,y,z,px,py,pz;

	for (n=0; n<size; n++) {
		if (fgets(m_buf, MMGR_BUFSIZE, f)==NULL)
			return 1;
		if (sscanf(m_buf, "%d %lg %lg %lg %lg %lg %lg",&i,
			   &x, &y, &z, &px, &py, &pz)!=7)
			return 1;
		if (i!=(n+start))
			return 1;
		lst[n].x = x;
		lst[n].y = y;
		lst[n].z = z;
		lst[n].px = px;
		lst[n].py = py;
		lst[n].pz = pz;
	}

	return 0;
}

int
readDoubleList(FILE *f, double *lst, int start, int size)
{
	int n,i;
	double v;

	for (n=0; n<size; n++){
		if (fgets(m_buf, MMGR_BUFSIZE, f)==NULL) 
			return 1;
		if (sscanf(m_buf, "%d %lf",&i, &v)!=2) 
			return 1;
		if (i!=(n+start)) 
			return 1;
		lst[n]=v;
	}

	return 0;
}

int
readListHdr(FILE *f, int *size)
{
	if (fgets(m_buf, MMGR_BUFSIZE, f)==NULL)     /* # of elements */
		return 1;
	if (sscanf(m_buf, "%d", size)!=1)
		return 1;
	if (*size<=0)
		return 1;
	return 0;
}

int *
loadIntList(FILE *f, int *size)
{
	int sz, *l;

	if(readListHdr(f, &sz))
		return NULL;
	l=new int[sz];
	if (l==NULL)
		return NULL;
	if (readIntList(f,l,1,sz)) {
		delete[] l;
		return NULL;
	}
	*size=sz;
	return l;
}


Dipole *
loadDipoleList(FILE *f, int *size)
{
	int sz;
	Dipole *l;

	if(readListHdr(f, &sz))
		return NULL;

	l=new Dipole[sz];
	if (l == NULL)
		return NULL;
	if (readDipoleList(f,l,1,sz)) {
		delete[] l;
		return NULL;
	}
	*size=sz;
	return l;
}
