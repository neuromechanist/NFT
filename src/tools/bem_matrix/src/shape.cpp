/* $Id: shape.cpp,v 1.3 2008/01/28 07:26:21 canacar Exp $ */
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
#include "shape.h"
//---------------------------------------------------------------------------
GPoint::GPoint(int size, double x, double y, double w)
{
    m_x=x;
    m_y=y;
    m_w=w;
    m_size=size;
    m_shape=m_der1=m_der2=0;

    if(size==3) setupLin();
    else if(size==6) setupQuad();
    else if(size==10) setupCubic();
}
//---------------------------------------------------------------------------
GPoint::~GPoint()
{
    if(m_shape) delete[] m_shape;
    if(m_der1) delete[] m_der1;
    if(m_der2) delete[] m_der2;
}
//---------------------------------------------------------------------------
void GPoint::alloc()
{
    m_shape=new double[m_size];
    m_der1=new double[m_size];
    m_der2=new double[m_size];
}
//---------------------------------------------------------------------------
void GPoint::setupLin()
{
    alloc();
    m_shape[0]=m_y;
    m_shape[1]=1-m_x-m_y;
    m_shape[2]=m_x;

    m_der1[0]=0;
    m_der1[1]=-1;
    m_der1[2]=1;

    m_der2[0]=1;
    m_der2[1]=-1;
    m_der2[2]=0;
/* linear shape function setup */
}
//---------------------------------------------------------------------------
void GPoint::setupQuad()
{
    alloc();
    m_shape[0]=2*m_y*m_y-m_y;
    m_shape[1]=-4*(m_y*m_y+m_x*m_y-m_y);
    m_shape[2]=2*(m_x*m_x+m_y*m_y)+4*m_x*m_y-3*(m_x+m_y)+1;
    m_shape[3]=-4*(m_x*m_x+m_x*m_y-m_x);
    m_shape[4]=2*m_x*m_x-m_x;
    m_shape[5]=4*m_x*m_y;

    m_der1[0]=0;
    m_der1[1]=-4*m_y;
    m_der1[2]=4*(m_x+m_y)-3;
    m_der1[3]=-4*(2*m_x+m_y-1);
    m_der1[4]=4*m_x-1;
    m_der1[5]=4*m_y;

    m_der2[0]=4*m_y-1;
    m_der2[1]=-4*(2*m_y+m_x-1);
    m_der2[2]=m_der1[2];
    m_der2[3]=-4*m_x;
    m_der2[4]=0;
    m_der2[5]=4*m_x;
}
//---------------------------------------------------------------------------
void GPoint::setupCubic()
{
    alloc();
    /* cubic shape function setup */
}
//---------------------------------------------------------------------------
double GPoint::global(double *v)
{
    double sum=0;
    if(v==0 || m_shape==0) return 0;

    for(int i=0; i<m_size; i++)
        sum+=v[i]*m_shape[i];
    return sum;
}
//---------------------------------------------------------------------------
void GPoint::calcJacob(double *x, double *y, double *z,
                   double &jx, double &jy, double &jz)
{
    double j11, j12, j13;
    double j21, j22, j23;

    j11=j12=j13=j21=j22=j23=0;

    if(x==0 || y==0 || z==0 || m_der1==0 || m_der2==0) return;
    for(int n=0; n<m_size; n++){
        j11+=m_der1[n]*x[n];
        j12+=m_der1[n]*y[n];
        j13+=m_der1[n]*z[n];
        j21+=m_der2[n]*x[n];
        j22+=m_der2[n]*y[n];
        j23+=m_der2[n]*z[n];
    }
    jx=0.5*(j12*j23-j13*j22);
    jy=0.5*(j13*j21-j11*j23);
    jz=0.5*(j11*j22-j12*j21);
}
//---------------------------------------------------------------------------
//---------------------------------------------------------------------------
GPStore::GPStore(int numgp, int gpsize)
{
    m_max=numgp;
    m_size=gpsize;
    m_count=0;
    m_gps=new GPoint*[numgp];
}
//---------------------------------------------------------------------------
GPStore::~GPStore()
{
    if(m_gps) delete[] m_gps;
}
//---------------------------------------------------------------------------

