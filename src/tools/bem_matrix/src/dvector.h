/* $Id: dvector.h,v 1.3 2008/04/21 06:23:40 canacar Exp $ */
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
#ifndef dvectorH
#define dvectorH
/* This file defines the full and sparse vectors
 * containing double entries. They do not have a
 * common base class. They are just low-level structures
 * for storing vectors.
 * All vectors have mem functions for calculating the memory
 * consumption. And a clear function to clear contents.
 * Functions for calculating Inner product and vector addition
 * are also defined for selected combinations of vectors
 */

#include "define.h"
#include <string.h>

//---------------------------------------------------------------------------
/* DFVector: A FULL vector of sz entries (0 to sz-1)
 * access elements directly from the _vector variable
 */

// DFVector permits the use of constructing with 0 size
// to use an arbitrary double vector as a DRVector
// set _vector and _size to use, 
// set _vector to NULL before destroying

struct DFVector
{
	DFVector(int sz = 0);
	DFVector(const DFVector &v) : _size(0), _vector(0) {
		assign(v);
	}

	~DFVector() {
		if (_vector)
			delete[] _vector;
	}
	
	void mem(int &alloc, int &used, int &bytes);
	inline double& operator[](int i){
		assert(i>=0 && i<_size);
		return _vector[i];
	}

	inline double operator[](int i) const{
		assert(i>=0 && i<_size);
		return _vector[i];
	}

	inline void clear(void){
		memset(_vector,0,_size*sizeof(double));
	}
	void resize(int sz) {
		if (_size == sz)
			return;
		if (_vector)
			delete[] _vector;
		_size = sz;
		_vector = sz ? new double[sz] : NULL;
	}
	void assign(const DFVector &v) {
		resize(v._size);
		if (_size)
			memcpy(_vector, v._vector, _size * sizeof(double));
	}
	
	DFVector &operator=(const DFVector &v) {
		assign(v);
		return *this;
	}

	int _size;
	double *_vector;
};

/* DRVector: used for envelope storage
 * index Ranges from start to end, both inclusive
 * can access elements using the [] operator with correct index
 */
struct DRVector{
  DRVector(int start, int end);
  ~DRVector(){delete[] _vector;}

  void mem(int &alloc, int &used, int &bytes);
  inline double operator[](int i){
	i-=_start;
	if(i>=0 && i<_size)	return _vector[i];
	return 0;
  }
  inline void set(int i, double val){
	i-=_start;
    if(val==0 && i<0) return;
	assert(i>=0 && i<_size);
	_vector[i]=val;
  }
  inline void add(int i, double val){
	if(!val) return;
	i-=_start;
	assert(i>=0 && i<_size);
	_vector[i]+=val;
  }

  inline int end(void){return _start+_size-1;}
  inline void clear(void){  if(_vector) memset(_vector,0,_size*sizeof(double));}
  double *_vector;
  int _start,_size;
};

/* DSVector: A general sparse vector. The index is
 * stored with the value. Memory is allocated for 'size' items
 * and cannot be expanded or reduced. The stored values
 * are kept sorted by index.
 */

struct DSItem{
  double value;
  int index;
};

struct DSVector{
  DSVector(int size);
  ~DSVector(){delete[] _vector;}

  void mem(int &alloc, int &used, int &bytes);
  void clear(void);
  // two functions are variants for a non-recursive binary search
  double operator[](int i);

  // locates or inserts an entry with a given index
  int iseek(int i, int locate=0);
  inline void add(int i, double v){ _vector[iseek(i)].value+=v;}
  inline void set(int i, double v){
    if(v){
      _vector[iseek(i)].value=v;
    }else{
      int s=iseek(i,1);
      if(s!=_count) delitem(s);
    }
  }
  DSVector &operator=(const DSVector &v);

  void expand(DFVector *vec);
  void delitem(int i);

  DSItem *_vector;
  int _size,_count;
};


/* DSAdd(...): Vector addition functions overloaded for different
 * combination of vectors. The result is v1=v1+(s*v2).
 * functions are optimized for the vector combinations.
 */
void DSAdd(DFVector *v1, DFVector *v2, double s);
void DSAdd(DFVector *v1, DRVector *v2, double s);
void DSAdd(DFVector *v1, DSVector *v2, double s);
void DSAdd(DRVector *v1, DRVector *v2, double s);
void DSAdd(DSVector *v1, DSVector *v2, double s);

/* DSIProd(...): Vector inner product p=v1'*v2
 * function is overloaded for given vector combinations.
 */
double DSIProd(const DFVector *v1, const DFVector *v2);
double DSIProd(DFVector *v1, DRVector *v2);
double DSIProd(DFVector *v1, DSVector *v2);
double DSIProd(DRVector *v1, DRVector *v2);
double DSIProd(DRVector *v1, DSVector *v2);
double DSIProd(DSVector *v1, DSVector *v2);

#endif

