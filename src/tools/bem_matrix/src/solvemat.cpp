/* $Id: solvemat.cpp,v 1.1 2008/04/21 06:26:51 canacar Exp $ */
/* 
 * Based on the Preconditioned BiConjugate Gradient Stabilized method,
 * following the the algorithm described on p. 27 of the SIAM
 * Templates book, and C++ template code. Freely available in netlib:
 *
 * http://www.netlib.org/templates/index.html
 * http://www.netlib.org/linalg/html_templates/Templates.html
 *
 * R. Barrett, M. Berry, T. F. Chan, J. Demmel, J. Donato,
 * J. Dongarra, V. Eijkhout, R. Pozo, C. Romine, H. Van der Vorst,
 * "Templates for the Solution of Linear Systems: Building Blocks for
 * Iterative Methods, 2nd Edition", SIAM, 1994
 */

/* 
 * This file is part of the EMSI Tools Package developed at the
 * Brain Research Laboratory, Middle East Technical University
 * Department of Electrical and Electronics Engineering.
 *
 * Copyright (C) 2008 Zeynep Akalin Acar
 * Copyright (C) 2008 Can Erkin Acar
 * Copyright (C) 2008 Nevzat G. Gencer
 * 
 * The EMSI Tools Package is released under GPLv2 License.
 * The templates code appears to be under the BSD license.
 */

#include <math.h>
#include "dvector.h"
#include "matrow.h"


static inline double
norm(const DFVector &v)
{
	return sqrt(DSIProd(&v, &v));
}

static inline double
dot(const DFVector &v1, const DFVector &v2)
{
	return DSIProd(&v1, &v2);
}

/* y = Ax */
static void
mulAx(DFVector &y,const matRow &A, const DFVector &x, int tr)
{
	int sz = x._size;
	y.resize(sz);
	if (tr) {
		y.clear();
		for (int i = 0; i < sz; i++)
			A.add_row(&y, i, x[i]);
	} else {
		for (int i = 0; i < sz; i++)
			y[i] = A.iprod_row(i, x._vector);
		
	}
}

/* y = y + s Ax */
static void
sAxpy(DFVector &y, double s, const matRow &A, const DFVector &x, int tr)
{
	int sz = x._size;
	if (s == 0)
		return;

	if (tr) {
		for (int i = 0; i < sz; i++)
			A.add_row(&y, i, x[i] * s);
	} else {
		for (int i = 0; i < sz; i++)
			y[i] += s * A.iprod_row(i, x._vector);
		
	}
}

/* preconditioner solve y = Ax */
/* use diagonal as preconditioner */
static void
pcSolve(DFVector &y, const matRow &A, const DFVector &x)
{
	static DFVector v(0);
	if (v._size == 0) {
		v.resize(A.numRows());
		for (int i = 0; i < v._size; i++)
			v[i] = A.get(i,i) ? 1/A.get(i,i) : 0;
	}
	for (int i = 0; i < v._size; i++)
		y[i] = v[i] * x[i];
}


static 
int 
BiCGSTAB(const matRow &A, DFVector &x, const DFVector &b,
	 int &max_iter, double &tol, int tr)
{
	double resid;
	double rho_1, rho_2, alpha, beta, omega;
	DFVector p, phat, s, shat, t, v;

	double normb = norm(b);

	DFVector r = b;
	sAxpy(r, -1, A, x, tr);

	DFVector rtilde = r;

	if (normb == 0.0)
		normb = 1;
  
	if ((resid = norm(r) / normb) <= tol) {
		tol = resid;
		max_iter = 0;
		return 0;
	}

	for (int i = 1; i <= max_iter; i++) {
		rho_1 = dot(rtilde, r);
		if (rho_1 == 0) {
			tol = norm(r) / normb;
			return 2;
		}
		if (i == 1)
			p = r;
		else {
			beta = (rho_1/rho_2) * (alpha/omega);
			for (int j = 0; j < r._size; j++)
				p[j] = r[j] + beta * (p[j] - omega * v[j]);
		}
		pcSolve(phat, A, p);
		mulAx(v, A, phat, tr);

		alpha = rho_1 / dot(rtilde, v);
		for (int j = 0; j < r._size; j++)
			s[j] = r[j] - alpha * v[j];

		if ((resid = norm(s)/normb) < tol) {
			for (int j = 0; j < x._size; j++)
				x[j] += alpha * phat[j];
			tol = resid;
			return 0;
		}

		pcSolve(shat, A, s);
		mulAx(t, A, shat, tr);
		omega = dot(t,s) / dot(t,t);
		for (int j = 0; j < x._size; j++)
			x[j] += alpha * phat[j] + omega * shat[j];
		for (int j = 0; j < s._size; j++)
			r[j] = s[j] - omega * t[j];

		rho_2 = rho_1;
		if ((resid = norm(r) / normb) < tol) {
			tol = resid;
			max_iter = i;
			return 0;
		}
		if (omega == 0) {
			tol = norm(r) / normb;
			return 3;
		}
	}

	tol = resid;
	return 1;
}


void
solveMatrix(matRow &mat, DFVector &xvec, DFVector &rhs, int itmax, int tr)
{
	int max_iter = itmax;
	double tol = 1e-10;

	BiCGSTAB(mat, xvec, rhs, max_iter, tol, tr);

        printf("Solution in %d of %d Iterations, tol: %g (1e-10) ! ...\n",
	       max_iter, itmax, tol);
}
