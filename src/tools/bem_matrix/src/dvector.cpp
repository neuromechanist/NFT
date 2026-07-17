/* $Id: dvector.cpp,v 1.3 2008/04/21 06:23:40 canacar Exp $ */
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

#ifdef _WIN32_
#include <mem.h>
#endif

#include "dvector.h"

DFVector::DFVector(int sz)
{
	assert(sz>=0);
	if (sz){
		_vector=new double[sz];
		_size=sz;
		clear();
	}
}

void
DFVector::mem(int &alloc, int &used, int &bytes)
{
	alloc += _size;
	for (int n=0; n<_size; n++)
		if (_vector[n])
			used++;
	bytes += (_size * sizeof(double)) + sizeof(DFVector);
}
//---------------------------------------------------------------------------

DRVector::DRVector(int start, int end){
  assert(start>=0);
  _start=start;
  _size=end-start+1;
  assert(_size>=0);
  if(_size) _vector=new double[_size];
  else _vector=0;
  clear();
}



void DRVector::mem(int &alloc, int &used, int &bytes){
  alloc+=_size;
  for(int n=0; n<_size; n++)
	if(_vector[n]) used++;
  bytes+=(_size*sizeof(double))+sizeof(DRVector);
}

//---------------------------------------------------------------------------

DSVector::DSVector(int sz){
  assert(sz>0);
  _vector=new DSItem[sz];
  _size=sz;
  clear();
}

void DSVector::clear(void){
  memset(_vector,0,_size*sizeof(DSItem));
  _count=0;
}

void DSVector::mem(int &alloc, int &used, int &bytes){
  alloc+=_size;
  used+=_count;
  bytes+=(_size*sizeof(DSItem))+sizeof(DSVector);
}

int DSVector::iseek(int i, int locate){
  int s=0;
  int e=_count-1;
  while(s<=e){
    int t=(s+e)/2;
	if(_vector[t].index<i) s=t+1;
    else if(_vector[t].index>i) e=t-1;
    else return t;
  }
  if(locate)    // locate fails
     return _count;

  assert(_count<_size);
  if(s<_count)
    memmove(_vector+s+1, _vector+s, (_count-s)*sizeof(DSItem));
  _count++;
  _vector[s].index=i;
  _vector[s].value=0;
  return s;
}

void DSVector::delitem(int s){
  assert(s<_count);
  _count--;
  if(s==_count) return;
  memmove(_vector+s, _vector+s+1, (_count-s)*sizeof(DSItem));
}

double DSVector::operator[](int i){
	int s=0;
	int e=_count-1;
	while(s<=e){
	  int t=(s+e)/2;
	  if(_vector[t].index<i) s=t+1;
	  else if(_vector[t].index>i) e=t-1;
	  else return _vector[t].value;
	}
	return 0;
}


void DSVector::expand(DFVector *vec){
  assert(vec);

  DSItem *vec2=_vector;
  int i=0;
  for(int n=_count; n>0; n--, vec2++){
    assert(vec2->index>=0 && vec2->index<vec->_size);
    for(;i<vec2->index; i++) vec->_vector[i]=0;
    vec->_vector[i++]=vec2->value;
  }
  while(i<vec->_size) vec->_vector[i++]=0;
}

// assignment operator
DSVector &DSVector::operator=(const DSVector &v){
    if(this == &v) return *this;
    delete[] _vector;
    _size=v._size;
    _count=v._count;
    _vector=new DSItem[_size];
    memcpy(_vector, v._vector, _size*sizeof(DSItem));
    return *this;
}

//---------------------------------------------------------------------------
// All vector types can be added to DFVector
// proper size checking is asserted

void DSAdd(DFVector *v1, DFVector *v2, double s){
  assert(v1 && v2);
  assert(v1->_size>=v2->_size);
  assert(s);

  double *vec1=v1->_vector;
  double *vec2=v2->_vector;

  for(int n=v2->_size; n; n--, vec1++, vec2++)
    (*vec1)+=(*vec2)*s;
}

void DSAdd(DFVector *v1, DRVector *v2, double s){
  assert(v1 && v2);
  assert(v1->_size>=(v2->_size+v2->_start));
  assert(s);

  double *vec1=v1->_vector+v2->_start;
  double *vec2=v2->_vector;

  for(int n=v2->_size; n; n--, vec1++, vec2++)
    (*vec1)+=(*vec2)*s;
}

void DSAdd(DFVector *v1, DSVector *v2, double s){
  assert(v1 && v2);
  assert(s);

  DSItem *vec2=v2->_vector;

  for(int n=v2->_count; n; n--, vec2++){
    assert(vec2->index>=0 && vec2->index<v1->_size);
    v1->_vector[vec2->index]+=s*vec2->value;
  }
}


// for DRVector and DSVector, only vectors of their own kind are allowed

