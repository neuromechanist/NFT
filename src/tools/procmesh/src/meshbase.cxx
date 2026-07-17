//	$Id: meshbase.cxx,v 1.2 2008/01/10 05:27:22 canacar Exp $
#include <math.h>
#include "meshbase.h"

//---------------------------------------------------------------------------
VertexStore::VertexStore()
{
	for(int n=0; n<NUM_BUCKETS; n++)
		m_buckets[n]=new VpList();
}
//---------------------------------------------------------------------------
VertexStore::~VertexStore()
{
	for(int n=0; n<NUM_BUCKETS; n++)
		if(m_buckets[n]) delete m_buckets[n];
}
//---------------------------------------------------------------------------
int
VertexStore::addVertex(float x, float y, float z,
		       float nx,float ny,float nz)
{
	int hash=getBucket(x,y,z);
	if(hash<0 || hash>=NUM_BUCKETS)
		return -1;
	VpList *b=m_buckets[hash];
//	printf("bucket=%d list=%x\n",hash,b);
//	printf("size=%d\n",b->size());
	VpList::iterator i;

	for(i=b->begin(); i!=b->end(); i++){
		if((*i)->coord.getX()!=x) continue;
		if((*i)->coord.getY()!=y) continue;
		if((*i)->coord.getZ()!=z) continue;
		(*i)->normal+=Point3(nx,ny,nz);
		(*i)->ncount++;
		return (*i)->id;
	}
//	printf("not found\n");

	if(m_vert.size()==0){
		m_minx=m_maxx=x;
		m_miny=m_maxy=y;
		m_minz=m_maxz=z;
	}else{
		if(m_minx>x) m_minx=x;
		else if(m_maxx<x) m_maxx=x;
		if(m_miny>y) m_miny=y;
		else if(m_maxy<y) m_maxy=y;
		if(m_minz>z) m_minz=z;
		else if(m_maxz<z) m_maxz=z;
	}

	Vertex *v=new Vertex();
	v->id=numVertices();
	v->ncount=1;
	v->coord.setCoord(x,y,z);
	v->normal.setCoord(nx, ny, nz);
	b->push_back(v);
	m_vert.push_back(v);
	return v->id;

/*	
	Vertex v;
	v.id=numVertices();
	v.ncount=1;
	v.coord[0]=x;
	v.coord[1]=y;
	v.coord[2]=z;
	v.normal[0]=nx;
	v.normal[1]=ny;
	v.normal[2]=nz;
	m_vert.push_back(v);
	b->push_back(&(m_vert.back()));
	return v.id;
*/

}
//---------------------------------------------------------------------------
int
VertexStore::dumpBuckets(char *fname)
{
	FILE *bf=fopen(fname,"w");
	if(bf==0) return 1;
	/* Portability fix (SCCN, 07/2026): same size_t/%d mismatch as
	 * mesh.cxx's print_boundary(), found by compiler warning (-Wformat)
	 * rather than by inspection -- fixed on the same rationale. */
	for(int n=0; n<NUM_BUCKETS; n++)
		fprintf(bf,"%zu\n",(m_buckets[n])->size());
	fclose(bf);
	return 0;
}
//---------------------------------------------------------------------------
int
Neighbor::add(int nbr)
{
	if (nbr < 0)
		return -1;

	for (int n = 0; n < MAX_NEIGHBOR; n++) {
		if (m_nbrs[n] == nbr)
			return 1;
		if (m_nbrs[n] >= 0)
			continue;
		m_nbrs[n] = nbr;
		m_count++;
		return 0;
	}

	return -1;
}
//---------------------------------------------------------------------------
int
Neighbor::del(int nbr)
{
	if (nbr < 0)
		return -1;

	int dest = 0;
	int n;

	for (n = 0; n < MAX_NEIGHBOR; n++) {
		if (m_nbrs[n] == nbr)
			continue;
		if (dest != n)
			m_nbrs[dest] = m_nbrs[n];
		dest++;
	}

	if (dest == n)
		return 1;

	m_nbrs[dest] = -1;
	m_count--;
	
	return 0;
}
//---------------------------------------------------------------------------
Neighbor &
Neighbor::operator=(const Neighbor &n)
{
	int i;
	m_count = n.count();
	for (i = 0; i < m_count; i++)
		m_nbrs[i] = n[i];

	for (; i < MAX_NEIGHBOR; i++)
		m_nbrs[i] = -1;

	return *this;
}
//---------------------------------------------------------------------------
Neighbor::Neighbor(const Neighbor &n)
{
	int i;
	m_count = n.count();
	for (i = 0; i < m_count; i++)
		m_nbrs[i] = n[i];
	for (; i < MAX_NEIGHBOR; i++)
		m_nbrs[i] = -1;
}
//---------------------------------------------------------------------------
bool
Neighbor::contains(int nbr) const
{
	for (int i = 0; i < m_count; i++)
		if (m_nbrs[i] == nbr)
			return true;
	return false;
}
//---------------------------------------------------------------------------
bool
Neighbor::operator==(const Neighbor &n) const
{
	if (m_count != n.count())
		return false;

	for (int i = 0; i < m_count; i++)
		if (!n.contains(m_nbrs[i]))
			return false;
	return true;
}
//---------------------------------------------------------------------------
