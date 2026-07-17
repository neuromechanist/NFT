//---------------------------------------------------------------------------
#ifndef point3H
#define point3H
#include <math.h>
//---------------------------------------------------------------------------
extern int point3_length_count;
extern int point3_length2_count;

class Point3{
public:
	Point3(double x=0, double y=0, double z=0)
    	{m_x=x; m_y=y; m_z=z; }
    Point3(const Point3 &p)
    	{setCoord(p);}

    ~Point3() {}

	inline double getX(void) const {return m_x;}
	inline double getY(void) const{return m_y;}
	inline double getZ(void) const{return m_z;}
    inline void getCoord(double &x, double &y, double &z) const
    	{ x=m_x; y=m_y; z=m_z; }

    inline void setX(double x) {m_x=x;}
    inline void setY(double y) {m_y=y;}
    inline void setZ(double z) {m_z=z;}

    inline double &X(void) {return m_x;}
    inline double &Y(void) {return m_y;}
    inline double &Z(void) {return m_z;}

    inline void setCoord(double x=0, double y=0, double z=0)
    	{m_x=x; m_y=y; m_z=z; }
    inline void setCoord(const Point3 &p)
    	{p.getCoord(m_x, m_y, m_z); }

    inline double length2(void) const
    	{point3_length2_count ++; return m_x*m_x + m_y*m_y + m_z*m_z; }

    inline double length(void) const
    	{point3_length_count ++; return sqrt(length2());}

    inline double dot(const Point3 &p) const
    	{return m_x*p.getX() + m_y*p.getY() + m_z*p.getZ(); }

    inline Point3 &operator = (const Point3& p) {
    	setCoord(p);
        return *this;
    }

    inline Point3 &operator += (const Point3& p) {
    	m_x+=p.getX(); m_y+=p.getY(); m_z+=p.getZ();
        return *this;
    }

    inline Point3 &operator -= (const Point3& p) {
    	m_x-=p.getX(); m_y-=p.getY(); m_z-=p.getZ();
        return *this;
    }

    inline Point3 &operator *= (const double s) {
    	m_x*=s; m_y*=s; m_z*=s;
        return *this;
    }

    inline Point3 &operator /= (const double s) {
    	m_x/=s; m_y/=s; m_z/=s;
        return *this;
    }

    inline Point3 &normalize(void) {
        double d=length();
        m_x/=d; m_y/=d; m_z/=d;
        return *this;
    }

    inline Point3 &setCross(const Point3 &p1, const Point3 &p2) {
    	m_x=(p1.getY() * p2.getZ()) - (p1.getZ() * p2.getY());
    	m_y=(p1.getZ() * p2.getX()) - (p1.getX() * p2.getZ());
    	m_z=(p1.getX() * p2.getY()) - (p1.getY() * p2.getX());
        return *this;
    }

    inline bool operator == (const Point3 &p) const {
	    return (fabs(m_x - p.getX()) < 1e-10 &&
		    fabs(m_y - p.getY()) < 1e-10 && 
		    fabs(m_z - p.getZ()) < 1e-10);
    }

protected:
	double m_x, m_y, m_z;

};

Point3 operator * (double s, const Point3 &p);
Point3 operator * (const Point3 &p, double s);
Point3 operator / (const Point3 &p, double s);
Point3 operator + (const Point3 &p1, const Point3 &p2);
Point3 operator - (const Point3 &p1, const Point3 &p2);
Point3 operator - (const Point3 &p);
Point3 Cross(const Point3 &p1, const Point3 &p2);

#endif