// only overlapping elements are added for simplicity in factorization
// for the low-triangular column storage matrix

void DSAdd(DRVector *v1, DRVector *v2, double sc){
  assert(v1 && v2);
  assert(sc);

  double *vec1, *vec2;
  int s;
  if(v1->_start >= v2->_start){
    s=v1->_start;
    vec1=v1->_vector;
    vec2=v2->_vector+(v1->_start-v2->_start);
  }else{
    s=v2->_start;
    vec1=v1->_vector+(v2->_start-v1->_start);
    vec2=v2->_vector;
  }
  int e=v1->end()<v2->end() ? v1->end() : v2->end();

  for(;s<=e; s++, vec1++, vec2++)
    *vec1+=(*vec2)*sc;
}

// all elements are added together
void DSAdd(DSVector *v1, DSVector *v2, double s){
  assert(v1 && v2);
  assert(s);

  DSItem *vec1=v1->_vector;
  DSItem *vec2=v2->_vector;
  int i1=v1->_count;
  int i2=v2->_count;

  while(i1 && i2){
    if(vec1->index==vec2->index){
      vec1->value+=vec2->value*s;
      vec1++;
      vec2++;
      i1--;
      i2--;
    }else if(vec1->index<vec2->index){
      vec1++;
      i1--;
	}else{
      assert(v1->_count<v1->_size);
      memmove(vec1+1, vec1, i1*sizeof(DSItem));
      v1->_count++;
      vec1->index=vec2->index;
      vec1->value=vec2->value*s;
      vec1++;
      vec2++;
      i2--;
	}
  }

  while(i2){ // add remaining elements
    assert(v1->_count<v1->_size);
    v1->_count++;
    vec1->index=vec2->index;
    vec1->value=vec2->value*s;
    vec1++;
    vec2++;
    i2--;
  }
}

//---------------------------------------------------------------------------
// all combinations are allowed for inner product since it returns a single value

double DSIProd(const DFVector *v1, const DFVector *v2){
  assert(v1 && v2);
  assert(v1->_size>=v2->_size);

  double *vec1=v1->_vector;
  double *vec2=v2->_vector;
  double p=0;

  for(int n=v2->_size; n; n--, vec1++, vec2++)
    p+=(*vec1)*(*vec2);

  return p;
}

double DSIProd(DFVector *v1, DRVector *v2){
  assert(v1 && v2);
  assert(v1->_size>=(v2->_size+v2->_start));

  double *vec1=v1->_vector+v2->_start;
  double *vec2=v2->_vector;
  double p=0;
  for(int n=v2->_size; n; n--, vec1++, vec2++)
    p+=(*vec1)*(*vec2);
  return p;
}

double DSIProd(DFVector *v1, DSVector *v2){
  assert(v1 && v2);

  DSItem *vec2=v2->_vector;
  double p=0;

  for(int n=v2->_count; n; n--, vec2++){
    assert(vec2->index>=0 && vec2->index<v1->_size);
    p+=v1->_vector[vec2->index]*vec2->value;
  }

  return p;
}


double DSIProd(DRVector *v1, DRVector *v2){
  assert(v1 && v2);

  double *vec1, *vec2;
  int s;

  if(v1->_start >= v2->_start){
    s=v1->_start;
	vec1=v1->_vector;
    vec2=v2->_vector+(v1->_start-v2->_start);
  }else{
    s=v2->_start;
    vec1=v1->_vector+(v2->_start-v1->_start);
    vec2=v2->_vector;
  }
  int e=v1->end()<v2->end() ? v1->end() : v2->end();
  double p=0;
  for(;s<=e; s++, vec1++, vec2++)
    p+=(*vec1)*(*vec2);
  return p;
}
double DSIProd(DRVector *v1, DSVector *v2){
  assert(v1 && v2);

  int of=v2->iseek(v1->_start,1);
  DSItem *vec2=v2->_vector+of;
  double p=0;

  for(int n=v2->_count-of; n>0; n--, vec2++){
    assert(vec2->index<=v1->end());
	p+=(*v1)[vec2->index]*vec2->value;
  }

  return p;
}

double DSIProd(DSVector *v1, DSVector *v2){
  assert(v1 && v2);

  DSItem *vec1=v1->_vector;
  int of=v2->iseek(vec1->index,1);
  DSItem *vec2=v2->_vector+of;

  int i1=v1->_count;
  int i2=v2->_count-of;
  double p=0;

  while(i1>0 && i2>0){
    if(vec1->index==vec2->index){
      p+=vec1->value*vec2->value;
      vec1++;
      vec2++;
	  i1--;
      i2--;
    }else if(vec1->index<vec2->index){
      vec1++;
      i1--;
    }else{
      vec2++;
      i2--;
    }
  }
  return p;
}


