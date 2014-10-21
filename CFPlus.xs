#ifdef _WIN32
# define WIN32_LEAN_AND_MEAN
# define NTDDI_VERSION NTDDI_WIN2K // needed to get win2000 api calls
# include <malloc.h>
# include <windows.h>
# include <wininet.h>
# pragma warning(disable:4244)
# pragma warning(disable:4761)
#endif

//#define DEBUG 1
#if DEBUG
# include <valgrind/memcheck.h>
#endif

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#ifdef _WIN32
# undef pipe
// microsoft vs. C
# define sqrtf(x) sqrt(x)
# define roundf(x) (int)(x)
# define atan2f(x,y) atan2(x,y)
# define M_PI 3.14159265f
#endif

#include <assert.h>
#include <math.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

#define USE_RWOPS 1 // for SDL_mixer:LoadMUS_RW

#include <SDL.h>
#include <SDL_thread.h>
#include <SDL_endian.h>
#include <SDL_image.h>
#include <SDL_mixer.h>
#include <SDL_opengl.h>

#define PANGO_ENABLE_BACKEND
#define G_DISABLE_CAST_CHECKS

#include <glib/gmacros.h>

#include <pango/pango.h>

#ifndef _WIN32
# include <sys/types.h>
# include <sys/socket.h>
# include <netinet/in.h>
# include <netinet/tcp.h>
# include <inttypes.h>
#endif

#define OBJ_STR "\xef\xbf\xbc" /* U+FFFC, object replacement character */

#define FOW_DARKNESS 32

#define MAP_EXTEND_X  32
#define MAP_EXTEND_Y 512

#define MIN_FONT_HEIGHT 10

#if 0
# define PARACHUTE SDL_INIT_NOPARACHUTE
#else
# define PARACHUTE 0
#endif

static AV *texture_av;

static struct
{
#define GL_FUNC(ptr,name) ptr name;
#include "glfunc.h"
#undef GL_FUNC
} gl;

static void
gl_BlendFuncSeparate (GLenum sa, GLenum da, GLenum saa, GLenum daa)
{
  if (gl.BlendFuncSeparate)
    gl.BlendFuncSeparate (sa, da, saa, daa);
  else if (gl.BlendFuncSeparateEXT)
    gl.BlendFuncSeparateEXT (sa, da, saa, daa);
  else
    glBlendFunc (sa, da);
}

static GLuint
gen_texture ()
{
  GLuint name;

  if (AvFILL (texture_av) >= 0)
    name = (GLuint)(size_t)av_pop (texture_av);
  else
    glGenTextures (1, &name);

  return name;
}

static void
del_texture (GLuint name)
{
  /* make a half-assed attempt at returning the memory used by the texture */
  /* textures are frequently being reused by cfplus anyway */
  /*glBindTexture (GL_TEXTURE_2D, name);*/
  /*glTexImage2D (GL_TEXTURE_2D, 0, GL_ALPHA, 0, 0, 0, GL_ALPHA, GL_UNSIGNED_BYTE, 0);*/
  av_push (texture_av, (SV *)(size_t)name);
  glDeleteTextures (1, &name);
}

#include "texcache.c"
#include "rendercache.c"

#include "pango-font.c"
#include "pango-fontmap.c"
#include "pango-render.c"

typedef IV         CFPlus__Channel;
typedef SDL_RWops *CFPlus__RW;
typedef Mix_Chunk *CFPlus__MixChunk;
typedef Mix_Music *CFPlus__MixMusic;

typedef PangoFontDescription *CFPlus__Font;

static int
shape_attr_p (PangoLayoutRun *run)
{
  GSList *attrs = run->item->analysis.extra_attrs;
    
  while (attrs)
    {
      PangoAttribute *attr = attrs->data;

      if (attr->klass->type == PANGO_ATTR_SHAPE)
        return 1;

      attrs = attrs->next;
    }

  return 0;
}

typedef struct cf_layout {
  PangoLayout *pl;
  float r, g, b, a; // default color for rgba mode
  int base_height;
  CFPlus__Font font;
  rc_t *rc;
} *CFPlus__Layout;

static CFPlus__Font default_font;
static PangoContext *opengl_context;
static PangoFontMap *opengl_fontmap;

static void
substitute_func (FcPattern *pattern, gpointer data)
{
  FcPatternAddBool (pattern, FC_HINTING, 1);
#ifdef FC_HINT_STYLE
  FcPatternAddBool (pattern, FC_HINT_STYLE, FC_HINT_FULL);
#endif
  FcPatternAddBool (pattern, FC_AUTOHINT, 0);
}

static void
layout_update_font (CFPlus__Layout self)
{
  /* use a random scale factor to account for unknown descenders, 0.8 works
   * reasonably well with bitstream vera
   */
  PangoFontDescription *font = self->font ? self->font : default_font;

  pango_font_description_set_absolute_size (font,
    MAX (MIN_FONT_HEIGHT, self->base_height) * (PANGO_SCALE * 8 / 10));

  pango_layout_set_font_description (self->pl, font);
}

static void
layout_get_pixel_size (CFPlus__Layout self, int *w, int *h)
{
  PangoRectangle rect;

  // get_pixel_* wrongly rounds down
  pango_layout_get_extents (self->pl, 0, &rect);

  rect.width  = (rect.width  + PANGO_SCALE - 1) / PANGO_SCALE;
  rect.height = (rect.height + PANGO_SCALE - 1) / PANGO_SCALE;

  if (!rect.width)  rect.width  = 1;
  if (!rect.height) rect.height = 1;

  *w = rect.width;
  *h = rect.height;
}

typedef uint16_t tileid;
typedef uint16_t faceid;

typedef struct {
  GLuint name;
  int w, h;
  float s, t;
  uint8_t r, g, b, a;
  tileid smoothtile;
  uint8_t smoothlevel;
} maptex;

typedef struct {
  uint32_t player;
  tileid tile[3];
  uint16_t darkness;
  uint8_t stat_width, stat_hp, flags, smoothmax;
} mapcell;

typedef struct {
  int32_t c0, c1;
  mapcell *col;
} maprow;

typedef struct map {
  int x, y, w, h;
  int ox, oy; /* offset to virtual global coordinate system */
  int faces; tileid *face2tile; // [faceid]
  int texs;  maptex *tex;       // [tileid]

  int32_t rows;
  maprow *row;
} *CFPlus__Map;

static char *
prepend (char *ptr, int sze, int inc)
{
  char *p;

  New (0, p, sze + inc, char);
  Zero (p, inc, char);
  Move (ptr, p + inc, sze, char);
  Safefree (ptr);

  return p;
}

static char *
append (char *ptr, int sze, int inc)
{
  Renew (ptr, sze + inc, char);
  Zero (ptr + sze, inc, char);

  return ptr;
}

#define Append(type,ptr,sze,inc)  (ptr) = (type *)append  ((char *)ptr, (sze) * sizeof (type), (inc) * sizeof (type))
#define Prepend(type,ptr,sze,inc) (ptr) = (type *)prepend ((char *)ptr, (sze) * sizeof (type), (inc) * sizeof (type))

static void
need_facenum (struct map *self, faceid face)
{
  while (self->faces <= face)
    {
      Append (tileid, self->face2tile, self->faces, self->faces);
      self->faces *= 2;
    }
}

static void
need_texid (struct map *self, int texid)
{
  while (self->texs <= texid)
    {
      Append (maptex, self->tex, self->texs, self->texs);
      self->texs *= 2;
    }
}

static maprow *
map_get_row (CFPlus__Map self, int y)
{
  if (0 > y)
    {
      int extend = - y + MAP_EXTEND_Y;
      Prepend (maprow, self->row, self->rows, extend);

      self->rows += extend;
      self->y    += extend;
      y          += extend;
    }
  else if (y >= self->rows)
    {
      int extend = y - self->rows + MAP_EXTEND_Y;
      Append (maprow, self->row, self->rows, extend);
      self->rows += extend;
    }

  return self->row + y;
}

static mapcell *
row_get_cell (maprow *row, int x)
{
  if (!row->col)
    {
      Newz (0, row->col, MAP_EXTEND_X, mapcell);
      row->c0 = x - MAP_EXTEND_X / 4;
      row->c1 = row->c0 + MAP_EXTEND_X;
    }

  if (row->c0 > x)
    {
      int extend = row->c0 - x + MAP_EXTEND_X;
      Prepend (mapcell, row->col, row->c1 - row->c0, extend);
      row->c0 -= extend;
    }
  else if (x >= row->c1)
    {
      int extend = x - row->c1 + MAP_EXTEND_X;
      Append (mapcell, row->col, row->c1 - row->c0, extend);
      row->c1 += extend;
    }

  return row->col + (x - row->c0);
}

static mapcell *
map_get_cell (CFPlus__Map self, int x, int y)
{
  return row_get_cell (map_get_row (self, y), x);
}

static void
map_clear (CFPlus__Map self)
{
  int r;

  for (r = 0; r < self->rows; r++)
    Safefree (self->row[r].col);

  Safefree (self->row);

  self->x    = 0;
  self->y    = 0;
  self->ox   = 0;
  self->oy   = 0;
  self->row  = 0;
  self->rows = 0;
}

static void
map_blank (CFPlus__Map self, int x0, int y0, int w, int h)
{
  int x, y;
  maprow *row;
  mapcell *cell;

  for (y = y0; y < y0 + h; y++)
    if (y >= 0)
      {
        if (y >= self->rows)
          break;

        row = self->row + y;

        for (x = x0; x < x0 + w; x++)
          if (x >= row->c0)
            {
              if (x >= row->c1)
                break;

              cell = row->col + x - row->c0;
              
              cell->darkness = 0;
              cell->stat_hp  = 0;
              cell->flags    = 0;
              cell->player   = 0;
            }
      }
}

typedef struct  {
  tileid tile;
  uint8_t x, y, level;
} smooth_key;

static void
smooth_or_bits (HV *hv, smooth_key *key, IV bits)
{
  SV **sv = hv_fetch (hv, (char *)key, sizeof (*key), 1);

  if (SvIOK (*sv))
    SvIV_set (*sv, SvIVX (*sv) | bits);
  else
    sv_setiv (*sv, bits);
}

static void
music_finished (void)
{
  SDL_UserEvent ev;

  ev.type  = SDL_USEREVENT;
  ev.code  = 0;
  ev.data1 = 0;
  ev.data2 = 0;

  SDL_PushEvent ((SDL_Event *)&ev);
}

static void
channel_finished (int channel)
{
  SDL_UserEvent ev;

  ev.type  = SDL_USEREVENT;
  ev.code  = 1;
  ev.data1 = (void *)(long)channel;
  ev.data2 = 0;

  SDL_PushEvent ((SDL_Event *)&ev);
}

static unsigned int
minpot (unsigned int n)
{
  if (!n)
    return 0;

  --n;

  n |= n >>  1;
  n |= n >>  2;
  n |= n >>  4;
  n |= n >>  8;
  n |= n >> 16;

  return n + 1;
}

static unsigned int
popcount (unsigned int n)
{
  n -=  (n >> 1) & 0x55555555U;
  n  = ((n >> 2) & 0x33333333U) + (n & 0x33333333U);
  n  = ((n >> 4) + n) & 0x0f0f0f0fU;
  n *= 0x01010101U;

  return n >> 24;
}

/* SDL should provide this, really. */
#define SDLK_MODIFIER_MIN 300
#define SDLK_MODIFIER_MAX 314

/******************************************************************************/

static GV *draw_x_gv, *draw_y_gv, *draw_w_gv, *draw_h_gv;
static GV *hover_gv;

