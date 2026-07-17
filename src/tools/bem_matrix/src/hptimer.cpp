/* $Id: hptimer.cpp,v 1.3 2008/01/28 07:26:21 canacar Exp $ */
/* 
 * This file is part of the EMSI Tools Package developed at the
 * Brain Research Laboratory, Middle East Technical University
 * Department of Electrical and Electronics Engineering.
 *
 * Copyright (C) 2008 Zeynep Akalin Acar
 * Copyright (C) 2008 Can Erkin Acar
 * Copyright (C) 2008 Nevzat G. Gencer
 * 
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */
//---------------------------------------------------------------------------
#include <string.h>
#include <stdio.h>
#include "hptimer.h"
//#include "mcprintf.h"
//---------------------------------------------------------------------------
#define mprintf printf

HPTimerMgr *HPTimerMgr::m_instance=0;

HPTimerMgr::HPTimerMgr(){
        LARGE_INTEGER freq;
        m_root=m_end=0;
        if(!QueryPerformanceFrequency(&freq)) m_freq=0;
        else m_freq=freq.QuadPart;
}

HPTimerMgr::~HPTimerMgr(){
        while(m_root) delete m_root; // destructor modifies root!
        m_instance=0;
}

void HPTimerMgr::addTimer(HPTimer *t){
        if(!m_end) m_root=m_end=t;
        else{
            m_end->m_next=t;
            m_end=t;
        }

}

void HPTimerMgr::removeTimer(HPTimer *t){
        if(m_root==t){
                m_root=t->m_next;
                if(!m_root) m_end=0;
                t->m_next=0;
                return;
        }
        for(HPTimer *i=m_root; i; i=i->m_next){
                if(i->m_next==t){
                        i->m_next=t->m_next;
                        if(!i->m_next) m_end=i;
                }
        }
}

// static function
HPTimerMgr *HPTimerMgr::getManager(void){
        if(!m_instance) m_instance=new HPTimerMgr();
        return m_instance;
}

// static function
HPTimer *HPTimerMgr::getTimer(char *name){
        HPTimerMgr *mgr=getManager();
        if(!mgr->m_freq) return 0; // not supported
        HPTimer *t=new HPTimer(mgr, name);
        mgr->addTimer(t);
        return t;
}

// static function
void HPTimerMgr::report(void){
        HPTimerMgr *mgr=getManager();
        double f=(double)mgr->m_freq;
        if(!mgr->m_freq){
            mprintf("High Performance Timer not supported in this configuration!\n");
            return;
        }

        mprintf("Timing results (timer frequency= %s):\n", dispFreq(f));
        for (HPTimer *t=mgr->m_root; t; t=t->m_next)
		t->report();
        mprintf("Done - timing results\n");
}


// static function
void HPTimerMgr::report(char *out, int len){
        HPTimerMgr *mgr=getManager();
        double f=(double)mgr->m_freq;

	if (len <= 0)
		return;

        if(!mgr->m_freq){
            snprintf(out, len, "Timer not supported!");
            return;
        }

	int l = snprintf(out, len, "Timer:%g:", f);
	len-=l;
	out+=l;

        for(HPTimer *t=mgr->m_root; t && len > 0; t=t->m_next) {
		l = t->report(out, len);
		len -= l;
		out += l;
	}
}

// static function
char *HPTimerMgr::dispFreq(double t){
	static char buf[HPT_BUF_LEN];
        if (t > 1e9)
		snprintf(buf, sizeof(buf), "%g GHz",t/1e9);
        else if (t > 1e6)
		snprintf(buf, sizeof(buf), "%g MHz",t/1e6);
        else if (t > 1e3)
		snprintf(buf, sizeof(buf), "%g KHz",t/1e3);
        else
		snprintf(buf, sizeof(buf), "%g Hz",t);
        return buf;
}

// static function
char *HPTimerMgr::dispTime(double t){
	static char buf[HPT_BUF_LEN];
        if (t < 1e-6)
		snprintf(buf, sizeof(buf), "%g ns",t*1e9);
        else if (t < 1e-3)
		snprintf(buf, sizeof(buf), "%g us",t*1e6);
        else if (t < 1)
		snprintf(buf, sizeof(buf), "%g ms",t*1e3);
        else
		snprintf(buf, sizeof(buf), "%g s",t);
        return buf;
}

//---------------------------------------------------------------------------
HPTimer::HPTimer(HPTimerMgr *parent, char *name){
        m_parent=parent;
        m_next=0;
        strncpy(m_name, name, HPT_NAME_LEN-1);
        m_name[HPT_NAME_LEN-1]=0;
        reset();
}

void HPTimer::reset(void){
        m_start.QuadPart=0;
        m_stop.QuadPart=0;
        m_cur=m_total=0;
        m_min=MAXLONGLONG;
        m_max=-1;
        m_count=0;
}

void HPTimer::report(void){
        double f=(double)m_parent->m_freq;

        mprintf("  Timer: %s - called %d times:\n",m_name, m_count);
        if(m_count){
                mprintf("    Minimum: %s\n",HPTimerMgr::dispTime((double)m_min/f));
                mprintf("    Maximum: %s\n",HPTimerMgr::dispTime((double)m_max/f));
                mprintf("    Average: %s\n",HPTimerMgr::dispTime((double)m_total/f/(double)m_count));
                mprintf("    Total  : %s\n",HPTimerMgr::dispTime((double)m_total/f));
        }
}

int HPTimer::report(char *out, int len){
        double f=(double)m_parent->m_freq;
	int l = snprintf(out, len, "%s:%d:%g:%g:%g:", m_name, m_count,
		(double)m_min/f, (double)m_max/f, (double)m_total/f);
	return l;
}

HPTimer::~HPTimer(){
        m_parent->removeTimer(this);
}
//---------------------------------------------------------------------------
#ifndef _WIN32_
extern "C"{
	struct timeval _hpt_tval;
	struct timezone _hpt_tzone;
/*
	int QueryPerformanceCounter(LARGE_INTEGER *lpPerfCnt){
                static struct timeval tv;
                static struct timezone tz;
		gettimeofday(&tv, &tz);
		lpPerfCnt->QuadPart=tv.tv_sec*1000+tv.tv_usec;
		return 0;
	}
	int QueryPerformanceFrequency(LARGE_INTEGER *lpPerfCnt){
		lpPerfCnt->QuadPart=1000;
		return 0;
	}
*/
}

#endif
