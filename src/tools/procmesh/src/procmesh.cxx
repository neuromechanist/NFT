//	$Id: showmesh.cxx,v 1.22 2008/04/16 08:11:27 canacar Exp $

#include "procmesh.h"
#include "command.h"
#include "meshproc.h"
//---------------------------------------------------------------------------

// number of times we try to correct the mesh
#define MAX_CORRECT 10

ProcessMesh::ProcessMesh(void)
{
	m_mx = m_my = m_mz = 0;

	fclass = 0;

	tselected = 0;
	tstep = 1;

	num_meshes = 0;

	m_delsc = 1;
}

double *
ProcessMesh::loadPotFile(TriMeshLin *msh, FILE *f)
{
	if (f == NULL || msh == NULL)
		return 0;

	int nn = msh->getNumVerts();
	double *pot = new double[nn];

	int n;
	for (n = 0; n < nn; n++)
		if (fscanf(f, "%lg", pot+n) != 1)
			break;

	if (n != nn) {
		delete[] pot;
		return 0;
	}

	return pot;
}

int
ProcessMesh::save_mesh(const char *fn, int mn, int fc)
{
	int ret;
	TriMeshLin *mesh = getMesh(mn);
			
        mesh->moveMesh(m_mx, m_my, m_mz);

	if (fc < 0)
		ret = mesh->save(fn);
	else
		ret = mesh->saveClass(fn, fc);

        mesh->moveMesh(-m_mx, -m_my, -m_mz);

	return ret;
}

int
ProcessMesh::extract_class(int mn, int fc)
{
	TriMeshLin *mesh = getMesh(mn);
	MeshProc mp(mesh);

//        mesh->moveMesh(m_mx, m_my, m_mz);

	int nc = mesh->getNumClasses();
	if (nc == 1) {
		printf("Mesh has only one class\n");
		return 0;
	}

	if (fc == -1) {
		printf("Selecting largest class\n");
		int mx = 0;
		for (int n = 0; n < nc; n++) {
			if (mesh->getNumTris(n) > mx) {
				mx = mesh->getNumTris(n);
				fc = n;
			}
		}
	}

	TriMeshLin *mc = mp.extractClass(fc);
	if (mc == NULL)
		return 1;

	mesh->set(*mc);
//	mesh->moveMesh(-m_mx, -m_my, -m_mz);

	delete mc;

	return 0;
}

int
ProcessMesh::improve_mesh(int mn, int cnt, double aspect, double esize)
{
	static int sid = 0;
	char name[64];

	TriMeshLin *mesh = getMesh(mn);

	if (mesh == NULL)
		return 1;

	for (int n = 0; n < cnt; n++) {
		int ret;
		MeshProc mp(mesh);
		mesh->recalculateEdges();
		double avg =  mp.averageEdgeDistance();
		printf("Average Edge Distance: %g\n", avg);

#if 0
		mp.mergeVertices(0);
#endif
		ret = mesh->flipElements();
		printf(" >> flipped %d edges\n", ret);
		ret = mesh->removeBadAspectElements(aspect);
		printf(" >> removed %d bad aspect elements\n", ret);
		ret = mesh->removeSmallElements(avg * esize);
		printf(" >> removed %d small elements\n", ret);
		ret = mp.flipSharpEdges();
		printf(" >> flipped %d sharp edges\n", ret);

#if 0
		double *ef = new double[mesh->getNumTris()];
		mp.mergeElements(ef);
		mesh->recalculateEdges();

		int flag = 0;
		set<unsigned int> nbrs;
		for (int i = 0; i < mesh->getNumTris(); i++) {
			if (ef[i])
				flag++;
			else
				continue;
			for (int m = 0; m < 3; m++) {
				int v = mesh->getElemInd(i, m);
				Neighbor &nb = mesh->getFaceNbrs(v);
				printf("e: %d, v: %d nb: %d\n",
				       i, v, nb.count());
				for (int n = 0; n < nb.count(); n++)
					nbrs.insert(nb[n]);
			}
		}

		printf(">> %d elements flagged as identical \n", flag);
		printf(">> %d neighbors selected\n", nbrs.size());

		for (set<unsigned int>::iterator it = nbrs.begin();
		     it != nbrs.end(); it++)
			ef[*it] += 0.1;

		meshes[mn]->setEField(ef);
		meshes[mn]->setFlag(MRF_SHOW_ECOLOR);
		snprintf(name, sizeof(name), "merged_%02d.dat", sid);
		FILE *f = fopen(name, "wb");
		for (int i = 0; i < mesh->getNumTris(); i++) {
			fprintf(f, "%d %g\n", i, ef[i]);
		}
		fclose(f);
		snprintf(name, sizeof(name), "merged_%02d.smf", sid);
		mesh->save(name);
		sid++;
		delete[] ef;
#endif
	}

	return 0;
}

