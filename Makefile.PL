use ExtUtils::MakeMaker;

sub manifest_resources {
   open my $manifest, "MANIFEST" or die "Couldn't open MANIFEST: $!";
   map { chomp; $_ } grep /^resources\//, <$manifest>
}

print <<EOF;

*** opengl 1.1 is required to run this client
*** opengl 1.2 is recommended to run this client
*** opengl 2.0 helps some more....

*** other dependencies:
*** pango-1.12.3, glib-2.10
*** libsdl, libSDL_mixer, libSDL_image

*** Pod::POM, Compress::LZF, BerkeleyDB, Crossfire, Event, AnyEvent perl modules

*** HINT: BerkeleyDB must be linked against version 4.3 or higher of libdb

EOF

if ($^O =~ /win32/i or $^O =~ /mswin/) {
   print <<EOF;
*** microsoft compatibility forced us to only support manual configuration
*** by editing Makefile.PL. complain to microsoft.

EOF
   $INC  = "-I/gtk/include -I/gtk/include/pango-1.0 -I/gtk/include/glib-2.0 -I/gtk/lib/glib-2.0/include/ -I/gtk/include/freetype2";
   $LIBS = "-L/gtk/lib -lSDL -lSDL_image -lSDL_mixer -lpango-1.0 -lpangoft2-1.0 -lgobject-2.0 -lgmodule-2.0 -lglib-2.0 -lfreetype -lfontconfig -lopengl32",
} else {
   $INC  = join " ", qx<sdl-config --cflags>, qx<pkg-config pangoft2 --cflags>;
   $LIBS = join " ", qx<sdl-config --libs>, "-lSDL_image -lSDL_mixer", qx<pkg-config pangoft2 --libs>, "-lGL";

   $INC =~ s/\n/ /g for $INC, $LIBS;
}

WriteMakefile(
    dist	=> {
	            PREOP	=> 'pod2text bin/cfplus | tee README >$(DISTVNAME)/README; chmod -R u=rwX,go=rX . ;',
	            COMPRESS	=> 'gzip -9v',
	            SUFFIX	=> '.gz',
	           },
    NAME => "CFPlus",
    INC => $INC,
    LIBS => [$LIBS],
    EXE_FILES => [qw(bin/cfplus)],
    VERSION_FROM => "CFPlus.pm",
    PREREQ_PM => {
       BerkeleyDB    => 0.27,
       Crossfire     => 0.8,
       Time::HiRes   => 0,
       Event         => 1.01,
       AnyEvent      => 0,
       Compress::LZF => 1.6,
       Pod::POM      => 0.15,
    },
    depend    => {
       "CFPlus.o" => 'glfunc.h pangoopengl.h pango-font.c pango-fontmap.c pango-render.c texcache.c',
    },
    PM => {
       'CFPlus.pm'                    => '$(INST_LIBDIR)/CFPlus.pm',
       'CFPlus/Protocol.pm'           => '$(INST_LIBDIR)/CFPlus/Protocol.pm',
       'CFPlus/OpenGL.pm'             => '$(INST_LIBDIR)/CFPlus/OpenGL.pm',
       'CFPlus/Texture.pm'            => '$(INST_LIBDIR)/CFPlus/Texture.pm',
       'CFPlus/UI.pm'                 => '$(INST_LIBDIR)/CFPlus/UI.pm',
       'CFPlus/Pod.pm'                => '$(INST_LIBDIR)/CFPlus/Pod.pm',
       'CFPlus/MapWidget.pm'          => '$(INST_LIBDIR)/CFPlus/MapWidget.pm',
       'CFPlus/BindingEditor.pm'      => '$(INST_LIBDIR)/CFPlus/BindingEditor.pm',
       (map +($_ => "\$(INST_LIBDIR)/CFPlus/$_"), manifest_resources),
    }
);
