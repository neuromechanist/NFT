/* $Id: shape.h,v 1.2 2008/01/28 06:27:00 canacar Exp $ */
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
#ifndef shapeH
#define shapeH
//---------------------------------------------------------------------------
class GPoint{
public:
    GPoint(int size, double x, double y, double w);
    ~GPoint();

    double weight(void){return m_w;}
    double shape(int i){return m_shape[i];}
    double global(double *v);
    void calcJacob(double *x, double *y, double *z,
                   double &jx, double &jy, double &jz);

private:
    void alloc(void);
    void setupLin();
    void setupQuad();
    void setupCubic();

    int m_size;
    double m_x, m_y, m_w;
    double *m_shape, *m_der1, *m_der2;
};


class GPStore{
public:
    GPStore(int numgp, int gpsize);
    ~GPStore();

    void addGP(double x, double y, double w){addGP(new GPoint(m_size,x,y,w));}

    int count(void){return m_count;}
    GPoint *getGP(int i){ return( (i>=0 && i<m_count) ? m_gps[i]:0 );}

private:
    void addGP(GPoint *gp){if(m_count<m_max && gp) m_gps[m_count++]=gp;}
    GPoint **m_gps;
    int m_max, m_count, m_size;
};


#endif
