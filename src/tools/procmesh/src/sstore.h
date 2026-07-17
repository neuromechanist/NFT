#ifndef _SSTORE_H_
#define _SSTORE_H_
#include <list>

class SNode
{
	
private:
	Rect3 m_bound;
	map<SPhere3 *, unsigned int> m_spheres;
	SNode *m_children[8];
};


class SStore {
public:
	SStore();

private:
	
};


#endif
