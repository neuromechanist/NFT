/*
 * pcvalues.h
 *
 * This header is created to substitute the header file "values.h" 
 * in UNIX environment. There will be only macro definitions.
 * 
 * Tien-Tsin Wong and Desmond Fung
 * 8 Oct 1999
 *
 */
#ifndef	_PCVALUES_H
#define	_PCVALUES_H

#if defined(WIN32) || !__has_include(<values.h>)    // don't use this header if a real values.h exists

#include <limits.h>

#ifndef M_PI
#define	M_PI		3.14159265358979323846
#endif
#ifndef M_2_PI
#define	M_2_PI		(M_PI * 2)
#endif
#ifndef M_PI_2
#define	M_PI_2		(M_PI / 2)
#endif
#ifndef M_E
#define M_E		(2.7182818284590452354)
#endif

#ifndef MAXFLOAT
#ifdef  FLT_MAX
#define MAXFLOAT        FLT_MAX
#else
#define MAXFLOAT	((float)3.40282346638528860e+38)
#endif
#endif
#ifndef MINFLOAT
#ifdef  FLT_MIN
#define MINFLOAT        FLT_MIN
#else
#define MINFLOAT	((float)1.40129846432481707e-45)
#endif
#endif
#ifndef MAXSHORT
#define MAXSHORT        SHRT_MAX
#endif
#ifndef MINSHORT
#define MINSHORT        SHRT_MIN
#endif



#endif  // WIN32 || !__has_include(<values.h>)

#endif	// _PCVALUES_H 

