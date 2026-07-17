#ifndef _MESHPROC_H_
#define _MESHPROC_H_

#include <set>
#include <vector>
#include "mesh.h"
#include "scache.h"

class MeshProc {
public:
	MeshProc(TriMeshLin *msh) : m_mesh(msh) {};
	MeshProc(MeshProc &mp) { m_mesh = mp.getMesh();}

	TriMeshLin *getMesh(void) {return m_mesh;}

	int intLineTri(int tri, const Point3&p1,
		       const Point3 &p2, Point3 &pi) const;
	double triNearest (int tri, const Point3 &p1, Point3 &pi) const;
	double averageEdgeDistance(void);
	double minimumEdgeDistance(void);
	double minimumEdgeDistance(int node);
	void splitEdges(double thresh);
	void splitIntersecting(void);
	int printIntersecting(void);
	int pushIntersecting(void);
	void mergeVertices(double dist);
	void mergeElements(double *ef = NULL);
	int printSharpEdges(void);
	int flipSharpEdges(void);

	TriMeshLin *extractClass(int cls);

	typedef set<unsigned int> nodeset_t;
	typedef vector<unsigned> nodelist_t;

protected:
	int edgeNearest(const Point3 &p1, const Point3 &p2,
			const Point3 &pt, Point3 &pi) const;
	int splitElement(unsigned int e, vector<unsigned int> &faces);
	void splitElement3(vector<unsigned int> &faces,
			   unsigned int p1, unsigned int p2, unsigned int p3,
			   unsigned int c2, unsigned int c3);
	void triangulateElement(unsigned int e,
				nodelist_t &faces, const nodeset_t nl);
	int elementBoundingSphere(Point3 a, Point3 b, Point3 c,
				  Point3 &center, double &r);
	SCache *createElementCache(void);
	int checkSharpEdge(unsigned int el, unsigned int v1, unsigned int v2,
			   set<unsigned int> &eset);
	int flipSharp(unsigned int e0, unsigned int e1,
		      unsigned int e2, unsigned int v0);

	TriMeshLin *m_mesh;
};


#endif
