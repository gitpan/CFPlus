/* Pango
 * Rendering routines to OpenGL
 *
 * Copyright (C) 2006 Marc Lehmann <pcg@goof.com>
 * Copyright (C) 2004 Red Hat Software
 * Copyright (C) 2000 Tor Lillqvist
 *
 * This file is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#include <math.h>

#include "pangoopengl.h"

#define PANGO_OPENGL_RENDERER_CLASS(klass)    (G_TYPE_CHECK_CLASS_CAST ((klass), PANGO_TYPE_OPENGL_RENDERER, PangoOpenGLRendererClass))
#define PANGO_IS_OPENGL_RENDERER_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass), PANGO_TYPE_OPENGL_RENDERER))
#define PANGO_OPENGL_RENDERER_GET_CLASS(obj)  (G_TYPE_INSTANCE_GET_CLASS ((obj), PANGO_TYPE_OPENGL_RENDERER, PangoOpenGLRendererClass))

typedef struct {
  PangoRendererClass parent_class;
} PangoOpenGLRendererClass;

struct _PangoOpenGLRenderer
{
  PangoRenderer parent_instance;
  float r, g, b, a; // modulate
  int flags;
  GLuint curtex; // current texture
};

G_DEFINE_TYPE (PangoOpenGLRenderer, pango_opengl_renderer, PANGO_TYPE_RENDERER)

typedef struct
{
  uint8_t *bitmap;
  int width, stride, height, top, left;
} Glyph;

static void *
temp_buffer (size_t size)
{
  static char *buffer;
  static size_t alloc;

  if (size > alloc)
    {
      size = (size + 4095) & ~4095;
      free (buffer);
      alloc = size;
      buffer = malloc (size);
    }

  return buffer;
}

static void
render_box (Glyph *glyph, int width, int height, int top)
{
  int i;
  int left = 0;

  if (height > 2)
    {
      height -= 2;
      top++;
    }

  if (width > 2)
    {
      width -= 2;
      left++;
    }

  glyph->stride = (width + 3) & ~3;
  glyph->width  = width;
  glyph->height = height;
  glyph->top    = top;
  glyph->left   = left;

  glyph->bitmap = temp_buffer (width * height);
  memset (glyph->bitmap, 0, glyph->stride * height);

  for (i = width; i--; )
    glyph->bitmap [i] = glyph->bitmap [i + (height - 1) * glyph->stride] = 0xff;

  for (i = height; i--; )
    glyph->bitmap [i * glyph->stride] = glyph->bitmap [i * glyph->stride + (width - 1)] = 0xff;
}

static void
font_render_glyph (Glyph *glyph, PangoFont *font, int glyph_index)
{
  FT_Face face;

  if (glyph_index & PANGO_GLYPH_UNKNOWN_FLAG)
    {
      PangoFontMetrics *metrics;

      if (!font)
	goto generic_box;

      metrics = pango_font_get_metrics (font, NULL);
      if (!metrics)
	goto generic_box;

      render_box (glyph, PANGO_PIXELS (metrics->approximate_char_width),
		         PANGO_PIXELS (metrics->ascent + metrics->descent),
		         PANGO_PIXELS (metrics->ascent));

      pango_font_metrics_unref (metrics);

      return;
    }

  face = pango_opengl_font_get_face (font);
  
  if (face)
    {
      PangoOpenGLFont *glfont = (PangoOpenGLFont *)font;

      FT_Load_Glyph (face, glyph_index, glfont->load_flags);
      FT_Render_Glyph (face->glyph, ft_render_mode_normal);

      glyph->width  = face->glyph->bitmap.width;
      glyph->stride = face->glyph->bitmap.pitch;
      glyph->height = face->glyph->bitmap.rows;
      glyph->top    = face->glyph->bitmap_top;
      glyph->left   = face->glyph->bitmap_left;
      glyph->bitmap = face->glyph->bitmap.buffer;
    }
  else
    generic_box:
      render_box (glyph, PANGO_UNKNOWN_GLYPH_WIDTH, PANGO_UNKNOWN_GLYPH_HEIGHT, PANGO_UNKNOWN_GLYPH_HEIGHT);
}

typedef struct glyph_info {
  tc_area tex;
  int left, top;
  int generation;
} glyph_info;

static void
free_glyph_info (glyph_info *g)
{
  tc_put (&g->tex);
  g_slice_free (glyph_info, g);
}

static void
draw_glyph (PangoRenderer *renderer_, PangoFont *font, PangoGlyph glyph, double x, double y)
{
  PangoOpenGLRenderer *renderer = PANGO_OPENGL_RENDERER (renderer_);
  glyph_info *g;
  float x1, y1, x2, y2;

  if (glyph & PANGO_GLYPH_UNKNOWN_FLAG)
    {
      glyph = pango_opengl_get_unknown_glyph (font);

      if (glyph == PANGO_GLYPH_EMPTY)
	glyph = PANGO_GLYPH_UNKNOWN_FLAG;
    }

  g = _pango_opengl_font_get_cache_glyph_data (font, glyph);

  if (!g || g->generation != tc_generation)
    {
      Glyph bm;
      font_render_glyph (&bm, font, glyph);

      if (g)
        g->generation = tc_generation;
      else
        {
          g = g_slice_new (glyph_info);

          _pango_opengl_font_set_glyph_cache_destroy (font, (GDestroyNotify)free_glyph_info);
          _pango_opengl_font_set_cache_glyph_data (font, glyph, g);
        }

      if (renderer->curtex)
        glEnd ();

      tc_get (&g->tex, bm.width, bm.height);

      g->left = bm.left;
      g->top  = bm.top;

      glBindTexture (GL_TEXTURE_2D, g->tex.name);
      glPixelStorei (GL_UNPACK_ROW_LENGTH, bm.stride);
      glPixelStorei (GL_UNPACK_ALIGNMENT, 1);
      glTexSubImage2D (GL_TEXTURE_2D, 0, g->tex.x, g->tex.y, bm.width, bm.height, GL_ALPHA, GL_UNSIGNED_BYTE, bm.bitmap);
      glPixelStorei (GL_UNPACK_ROW_LENGTH, 0);
      glPixelStorei (GL_UNPACK_ALIGNMENT, 4);

      renderer->curtex = g->tex.name;
      glBegin (GL_QUADS);
    }

  x += g->left;
  y -= g->top;

  x1 = g->tex.x * (1. / TC_WIDTH );
  y1 = g->tex.y * (1. / TC_HEIGHT);
  x2 = g->tex.w * (1. / TC_WIDTH ) + x1;
  y2 = g->tex.h * (1. / TC_HEIGHT) + y1;

  if (g->tex.name != renderer->curtex)
    {
      if (renderer->curtex)
        glEnd ();

      glBindTexture (GL_TEXTURE_2D, g->tex.name);
      renderer->curtex = g->tex.name;

      glBegin (GL_QUADS);
    }

  glTexCoord2f (x1, y1); glVertex2i (x           , y           );
  glTexCoord2f (x2, y1); glVertex2i (x + g->tex.w, y           );
  glTexCoord2f (x2, y2); glVertex2i (x + g->tex.w, y + g->tex.h);
  glTexCoord2f (x1, y2); glVertex2i (x           , y + g->tex.h);
}

static void
draw_trapezoid (PangoRenderer   *renderer_,
		PangoRenderPart  part,
		double           y1,
		double           x11,
		double           x21,
		double           y2,
		double           x12,
		double           x22)
{
  PangoOpenGLRenderer *renderer = (PangoOpenGLRenderer *)renderer_;

  if (renderer->curtex)
    {
      glEnd ();
      renderer->curtex = 0;
    }

  glDisable (GL_TEXTURE_2D);

  glBegin (GL_QUADS);
  glVertex2d (x11, y1);
  glVertex2d (x21, y1);
  glVertex2d (x22, y2);
  glVertex2d (x12, y2);
  glEnd ();

  glEnable (GL_TEXTURE_2D);
}

void 
pango_opengl_render_layout_subpixel (PangoLayout *layout,
                                     int x, int y,
                                     float r, float g, float b, float a,
                                     int flags)
{
  PangoContext *context;
  PangoFontMap *fontmap;
  PangoRenderer *renderer;

  context = pango_layout_get_context (layout);
  fontmap = pango_context_get_font_map (context);
  renderer = _pango_opengl_font_map_get_renderer (PANGO_OPENGL_FONT_MAP (fontmap));

  PANGO_OPENGL_RENDERER (renderer)->r = r;
  PANGO_OPENGL_RENDERER (renderer)->g = g;
  PANGO_OPENGL_RENDERER (renderer)->b = b;
  PANGO_OPENGL_RENDERER (renderer)->a = a;
  PANGO_OPENGL_RENDERER (renderer)->flags = flags;
  
  pango_renderer_draw_layout (renderer, layout, x, y);
}

void 
pango_opengl_render_layout (PangoLayout *layout,
			    int x, int y,
                            float r, float g, float b, float a,
                            int flags)
{
  pango_opengl_render_layout_subpixel (layout, x * PANGO_SCALE, y * PANGO_SCALE, r, g, b, a, flags);
}

static void
pango_opengl_renderer_init (PangoOpenGLRenderer *renderer)
{
  renderer->r = 1.;
  renderer->g = 1.;
  renderer->b = 1.;
  renderer->a = 1.;
}

static void
prepare_run (PangoRenderer *renderer, PangoLayoutRun *run)
{
  PangoOpenGLRenderer *glrenderer = (PangoOpenGLRenderer *)renderer;
  PangoColor *fg = 0;
  GSList *l;
  unsigned char r, g, b, a;

  renderer->underline = PANGO_UNDERLINE_NONE;
  renderer->strikethrough = FALSE;

  for (l = run->item->analysis.extra_attrs; l; l = l->next)
    {
      PangoAttribute *attr = l->data;
      
      switch (attr->klass->type)
	{
	case PANGO_ATTR_UNDERLINE:
	  renderer->underline = ((PangoAttrInt *)attr)->value;
	  break;
	  
	case PANGO_ATTR_STRIKETHROUGH:
	  renderer->strikethrough = ((PangoAttrInt *)attr)->value;
	  break;
	  
	case PANGO_ATTR_FOREGROUND:
          fg = &((PangoAttrColor *)attr)->color;
	  break;
	  
	default:
	  break;
	}
    }

  if (fg)
    {
      r = fg->red   * (255.f / 65535.f);
      g = fg->green * (255.f / 65535.f);
      b = fg->blue  * (255.f / 65535.f);
    }
  else 
    {
      r = glrenderer->r * 255.f;
      g = glrenderer->g * 255.f;
      b = glrenderer->b * 255.f;
    }

  a = glrenderer->a * 255.f;

  if (glrenderer->flags & FLAG_INVERSE)
    {
      r ^= 0xffU;
      g ^= 0xffU;
      b ^= 0xffU;
    } 

  glColor4ub (r, g, b, a);
}

static void
draw_begin (PangoRenderer *renderer_)
{
  PangoOpenGLRenderer *renderer = (PangoOpenGLRenderer *)renderer_;

  renderer->curtex = 0;

  glEnable (GL_TEXTURE_2D);
  glTexEnvi (GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
  glEnable (GL_BLEND);
  gl_BlendFuncSeparate (GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA,
                        GL_ONE      , GL_ONE_MINUS_SRC_ALPHA);
  glEnable (GL_ALPHA_TEST);
  glAlphaFunc (GL_GREATER, 0.01f);
}

static void
draw_end (PangoRenderer *renderer_)
{
  PangoOpenGLRenderer *renderer = (PangoOpenGLRenderer *)renderer_;

  if (renderer->curtex)
    glEnd ();

  glDisable (GL_ALPHA_TEST);
  glDisable (GL_BLEND);
  glDisable (GL_TEXTURE_2D);
}

static void
pango_opengl_renderer_class_init (PangoOpenGLRendererClass *klass)
{
  PangoRendererClass *renderer_class = PANGO_RENDERER_CLASS (klass);

  renderer_class->draw_glyph     = draw_glyph;
  renderer_class->draw_trapezoid = draw_trapezoid;
  renderer_class->prepare_run    = prepare_run;
  renderer_class->begin          = draw_begin;
  renderer_class->end            = draw_end;
}

