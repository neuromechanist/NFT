#ifndef _SHOWMESH_H_
#define _SHOWMESH_H_

#include "mesh.h"

#define MAX_MESHES 20

class ProcessMesh
{
public:
	ProcessMesh(void);

	TriMeshLin *addMesh(const char *fn);

	int save_mesh(const char *fn, int mn, int fc = -1);
	int load_node_fn(const char *fn, int mn);
	int set_node_range(double rmin, double rmax, int mn);
	int extract_class(int mn, int fc);

	int smooth_mesh(int mn, int cnt = 1) {
		TriMeshLin *mesh = getMesh(mn);
		if (mesh == NULL)
			return 1;
		mesh->smooth(cnt);
		return 0;
	}

	int fill_holes(int mn) {
		TriMeshLin *mesh = getMesh(mn);
		if (mesh == NULL)
			return 1;
		return (mesh->fillHoles());
	}

	int correct_mesh(int mn);
	int improve_mesh(int mn, int cnt = 1,
	    double aspect = 0.001, double esize = 1000);
	int split_mesh(int mn, double thresh);
	int split_intersecting(int mn);
	int process_intersecting(int mn, int fix);
	int process_sharp_edges(int mn, int fix);

	int numMeshes(void) {
		return num_meshes;
	}

	TriMeshLin *getMesh(int n) {
		return (n < 0 || n > num_meshes) ? NULL: meshes[n];
	}

	void getMeshOffset(double &mx, double &my, double &mz) {
		mx = m_mx;
		my = m_my;
		mz = m_mz;
	}

	Point3 getMeshOffset(void) {
		return Point3(m_mx, m_my, m_mz);
	}

private:
	double *loadPotFile(TriMeshLin *msh, FILE *f);

	TriMeshLin *meshes[MAX_MESHES];

	int num_meshes;
	int numiter;
	int numcorrect;
	int update;
	int fclass;
	double tstep;
	int tselected;

	double m_delsc;

	// mesh mean
	double m_mx, m_my, m_mz;
};

#endif
