//---------------------------------------------------------------------------
#ifndef sphere3H
#define sphere3H
#include "rect3.h"
//---------------------------------------------------------------------------

class Sphere3 {
 public:

	Sphere3 (double x=0, double y=0, double z=0, double rad=1):
		m_c(x,y,z), m_r(rad) {}

	Sphere3 (const Point3 &c, double rad):
		m_c(c), m_r(rad) {}

	Sphere3 (const Sphere3 &s):
		m_c(s.getCenter()), m_r(s.getRadius()) {}

	Sphere3 (const Rect3 &r):
		m_c(r.getMid()), m_r((m_c-r.getP1()).length()) {}

	inline const Point3 &getCenter(void) const { return m_c; }
	inline double getRadius(void) const { return m_r; }

	inline int isInside(const Point3 &p) const {
		Point3 pt(p-m_c);
		return pt.length() <= m_r;
	}

	inline int intersect(const Point3 &p, double r) const {
		Point3 pt(p-m_c);
		return (pt.length() <= (m_r + r));
	}

	inline int intersect(const Sphere3 &s) const {
		return intersect(s.getCenter(), s.getRadius());
	}

/*    inline int intersect(const Rect3 &r) const
      {return intersect(Sphere3(r));}*/

 protected:
	Point3 m_c;
	double m_r;
};
#endif
