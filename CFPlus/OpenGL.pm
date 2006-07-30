package CFPlus::OpenGL;

use strict;

use Carp ();
use CFPlus;

our %GL_EXT;
our $GL_VERSION;

our $GL_NPOT;

our $DEBUG = 1;
our %INIT_HOOK;
our %SHUTDOWN_HOOK;

sub import {
   my $caller = caller;

   no strict;

   my $symtab = *{"main::CFPlus::OpenGL::"}{HASH};

   for (keys %$symtab) {
      *{"$caller\::$_"} = *$_
         if /^(?:gl[A-Z_]|GL_)/;
   }
}

sub init {
   $GL_VERSION = gl_version * 1;
   %GL_EXT = map +($_ => 1), split /\s+/, gl_extensions;

   $GL_NPOT = $GL_EXT{GL_ARB_texture_non_power_of_two} || $GL_VERSION >= 2;
   $GL_NPOT = 0 if gl_vendor =~ /ATI Technologies/; # ATI doesn't get it right...

   glDisable GL_COLOR_MATERIAL;
   glShadeModel GL_FLAT;
   glDisable GL_DITHER;
   glDisable GL_DEPTH_TEST;
   glDepthMask 0;
   glHint GL_PERSPECTIVE_CORRECTION_HINT, GL_FASTEST;
   glDrawBuffer GL_BACK;
   glReadBuffer GL_BACK;

   $_->() for values %INIT_HOOK;
}

sub shutdown {
   $_->() for values %SHUTDOWN_HOOK;
}

sub gl_check {
   return unless $DEBUG;

   if (my $error = glGetError) {
      my ($format, @args) = @_;
      Carp::cluck sprintf "opengl error %x while $format", $error, @args;
   }
}

1;

