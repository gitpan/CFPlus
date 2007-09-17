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

*** HINT: Debian/Ubuntu users might have luck with:
*** apt-get install perl libpango1.0-dev libglib2.0-dev libsdl1.2-dev
*** apt-get install libevent-perl libsdl-mixer1.2-dev libsdl-image1.2-dev
*** apt-get install libberkeleydb-perl libwww-perl libdb4.4-dev
*** apt-get install anyevent-perl

EOF

if ($^O =~ /win32/i or $^O =~ /mswin/) {
   print <<EOF;
*** microsoft compatibility forced us to only support manual configuration
*** by editing Makefile.PL. complain to microsoft.

EOF
   $INC  = "-I/gtk/include -I/gtk/include/pango-1.0 -I/gtk/include/glib-2.0 -I/gtk/lib/glib-2.0/include/ -I/gtk/include/freetype2";
   $LIBS = "-L/gtk/lib -lSDL -lSDL_image -lSDL_mixer -lpango-1.0 -lpangoft2-1.0 -lgobject-2.0 -lgmodule-2.0 -lglib-2.0 -lfreetype -lfontconfig -lopengl32 -lwininet",
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
       Crossfire     => 1.0,
       Time::HiRes   => 0,
       Event         => 1.07,
       AnyEvent      => 0,
       Compress::LZF => 1.6,
       Pod::POM      => 0.15,
       LWP           => 0,
       JSON::XS      => 1.5,
    },
    depend    => {
       "CFPlus.o" => 'glfunc.h pangoopengl.h pango-font.c pango-fontmap.c pango-render.c texcache.c rendercache.c',
    },
    clean     => { FILES => 'docwiki.pst' },
    PM => {
       'CFPlus.pm'                    => '$(INST_LIBDIR)/CFPlus.pm',
       'CFPlus/Protocol.pm'           => '$(INST_LIBDIR)/CFPlus/Protocol.pm',
       'CFPlus/OpenGL.pm'             => '$(INST_LIBDIR)/CFPlus/OpenGL.pm',
       'CFPlus/Texture.pm'            => '$(INST_LIBDIR)/CFPlus/Texture.pm',
       'CFPlus/DB.pm'                 => '$(INST_LIBDIR)/CFPlus/DB.pm',
       'CFPlus/UI.pm'                 => '$(INST_LIBDIR)/CFPlus/UI.pm',
       'CFPlus/UI/Canvas.pm'          => '$(INST_LIBDIR)/CFPlus/UI/Canvas.pm',
       'CFPlus/UI/Inventory.pm'       => '$(INST_LIBDIR)/CFPlus/UI/Inventory.pm',
       'CFPlus/UI/SpellList.pm'       => '$(INST_LIBDIR)/CFPlus/UI/SpellList.pm',
       'CFPlus/UI/Canvas.pm'          => '$(INST_LIBDIR)/CFPlus/UI/Canvas.pm',
       'CFPlus/UI/ChatView.pm'        => '$(INST_LIBDIR)/CFPlus/UI/ChatView.pm',
       'CFPlus/UI/Dockable.pm'   => '$(INST_LIBDIR)/CFPlus/UI/Dockable.pm', #0.99a
       'CFPlus/UI/MessageWindow.pm'   => '$(INST_LIBDIR)/CFPlus/UI/MessageWindow.pm',
       'CFPlus/Item.pm'               => '$(INST_LIBDIR)/CFPlus/Item.pm',
       'CFPlus/Pod.pm'                => '$(INST_LIBDIR)/CFPlus/Pod.pm',
       'CFPlus/MapWidget.pm'          => '$(INST_LIBDIR)/CFPlus/MapWidget.pm',
       'CFPlus/Macro.pm'              => '$(INST_LIBDIR)/CFPlus/Macro.pm',
       'docwiki.pst'                  => '$(INST_LIBDIR)/CFPlus/resources/docwiki.pst',
       (map +($_ => "\$(INST_LIBDIR)/CFPlus/$_"), manifest_resources),
    }
);

sub MY::postamble {
   my $self = shift;

   # try to add MANIFEST to CONFIGDEP
   s/^CONFIGDEP = /CONFIGDEP = MANIFEST /m
      for @{ $self->{RESULT} };

   my $pods = join " ", <pod/*.pod>;

   <<EOF

all :: docwiki.pst

docwiki.pst: bin/pod2wiki $pods
	\$(PERL) -Mlib=. bin/pod2wiki $pods

EOF
}

