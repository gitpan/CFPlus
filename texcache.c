// all these must be powers of two
#define TC_WIDTH  256
#define TC_HEIGHT 256
#define TC_ROUND  4

typedef struct {
  GLuint name;
  int x, y, w, h;
} tc_area;

extern int tc_generation;

void tc_get (tc_area *area, int width, int height);
void tc_put (tc_area *area);
void tc_clear ();

/////////////////////////////////////////////////////////////////////////////

#include <glib.h>

int tc_generation;

typedef struct tc_texture {
  struct tc_texture *next;
  GLuint name;
  int avail;
} tc_texture;

typedef struct tc_slice {
  GLuint name;
  int avail, y;
} tc_slice;

static tc_slice slices[TC_HEIGHT / TC_ROUND];
static tc_texture *first_texture;

void
tc_clear ()
{
  int i;

  for (i = TC_HEIGHT / TC_ROUND; i--; )
    slices [i].name = 0;

  while (first_texture)
    {
      tc_texture *next = first_texture->next;
      del_texture (first_texture->name);
      g_slice_free (tc_texture, first_texture);
      first_texture = next;
    }

  ++tc_generation;
}

void
tc_get (tc_area *area, int width, int height)
{
  int slice_height = MIN (height + TC_ROUND - 1, TC_HEIGHT) & ~(TC_ROUND - 1);
  tc_slice *slice = slices + slice_height / TC_ROUND;

  area->w = width;
  area->h = height;

  width = MIN (width, TC_WIDTH);

  if (!slice->name || slice->avail < width)
    {
      // try to find a texture with enough space
      tc_texture *tex, *match = 0;

      for (tex = first_texture; tex; tex = tex->next)
        if (tex->avail >= slice_height && (!match || match->avail > tex->avail))
          match = tex;

      // create a new texture if necessary
      if (!match)
        {
          match = g_slice_new (tc_texture);
          match->next = first_texture;
          first_texture = match;
          match->name = gen_texture ();
          match->avail = TC_HEIGHT;

          glBindTexture (GL_TEXTURE_2D, match->name);
          glTexParameteri (GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
          glTexParameteri (GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
          glTexImage2D (GL_TEXTURE_2D, 0, GL_ALPHA, TC_WIDTH, TC_HEIGHT, 0, GL_ALPHA, GL_UNSIGNED_BYTE, 0);
        }

      match->avail -= slice_height;

      slice->name  = match->name;
      slice->avail = TC_WIDTH;
      slice->y     = match->avail;
    }

  slice->avail -= width;

  area->name = slice->name;
  area->x    = slice->avail;
  area->y    = slice->y;
}

void
tc_put (tc_area *area)
{
  // our management is too primitive to support this operation yet
}
