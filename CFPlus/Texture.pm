=head1 NAME

CFPlus::Texture - tetxure class for CFPlus

=head1 SYNOPSIS

 use CFPlus::Texture;

=head1 DESCRIPTION

=over 4

=cut

package CFPlus::Texture;

use strict;

use Scalar::Util;

use CFPlus::OpenGL;

my %TEXTURES;

sub new {
   my ($class, %data) = @_;

   my $self = bless {
      internalformat => GL_RGBA,
      format         => GL_RGBA,
      type           => GL_UNSIGNED_BYTE,
      %data,
   }, $class;

   Scalar::Util::weaken ($TEXTURES{$self+0} = $self);

   $self->upload;

   $self
}

sub new_from_image {
   my ($class, $image, %arg) = @_;

   $class->new (image => $image, internalformat => undef, %arg)
}

sub new_from_file {
   my ($class, $path, %arg) = @_;

   open my $fh, "<:raw", $path
      or die "$path: $!";

   local $/;
   $class->new_from_image (<$fh>, %arg)
}

#sub new_from_surface {
#   my ($class, $surface) = @_;
#
#   $surface->rgba;
#
#   $class->new (
#      data   => $surface->pixels,
#      w      => $surface->width,
#      h      => $surface->height,
#   )
#}

#sub new_from_layout {
#   my ($class, $layout, %arg) = @_;
#
#   my ($w, $h, $data, $format, $internalformat) = $layout->render;
#
#   $class->new (
#      w              => $w,
#      h              => $h,
#      data           => $data,
#      format         => $format,
#      internalformat => $format,
#      type           => GL_UNSIGNED_BYTE,
#      %arg,
#   )
#}

sub new_from_opengl {
   my ($class, $w, $h, $cb) = @_;

   $class->new (w => $w || 1, h => $h || 1, render_cb => $cb, nearest => 1)
}

sub upload {
   my ($self) = @_;

   return unless $GL_VERSION;

   my $data;

   if (exists $self->{data}) {
      $data = $self->{data};

   } elsif (exists $self->{render_cb}) {
      glViewport 0, 0, $self->{w}, $self->{h};
      glMatrixMode GL_PROJECTION;
      glLoadIdentity;
      glOrtho 0, $self->{w}, 0, $self->{h}, -10000, 10000;
      glMatrixMode GL_MODELVIEW;
      glLoadIdentity;
      $self->{render_cb}->($self, $self->{w}, $self->{h});

   } else {
      ($self->{w}, $self->{h}, $data, my $internalformat, $self->{format}, $self->{type})
         = CFPlus::load_image_inline $self->{image};

      $self->{internalformat} ||= $internalformat;
   }

   my ($tw, $th) = @$self{qw(w h)};

   $self->{minified} ||= [CFPlus::average $tw, $th, $data]
      if $self->{minify};

   pad2pot $data, $tw, $th unless $GL_NPOT;

   $self->{s} = $self->{w} / $tw;
   $self->{t} = $self->{h} / $th;

   $self->{name} ||= glGenTexture;

   glBindTexture GL_TEXTURE_2D, $self->{name};

   if ($self->{wrap}) {
      glTexParameter GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT;
      glTexParameter GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT;
   } else {
      glTexParameter GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, $GL_VERSION >= 1.2 ? GL_CLAMP_TO_EDGE : GL_CLAMP;
      glTexParameter GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, $GL_VERSION >= 1.2 ? GL_CLAMP_TO_EDGE : GL_CLAMP;
   }

   if ($::FAST || $self->{nearest}) {
      glTexParameter GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST;
      glTexParameter GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST;
   } elsif ($self->{mipmap} && $GL_VERSION >= 1.4) {
      glTexParameter GL_TEXTURE_2D, GL_GENERATE_MIPMAP, 1;
      glTexParameter GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR;
      glTexParameter GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR;
   } else {
      glTexParameter GL_TEXTURE_2D, GL_GENERATE_MIPMAP, $self->{mipmap};
      glTexParameter GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR;
      glTexParameter GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR;
   }
   
   glGetError;

   if (defined $data) {
      glTexImage2D GL_TEXTURE_2D, 0,
                   $self->{internalformat},
                   $tw, $th,
                   0,
                   $self->{format},
                   $self->{type},
                   $data;
      gl_check "uploading texture %dx%d if=%x f=%x t=%x",
               $tw, $th, $self->{internalformat},  $self->{format}, $self->{type};
   } else {
      exists $self->{render_cb} or die;
      glCopyTexImage2D GL_TEXTURE_2D, 0,
                   $self->{internalformat},
                   0, 0,
                   $tw, $th,
                   0;
      gl_check "copying to texture %dx%d if=%x",
               $tw, $th, $self->{internalformat};
   }
}

sub shutdown {
   my ($self) = @_;

   glDeleteTexture $self->{name}
      if $self->{name};
} 

sub DESTROY {
   my ($self) = @_;

   delete $TEXTURES{$self+0};

   $self->shutdown;
}

$CFPlus::OpenGL::INIT_HOOK{"CFPlus::Texture"} = sub {
   # first mark all existing texture names as in-use, in case the context lost textures
   glBindTexture GL_TEXTURE_2D, $_->{name}
      for values %TEXTURES;
   $_->upload
      for values %TEXTURES;
};

$CFPlus::OpenGL::SHUTDOWN_HOOK{"CFPlus::Texture"} = sub {
   $_->shutdown
      for values %TEXTURES;
};

1;

=back

=head1 AUTHOR

 Marc Lehmann <schmorp@schmorp.de>
 http://home.schmorp.de/

=cut

