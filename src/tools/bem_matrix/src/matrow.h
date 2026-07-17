/* $Id: matrow.h,v 1.3 2008/04/21 06:25:28 canacar Exp $ */
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
#ifndef matrowH
#define matrowH

#include <stdio.h>
#include "dvector.h"

//---------------------------------------------------------------------------
class matRow{
public:
    matRow(int rows, int cols):_nrows(rows),_ncols(cols){};
    virtual ~matRow(){};

    virtual void clear(void)=0;
    virtual void mem(int &alloc, int &used, int &bytes)=0;

    virtual void add(int i, int j, double val)=0;
    virtual void set(int i, int j, double val)=0;
    virtual double get(int i, int j) const =0;

    virtual double iprod_row(int row, double *vec) const = 0;
    virtual double iprod_row(int row, const DFVector &vec) const = 0;
    virtual void expand_row(int row, double *vec)=0;
    virtual void add_row(DFVector *vec, int row, double s) const = 0;

    virtual void multiadd(int np, int *i, int *j, double *val, double mul=1);
    virtual int serialize(int np, int *i, int *j, double *val, int &si, int &sj);
    virtual int save(FILE *f) const;
    virtual int load(FILE *f);

    inline int numRows() const {return _nrows;}
    inline int numCols() const {return _ncols;}

protected:
    int _nrows, _ncols;
};


class matFullRow:public matRow{
public:
    virtual ~matFullRow(){};

    virtual void clear(void);
    virtual void mem(int &alloc, int &used, int &bytes);

    virtual void add(int i, int j, double val);
    virtual void set(int i, int j, double val);
    virtual double get(int i, int j) const;

    virtual void expand_row(int col, double *vec);
    virtual double iprod_row(int col, double *vec) const;
    virtual double iprod_row(int col, const DFVector &vec) const;
    virtual void add_row(DFVector *vec, int col, double s) const;

    inline DFVector *getRow(int row)
        {assert(row>=0 && row<_nrows); return _rows[row];}

protected:
    matFullRow(int rows, int cols):matRow(rows,cols),_rows(0){};
    matFullRow(void):matRow(0,0),_rows(0){};

    DFVector **_rows;
};

class matFullRowDynamic:public matFullRow{
public:
    matFullRowDynamic(int nr, int nc, DFVector **rows);
    virtual ~matFullRowDynamic();
};

class matFullRowStatic:public matFullRow{
public:
    matFullRowStatic(int rows, int cols);
    virtual ~matFullRowStatic();
};


#endif