static int
within_widget (SV *widget, NV x, NV y)
{
  HV *self;
  SV **svp;
  NV wx, ww, wy, wh;

  if (!SvROK (widget))
    return 0;

  self = (HV *)SvRV (widget);

  if (SvTYPE (self) != SVt_PVHV)
    return 0;

  svp = hv_fetch (self, "y", 1, 0); wy = svp ? SvNV (*svp) : 0.;
  if (y < wy)
    return 0;

  svp = hv_fetch (self, "h", 1, 0); wh = svp ? SvNV (*svp) : 0.;
  if (y >= wy + wh)
    return 0;

  svp = hv_fetch (self, "x", 1, 0); wx = svp ? SvNV (*svp) : 0.;
  if (x < wx)
    return 0;

  svp = hv_fetch (self, "w", 1, 0); ww = svp ? SvNV (*svp) : 0.;
  if (x >= wx + ww)
    return 0;

  svp = hv_fetch (self, "can_events", sizeof ("can_events") - 1, 0);
  if (!svp || !SvTRUE (*svp))
    return 0;

  return 1;
}

MODULE = CFPlus	PACKAGE = CFPlus

PROTOTYPES: ENABLE

BOOT:
{
  HV *stash = gv_stashpv ("CFPlus", 1);
  static const struct {
    const char *name;
    IV iv;
  } *civ, const_iv[] = {
#	define const_iv(name) { # name, (IV)name }
        const_iv (SDLK_MODIFIER_MIN),
        const_iv (SDLK_MODIFIER_MAX),

	const_iv (SDL_ACTIVEEVENT),
	const_iv (SDL_KEYDOWN),
	const_iv (SDL_KEYUP),
	const_iv (SDL_MOUSEMOTION),
	const_iv (SDL_MOUSEBUTTONDOWN),
	const_iv (SDL_MOUSEBUTTONUP),
	const_iv (SDL_JOYAXISMOTION),
	const_iv (SDL_JOYBALLMOTION),
	const_iv (SDL_JOYHATMOTION),
	const_iv (SDL_JOYBUTTONDOWN),
	const_iv (SDL_JOYBUTTONUP),
	const_iv (SDL_QUIT),
	const_iv (SDL_SYSWMEVENT),
	const_iv (SDL_EVENT_RESERVEDA),
	const_iv (SDL_EVENT_RESERVEDB),
	const_iv (SDL_VIDEORESIZE),
	const_iv (SDL_VIDEOEXPOSE),
        const_iv (SDL_USEREVENT),

        const_iv (SDL_APPINPUTFOCUS),
        const_iv (SDL_APPMOUSEFOCUS),
        const_iv (SDL_APPACTIVE),

	const_iv (SDLK_FIRST),
	const_iv (SDLK_LAST),
	const_iv (SDLK_KP0),
	const_iv (SDLK_KP1),
	const_iv (SDLK_KP2),
	const_iv (SDLK_KP3),
	const_iv (SDLK_KP4),
	const_iv (SDLK_KP5),
	const_iv (SDLK_KP6),
	const_iv (SDLK_KP7),
	const_iv (SDLK_KP8),
	const_iv (SDLK_KP9),
	const_iv (SDLK_KP_PERIOD),
	const_iv (SDLK_KP_DIVIDE),
	const_iv (SDLK_KP_MULTIPLY),
	const_iv (SDLK_KP_MINUS),
	const_iv (SDLK_KP_PLUS),
	const_iv (SDLK_KP_ENTER),
	const_iv (SDLK_KP_EQUALS),
	const_iv (SDLK_UP),
	const_iv (SDLK_DOWN),
	const_iv (SDLK_RIGHT),
	const_iv (SDLK_LEFT),
	const_iv (SDLK_INSERT),
	const_iv (SDLK_HOME),
	const_iv (SDLK_END),
	const_iv (SDLK_PAGEUP),
	const_iv (SDLK_PAGEDOWN),
	const_iv (SDLK_F1),
	const_iv (SDLK_F2),
	const_iv (SDLK_F3),
	const_iv (SDLK_F4),
	const_iv (SDLK_F5),
	const_iv (SDLK_F6),
	const_iv (SDLK_F7),
	const_iv (SDLK_F8),
	const_iv (SDLK_F9),
	const_iv (SDLK_F10),
	const_iv (SDLK_F11),
	const_iv (SDLK_F12),
	const_iv (SDLK_F13),
	const_iv (SDLK_F14),
	const_iv (SDLK_F15),
	const_iv (SDLK_NUMLOCK),
	const_iv (SDLK_CAPSLOCK),
	const_iv (SDLK_SCROLLOCK),
	const_iv (SDLK_RSHIFT),
	const_iv (SDLK_LSHIFT),
	const_iv (SDLK_RCTRL),
	const_iv (SDLK_LCTRL),
	const_iv (SDLK_RALT),
	const_iv (SDLK_LALT),
	const_iv (SDLK_RMETA),
	const_iv (SDLK_LMETA),
	const_iv (SDLK_LSUPER),
	const_iv (SDLK_RSUPER),
	const_iv (SDLK_MODE),
	const_iv (SDLK_COMPOSE),
	const_iv (SDLK_HELP),
	const_iv (SDLK_PRINT),
	const_iv (SDLK_SYSREQ),
	const_iv (SDLK_BREAK),
	const_iv (SDLK_MENU),
	const_iv (SDLK_POWER),
	const_iv (SDLK_EURO),
	const_iv (SDLK_UNDO),

	const_iv (KMOD_NONE),
	const_iv (KMOD_SHIFT),
	const_iv (KMOD_LSHIFT),
	const_iv (KMOD_RSHIFT),
	const_iv (KMOD_CTRL),
	const_iv (KMOD_LCTRL),
	const_iv (KMOD_RCTRL),
	const_iv (KMOD_ALT),
	const_iv (KMOD_LALT),
	const_iv (KMOD_RALT),
	const_iv (KMOD_META),
	const_iv (KMOD_LMETA),
	const_iv (KMOD_RMETA),
	const_iv (KMOD_NUM),
	const_iv (KMOD_CAPS),
	const_iv (KMOD_MODE),
#	undef const_iv
  };
    
  for (civ = const_iv + sizeof (const_iv) / sizeof (const_iv [0]); civ-- > const_iv; )
    newCONSTSUB (stash, (char *)civ->name, newSViv (civ->iv));

  assert (SDLK_MODIFIER_MIN == SDLK_NUMLOCK);
  assert (SDLK_MODIFIER_MAX == SDLK_COMPOSE);
}

void
weaken (SV *rv)
	PROTOTYPE: $
	CODE:
        sv_rvweaken (rv);

int
in_destruct ()
	CODE:
        RETVAL = PL_main_cv == Nullcv;
        OUTPUT:
        RETVAL

NV floor (NV x)

NV ceil (NV x)

IV minpot (UV n)

IV popcount (UV n)

void
pango_init ()
	CODE:
{
        opengl_fontmap = pango_opengl_font_map_new ();
        pango_opengl_font_map_set_default_substitute ((PangoOpenGLFontMap *)opengl_fontmap, substitute_func, 0, 0);
        opengl_context = pango_opengl_font_map_create_context ((PangoOpenGLFontMap *)opengl_fontmap);
}

char *
SDL_GetError ()

int
SDL_Init (U32 flags = SDL_INIT_VIDEO | SDL_INIT_AUDIO | PARACHUTE)

void
SDL_Quit ()

void
SDL_ListModes (int rgb, int alpha)
	PPCODE:
{
	SDL_Rect **m;
	
        SDL_GL_SetAttribute (SDL_GL_RED_SIZE  , rgb);
        SDL_GL_SetAttribute (SDL_GL_GREEN_SIZE, rgb);
        SDL_GL_SetAttribute (SDL_GL_BLUE_SIZE , rgb);
        SDL_GL_SetAttribute (SDL_GL_ALPHA_SIZE, alpha);

        SDL_GL_SetAttribute (SDL_GL_BUFFER_SIZE, 15);
        SDL_GL_SetAttribute (SDL_GL_DEPTH_SIZE ,  0);

        SDL_GL_SetAttribute (SDL_GL_ACCUM_RED_SIZE  , 0);
        SDL_GL_SetAttribute (SDL_GL_ACCUM_GREEN_SIZE, 0);
        SDL_GL_SetAttribute (SDL_GL_ACCUM_BLUE_SIZE , 0);
        SDL_GL_SetAttribute (SDL_GL_ACCUM_ALPHA_SIZE, 0);

        SDL_GL_SetAttribute (SDL_GL_DOUBLEBUFFER, 1);
#if SDL_VERSION_ATLEAST(1,2,10)
        SDL_GL_SetAttribute (SDL_GL_ACCELERATED_VISUAL, 1);
        SDL_GL_SetAttribute (SDL_GL_SWAP_CONTROL, 1);
#endif

	m = SDL_ListModes (0, SDL_FULLSCREEN | SDL_OPENGL);

        if (m && m != (SDL_Rect **)-1)
          while (*m)
            {
              if ((*m)->w >= 640 && (*m)->h >= 480)
                {
                  AV *av = newAV ();
                  av_push (av, newSViv ((*m)->w));
                  av_push (av, newSViv ((*m)->h));
                  av_push (av, newSViv (rgb));
                  av_push (av, newSViv (alpha));
                  XPUSHs (sv_2mortal (newRV_noinc ((SV *)av)));
                }

              ++m;
            }
}

int
SDL_SetVideoMode (int w, int h, int rgb, int alpha, int fullscreen)
	CODE:
{
        SDL_EnableUNICODE (1);
        SDL_EnableKeyRepeat (SDL_DEFAULT_REPEAT_DELAY, SDL_DEFAULT_REPEAT_INTERVAL);

        SDL_GL_SetAttribute (SDL_GL_RED_SIZE  , rgb);
        SDL_GL_SetAttribute (SDL_GL_GREEN_SIZE, rgb);
        SDL_GL_SetAttribute (SDL_GL_BLUE_SIZE , rgb);
        SDL_GL_SetAttribute (SDL_GL_ALPHA_SIZE, alpha);

        RETVAL = !!SDL_SetVideoMode (
          w, h, 0, SDL_OPENGL | (fullscreen ? SDL_FULLSCREEN : 0)
        );

        if (RETVAL)
          {
            av_clear (texture_av);

            SDL_WM_SetCaption ("Crossfire TRT Client " VERSION, "Crossfire TRT");
#define GL_FUNC(ptr,name) gl.name = (ptr)SDL_GL_GetProcAddress ("gl" # name);
#include "glfunc.h"
#undef GL_FUNC
          }
}
	OUTPUT:
        RETVAL

void
SDL_GL_SwapBuffers ()

char *
SDL_GetKeyName (int sym)

int
SDL_GetAppState ()

