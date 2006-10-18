#ifdef _WIN32
# define WIN32_LEAN_AND_MEAN
# define _WIN32_WINNT 0x0500 // needed to get win2000 api calls
# include <malloc.h>
# include <windows.h>
# include <wininet.h>
# pragma warning(disable:4244)
# pragma warning(disable:4761)
#endif

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#ifdef _WIN32
# undef pipe
#endif

#include <math.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

#include <SDL.h>
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

static struct
{
#define GL_FUNC(ptr,name) ptr name;
#include "glfunc.h"
#undef GL_FUNC
} gl;

static void gl_BlendFuncSeparate (GLenum sa, GLenum da, GLenum saa, GLenum daa)
{
  if (gl.BlendFuncSeparate)
    gl.BlendFuncSeparate (sa, da, saa, daa);
  else if (gl.BlendFuncSeparateEXT)
    gl.BlendFuncSeparateEXT (sa, da, saa, daa);
  else
    glBlendFunc (sa, da);
}

#include "texcache.c"

#include "pango-font.c"
#include "pango-fontmap.c"
#include "pango-render.c"

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

typedef uint16_t mapface;

typedef struct {
  GLint name;
  int w, h;
  float s, t;
  uint8_t r, g, b, a;
} maptex;

typedef struct {
  uint32_t player;
  mapface face[3];
  uint16_t darkness;
  uint8_t stat_width, stat_hp, flags;
} mapcell;

typedef struct {
  int32_t c0, c1;
  mapcell *col;
} maprow;

typedef struct map {
  int x, y, w, h;
  int ox, oy; /* offset to virtual global coordinate system */
  int faces;
  mapface *face;

  int texs;
  maptex *tex;

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
	const_iv (KMOD_LSHIFT),
	const_iv (KMOD_RSHIFT),
	const_iv (KMOD_LCTRL),
	const_iv (KMOD_RCTRL),
	const_iv (KMOD_LALT),
	const_iv (KMOD_RALT),
	const_iv (KMOD_LMETA),
	const_iv (KMOD_RMETA),
	const_iv (KMOD_NUM),
	const_iv (KMOD_CAPS),
	const_iv (KMOD_MODE),
	const_iv (KMOD_CTRL),
	const_iv (KMOD_SHIFT),
	const_iv (KMOD_ALT),
	const_iv (KMOD_META)
#	undef const_iv
  };
    
  for (civ = const_iv + sizeof (const_iv) / sizeof (const_iv [0]); civ-- > const_iv; )
    newCONSTSUB (stash, (char *)civ->name, newSViv (civ->iv));
}

int
in_destruct ()
	CODE:
        RETVAL = PL_main_cv == Nullcv;
        OUTPUT:
        RETVAL

NV floor (NV x)

NV ceil (NV x)

void
pango_init ()
	CODE:
{
        opengl_fontmap = pango_opengl_font_map_new ();
        pango_opengl_font_map_set_default_substitute ((PangoOpenGLFontMap *)opengl_fontmap, substitute_func, 0, 0);
        opengl_context = pango_opengl_font_map_create_context ((PangoOpenGLFontMap *)opengl_fontmap);
}

int
SDL_Init (U32 flags = SDL_INIT_VIDEO | SDL_INIT_AUDIO | PARACHUTE)

void
SDL_Quit ()

void
SDL_ListModes ()
	PPCODE:
{
	SDL_Rect **m;
	
        SDL_GL_SetAttribute (SDL_GL_RED_SIZE, 5);
        SDL_GL_SetAttribute (SDL_GL_GREEN_SIZE, 5);
        SDL_GL_SetAttribute (SDL_GL_BLUE_SIZE, 5);
        SDL_GL_SetAttribute (SDL_GL_ALPHA_SIZE, 1);

        SDL_GL_SetAttribute (SDL_GL_BUFFER_SIZE, 15);
        SDL_GL_SetAttribute (SDL_GL_DEPTH_SIZE, 0);

        SDL_GL_SetAttribute (SDL_GL_ACCUM_RED_SIZE, 0);
        SDL_GL_SetAttribute (SDL_GL_ACCUM_GREEN_SIZE, 0);
        SDL_GL_SetAttribute (SDL_GL_ACCUM_BLUE_SIZE, 0);
        SDL_GL_SetAttribute (SDL_GL_ACCUM_ALPHA_SIZE, 0);

        SDL_GL_SetAttribute (SDL_GL_DOUBLEBUFFER, 1);
#if SDL_VERSION_ATLEAST(1,2,10)
        SDL_GL_SetAttribute (SDL_GL_ACCELERATED_VISUAL, 1);
        SDL_GL_SetAttribute (SDL_GL_SWAP_CONTROL, 1);
#endif

        SDL_EnableUNICODE (1);
        SDL_EnableKeyRepeat (SDL_DEFAULT_REPEAT_DELAY, SDL_DEFAULT_REPEAT_INTERVAL);

	m = SDL_ListModes (0, SDL_FULLSCREEN | SDL_OPENGL);

        if (m && m != (SDL_Rect **)-1)
          while (*m)
            {
              AV *av = newAV ();
              av_push (av, newSViv ((*m)->w));
              av_push (av, newSViv ((*m)->h));
              XPUSHs (sv_2mortal (newRV_noinc ((SV *)av)));

              ++m;
            }
}

