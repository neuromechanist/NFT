/* $Id: matrow.cpp,v 1.3 2008/04/21 06:25:28 canacar Exp $ */
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
#include <ctype.h>
#include "matrow.h"
//---------------------------------------------------------------------------
// Row matrix abstract base class
//---------------------------------------------------------------------------

void matRow::multiadd(int np, int *i, int *j, double *val, double mul){
        assert(i && j && val);
        assert(np>=0);
        while(np--)
                add(*(i++),*(j++),(*(val++))*mul);
}

int matRow::serialize(int np, int *i, int *j, double *val, int &si, int &sj){
        assert(i && j && val);
        assert(np>=0);
        assert(si>=0 && si<_nrows && sj>=0 && sj<_ncols);

        int cnt=0;

        for(;si<_nrows;si++){
                for(;sj<_ncols; sj++){
                   double v=get(si,sj);
                   if(!v) continue;
                   if(cnt==np) return cnt;
                   i[cnt]=si;
                   j[cnt]=sj;
                   val[cnt++]=v;
                }
                sj=0;
        }
        return cnt;
}

int matRow::save(FILE *f) const {
        if (f == NULL) return 1;

        for(int si=0 ;si<_nrows; si++){
                for(int sj=0; sj<_ncols; sj++){
                        double v=get(si,sj);
                        fprintf(f,"%g ", v);
                }
                fprintf(f,"\n");
        }
        return 0;
}

int matRow::load(FILE *f){
        static char buf[256];
        if (f == NULL) return 1;

        for(int si=0 ;si<_nrows; si++){
                for(int sj=0; sj<_ncols; sj++){
                        double v;
                        if (fscanf(f,"%lg", &v) != 1)
                                return 1;
                        set(si, sj, v);
                }
                fgets(buf, 256, f);
                char *end = strchr(buf, '\n');
                if (end == NULL) return 1;
                for (char *t = buf; *t; t++)
                        if (! isspace(*t)) return 1;
        }
        return 0;
}

//---------------------------------------------------------------------------
// Full Row Matrix:
// have two (lightweight) variations Ststic and Dynamic -
//   Static allocates/uses/destroys its own data structure
//   Dynamic gets pre-allocated columns and does not destroy them
//---------------------------------------------------------------------------

matFullRowStatic::matFullRowStatic(int rows, int cols):
matFullRow(rows,cols){
  assert (rows>0 && cols>0);
  _rows=new DFVector*[rows];
  for(int n=0; n<rows; n++)
    _rows[n]=new DFVector(cols);
}

matFullRowStatic::~matFullRowStatic(){
  for(int n=0; n<_nrows; n++)
    delete _rows[n];
  delete _rows;
}

matFullRowDynamic::matFullRowDynamic(int nr, int nc, DFVector **rows):
matFullRow(nr,nc){
  assert (nr>0 && nc>0  && rows);
  _rows=rows;
#ifndef NDEBUG
  for(int n=0; n<nr; n++){
        assert(_rows[n]);
        assert(_rows[n]->_size>=nc);
  }
#endif
}

matFullRowDynamic::~matFullRowDynamic(){
  _rows=0;
}

void matFullRow::clear(void){
    assert(_rows);
    for(int n=0; n<_nrows; n++)
        _rows[n]->clear();
}

void matFullRow::add(int i, int j, double val){
    assert(j>=0 && j<_ncols);
    assert(i>=0 && i<_nrows);
    (*_rows[i])[j]+=val;
}

void matFullRow::set(int i, int j, double val){
    assert(j>=0 && j<_ncols);
    assert(i>=0 && i<_nrows);
    (*_rows[i])[j]=val;
}

double matFullRow::get(int i, int j) const{
    assert(j>=0 && j<_ncols);
    assert(i>=0 && i<_nrows);
    return (*_rows[i])[j];
}

void matFullRow::expand_row(int row, double *vec){
    assert(row>=0 && row<_nrows);
    memcpy(vec, _rows[row]->_vector, _ncols*sizeof(double));
}

double matFullRow::iprod_row(int row, double *vec) const{
    assert(row>=0 && row<_nrows);
    DFVector v(0);
    v._size=_ncols;
    v._vector=vec;
    double ret=DSIProd(&v, _rows[row]);
    v._vector=0;
    return ret;
}

double matFullRow::iprod_row(int row, const DFVector &v) const {
    assert(row>=0 && row<_nrows);
    assert(v._size == _ncols);
    double ret=DSIProd(&v, _rows[row]);
    return ret;
}

void matFullRow::add_row(DFVector *vec, int row, double s) const{
    assert(row>=0 && row<_nrows);
    if(s)
	    DSAdd(vec, _rows[row],s);
}

void matFullRow::mem(int &alloc, int &used, int &bytes){
    bytes+=sizeof(matFullRow);
    if(_rows){
        bytes+=_nrows*sizeof(DFVector*);
        for(int n=0; n<_nrows; n++)
            if(_rows[n]) _rows[n]->mem(alloc,used,bytes);
    }
}

