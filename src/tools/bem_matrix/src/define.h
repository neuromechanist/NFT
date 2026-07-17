/* $Id: define.h,v 1.2 2008/01/28 06:27:00 canacar Exp $ */
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

/* 	$Id: define.h,v 1.2 2008/01/28 06:27:00 canacar Exp $	 */
#ifndef _DEFINE_H_
#define _DEFINE_H_

//#define NDEBUG // to remove assertions
#include <assert.h>

#define TRESHOLD 1e-14
// number of nodes in an element
#define NUM_NODES 20
// maximum fill-in for off-diagonal
#define MAX_FILL 80

//! point x,y,z coordinates
typedef double point[3];
//! element structure, contains point index (mesh coord) for each node
typedef int node[NUM_NODES];
#endif