char *
SDL_GetError ()

int
SDL_SetVideoMode (int w, int h, int fullscreen)
	CODE:
        RETVAL = !!SDL_SetVideoMode (
          w, h, 0, SDL_OPENGL | (fullscreen ? SDL_FULLSCREEN : 0)
        );
        if (RETVAL)
          {
            SDL_WM_SetCaption ("Crossfire+ Client " VERSION, "Crossfire+");
#           define GL_FUNC(ptr,name) gl.name = (ptr)SDL_GL_GetProcAddress ("gl" # name);
#           include "glfunc.h"
#           undef GL_FUNC
          }
	OUTPUT:
        RETVAL

void
SDL_GL_SwapBuffers ()

char *
SDL_GetKeyName (int sym)

void
SDL_PollEvent ()
	PPCODE:
{
	SDL_Event ev;

        while (SDL_PollEvent (&ev))
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
                  hv_store (hv, "unicode", 7, newSViv (ev.key.keysym.unicode), 0);
                  break;

                case SDL_ACTIVEEVENT:
                  hv_store (hv, "gain",   4, newSViv (ev.active.gain), 0);
                  hv_store (hv, "state",  5, newSViv (ev.active.state), 0);
                  break;

                case SDL_MOUSEMOTION:
                  hv_store (hv, "mod",    3, newSViv (SDL_GetModState ()), 0);

                  hv_store (hv, "state",  5, newSViv (ev.motion.state), 0);
                  hv_store (hv, "x",      1, newSViv (ev.motion.x), 0);
                  hv_store (hv, "y",      1, newSViv (ev.motion.y), 0);
                  hv_store (hv, "xrel",   4, newSViv (ev.motion.xrel), 0);
                  hv_store (hv, "yrel",   4, newSViv (ev.motion.yrel), 0);
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
Mix_OpenAudio (int frequency = 48000, int format = MIX_DEFAULT_FORMAT, int channels = 1, int chunksize = 2048)
  	POSTCALL:
        Mix_HookMusicFinished (music_finished);
        Mix_ChannelFinished (channel_finished);

void
Mix_CloseAudio ()

int
Mix_AllocateChannels (int numchans = -1)

void
lowdelay (int fd, int val = 1)
	CODE:
#ifndef _WIN32
        setsockopt (fd, IPPROTO_TCP, TCP_NODELAY, &val, sizeof (val));
#endif

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
          ? SDL_RWFromFile (image, "r")
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

MODULE = CFPlus	PACKAGE = CFPlus::Font

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
	CODE:
        default_font = self;

MODULE = CFPlus	PACKAGE = CFPlus::Layout

void
reset_glyph_cache ()
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

        pango_layout_set_wrap (RETVAL->pl, PANGO_WRAP_WORD_CHAR);
        layout_update_font (RETVAL);
	OUTPUT:
        RETVAL

void
DESTROY (CFPlus::Layout self)
	CODE:
        g_object_unref (self->pl);
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
        RETVAL = index;
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
render (CFPlus::Layout self, float x, float y, int flags = 0)
	PPCODE:
        pango_opengl_render_layout_subpixel (
          self->pl,
          x * PANGO_SCALE, y * PANGO_SCALE,
          self->r, self->g, self->b, self->a,
          flags
        );

MODULE = CFPlus	PACKAGE = CFPlus::Texture

void
pad2pot (SV *data_, SV *w_, SV *h_)
	CODE:
{
        int ow = SvIV (w_);
        int oh = SvIV (h_);

        if (ow && oh)
          {
            int nw = minpot (ow);
            int nh = minpot (oh);

            if (nw != ow || nh != oh)
              {
                if (SvOK (data_))
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

                sv_setiv (w_, nw);
                sv_setiv (h_, nh);
              }
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

MODULE = CFPlus	PACKAGE = CFPlus::Map

CFPlus::Map
new (SV *class, int map_width, int map_height)
	CODE:
        New (0, RETVAL, 1, struct map);
        RETVAL->x  = 0;
        RETVAL->y  = 0;
        RETVAL->w  = map_width;
        RETVAL->h  = map_height;
        RETVAL->ox = 0;
        RETVAL->oy = 0;
        RETVAL->faces = 8192;
        Newz (0, RETVAL->face, RETVAL->faces, mapface);
        RETVAL->texs = 8192;
        Newz (0, RETVAL->tex, RETVAL->texs, maptex);
        RETVAL->rows = 0;
        RETVAL->row = 0;
	OUTPUT:
        RETVAL

void
DESTROY (CFPlus::Map self)
	CODE:
{
        map_clear (self);
        Safefree (self->face);
        Safefree (self->tex);
        Safefree (self);
}

void
clear (CFPlus::Map self)
	CODE:
        map_clear (self);

void
set_face (CFPlus::Map self, int face, int texid)
	CODE:
{
        while (self->faces <= face)
          {
            Append (mapface, self->face, self->faces, self->faces);
            self->faces *= 2;
          }

        self->face [face] = texid;
}

void
set_texture (CFPlus::Map self, int texid, int name, int w, int h, float s, float t, int r, int g, int b, int a)
	CODE:
{
        while (self->texs <= texid)
          {
            Append (maptex, self->tex, self->texs, self->texs);
            self->texs *= 2;
          }

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
          map_blank (self, self->x + self->w + dx + 1, self->y, -dx, self->h);

        if (dy > 0)
          map_blank (self, self->x, self->y, self->w, dy);
        else if (dy < 0)
          map_blank (self, self->x, self->y + self->h + dy + 1, self->w, -dy);

	self->ox += dx; self->x += dx;
	self->oy += dy; self->y += dy;

        while (self->y < 0)
          {
            Prepend (maprow, self->row, self->rows, MAP_EXTEND_Y);
             
            self->rows += MAP_EXTEND_Y;
            self->y    += MAP_EXTEND_Y;
          }
}

void
map1a_update (CFPlus::Map self, SV *data_, int extmap)
	CODE:
{
        uint8_t *data = (uint8_t *)SvPVbyte_nolen (data_);
        uint8_t *data_end = (uint8_t *)SvEND (data_);
        mapcell *cell;
        int x, y, flags;

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
                            else if (cmd == 0x47) // monster width
                              {
                                if (*data == 4)
                                  ; // decode player tag

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

                if (flags & 4)
                  {
                    cell->face [0] = self->face [(data [0] << 8) + data [1]]; data += 2;
                  }

                if (flags & 2)
                  {
                    cell->face [1] = self->face [(data [0] << 8) + data [1]]; data += 2;
                  }

                if (flags & 1)
                  {
                    cell->face [2] = self->face [(data [0] << 8) + data [1]]; data += 2;
                  }
              }
            else
              cell->darkness = 0;
          }
}

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
                        mapface face = cell->face [z];

                        if (face)
                          {
                            maptex tex = self->tex [face];
                            int a0 = 255 - tex.a;
                            int a1 = tex.a;

                            r = (r * a0 + tex.r * a1) / 255;
                            g = (g * a0 + tex.g * a1) / 255;
                            b = (b * a0 + tex.b * a1) / 255;
                            a = (a * a0 + tex.a * a1) / 255;
                          }
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
draw (CFPlus::Map self, int shift_x, int shift_y, int x0, int y0, int sw, int sh)
	CODE:
{
	int vx, vy;
        int x, y, z;
        int last_name;
        mapface face;

        vx = self->x + ((self->w - sw) >> 1) - shift_x;
        vy = self->y + ((self->h - sh) >> 1) - shift_y;

        /*
        int vx = self->vx = self->w >= sw
          ? self->x + (self->w - sw) / 2
          : MIN (self->x, MAX (self->x + self->w - sw + 1, self->vx));

        int vy = self->vy = self->h >= sh
          ? self->y + (self->h - sh) / 2
          : MIN (self->y, MAX (self->y + self->h - sh + 1, self->vy));
        */

        glColor4ub (255, 255, 255, 255);

        glEnable (GL_BLEND);
        glBlendFunc (GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glEnable (GL_TEXTURE_2D);
        glTexEnvi (GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);

        glBegin (GL_QUADS);

        last_name = 0;

        for (z = 0; z < 3; z++)
          for (y = 0; y < sh; y++)
            if (0 <= y + vy && y + vy < self->rows)
              {
                maprow *row = self->row + (y + vy);

                for (x = 0; x < sw; x++)
                  if (row->c0 <= x + vx && x + vx < row->c1)
                    {
                      mapcell *cell = row->col + (x + vx - row->c0);

                      face = cell->face [z];

                      if (face && face < self->texs)
                        {
                          maptex tex = self->tex [face];
                          int px = (x + 1) * 32 - tex.w;
                          int py = (y + 1) * 32 - tex.h;

                          if (last_name != tex.name)
                            {
                              glEnd ();
                              glBindTexture (GL_TEXTURE_2D, last_name = tex.name);
                              glBegin (GL_QUADS);
                            }

                          glTexCoord2f (0    , 0    ); glVertex2f (px        , py        );
                          glTexCoord2f (0    , tex.t); glVertex2f (px        , py + tex.h);
                          glTexCoord2f (tex.s, tex.t); glVertex2f (px + tex.w, py + tex.h);
                          glTexCoord2f (tex.s, 0    ); glVertex2f (px + tex.w, py        );
                        }

                      if (cell->flags && z == 2)
                        {
                          if (cell->flags & 1)
                            {
                              maptex tex = self->tex [1];
                              int px = (x + 1) * 32 - tex.w + 2;
                              int py = (y + 1) * 32 - tex.h - 6;

                              glEnd ();
                              glBindTexture (GL_TEXTURE_2D, last_name = tex.name);
                              glBegin (GL_QUADS);

                              glTexCoord2f (0    , 0    ); glVertex2f (px        , py        );
                              glTexCoord2f (0    , tex.t); glVertex2f (px        , py + tex.h);
                              glTexCoord2f (tex.s, tex.t); glVertex2f (px + tex.w, py + tex.h);
                              glTexCoord2f (tex.s, 0    ); glVertex2f (px + tex.w, py        );
                            }
                        }
                    }
              }

	glEnd ();

        glDisable (GL_TEXTURE_2D);
        glDisable (GL_BLEND);

        // top layer: overlays such as the health bar
        for (y = 0; y < sh; y++)
          if (0 <= y + vy && y + vy < self->rows)
            {
              maprow *row = self->row + (y + vy);

              for (x = 0; x < sw; x++)
                if (row->c0 <= x + vx && x + vx < row->c1)
                  {
                    mapcell *cell = row->col + (x + vx - row->c0);

                    int px = x * 32;
                    int py = y * 32;

                    if (cell->stat_hp)
                      {
                        int width = cell->stat_width * 32;
                        int thick = sh / 28 + 1 + cell->stat_width;

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
fow_texture (CFPlus::Map self, int shift_x, int shift_y, int x0, int y0, int sw, int sh)
	PPCODE:
{
	int vx, vy;
        int x, y;
        int sw4 = (sw + 3) & ~3;
	SV *darkness_sv = sv_2mortal (newSV (sw4 * sh));
        uint8_t *darkness = (uint8_t *)SvPVX (darkness_sv);

        memset (darkness, 255, sw4 * sh);
        SvPOK_only (darkness_sv);
        SvCUR_set (darkness_sv, sw4 * sh);

        vx = self->x + (self->w - sw + 1) / 2 - shift_x;
        vy = self->y + (self->h - sh + 1) / 2 - shift_y;

        for (y = 0; y < sh; y++)
          if (0 <= y + vy && y + vy < self->rows)
            {
              maprow *row = self->row + (y + vy);

              for (x = 0; x < sw; x++)
                if (row->c0 <= x + vx && x + vx < row->c1)
                  {
                    mapcell *cell = row->col + (x + vx - row->c0);

                    darkness[y * sw4 + x] = cell->darkness
                      ? 255 - (cell->darkness - 1)
                      : 255 - FOW_DARKNESS;
                  }
            }

        EXTEND (SP, 3);
        PUSHs (sv_2mortal (newSViv (sw4)));
        PUSHs (sv_2mortal (newSViv (sh)));
        PUSHs (darkness_sv);
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

                    if (cell->face [0]) flags |= 1;
                    if (cell->face [1]) flags |= 2;
                    if (cell->face [2]) flags |= 4;

                    *data++ = flags;

                    if (flags & 1)
                      {
                        *data++ = cell->face [0] >> 8;
                        *data++ = cell->face [0];
                      }

                    if (flags & 2)
                      {
                        *data++ = cell->face [1] >> 8;
                        *data++ = cell->face [1];
                      }

                    if (flags & 4)
                      {
                        *data++ = cell->face [2] >> 8;
                        *data++ = cell->face [2];
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
          return; /* version mismatch */

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
                    mapface face[3] = { 0, 0, 0 };

                    mapcell *cell = row_get_cell (row, x);

                    if (flags & 1) { face[0] = *data++ << 8; face[0] |= *data++; }
                    if (flags & 2) { face[1] = *data++ << 8; face[1] |= *data++; }
                    if (flags & 4) { face[2] = *data++ << 8; face[2] |= *data++; }

                    if (cell->darkness == 0)
                      {
                        cell->darkness = 0;

                        for (z = 0; z <= 2; z++)
                          {
                            cell->face[z] = face[z];

                            if (face[z] && (face[z] >= self->texs || !self->tex[face [z]].name))
                              XPUSHs (sv_2mortal (newSViv (face[z])));
                          }
                      }
                  }
              }
          }
}

MODULE = CFPlus	PACKAGE = CFPlus::MixChunk

CFPlus::MixChunk
new_from_file (SV *class, char *path)
	CODE:
        RETVAL = Mix_LoadWAV (path);
	OUTPUT:
        RETVAL

void
DESTROY (CFPlus::MixChunk self)
	CODE:
        Mix_FreeChunk (self);

int
volume (CFPlus::MixChunk self, int volume = -1)
	CODE:
        RETVAL = Mix_VolumeChunk (self, volume);
	OUTPUT:
        RETVAL

int
play (CFPlus::MixChunk self, int channel = -1, int loops = 0, int ticks = -1)
	CODE:
        RETVAL = Mix_PlayChannelTimed (channel, self, loops, ticks);
	OUTPUT:
        RETVAL

MODULE = CFPlus	PACKAGE = CFPlus::MixMusic

int
volume (int volume = -1)
	CODE:
        RETVAL = Mix_VolumeMusic (volume);
	OUTPUT:
        RETVAL

CFPlus::MixMusic
new_from_file (SV *class, char *path)
	CODE:
        RETVAL = Mix_LoadMUS (path);
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

MODULE = CFPlus	PACKAGE = CFPlus::OpenGL

BOOT:
{
  HV *stash = gv_stashpv ("CFPlus::OpenGL", 1);
  static const struct {
    const char *name;
    IV iv;
  } *civ, const_iv[] = {
#	define const_iv(name) { # name, (IV)name }
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
	const_iv (GL_COMPILE),
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
	const_iv (GL_LINES),
	const_iv (GL_LINE_STRIP),
	const_iv (GL_LINE_LOOP),
	const_iv (GL_QUADS),
	const_iv (GL_QUAD_STRIP),
	const_iv (GL_TRIANGLES),
	const_iv (GL_TRIANGLE_STRIP),
	const_iv (GL_TRIANGLE_FAN),
	const_iv (GL_PERSPECTIVE_CORRECTION_HINT),
        const_iv (GL_FASTEST),
        const_iv (GL_V2F),
        const_iv (GL_V3F),
        const_iv (GL_T2F_V3F),
        const_iv (GL_T2F_N3F_V3F),
#	undef const_iv
  };
    
  for (civ = const_iv + sizeof (const_iv) / sizeof (const_iv [0]); civ-- > const_iv; )
    newCONSTSUB (stash, (char *)civ->name, newSViv (civ->iv));
}

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

void glBegin (int mode)

void glEnd ()

void glColor (float r, float g, float b, float a = 1.0)
	PROTOTYPE: @
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

void glInterleavedArrays (int format, int stride, char *data)

void glDrawElements (int mode, int count, int type, char *indices)

# 1.2 void glDrawRangeElements (int mode, int start, int end

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

void glCopyPixels (int x, int y, int width, int height, int type = GL_COLOR)

int glGenTexture ()
        CODE:
{
        GLuint name;
        glGenTextures (1, &name);
        RETVAL = name;
}
	OUTPUT:
        RETVAL

void glDeleteTexture (int name)
	CODE:
{
        GLuint name_ = name;
        glDeleteTextures (1, &name_);
}
        
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

