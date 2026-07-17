//---------------------------------------------------------------------------
#ifdef __BORLANDC__
#pragma hdrstop
#endif
#include "point3.h"
//---------------------------------------------------------------------------
int point3_length_count=0;
int point3_length2_count=0;
//---------------------------------------------------------------------------
Point3 operator * (double s, const Point3 &p) {
	Point3 P(p);
    P*=s;
    return P;
}
//---------------------------------------------------------------------------
Point3 operator * (const Point3 &p, double s) {
	Point3 P(p);
    P*=s;
    return P;
}
//---------------------------------------------------------------------------
Point3 operator / (const Point3 &p, double s) {
	Point3 P(p);
    P/=s;
    return P;
}
//---------------------------------------------------------------------------
Point3 operator + (const Point3 &p1, const Point3 &p2) {
	Point3 P(p1);
    P+=p2;
    return P;
}
//---------------------------------------------------------------------------
Point3 operator - (const Point3 &p1, const Point3 &p2) {
	Point3 P(p1);
    P-=p2;
    return P;
}
//---------------------------------------------------------------------------
Point3 operator - (const Point3 &p) {
	Point3 P(0);
    P-=p;
    return P;
}
//---------------------------------------------------------------------------
Point3 Cross(const Point3 &p1, const Point3 &p2)
{
    Point3 P;
	P.setX((p1.getY() * p2.getZ()) - (p1.getZ() * p2.getY()));
	P.setY((p1.getZ() * p2.getX()) - (p1.getX() * p2.getZ()));
	P.setZ((p1.getX() * p2.getY()) - (p1.getY() * p2.getX()));
    return P;
}
//---------------------------------------------------------------------------