int
ProcessMesh::correct_mesh(int mn)
{
	TriMeshLin *mesh = getMesh(mn);
	int tries;

	if (mesh == NULL)
		return 1;

	printf(" >> Correcting ...\n");

	for (tries = 0; tries < MAX_CORRECT; tries++)
		if (!mesh->correctMesh())
			break;

	if (tries == MAX_CORRECT)
		printf(" >> Failed to correct ...\n");
	else
		printf(" >> Corrected in %d tries ...\n", tries + 1);

	return 0;
}

int
ProcessMesh::split_mesh(int mn, double thresh)
{
	TriMeshLin *mesh = getMesh(mn);

	if (mesh == NULL)
		return 1;

	MeshProc mp(mesh);
	printf("Average Edge Distance: %g\n", mp.averageEdgeDistance());
	printf("Splitting Edges ...\n");
	mp.splitEdges(thresh);
	printf("Average Edge Distance: %g\n", mp.averageEdgeDistance());
	return 0;
}

int
ProcessMesh::split_intersecting(int mn)
{
	TriMeshLin *mesh = getMesh(mn);

	if (mesh == NULL)
		return 1;

	MeshProc mp(mesh);
	double d = mp.averageEdgeDistance();
	double md = mp.minimumEdgeDistance();

	printf("Average Edge Distance: %g\n", d);
	printf("Minimum Edge Distance: %g\n", md);
	mp.mergeVertices(md/10);

	printf("Splitting intersecting elements ...\n");
	mp.splitIntersecting();
	mesh->printIntersectionBoundaries();
	return 0;
}

int
ProcessMesh::process_intersecting(int mn, int fix)
{
	TriMeshLin *mesh = getMesh(mn);
	int ni;

	if (mesh == NULL)
		return 1;

	MeshProc mp(mesh);

	if (fix) {
		printf("Looking for intersecting elements ...\n");
		ni = mp.pushIntersecting();

	} else {
		printf("Looking for intersecting elements ...\n");
		ni = mp.printIntersecting();
	}

	if (ni)
		printf("%d intersections %s\n", ni, fix ? "fixed" : "detected");
	else
		printf("no intersections\n");
	return (0);
}

int
ProcessMesh::process_sharp_edges(int mn, int fix)
{
	TriMeshLin *mesh = getMesh(mn);
	int ni;

	if (mesh == NULL)
		return 1;

	MeshProc mp(mesh);

	printf("Looking for sharp edges ...\n");
	if (fix)
		ni = mp.flipSharpEdges();
	else
		ni = mp.printSharpEdges();		

	if (ni)
		printf("%d elements have sharp edges\n", ni);
	else
		printf("no sharp edges\n");

	return (0);
}

// setup and load the mesh
TriMeshLin *
ProcessMesh::addMesh(const char *fn)
{
        if (num_meshes >= MAX_MESHES) {
                printf ("Too many meshes!\n");
                return (NULL);
        }

        TriMeshLin *mesh = new TriMeshLin();
//        mesh->setScale(2.2);
        if(mesh->loadMesh(fn)){
                printf("failed to load mesh %s!\n",fn);
                return (NULL);
        }
        mesh->scaleMesh(1,1,1);

        if (num_meshes == 0)
                mesh->getMean().getCoord(m_mx, m_my, m_mz);

        mesh->moveMesh(-m_mx, -m_my, -m_mz);

        meshes[num_meshes++] = mesh;
        
        return mesh;
}