void
poll_events ()
	PPCODE:
{
	SDL_Event ev;

        SDL_PumpEvents ();
        while (SDL_PeepEvents (&ev, 1, SDL_GETEVENT, SDL_ALLEVENTS) > 0)
          {
            HV *hv = newHV ();
            hv_store (hv, "type", 4, newSViv (ev.type), 0);

            switch (ev.type)
              {
                case SDL_KEYDOWN:
                case SDL_KEYUP:
                  hv_store (hv, "state",   5, newSViv (ev.key.state), 0);
                  hv_store (hv, "sym",     3, newSViv (ev.key.keysym.sym), 0);
                  hv_store (hv, "mod",     3, newSViv (ev.key.keysym.mod), 0);
                  hv_store (hv, "cmod",    4, newSViv (SDL_GetModState ()), 0); /* current mode */
                  hv_store (hv, "unicode", 7, newSViv (ev.key.keysym.unicode), 0);
                  break;

                case SDL_ACTIVEEVENT:
                  hv_store (hv, "gain",   4, newSViv (ev.active.gain), 0);
                  hv_store (hv, "state",  5, newSViv (ev.active.state), 0);
                  break;

                case SDL_MOUSEMOTION:
                  {
                    int state = ev.motion.state;
                    int x     = ev.motion.x;
                    int y     = ev.motion.y;
                    int xrel  = ev.motion.xrel;
                    int yrel  = ev.motion.yrel;

                    /* do simplistic event compression */
                    while (SDL_PeepEvents (&ev, 1, SDL_PEEKEVENT, SDL_EVENTMASK (SDL_MOUSEMOTION)) > 0
                           && state == ev.motion.state)
                      {
                        xrel += ev.motion.xrel;
                        yrel += ev.motion.yrel;
                        x     = ev.motion.x;
                        y     = ev.motion.y;
                        SDL_PeepEvents (&ev, 1, SDL_GETEVENT, SDL_EVENTMASK (SDL_MOUSEMOTION));
                      }

                    hv_store (hv, "mod",    3, newSViv (SDL_GetModState ()), 0);
                    hv_store (hv, "state",  5, newSViv (state), 0);
                    hv_store (hv, "x",      1, newSViv (x), 0);
                    hv_store (hv, "y",      1, newSViv (y), 0);
                    hv_store (hv, "xrel",   4, newSViv (xrel), 0);
                    hv_store (hv, "yrel",   4, newSViv (yrel), 0);
                  }
                  break;

                case SDL_MOUSEBUTTONDOWN:
                case SDL_MOUSEBUTTONUP:
                  hv_store (hv, "mod",    3, newSViv (SDL_GetModState ()), 0);

                  hv_store (hv, "button", 6, newSViv (ev.button.button), 0);
                  hv_store (hv, "state",  5, newSViv (ev.button.state), 0);
                  hv_store (hv, "x",      1, newSViv (ev.button.x), 0);
                  hv_store (hv, "y",      1, newSViv (ev.button.y), 0);
                  break;

                case SDL_USEREVENT:
                  hv_store (hv, "code",   4, newSViv (ev.user.code), 0);
                  hv_store (hv, "data1",  5, newSViv ((IV)ev.user.data1), 0);
                  hv_store (hv, "data2",  5, newSViv ((IV)ev.user.data2), 0);
                  break;
              }

            XPUSHs (sv_2mortal (sv_bless (newRV_noinc ((SV *)hv), gv_stashpv ("CFPlus::UI::Event", 1))));
          }
}

int
Mix_OpenAudio (int frequency = 44100, int format = MIX_DEFAULT_FORMAT, int channels = 2, int chunksize = 1024)
  	POSTCALL:
        Mix_HookMusicFinished (music_finished);
        Mix_ChannelFinished (channel_finished);

void
Mix_CloseAudio ()

int
Mix_AllocateChannels (int numchans = -1)

const char *
Mix_GetError ()

void
lowdelay (int fd, int val = 1)
	CODE:
        setsockopt (fd, IPPROTO_TCP, TCP_NODELAY, (void *)&val, sizeof (val));

void
win32_proxy_info ()
	PPCODE:
{
#ifdef _WIN32
        char buffer[2048];
        DWORD buflen;

        EXTEND (SP, 3);
	
        buflen = sizeof (buffer);
        if (InternetQueryOption (0, INTERNET_OPTION_PROXY, (void *)buffer, &buflen))
          if (((INTERNET_PROXY_INFO *)buffer)->dwAccessType == INTERNET_OPEN_TYPE_PROXY)
            {
              PUSHs (newSVpv (((INTERNET_PROXY_INFO *)buffer)->lpszProxy, 0));

              buflen = sizeof (buffer);
              if (InternetQueryOption (0, INTERNET_OPTION_PROXY_USERNAME, (void *)buffer, &buflen))
                {
                  PUSHs (newSVpv (buffer, 0));

                  buflen = sizeof (buffer);
                  if (InternetQueryOption (0, INTERNET_OPTION_PROXY_PASSWORD, (void *)buffer, &buflen))
                    PUSHs (newSVpv (buffer, 0));
                }
            }
#endif
}

void
add_font (char *file)
	CODE:
        FcConfigAppFontAddFile (0, (const FcChar8 *)file);

void
load_image_inline (SV *image_)
	ALIAS:
        load_image_file = 1
	PPCODE:
{
	STRLEN image_len;
	char *image = (char *)SvPVbyte (image_, image_len);
        SDL_Surface *surface, *surface2;
        SDL_PixelFormat fmt;
	SDL_RWops *rw = ix
          ? SDL_RWFromFile (image, "rb")
          : SDL_RWFromConstMem (image, image_len);

        if (!rw)
          croak ("load_image: %s", SDL_GetError ());

        surface = IMG_Load_RW (rw, 1);
        if (!surface)
          croak ("load_image: %s", SDL_GetError ());

        fmt.palette = NULL;
        fmt.BitsPerPixel = 32;
        fmt.BytesPerPixel = 4;
#if SDL_BYTEORDER == SDL_LIL_ENDIAN
        fmt.Rmask = 0x000000ff;
        fmt.Gmask = 0x0000ff00;
        fmt.Bmask = 0x00ff0000;
        fmt.Amask = 0xff000000;
#else
        fmt.Rmask = 0xff000000;
        fmt.Gmask = 0x00ff0000;
        fmt.Bmask = 0x0000ff00;
        fmt.Amask = 0x000000ff;
#endif
        fmt.Rloss = 0;
        fmt.Gloss = 0;
        fmt.Bloss = 0;
        fmt.Aloss = 0;
        fmt.Rshift = 0;
        fmt.Gshift = 8;
        fmt.Bshift = 16;
        fmt.Ashift = 24;
        fmt.colorkey = 0;
        fmt.alpha = 0;

        surface2 = SDL_ConvertSurface (surface, &fmt, SDL_SWSURFACE);

        assert (surface2->pitch == surface2->w * 4);

        SDL_LockSurface (surface2);
        EXTEND (SP, 6);
        PUSHs (sv_2mortal (newSViv (surface2->w)));
        PUSHs (sv_2mortal (newSViv (surface2->h)));
        PUSHs (sv_2mortal (newSVpvn (surface2->pixels, surface2->h * surface2->pitch)));
        PUSHs (sv_2mortal (newSViv (surface->flags & (SDL_SRCCOLORKEY | SDL_SRCALPHA) ? GL_RGBA : GL_RGB)));
        PUSHs (sv_2mortal (newSViv (GL_RGBA)));
        PUSHs (sv_2mortal (newSViv (GL_UNSIGNED_BYTE)));
        SDL_UnlockSurface (surface2);

        SDL_FreeSurface (surface);
        SDL_FreeSurface (surface2);
}

void
average (int x, int y, uint32_t *data)
	PPCODE:
{
        uint32_t r = 0, g = 0, b = 0, a = 0;

        x = y = x * y;

        while (x--)
          {
            uint32_t p = *data++;

            r += (p      ) & 255;
            g += (p >>  8) & 255;
            b += (p >> 16) & 255;
            a += (p >> 24) & 255;
          }

        EXTEND (SP, 4);
        PUSHs (sv_2mortal (newSViv (r / y)));
        PUSHs (sv_2mortal (newSViv (g / y)));
        PUSHs (sv_2mortal (newSViv (b / y)));
        PUSHs (sv_2mortal (newSViv (a / y)));
}

void
error (char *message)
	CODE:
        fprintf (stderr, "ERROR: %s\n", message);
#ifdef _WIN32
        MessageBox (0, message, "Crossfire+ Error", MB_OK | MB_ICONERROR);
#endif

void
fatal (char *message)
	CODE:
        fprintf (stderr, "FATAL: %s\n", message);
#ifdef _WIN32
        MessageBox (0, message, "Crossfire+ Fatal Error", MB_OK | MB_ICONERROR);
#endif
        _exit (1);

void
_exit (int retval = 0)
	CODE:
#ifdef WIN32
        ExitThread (retval); // unclean, please beam me up
#else
        _exit (retval);
#endif

void
debug ()
	CODE:
{
#if DEBUG
	VALGRIND_DO_LEAK_CHECK;
#endif
}

MODULE = CFPlus	PACKAGE = CFPlus::Font

PROTOTYPES: DISABLE

CFPlus::Font
new_from_file (SV *class, char *path, int id = 0)
	CODE:
{
        int count;
        FcPattern *pattern = FcFreeTypeQuery ((const FcChar8 *)path, id, 0, &count);
        RETVAL = pango_fc_font_description_from_pattern (pattern, 0);
	FcPatternDestroy (pattern);
}
	OUTPUT:
        RETVAL

void
DESTROY (CFPlus::Font self)
	CODE:
        pango_font_description_free (self);

void
make_default (CFPlus::Font self)
	PROTOTYPE: $
	CODE:
        default_font = self;

MODULE = CFPlus	PACKAGE = CFPlus::Layout

PROTOTYPES: DISABLE

void
reset_glyph_cache ()
	PROTOTYPE:
	CODE:
        tc_clear ();

CFPlus::Layout
new (SV *class)
	CODE:
        New (0, RETVAL, 1, struct cf_layout);

        RETVAL->pl          = pango_layout_new (opengl_context);
        RETVAL->r           = 1.;
        RETVAL->g           = 1.;
        RETVAL->b           = 1.;
        RETVAL->a           = 1.;
        RETVAL->base_height = MIN_FONT_HEIGHT;
        RETVAL->font        = 0;
        RETVAL->rc          = rc_alloc ();

        pango_layout_set_wrap (RETVAL->pl, PANGO_WRAP_WORD_CHAR);
        layout_update_font (RETVAL);
	OUTPUT:
        RETVAL

void
DESTROY (CFPlus::Layout self)
	CODE:
        g_object_unref (self->pl);
        rc_free (self->rc);
        Safefree (self);

void
set_text (CFPlus::Layout self, SV *text_)
	CODE:
{
	STRLEN textlen;
        char *text = SvPVutf8 (text_, textlen);

        pango_layout_set_text (self->pl, text, textlen);
}

void
set_markup (CFPlus::Layout self, SV *text_)
	CODE:
{
	STRLEN textlen;
        char *text = SvPVutf8 (text_, textlen);

        pango_layout_set_markup (self->pl, text, textlen);
}

void
set_shapes (CFPlus::Layout self, ...)
	CODE:
{
        PangoAttrList *attrs = 0;
        const char *text = pango_layout_get_text (self->pl);
        const char *pos = text;
        int arg = 4;

        while (arg < items && (pos = strstr (pos, OBJ_STR)))
          {
            PangoRectangle inkrect, rect;
            PangoAttribute *attr;

            int x = SvIV (ST (arg - 3));
            int y = SvIV (ST (arg - 2));
            int w = SvIV (ST (arg - 1));
            int h = SvIV (ST (arg    ));

            inkrect.x      = 0;
            inkrect.y      = 0;
            inkrect.width  = 0;
            inkrect.height = 0;

            rect.x      = x * PANGO_SCALE;
            rect.y      = y * PANGO_SCALE;
            rect.width  = w * PANGO_SCALE;
            rect.height = h * PANGO_SCALE;
              
            if (!attrs)
              attrs = pango_layout_get_attributes (self->pl);

            attr = pango_attr_shape_new (&inkrect, &rect);
            attr->start_index = pos - text;
            attr->end_index = attr->start_index + sizeof (OBJ_STR) - 1;
            pango_attr_list_insert (attrs, attr);

            arg += 4;
            pos += sizeof (OBJ_STR) - 1;
          }
        
        if (attrs)
          pango_layout_set_attributes (self->pl, attrs);
}

