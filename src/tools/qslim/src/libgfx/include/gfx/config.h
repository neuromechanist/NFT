/* config.h -- libgfx build configuration for the NFT qslim import.
 *
 * Copyright (C) 2026 Seyed Yahya Shirazi, SCCN/INC/UCSD.
 * SPDX-License-Identifier: GPL-2.0-or-later
 *
 * libgfx/include/gfx/gfx.h does `#if defined(HAVE_CONFIG_H) #include
 * "config.h"`; upstream's own build generates this file from
 * config.h.in via the bundled autoconf `configure` script. Rather than
 * run that 2002-vintage script (X11/FLTK-oriented, not meant for a
 * headless CMake rebuild) we author the file directly, matching only
 * what src/tools/qslim actually needs -- see CMakeLists.txt for the
 * full "what's compiled and why" rationale.
 *
 * Deliberately NOT defined: HAVE_FLTK / HAVE_FLTK_GL / HAVE_OPENGL (no
 * GUI/GL code is compiled here at all) and HAVE_LIBTIFF / HAVE_LIBPNG /
 * HAVE_LIBJPEG (raster-{tiff,png,jpeg}.cxx compile to harmless stubs --
 * see their own `#ifdef HAVE_LIB*` guards -- when these are left
 * undefined, which keeps the qslim CLI free of any image-codec library
 * dependency it never needed in the first place).
 */
#define HAVE_BOOL 1
#define HAVE_RINT 1
#define HAVE_GETRUSAGE 1
#define HAVE_RANDOM 1