void
get_shapes (CFPlus::Layout self)
	PPCODE:
{
        PangoLayoutIter *iter = pango_layout_get_iter (self->pl);

        do
          {
            PangoLayoutRun *run = pango_layout_iter_get_run (iter);

            if (run && shape_attr_p (run))
              {
                PangoRectangle extents;
                pango_layout_iter_get_run_extents (iter, 0, &extents);

                EXTEND (SP, 2);
                PUSHs (sv_2mortal (newSViv (PANGO_PIXELS (extents.x))));
                PUSHs (sv_2mortal (newSViv (PANGO_PIXELS (extents.y))));
              }
          }
        while (pango_layout_iter_next_run (iter));
  
        pango_layout_iter_free (iter);
}

int
has_wrapped (CFPlus::Layout self)
	CODE:
{
	int lines = 1;
        const char *text = pango_layout_get_text (self->pl);

        while (*text)
          lines += *text++ == '\n';

        RETVAL = lines < pango_layout_get_line_count (self->pl);
}
	OUTPUT:
        RETVAL

SV *
get_text (CFPlus::Layout self)
	CODE:
        RETVAL = newSVpv (pango_layout_get_text (self->pl), 0);
        sv_utf8_decode (RETVAL);
	OUTPUT:
        RETVAL

void
set_foreground (CFPlus::Layout self, float r, float g, float b, float a = 1.)
	CODE:
        self->r = r;
        self->g = g;
        self->b = b;
        self->a = a;

void
set_font (CFPlus::Layout self, CFPlus::Font font = 0)
	CODE:
        if (self->font != font)
	  {
            self->font = font;
            layout_update_font (self);
          }

void
set_height (CFPlus::Layout self, int base_height)
	CODE:
        if (self->base_height != base_height)
  	  {
            self->base_height = base_height;
            layout_update_font (self);
          }

void
set_width (CFPlus::Layout self, int max_width = -1)
	CODE:
        pango_layout_set_width (self->pl, max_width < 0 ? max_width : max_width * PANGO_SCALE);

void
set_indent (CFPlus::Layout self, int indent)
	CODE:
        pango_layout_set_indent (self->pl, indent * PANGO_SCALE);

void
set_spacing (CFPlus::Layout self, int spacing)
	CODE:
        pango_layout_set_spacing (self->pl, spacing * PANGO_SCALE);

void
set_ellipsise (CFPlus::Layout self, int ellipsise)
	CODE:
        pango_layout_set_ellipsize (self->pl,
            ellipsise == 1 ? PANGO_ELLIPSIZE_START
          : ellipsise == 2 ? PANGO_ELLIPSIZE_MIDDLE
          : ellipsise == 3 ? PANGO_ELLIPSIZE_END
          :                  PANGO_ELLIPSIZE_NONE
        );

void
set_single_paragraph_mode (CFPlus::Layout self, int spm)
	CODE:
        pango_layout_set_single_paragraph_mode (self->pl, !!spm);

void
size (CFPlus::Layout self)
	PPCODE:
{
	int w, h;

        layout_get_pixel_size (self, &w, &h);

        EXTEND (SP, 2);
        PUSHs (sv_2mortal (newSViv (w)));
        PUSHs (sv_2mortal (newSViv (h)));
}

int
descent (CFPlus::Layout self)
	CODE:
{
	PangoRectangle rect;
        PangoLayoutLine *line = pango_layout_get_line (self->pl, 0);
	pango_layout_line_get_pixel_extents (line, 0, &rect);
        RETVAL = PANGO_DESCENT (rect);
}
	OUTPUT:
        RETVAL

int
xy_to_index (CFPlus::Layout self, int x, int y)
	CODE:
{
	int index, trailing;
        pango_layout_xy_to_index (self->pl, x * PANGO_SCALE, y * PANGO_SCALE, &index, &trailing);
        RETVAL = index + trailing;
}
	OUTPUT:
        RETVAL

void
cursor_pos (CFPlus::Layout self, int index)
	PPCODE:
{
	PangoRectangle strong_pos;
        pango_layout_get_cursor_pos (self->pl, index, &strong_pos, 0);

        EXTEND (SP, 3);
        PUSHs (sv_2mortal (newSViv (strong_pos.x      / PANGO_SCALE)));
        PUSHs (sv_2mortal (newSViv (strong_pos.y      / PANGO_SCALE)));
        PUSHs (sv_2mortal (newSViv (strong_pos.height / PANGO_SCALE)));
}

void
index_to_line_x (CFPlus::Layout self, int index, int trailing = 0)
	PPCODE:
{
	int line, x;

	pango_layout_index_to_line_x (self->pl, index, trailing, &line, &x);
        /* pango bug: line is between 1..numlines, not 0..numlines-1 */

        EXTEND (SP, 2);
        PUSHs (sv_2mortal (newSViv (line - 1)));
        PUSHs (sv_2mortal (newSViv (x / PANGO_SCALE)));
}

void
line_x_to_index (CFPlus::Layout self, int line, int x)
	PPCODE:
{
	PangoLayoutLine *lp;
        int index, trailing;

        if (line < 0)
          XSRETURN_EMPTY;

        if (!(lp = pango_layout_get_line (self->pl, line)))
          XSRETURN_EMPTY; /* do better */

        pango_layout_line_x_to_index (lp, x * PANGO_SCALE, &index, &trailing);

        EXTEND (SP, 2);
        if (GIMME_V == G_SCALAR)
          PUSHs (sv_2mortal (newSViv (index + trailing)));
        else
          {
            PUSHs (sv_2mortal (newSViv (index)));
            PUSHs (sv_2mortal (newSViv (trailing)));
          }
}

void
render (CFPlus::Layout self, float x, float y, int flags = 0)
	CODE:
        rc_clear (self->rc);
        pango_opengl_render_layout_subpixel (
          self->pl,
          self->rc,
          x * PANGO_SCALE, y * PANGO_SCALE,
          self->r, self->g, self->b, self->a,
          flags
        );
        // we assume that context_change actually clears/frees stuff
        // and does not do any recomputation...
        pango_layout_context_changed (self->pl);

void
draw (CFPlus::Layout self)
	CODE:
{
        glEnable (GL_TEXTURE_2D);
        glTexEnvi (GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
        glEnable (GL_BLEND);
        gl_BlendFuncSeparate (GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA,
                              GL_ONE      , GL_ONE_MINUS_SRC_ALPHA);
        glEnable (GL_ALPHA_TEST);
        glAlphaFunc (GL_GREATER, 7.f / 255.f);

        rc_draw (self->rc);

        glDisable (GL_ALPHA_TEST);
        glDisable (GL_BLEND);
        glDisable (GL_TEXTURE_2D);
}

MODULE = CFPlus	PACKAGE = CFPlus::Texture

PROTOTYPES: ENABLE

void
pad (SV *data_, int ow, int oh, int nw, int nh)
	CODE:
{
        if ((nw != ow || nh != oh) && SvOK (data_))
          {
            STRLEN datalen;
            char *data = SvPVbyte (data_, datalen);
            int bpp = datalen / (ow * oh);
            SV *result_ = sv_2mortal (newSV (nw * nh * bpp));

            SvPOK_only (result_);
            SvCUR_set (result_, nw * nh * bpp);

            memset (SvPVX (result_), 0, nw * nh * bpp);
            while (oh--)
              memcpy (SvPVX (result_) + oh * nw * bpp, data + oh * ow * bpp, ow * bpp);

            sv_setsv (data_, result_);
          }
}

void
draw_quad (SV *self, float x, float y, float w = 0., float h = 0.)
	PROTOTYPE: $$$;$$
        ALIAS:
           draw_quad_alpha = 1
           draw_quad_alpha_premultiplied = 2
	CODE:
{
	HV *hv = (HV *)SvRV (self);
	float s = SvNV (*hv_fetch (hv, "s", 1, 1));
	float t = SvNV (*hv_fetch (hv, "t", 1, 1));
        int name = SvIV (*hv_fetch (hv, "name", 4, 1));

        if (name <= 0)
          XSRETURN_EMPTY;

        if (items < 5)
          {
            w = SvNV (*hv_fetch (hv, "w", 1, 1));
            h = SvNV (*hv_fetch (hv, "h", 1, 1));
          }

        if (ix)
          {
            glEnable (GL_BLEND);

            if (ix == 2)
              glBlendFunc (GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
            else
              gl_BlendFuncSeparate (GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA,
                                    GL_ONE      , GL_ONE_MINUS_SRC_ALPHA);

            glEnable (GL_ALPHA_TEST);
            glAlphaFunc (GL_GREATER, 0.01f);
          }

        glBindTexture (GL_TEXTURE_2D, name);

        glBegin (GL_QUADS);
        glTexCoord2f (0, 0); glVertex2f (x    , y    );
        glTexCoord2f (0, t); glVertex2f (x    , y + h);
        glTexCoord2f (s, t); glVertex2f (x + w, y + h);
        glTexCoord2f (s, 0); glVertex2f (x + w, y    );
        glEnd ();

        if (ix)
          {
            glDisable (GL_ALPHA_TEST);
            glDisable (GL_BLEND);
          }
}

IV texture_valid_2d (GLint internalformat, GLsizei w, GLsizei h, GLenum format, GLenum type)
	CODE:
{
        GLint width;
        glTexImage2D (GL_PROXY_TEXTURE_2D, 0, internalformat, w, h, 0, format, type, 0);
        glGetTexLevelParameteriv (GL_PROXY_TEXTURE_2D, 0, GL_TEXTURE_WIDTH, &width);
        RETVAL = width > 0;
}
	OUTPUT:
        RETVAL

MODULE = CFPlus	PACKAGE = CFPlus::Map

PROTOTYPES: DISABLE

CFPlus::Map
new (SV *class)
	CODE:
        New (0, RETVAL, 1, struct map);
        RETVAL->x  = 0;
        RETVAL->y  = 0;
        RETVAL->w  = 0;
        RETVAL->h  = 0;
        RETVAL->ox = 0;
        RETVAL->oy = 0;
        RETVAL->faces = 8192; Newz (0, RETVAL->face2tile, RETVAL->faces, tileid);
        RETVAL->texs  = 8192; Newz (0, RETVAL->tex      , RETVAL->texs , maptex);
        RETVAL->rows = 0;
        RETVAL->row = 0;
	OUTPUT:
        RETVAL

void
DESTROY (CFPlus::Map self)
	CODE:
{
        map_clear (self);
        Safefree (self->face2tile);
        Safefree (self->tex);
        Safefree (self);
}

void
resize (CFPlus::Map self, int map_width, int map_height)
	CODE:
        self->w = map_width;
        self->h = map_height;

void
clear (CFPlus::Map self)
	CODE:
        map_clear (self);

void
set_tileid (CFPlus::Map self, int face, int tile)
	CODE:
{
	need_facenum (self, face); self->face2tile [face] = tile;
        need_texid   (self, tile);
}

void
set_smooth (CFPlus::Map self, int face, int smooth, int level)
	CODE:
{
  	tileid texid;
        maptex *tex;

        if (face < 0 || face >= self->faces)
          return;

        if (smooth < 0 || smooth >= self->faces)
          return;

  	texid = self->face2tile [face];

        if (!texid)
          return;

        tex = self->tex + texid;
        tex->smoothtile  = self->face2tile [smooth];
        tex->smoothlevel = level;
}

void
set_texture (CFPlus::Map self, int texid, int name, int w, int h, float s, float t, int r, int g, int b, int a)
	CODE:
{
	need_texid (self, texid);

        {
          maptex *tex = self->tex + texid;

          tex->name = name;
          tex->w = w;
          tex->h = h;
          tex->s = s;
          tex->t = t;
          tex->r = r;
          tex->g = g;
          tex->b = b;
          tex->a = a;
        }

       // somewhat hackish, but for textures that require it, it really
       // improves the look, and most others don't suffer.
       glBindTexture (GL_TEXTURE_2D, name);
       //glTexParameteri (GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
       //glTexParameteri (GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
       // use uglier nearest interpolation because linear suffers
       // from transparent color bleeding and ugly wrapping effects.
       glTexParameteri (GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
}

int
ox (CFPlus::Map self)
	ALIAS:
           oy = 1
           x  = 2
           y  = 3
           w  = 4
           h  = 5
        CODE:
        switch (ix)
          {
            case 0: RETVAL = self->ox; break;
            case 1: RETVAL = self->oy; break;
            case 2: RETVAL = self->x;  break;
            case 3: RETVAL = self->y;  break;
            case 4: RETVAL = self->w;  break;
            case 5: RETVAL = self->h;  break;
          }
	OUTPUT:
        RETVAL

void
scroll (CFPlus::Map self, int dx, int dy)
	CODE:
{
        if (dx > 0)
          map_blank (self, self->x, self->y, dx, self->h);
        else if (dx < 0)
          map_blank (self, self->x + self->w + dx, self->y, -dx, self->h);

        if (dy > 0)
          map_blank (self, self->x, self->y, self->w, dy);
        else if (dy < 0)
          map_blank (self, self->x, self->y + self->h + dy, self->w, -dy);

	self->ox += dx; self->x += dx;
	self->oy += dy; self->y += dy;

        while (self->y < 0)
          {
            Prepend (maprow, self->row, self->rows, MAP_EXTEND_Y);
             
            self->rows += MAP_EXTEND_Y;
            self->y    += MAP_EXTEND_Y;
          }
}

SV *
map1a_update (CFPlus::Map self, SV *data_, int extmap)
	CODE:
{
        uint8_t *data = (uint8_t *)SvPVbyte_nolen (data_);
        uint8_t *data_end = (uint8_t *)SvEND (data_);
        mapcell *cell;
        int x, y, z, flags;
        AV *missing = newAV ();
        RETVAL = newRV_noinc ((SV *)missing);

        while (data < data_end - 1)
          {
            flags = (data [0] << 8) + data [1]; data += 2;
            
            x = self->x + ((flags >> 10) & 63);
            y = self->y + ((flags >>  4) & 63);

	    cell = map_get_cell (self, x, y);

            if (flags & 15)
              {
                if (!cell->darkness)
                  {
                    memset (cell, 0, sizeof (*cell));
                    cell->darkness = 256;
                  }

                //TODO: don't trust server data to be in-range(!)

                if (flags & 8)
                  {
                    if (extmap)
                      {
                        uint8_t ext, cmd;

                        do
                          {
                            ext = *data++;
                            cmd = ext & 0x3f;

                            if (cmd < 4)
                              cell->darkness = 255 - ext * 64 + 1;
                            else if (cmd == 5) // health
                              {
                                cell->stat_width = 1;
                                cell->stat_hp = *data++;
                              }
                            else if (cmd == 6) // monster width
                              cell->stat_width = *data++ + 1;
                            else if (cmd == 0x47)
                              {
                                if (*data == 4)
                                  ; // decode player count

                                data += *data + 1;
                              }
                            else if (cmd == 8) // cell flags
                              cell->flags = *data++;
                            else if (ext & 0x40) // unknown, multibyte => skip
                              data += *data + 1;
                            else
                              data++;
                          }
                        while (ext & 0x80);
                      }
                    else
                      cell->darkness = *data++ + 1;
                  }

                for (z = 0; z <= 2; ++z)
                  if (flags & (4 >> z))
                    {
                      faceid face = (data [0] << 8) + data [1]; data += 2;
                      need_facenum (self, face);
                      cell->tile [z] = self->face2tile [face];

                      if (cell->tile [z])
                        {
                          maptex *tex = self->tex + cell->tile [z];
                          if (!tex->name)
                            av_push (missing, newSViv (cell->tile [z]));

                          if (tex->smoothtile)
                            {
                              maptex *smooth = self->tex + tex->smoothtile;
                              if (!smooth->name)
                                av_push (missing, newSViv (tex->smoothtile));
                            }
                        }
                    }
              }
            else
              cell->darkness = 0;
          }
}
	OUTPUT:
        RETVAL

SV *
mapmap (CFPlus::Map self, int x0, int y0, int w, int h)
	CODE:
{
	int x1, x;
	int y1, y;
        int z;
	SV *map_sv = newSV (w * h * sizeof (uint32_t));
        uint32_t *map = (uint32_t *)SvPVX (map_sv);

        SvPOK_only (map_sv);
        SvCUR_set (map_sv, w * h * sizeof (uint32_t));

        x0 += self->x; x1 = x0 + w;
        y0 += self->y; y1 = y0 + h;

        for (y = y0; y < y1; y++)
          {
            maprow *row = 0 <= y && y < self->rows
              ? self->row + y
              : 0;

            for (x = x0; x < x1; x++)
              {
                int r = 32, g = 32, b = 32, a = 192;

                if (row && row->c0 <= x && x < row->c1)
                  {
                    mapcell *cell = row->col + (x - row->c0);

                    for (z = 0; z <= 0; z++)
                      {
                        maptex tex = self->tex [cell->tile [z]];
                        int a0 = 255 - tex.a;
                        int a1 = tex.a;

                        r = (r * a0 + tex.r * a1) / 255;
                        g = (g * a0 + tex.g * a1) / 255;
                        b = (b * a0 + tex.b * a1) / 255;
                        a = (a * a0 + tex.a * a1) / 255;
                      }
                  }

                *map++ = (r      )
                       | (g <<  8)
                       | (b << 16)
                       | (a << 24);
              }
          }

      	RETVAL = map_sv;
}
	OUTPUT:
        RETVAL

void
draw (CFPlus::Map self, int mx, int my, int sw, int sh, int T)
	CODE:
{
        int x, y, z;

  	HV *smooth = (HV *)sv_2mortal ((SV *)newHV ());
        uint32_t smooth_level[256 / 32]; // one bit for every possible smooth level
        static uint8_t smooth_max[256][256]; // egad, fast and wasteful on memory (64k)
        smooth_key skey;

        rc_t *rc = rc_alloc ();
        rc_key_t key;
        rc_array_t *arr;

        // thats current max. sorry.
        if (sw > 255) sw = 255;
        if (sh > 255) sh = 255;

        // clear key, in case of extra padding
        memset (&skey, 0, sizeof (skey));

        memset (&key, 0, sizeof (key));
        key.r       = 255;
        key.g       = 255;
        key.b       = 255;
        key.a       = 255;
        key.mode    = GL_QUADS;
        key.format  = GL_T2F_V3F;
        key.texname = -1;

        mx += self->x;
        my += self->y;

        // first pass: determine smooth_max
        // rather ugly, if you ask me
        // could also be stored inside mapcell and updated on change
        memset (smooth_max, 0, sizeof (smooth_max));

        for (y = 0; y < sh; y++)
          if (0 <= y + my && y + my < self->rows)
            {
              maprow *row = self->row + (y + my);

              for (x = 0; x < sw; x++)
                if (row->c0 <= x + mx && x + mx < row->c1)
                  {
                    mapcell *cell = row->col + (x + mx - row->c0);

                    smooth_max[x + 1][y + 1] =
                      MAX (self->tex [cell->tile [0]].smoothlevel,
                        MAX (self->tex [cell->tile [1]].smoothlevel,
                          self->tex [cell->tile [2]].smoothlevel));
                  }
            }

        glEnable (GL_BLEND);
        glBlendFunc (GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glTexEnvi (GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);

        for (z = 0; z <= 2; z++)
          {
            memset (smooth_level, 0, sizeof (smooth_level));

            for (y = 0; y < sh; y++)
              if (0 <= y + my && y + my < self->rows)
                {
                  maprow *row = self->row + (y + my);

                  for (x = 0; x < sw; x++)
                    if (row->c0 <= x + mx && x + mx < row->c1)
                      {
                        mapcell *cell = row->col + (x + mx - row->c0);
                        tileid tile = cell->tile [z];
                        
                        if (tile)
                          {
                            maptex tex = self->tex [tile];
                            int px, py;

                            if (key.texname != tex.name)
                              {
                                if (!tex.name)
                                  tex = self->tex [2]; /* missing, replace by noface */

                                key.texname = tex.name;
                                arr = rc_array (rc, &key);
                              }

                            px = (x + 1) * T - tex.w;
                            py = (y + 1) * T - tex.h;

                            rc_t2f_v3f (arr, 0    , 0    , px        , py        , 0);
                            rc_t2f_v3f (arr, 0    , tex.t, px        , py + tex.h, 0);
                            rc_t2f_v3f (arr, tex.s, tex.t, px + tex.w, py + tex.h, 0);
                            rc_t2f_v3f (arr, tex.s, 0    , px + tex.w, py        , 0);

                            if (cell->flags && z == 2)
                              {
                                // overlays such as the speech bubble, probably more to come
                                if (cell->flags & 1)
                                  {
                                    maptex tex = self->tex [1];
                                    int px = x * T + T * 2 / 32;
                                    int py = y * T - T * 6 / 32;

                                    if (tex.name)
                                      {
                                        if (key.texname != tex.name)
                                          {
                                            key.texname = tex.name;
                                            arr = rc_array (rc, &key);
                                          }

                                        rc_t2f_v3f (arr, 0    , 0    , px    , py    , 0);
                                        rc_t2f_v3f (arr, 0    , tex.t, px    , py + T, 0);
                                        rc_t2f_v3f (arr, tex.s, tex.t, px + T, py + T, 0);
                                        rc_t2f_v3f (arr, tex.s, 0    , px + T, py    , 0);
                                      }
                                  }
                              }

                            // update smooth hash
                            if (tex.smoothtile)
                              {
                                skey.tile  = tex.smoothtile;
                                skey.level = tex.smoothlevel;

                                smooth_level [tex.smoothlevel >> 5] |= ((uint32_t)1) << (tex.smoothlevel & 31);

                                // add bits to current tile and all neighbours. skey.x|y is
                                // shifted +1|+1 so we always stay positive.

                                // bits is ___n cccc CCCC bbbb
                                // n  do not draw borders&corners
                                // c  draw these corners, but...
                                // C  ... not these
                                // b  draw these borders

                                // borders: 1 ┃·  2 ━━  4 ·┃  8 ··
                                //            ┃·    ··    ·┃    ━━
                                
                                // corners: 1 ┛·  2 ·┗  4 ··  8 ··
                                //            ··    ··    ·┏    ┓·

                                // full tile
                                skey.x = x + 1; skey.y = y + 1; smooth_or_bits (smooth, &skey, 0x1000);

                                // borders
                                skey.x = x + 2; skey.y = y + 1; smooth_or_bits (smooth, &skey, 0x0091);
                                skey.x = x + 1; skey.y = y + 2; smooth_or_bits (smooth, &skey, 0x0032);
                                skey.x = x    ; skey.y = y + 1; smooth_or_bits (smooth, &skey, 0x0064);
                                skey.x = x + 1; skey.y = y    ; smooth_or_bits (smooth, &skey, 0x00c8);

                                // corners
                                skey.x = x + 2; skey.y = y + 2; smooth_or_bits (smooth, &skey, 0x0100);
                                skey.x = x    ; skey.y = y + 2; smooth_or_bits (smooth, &skey, 0x0200);
                                skey.x = x    ; skey.y = y    ; smooth_or_bits (smooth, &skey, 0x0400);
                                skey.x = x + 2; skey.y = y    ; smooth_or_bits (smooth, &skey, 0x0800);
                              }
                          }
                      }
              }

            rc_draw (rc);
            rc_clear (rc);

            // go through all smoothlevels, lowest to highest, then draw.
            // this is basically counting sort
            {
              int w, b;

              glEnable (GL_TEXTURE_2D);
              glBegin (GL_QUADS);
              for (w = 0; w < 256 / 32; ++w)
                {
                  uint32_t smask = smooth_level [w];
                  if (smask)
                    for (b = 0; b < 32; ++b)
                      if (smask & (((uint32_t)1) << b))
                        {
                          int level = (w << 5) | b;
                          HE *he;

                          hv_iterinit (smooth);
                          while ((he = hv_iternext (smooth)))
                            {
                              smooth_key *skey = (smooth_key *)HeKEY (he);
                              IV bits = SvIVX (HeVAL (he));

                              if (!(bits & 0x1000)
                                  && skey->level == level
                                  && level > smooth_max [skey->x][skey->y])
                                {
                                  maptex tex = self->tex [skey->tile];
                                  int px = (((int)skey->x) - 1) * T;
                                  int py = (((int)skey->y) - 1) * T;
                                  int border = bits & 15;
                                  int corner = (bits >> 8) & ~(bits >> 4) & 15;
                                  float dx = tex.s * .0625f; // 16 images/row
                                  float dy = tex.t * .5f   ; // 2 images/column

                                  if (tex.name)
                                    {
                                      // this time avoiding texture state changes
                                      // save gobs of state changes.
                                      if (key.texname != tex.name)
                                        {
                                          glEnd ();
                                          glBindTexture (GL_TEXTURE_2D, key.texname = tex.name);
                                          glBegin (GL_QUADS);
                                        }

                                      if (border)
                                        {
                                          float ox = border * dx;

                                          glTexCoord2f (ox     , 0.f     ); glVertex2i (px    , py    );
                                          glTexCoord2f (ox     , dy      ); glVertex2i (px    , py + T);
                                          glTexCoord2f (ox + dx, dy      ); glVertex2i (px + T, py + T);
                                          glTexCoord2f (ox + dx, 0.f     ); glVertex2i (px + T, py    );
                                        }

                                      if (corner)
                                        {
                                          float ox = corner * dx;

                                          glTexCoord2f (ox     , dy      ); glVertex2i (px    , py    );
                                          glTexCoord2f (ox     , dy * 2.f); glVertex2i (px    , py + T);
                                          glTexCoord2f (ox + dx, dy * 2.f); glVertex2i (px + T, py + T);
                                          glTexCoord2f (ox + dx, dy      ); glVertex2i (px + T, py    );
                                        }
                                    }
                                }
                            }
                        }
                }

              glEnd ();
              glDisable (GL_TEXTURE_2D);
              key.texname = -1;
            }

            hv_clear (smooth);
          }

        glDisable (GL_BLEND);
        rc_free (rc);

        // top layer: overlays such as the health bar
        for (y = 0; y < sh; y++)
          if (0 <= y + my && y + my < self->rows)
            {
              maprow *row = self->row + (y + my);

              for (x = 0; x < sw; x++)
                if (row->c0 <= x + mx && x + mx < row->c1)
                  {
                    mapcell *cell = row->col + (x + mx - row->c0);

                    int px = x * T;
                    int py = y * T;

                    if (cell->stat_hp)
                      {
                        int width = cell->stat_width * T;
                        int thick = (sh * T / 32 + 27) / 28 + 1 + cell->stat_width;

                        glColor3ub (0,  0,  0);
                        glRectf (px + 1, py - thick - 2,
                                 px + width - 1, py);

                        glColor3ub (cell->stat_hp, 255 - cell->stat_hp, 0);
                        glRectf (px + 2,
                                 py - thick - 1,
                                 px + width - 2 - cell->stat_hp * (width - 4) / 255, py - 1);
                      }
                  }
            }
}

void
draw_magicmap (CFPlus::Map self, int dx, int dy, int w, int h, unsigned char *data)
	CODE:
{
	static float color[16][3] = {
           { 0.00F, 0.00F, 0.00F },
           { 1.00F, 1.00F, 1.00F },
           { 0.00F, 0.00F, 0.55F },
           { 1.00F, 0.00F, 0.00F },

           { 1.00F, 0.54F, 0.00F },
           { 0.11F, 0.56F, 1.00F },
           { 0.93F, 0.46F, 0.00F },
           { 0.18F, 0.54F, 0.34F },

           { 0.56F, 0.73F, 0.56F },
           { 0.80F, 0.80F, 0.80F },
           { 0.55F, 0.41F, 0.13F },
           { 0.99F, 0.77F, 0.26F },

           { 0.74F, 0.65F, 0.41F },

           { 0.00F, 1.00F, 1.00F },
           { 1.00F, 0.00F, 1.00F },
           { 1.00F, 1.00F, 0.00F },
        };
        
	int x, y;

	glEnable (GL_TEXTURE_2D);
        glTexEnvi (GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
        glEnable (GL_BLEND);
        glBlendFunc (GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glBegin (GL_QUADS);

        for (y = 0; y < h; y++)
          for (x = 0; x < w; x++)
            {
              unsigned char m = data [x + y * w];

              if (m)
                {
                  float *c = color [m & 15];

                  float tx1 = m & 0x40 ? 0.5 : 0.;
                  float tx2 = tx1 + 0.5;

                  glColor4f (c[0], c[1], c[2], 0.75);
                  glTexCoord2f (tx1, 0.); glVertex2i (x    , y    );
                  glTexCoord2f (tx1, 1.); glVertex2i (x    , y + 1);
                  glTexCoord2f (tx2, 1.); glVertex2i (x + 1, y + 1);
                  glTexCoord2f (tx2, 0.); glVertex2i (x + 1, y    );
                }
            }

        glEnd ();
        glDisable (GL_BLEND);
        glDisable (GL_TEXTURE_2D);
}

void
fow_texture (CFPlus::Map self, int mx, int my, int sw, int sh)
	PPCODE:
{
        int x, y;
        int sw1  = sw + 2;
        int sh1  = sh + 2;
        int sh3  = sh * 3;
        int sw34 = (sw * 3 + 3) & ~3;
        uint8_t *darkness1 = (uint8_t *)malloc (sw1 * sh1);
        SV *darkness3_sv = sv_2mortal (newSV (sw34 * sh3));
        uint8_t *darkness3 = (uint8_t *)SvPVX (darkness3_sv);

        SvPOK_only (darkness3_sv);
        SvCUR_set (darkness3_sv, sw34 * sh3);

        mx += self->x - 1;
        my += self->y - 1;

        memset (darkness1, 255, sw1 * sh1);

        for (y = 0; y < sh1; y++)
          if (0 <= y + my && y + my < self->rows)
            {
              maprow *row = self->row + (y + my);

              for (x = 0; x < sw1; x++)
                if (row->c0 <= x + mx && x + mx < row->c1)
                  {
                    mapcell *cell = row->col + (x + mx - row->c0);

                    darkness1 [y * sw1 + x] = cell->darkness
                      ? 255 - (cell->darkness - 1)
                      : 255 - FOW_DARKNESS;
                  }
            }

        for (y = 0; y < sh; ++y)
          for (x = 0; x < sw; ++x)
            {
              uint8_t d11 = darkness1 [(y    ) * sw1 + x    ];
              uint8_t d21 = darkness1 [(y    ) * sw1 + x + 1];
              uint8_t d31 = darkness1 [(y    ) * sw1 + x + 2];
              uint8_t d12 = darkness1 [(y + 1) * sw1 + x    ];
              uint8_t d22 = darkness1 [(y + 1) * sw1 + x + 1];
              uint8_t d32 = darkness1 [(y + 1) * sw1 + x + 2];
              uint8_t d13 = darkness1 [(y + 2) * sw1 + x    ];
              uint8_t d23 = darkness1 [(y + 2) * sw1 + x + 1];
              uint8_t d33 = darkness1 [(y + 2) * sw1 + x + 2];

              uint8_t r11 = (d11 + d21 + d12) / 3;
              uint8_t r21 = d21;
              uint8_t r31 = (d21 + d31 + d32) / 3;

              uint8_t r12 = d12;
              uint8_t r22 = d22;
              uint8_t r32 = d32;

              uint8_t r13 = (d13 + d23 + d12) / 3;
              uint8_t r23 = d23;
              uint8_t r33 = (d23 + d33 + d32) / 3;

              darkness3 [(y * 3    ) * sw34 + (x * 3    )] = MAX (d22, r11);
              darkness3 [(y * 3    ) * sw34 + (x * 3 + 1)] = MAX (d22, r21);
              darkness3 [(y * 3    ) * sw34 + (x * 3 + 2)] = MAX (d22, r31);
              darkness3 [(y * 3 + 1) * sw34 + (x * 3    )] = MAX (d22, r12);
              darkness3 [(y * 3 + 1) * sw34 + (x * 3 + 1)] = MAX (d22, r22);
              darkness3 [(y * 3 + 1) * sw34 + (x * 3 + 2)] = MAX (d22, r32);
              darkness3 [(y * 3 + 2) * sw34 + (x * 3    )] = MAX (d22, r13);
              darkness3 [(y * 3 + 2) * sw34 + (x * 3 + 1)] = MAX (d22, r23);
              darkness3 [(y * 3 + 2) * sw34 + (x * 3 + 2)] = MAX (d22, r33);
            }

        free (darkness1);

        EXTEND (SP, 3);
        PUSHs (sv_2mortal (newSViv (sw34)));
        PUSHs (sv_2mortal (newSViv (sh3)));
        PUSHs (darkness3_sv);
}

SV *
get_rect (CFPlus::Map self, int x0, int y0, int w, int h)
	CODE:
{
	int x, y, x1, y1;
	SV *data_sv = newSV (w * h * 7 + 5);
        uint8_t *data = (uint8_t *)SvPVX (data_sv);

        *data++ = 0; /* version 0 format */
        *data++ = w >> 8; *data++ = w;
        *data++ = h >> 8; *data++ = h;

        // we need to do this 'cause we don't keep an absolute coord system for rows
        // TODO: treat rows as we treat columns
        map_get_row (self, y0 + self->y - self->oy);//D
        map_get_row (self, y0 + self->y - self->oy + h - 1);//D

        x0 += self->x - self->ox;
        y0 += self->y - self->oy;

        x1 = x0 + w;
        y1 = y0 + h;

        for (y = y0; y < y1; y++)
          {
            maprow *row = 0 <= y && y < self->rows
              ? self->row + y
              : 0;

            for (x = x0; x < x1; x++)
              {
                if (row && row->c0 <= x && x < row->c1)
                  {
                    mapcell *cell = row->col + (x - row->c0);
                    uint8_t flags = 0;

                    if (cell->tile [0]) flags |= 1;
                    if (cell->tile [1]) flags |= 2;
                    if (cell->tile [2]) flags |= 4;

                    *data++ = flags;

                    if (flags & 1)
                      {
                        tileid tile = cell->tile [0];
                        *data++ = tile >> 8;
                        *data++ = tile;
                      }

                    if (flags & 2)
                      {
                        tileid tile = cell->tile [1];
                        *data++ = tile >> 8;
                        *data++ = tile;
                      }

                    if (flags & 4)
                      {
                        tileid tile = cell->tile [2];
                        *data++ = tile >> 8;
                        *data++ = tile;
                      }
                  }
                else
                  *data++ = 0;
              }
          }

        SvPOK_only (data_sv);
        SvCUR_set (data_sv, data - (uint8_t *)SvPVX (data_sv));
      	RETVAL = data_sv;
}
	OUTPUT:
        RETVAL

void
set_rect (CFPlus::Map self, int x0, int y0, uint8_t *data)
	PPCODE:
{
	int x, y, z;
        int w, h;
        int x1, y1;

        if (*data++ != 0)
          XSRETURN_EMPTY; /* version mismatch */

        w = *data++ << 8; w |= *data++;
        h = *data++ << 8; h |= *data++;

        // we need to do this 'cause we don't keep an absolute coord system for rows
        // TODO: treat rows as we treat columns
        map_get_row (self, y0 + self->y - self->oy);//D
        map_get_row (self, y0 + self->y - self->oy + h - 1);//D

        x0 += self->x - self->ox;
        y0 += self->y - self->oy;

        x1 = x0 + w;
        y1 = y0 + h;

        for (y = y0; y < y1; y++)
          {
            maprow *row = map_get_row (self, y);

            for (x = x0; x < x1; x++)
              {
                uint8_t flags = *data++;

                if (flags)
                  {
                    mapcell *cell = row_get_cell (row, x);
                    tileid tile[3] = { 0, 0, 0 };

                    if (flags & 1) { tile[0] = *data++ << 8; tile[0] |= *data++; }
                    if (flags & 2) { tile[1] = *data++ << 8; tile[1] |= *data++; }
                    if (flags & 4) { tile[2] = *data++ << 8; tile[2] |= *data++; }

                    if (cell->darkness == 0)
                      {
                        cell->darkness = 0;

                        for (z = 0; z <= 2; z++)
                          {
                            tileid t = tile [z];

                            if (t >= self->texs || (t && !self->tex [t].name))
                              {
                                XPUSHs (sv_2mortal (newSViv (t)));
                                need_texid (self, t);
                              }

                            cell->tile [z] = t;
                          }
                      }
                  }
              }
          }
}

MODULE = CFPlus	PACKAGE = CFPlus::RW

CFPlus::RW
new (SV *class, SV *data_sv)
	CODE:
{
        STRLEN datalen;
        char *data = SvPVbyte (data_sv, datalen);

        RETVAL = SDL_RWFromConstMem (data, datalen);
}
	OUTPUT:
        RETVAL

CFPlus::RW
new_from_file (SV *class, const char *path, const char *mode = "rb")
	CODE:
        RETVAL = SDL_RWFromFile (path, mode);
	OUTPUT:
        RETVAL

# fails on win32:
# CFPlus.xs(2268) : error C2059: syntax error : '('
#void
#close (CFPlus::RW self)
#	CODE:
#        (self->(close)) (self);

MODULE = CFPlus	PACKAGE = CFPlus::Channel

PROTOTYPES: DISABLE

CFPlus::Channel
find ()
	CODE:
{
        RETVAL = Mix_GroupAvailable (-1);

        if (RETVAL < 0)
          {
            RETVAL = Mix_GroupOldest (-1);

            if (RETVAL < 0)
              XSRETURN_UNDEF;

            Mix_HaltChannel (RETVAL);
          }

        Mix_UnregisterAllEffects (RETVAL);
        Mix_Volume (RETVAL, 128);
}
	OUTPUT:
        RETVAL

void
halt (CFPlus::Channel self)
	CODE:
        Mix_HaltChannel (self);

void
expire (CFPlus::Channel self, int ticks = -1)
	CODE:
        Mix_ExpireChannel (self, ticks);

void
fade_out (CFPlus::Channel self, int ticks = -1)
	CODE:
        Mix_FadeOutChannel (self, ticks);

int
volume (CFPlus::Channel self, int volume)
	CODE:
        RETVAL = Mix_Volume (self, CLAMP (volume, 0, 128));
	OUTPUT:
        RETVAL

void
unregister_all_effects (CFPlus::Channel self)
	CODE:
        Mix_UnregisterAllEffects (self);

void
set_panning (CFPlus::Channel self, int left, int right)
	CODE:
        left  = CLAMP (left , 0, 255);
        right = CLAMP (right, 0, 255);
        Mix_SetPanning (self, left, right);

void
set_distance (CFPlus::Channel self, int distance)
	CODE:
        Mix_SetDistance (self, CLAMP (distance, 0, 255));

void
set_position (CFPlus::Channel self, int angle, int distance)
	CODE:

void
set_position_r (CFPlus::Channel self, int dx, int dy, int maxdistance)
	CODE:
{
	int distance = sqrtf (dx * dx + dy * dy) * (255.f / sqrtf (maxdistance * maxdistance));
        int angle = 360 + (int)roundf (atan2f (dx, -dy) * 180.f / (float)M_PI);
        Mix_SetPosition (self, angle, CLAMP (distance, 0, 255));
}

void
set_reverse_stereo (CFPlus::Channel self, int flip)
	CODE:
        Mix_SetReverseStereo (self, flip);

MODULE = CFPlus	PACKAGE = CFPlus::MixChunk

PROTOTYPES: DISABLE

CFPlus::MixChunk
new (SV *class, CFPlus::RW rwops)
	CODE:
        RETVAL = Mix_LoadWAV_RW (rwops, 1);
	OUTPUT:
        RETVAL

void
DESTROY (CFPlus::MixChunk self)
	CODE:
        Mix_FreeChunk (self);

int
volume (CFPlus::MixChunk self, int volume = -1)
	CODE:
        if (items > 1)
          volume = CLAMP (volume, 0, 128);
        RETVAL = Mix_VolumeChunk (self, volume);
	OUTPUT:
        RETVAL

CFPlus::Channel
play (CFPlus::MixChunk self, CFPlus::Channel channel = -1, int loops = 0, int ticks = -1)
	CODE:
{
        RETVAL = Mix_PlayChannelTimed (channel, self, loops, ticks);

        if (RETVAL < 0)
          XSRETURN_UNDEF;

        if (channel < 0)
          {
            Mix_UnregisterAllEffects (RETVAL);
            Mix_Volume (RETVAL, 128);
          }
}
	OUTPUT:
        RETVAL

MODULE = CFPlus	PACKAGE = CFPlus::MixMusic

int
volume (int volume = -1)
	PROTOTYPE: ;$
	CODE:
        if (items > 0)
          volume = CLAMP (volume, 0, 128);
        RETVAL = Mix_VolumeMusic (volume);
	OUTPUT:
        RETVAL

void
fade_out (int ms)
	CODE:
        Mix_FadeOutMusic (ms);

void
halt ()
	CODE:
        Mix_HaltMusic ();

CFPlus::MixMusic
new (SV *class, CFPlus::RW rwops)
	CODE:
        RETVAL = Mix_LoadMUS_RW (rwops);
	OUTPUT:
        RETVAL

void
DESTROY (CFPlus::MixMusic self)
	CODE:
        Mix_FreeMusic (self);

int
play (CFPlus::MixMusic self, int loops = -1)
	CODE:
        RETVAL = Mix_PlayMusic (self, loops);
	OUTPUT:
        RETVAL

void
fade_in_pos (CFPlus::MixMusic self, int loops, int ms, double position)
	CODE:
        Mix_FadeInMusicPos (self, loops, ms, position);

MODULE = CFPlus	PACKAGE = CFPlus::OpenGL

PROTOTYPES: ENABLE

BOOT:
{
  HV *stash = gv_stashpv ("CFPlus::OpenGL", 1);
  static const struct {
    const char *name;
    IV iv;
  } *civ, const_iv[] = {
#	define const_iv(name) { # name, (IV)name }
        const_iv (GL_VENDOR),
        const_iv (GL_VERSION),
        const_iv (GL_EXTENSIONS),
	const_iv (GL_COLOR_MATERIAL),
	const_iv (GL_SMOOTH),
	const_iv (GL_FLAT),
	const_iv (GL_DITHER),
	const_iv (GL_BLEND),
	const_iv (GL_CULL_FACE),
	const_iv (GL_SCISSOR_TEST),
	const_iv (GL_DEPTH_TEST),
	const_iv (GL_ALPHA_TEST),
	const_iv (GL_NORMALIZE),
	const_iv (GL_RESCALE_NORMAL),
	const_iv (GL_FRONT),
	const_iv (GL_BACK),
	const_iv (GL_AUX0),
        const_iv (GL_AND),
	const_iv (GL_ONE),
	const_iv (GL_ZERO),
	const_iv (GL_SRC_ALPHA),
	const_iv (GL_DST_ALPHA),
	const_iv (GL_ONE_MINUS_SRC_ALPHA),
	const_iv (GL_ONE_MINUS_DST_ALPHA),
	const_iv (GL_SRC_ALPHA_SATURATE),
	const_iv (GL_RGB),
	const_iv (GL_RGBA),
	const_iv (GL_RGBA4),
	const_iv (GL_RGBA8),
	const_iv (GL_RGB5_A1),
	const_iv (GL_UNSIGNED_BYTE),
	const_iv (GL_UNSIGNED_SHORT),
	const_iv (GL_UNSIGNED_INT),
	const_iv (GL_ALPHA),
	const_iv (GL_INTENSITY),
	const_iv (GL_LUMINANCE),
	const_iv (GL_LUMINANCE_ALPHA),
	const_iv (GL_FLOAT),
	const_iv (GL_UNSIGNED_INT_8_8_8_8_REV),
        const_iv (GL_COMPRESSED_ALPHA_ARB),
        const_iv (GL_COMPRESSED_LUMINANCE_ARB),
        const_iv (GL_COMPRESSED_LUMINANCE_ALPHA_ARB),
        const_iv (GL_COMPRESSED_INTENSITY_ARB),
        const_iv (GL_COMPRESSED_RGB_ARB),
        const_iv (GL_COMPRESSED_RGBA_ARB),
	const_iv (GL_COMPILE),
	const_iv (GL_PROXY_TEXTURE_1D),
	const_iv (GL_PROXY_TEXTURE_2D),
	const_iv (GL_TEXTURE_1D),
	const_iv (GL_TEXTURE_2D),
	const_iv (GL_TEXTURE_ENV),
	const_iv (GL_TEXTURE_MAG_FILTER),
	const_iv (GL_TEXTURE_MIN_FILTER),
	const_iv (GL_TEXTURE_ENV_MODE),
	const_iv (GL_TEXTURE_WRAP_S),
	const_iv (GL_TEXTURE_WRAP_T),
	const_iv (GL_REPEAT),
	const_iv (GL_CLAMP),
	const_iv (GL_CLAMP_TO_EDGE),
	const_iv (GL_NEAREST),
	const_iv (GL_LINEAR),
        const_iv (GL_NEAREST_MIPMAP_NEAREST),
        const_iv (GL_LINEAR_MIPMAP_NEAREST),
        const_iv (GL_NEAREST_MIPMAP_LINEAR),
        const_iv (GL_LINEAR_MIPMAP_LINEAR),
        const_iv (GL_GENERATE_MIPMAP),
	const_iv (GL_MODULATE),
	const_iv (GL_DECAL),
	const_iv (GL_REPLACE),
	const_iv (GL_DEPTH_BUFFER_BIT),
	const_iv (GL_COLOR_BUFFER_BIT),
	const_iv (GL_PROJECTION),
	const_iv (GL_MODELVIEW),
	const_iv (GL_COLOR_LOGIC_OP),
	const_iv (GL_SEPARABLE_2D),
	const_iv (GL_CONVOLUTION_2D),
	const_iv (GL_CONVOLUTION_BORDER_MODE),
	const_iv (GL_CONSTANT_BORDER),
	const_iv (GL_POINTS),
	const_iv (GL_LINES),
	const_iv (GL_LINE_STRIP),
	const_iv (GL_LINE_LOOP),
	const_iv (GL_QUADS),
	const_iv (GL_QUAD_STRIP),
	const_iv (GL_TRIANGLES),
	const_iv (GL_TRIANGLE_STRIP),
	const_iv (GL_TRIANGLE_FAN),
	const_iv (GL_POLYGON),
	const_iv (GL_PERSPECTIVE_CORRECTION_HINT),
        const_iv (GL_POINT_SMOOTH_HINT),
        const_iv (GL_LINE_SMOOTH_HINT),
        const_iv (GL_POLYGON_SMOOTH_HINT),
        const_iv (GL_GENERATE_MIPMAP_HINT),
        const_iv (GL_TEXTURE_COMPRESSION_HINT),
        const_iv (GL_FASTEST),
        const_iv (GL_DONT_CARE),
        const_iv (GL_NICEST),
        const_iv (GL_V2F),
        const_iv (GL_V3F),
        const_iv (GL_T2F_V3F),
        const_iv (GL_T2F_N3F_V3F),
#	undef const_iv
  };
    
  for (civ = const_iv + sizeof (const_iv) / sizeof (const_iv [0]); civ-- > const_iv; )
    newCONSTSUB (stash, (char *)civ->name, newSViv (civ->iv));

  texture_av = newAV ();
  AvREAL_off (texture_av);
}

void
disable_GL_EXT_blend_func_separate ()
	CODE:
        gl.BlendFuncSeparate    = 0;
        gl.BlendFuncSeparateEXT = 0;

char *
gl_vendor ()
	CODE:
        RETVAL = (char *)glGetString (GL_VENDOR);
	OUTPUT:
        RETVAL

char *
gl_version ()
	CODE:
        RETVAL = (char *)glGetString (GL_VERSION);
	OUTPUT:
        RETVAL

char *
gl_extensions ()
	CODE:
        RETVAL = (char *)glGetString (GL_EXTENSIONS);
	OUTPUT:
        RETVAL

const char *glGetString (GLenum pname)

GLint glGetInteger (GLenum pname)
	CODE:
        glGetIntegerv (pname, &RETVAL);
	OUTPUT:
        RETVAL

GLdouble glGetDouble (GLenum pname)
	CODE:
        glGetDoublev (pname, &RETVAL);
	OUTPUT:
        RETVAL

int glGetError ()

void glFinish ()

void glClear (int mask)

void glClearColor (float r, float g, float b, float a = 1.0)
	PROTOTYPE: @

void glEnable (int cap)

void glDisable (int cap)

void glShadeModel (int mode)

void glHint (int target, int mode)

void glBlendFunc (int sfactor, int dfactor)

void glBlendFuncSeparate (int sa, int da, int saa, int daa)
	CODE:
        gl_BlendFuncSeparate (sa, da, saa, daa);

void glDepthMask (int flag)

void glLogicOp (int opcode)

void glColorMask (int red, int green, int blue, int alpha)

void glMatrixMode (int mode)

void glPushMatrix ()

void glPopMatrix ()

void glLoadIdentity ()

void glDrawBuffer (int buffer)

void glReadBuffer (int buffer)

# near_ and far_ are due to microsofts buggy "c" compiler
void glFrustum (double left, double right, double bottom, double top, double near_, double far_)

# near_ and far_ are due to microsofts buggy "c" compiler
void glOrtho (double left, double right, double bottom, double top, double near_, double far_)

PROTOTYPES: DISABLE

void glViewport (int x, int y, int width, int height)

void glScissor (int x, int y, int width, int height)

void glTranslate (float x, float y, float z = 0.)
        CODE:
        glTranslatef (x, y, z);

void glScale (float x, float y, float z = 1.)
        CODE:
        glScalef (x, y, z);

void glRotate (float angle, float x, float y, float z)
        CODE:
        glRotatef (angle, x, y, z);

void glColor (float r, float g, float b, float a = 1.0)
        ALIAS:
           glColor_premultiply = 1
        CODE:
        if (ix)
          {
            r *= a;
            g *= a;
            b *= a;
          }
        // microsoft visual "c" rounds instead of truncating...
        glColor4f (r, g, b, a);

void glRasterPos (float x, float y, float z = 0.)
        CODE:
        glRasterPos3f (0, 0, z);
        glBitmap (0, 0, 0, 0, x, y, 0);

void glVertex (float x, float y, float z = 0.)
        CODE:
        glVertex3f (x, y, z);

void glTexCoord (float s, float t)
        CODE:
        glTexCoord2f (s, t);

void glRect (float x1, float y1, float x2, float y2)
	CODE:
        glRectf (x1, y1, x2, y2);

void glRect_lineloop (float x1, float y1, float x2, float y2)
	CODE:
	glBegin (GL_LINE_LOOP);
	glVertex2f (x1, y1);
	glVertex2f (x2, y1);
	glVertex2f (x2, y2);
	glVertex2f (x1, y2);
	glEnd ();

PROTOTYPES: ENABLE

void glBegin (int mode)

void glEnd ()

void glPointSize (GLfloat size)

void glLineWidth (GLfloat width)

void glInterleavedArrays (int format, int stride, char *data)

void glDrawElements (int mode, int count, int type, char *indices)

# 1.2 void glDrawRangeElements (int mode, int start, int end

void glTexEnv (int target, int pname, float param)
        CODE:
        glTexEnvf (target, pname, param);

void glTexParameter (int target, int pname, float param)
	CODE:
        glTexParameterf (target, pname, param);

void glBindTexture (int target, int name)

void glConvolutionParameter (int target, int pname, float params)
	CODE:
        if (gl.ConvolutionParameterf)
          gl.ConvolutionParameterf (target, pname, params);

void glConvolutionFilter2D (int target, int internalformat, int width, int height, int format, int type, char *data)
	CODE:
        if (gl.ConvolutionFilter2D)
	  gl.ConvolutionFilter2D (target, internalformat, width, height, format, type, data);

void glSeparableFilter2D (int target, int internalformat, int width, int height, int format, int type, char *row, char *column)
	CODE:
        if (gl.SeparableFilter2D)
	  gl.SeparableFilter2D (target, internalformat, width, height, format, type, row, column);

void glTexImage2D (int target, int level, int internalformat, int width, int height, int border, int format, int type, char *data)

void glCopyTexImage2D (int target, int level, int internalformat, int x, int y, int width, int height, int border)

void glDrawPixels (int width, int height, int format, int type, char *pixels)

void glPixelZoom (float x, float y)

void glCopyPixels (int x, int y, int width, int height, int type = GL_COLOR)

int glGenTexture ()
        CODE:
        RETVAL = gen_texture ();
	OUTPUT:
        RETVAL

void glDeleteTexture (int name)
	CODE:
        del_texture (name);

int glGenList ()
	CODE:
        RETVAL = glGenLists (1);
	OUTPUT:
        RETVAL

void glDeleteList (int list)
	CODE:
        glDeleteLists (list, 1);

void glNewList (int list, int mode = GL_COMPILE)

void glEndList ()

void glCallList (int list)

MODULE = CFPlus	PACKAGE = CFPlus::UI::Base

PROTOTYPES: DISABLE

void
find_widget (SV *self, NV x, NV y)
	PPCODE:
{
  	if (within_widget (self, x, y))
          XPUSHs (self);
}

BOOT:
{
  hover_gv = gv_fetchpv ("CFPlus::UI::HOVER", 1, SVt_NV);

  draw_x_gv = gv_fetchpv ("CFPlus::UI::Base::draw_x", 1, SVt_NV);
  draw_y_gv = gv_fetchpv ("CFPlus::UI::Base::draw_y", 1, SVt_NV);
  draw_w_gv = gv_fetchpv ("CFPlus::UI::Base::draw_w", 1, SVt_NV);
  draw_h_gv = gv_fetchpv ("CFPlus::UI::Base::draw_h", 1, SVt_NV);
}

void
draw (SV *self)
	CODE:
{
  	HV *hv;
  	SV **svp;
	NV x, y, w, h;
        SV *draw_x_sv = GvSV (draw_x_gv);
        SV *draw_y_sv = GvSV (draw_y_gv);
        SV *draw_w_sv = GvSV (draw_w_gv);
        SV *draw_h_sv = GvSV (draw_h_gv);
        double draw_x, draw_y;

        if (!SvROK (self))
          croak ("CFPlus::Base::draw: %s not a reference", SvPV_nolen (self));

        hv = (HV *)SvRV (self);

        if (SvTYPE (hv) != SVt_PVHV)
          croak ("CFPlus::Base::draw: %s not a hashref", SvPV_nolen (self));

        svp = hv_fetch (hv, "w", 1, 0); w = svp ? SvNV (*svp) : 0.;
        svp = hv_fetch (hv, "h", 1, 0); h = svp ? SvNV (*svp) : 0.;

        if (!h || !w)
          XSRETURN_EMPTY;

        svp = hv_fetch (hv, "x", 1, 0); x = svp ? SvNV (*svp) : 0.;
        svp = hv_fetch (hv, "y", 1, 0); y = svp ? SvNV (*svp) : 0.;

        draw_x = SvNV (draw_x_sv) + x;
        draw_y = SvNV (draw_y_sv) + y;

        if (draw_x + w < 0 || draw_x >= SvNV (draw_w_sv)
         || draw_y + h < 0 || draw_y >= SvNV (draw_h_sv))
          XSRETURN_EMPTY;

        sv_setnv (draw_x_sv, draw_x);
        sv_setnv (draw_y_sv, draw_y);

        glPushMatrix ();
        glTranslated (x, y, 0);

        if (SvROK (GvSV (hover_gv)) && SvRV (GvSV (hover_gv)) == (SV *)hv)
          {
            svp = hv_fetch (hv, "can_hover", sizeof ("can_hover") - 1, 0);

            if (svp && SvTRUE (*svp))
              {
                glColor4f (1.0f * 0.2f, 0.8f * 0.2f, 0.5f * 0.2f, 0.2f);
                glEnable (GL_BLEND);
                glBlendFunc (GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
                glBegin (GL_QUADS);
                glVertex2f (0, 0);
                glVertex2f (w, 0);
                glVertex2f (w, h);
                glVertex2f (0, h);
                glEnd ();
                glDisable (GL_BLEND);
              }
          }
#if 0
        // draw borders, for debugging
        glPushMatrix ();
        glColor4f (1., 1., 0., 1.);
        glTranslatef (.5, .5, 0.);
        glBegin (GL_LINE_LOOP);
        glVertex2f (0    , 0);
        glVertex2f (w - 1, 0);
        glVertex2f (w - 1, h - 1);
        glVertex2f (0    , h - 1);
        glEnd ();
        glPopMatrix ();
#endif
	PUSHMARK (SP);
        XPUSHs (self);
        PUTBACK;
        call_method ("_draw", G_VOID | G_DISCARD);
        SPAGAIN;

        glPopMatrix ();

        draw_x = draw_x - x; sv_setnv (draw_x_sv, draw_x);
        draw_y = draw_y - y; sv_setnv (draw_y_sv, draw_y);
}

