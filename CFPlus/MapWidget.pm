package CFPlus::MapWidget;

use strict;
use utf8;

use List::Util qw(min max);

use CFPlus;
use CFPlus::OpenGL;
use CFPlus::UI;
use CFPlus::Macro;

our @ISA = CFPlus::UI::Base::;

my $magicmap_tex =
      new_from_file CFPlus::Texture CFPlus::find_rcfile "magicmap.png",
         mipmap => 1, wrap => 0, internalformat => GL_ALPHA;

sub new {
   my $class = shift;

   my $self = $class->SUPER::new (
      z         => -1,
      can_focus => 1,
      tilesize  => 32,
      @_
   );

   $self
}

sub set_tilesize {
   my ($self, $tilesize) = @_;

   $self->{tilesize} = $tilesize;
}

sub add_command {
   my ($self, $command, $tooltip, $widget, $cb) = @_;

   (my $data = $command) =~ s/\\//g;

   $tooltip =~ s/^\s+//;
   $tooltip = "<big>$data</big>\n\n$tooltip";
   $tooltip =~ s/\s+$//;

   $::COMPLETER->{command}{$command} = [$data, $tooltip, $widget, $cb, ++$self->{command_id}];
}

sub clr_commands {
   my ($self) = @_;

   %{$::COMPLETER->{command}} = ();

   $::COMPLETER->hide
      if $::COMPLETER;
}

sub server_login {
   my ($server) = @_;

   ::stop_game ();
   local $::PROFILE->{host} = $server;
   ::start_game ();
}

sub editor_invoke {
   my $editsup = $::CONN && $::CONN->{editor_support}
      or return;

   CFPlus::background {
      print "preparing editor startup...\n";

      my $server = $editsup->{gameserver} || "default";
      $server =~ s/([^a-zA-Z0-9_\-])/sprintf "=%x=", ord $1/ge;

      local $ENV{CROSSFIRE_MAPDIR} = my $mapdir = "$Crossfire::VARDIR/map.$server"; mkdir $mapdir;
      local $ENV{CROSSFIRE_LIBDIR} = my $libdir = "$Crossfire::VARDIR/lib.$server"; mkdir $libdir;

      print "map directory is $mapdir\n";
      print "lib directory is $libdir\n";

      my $ua = CFPlus::lwp_useragent;

      for my $file (qw(archetypes crossfire.0)) {
         my $url = "$editsup->{lib_root}$file";
         print "mirroring $url...\n";
         CFPlus::lwp_check $ua->mirror ($url, "$libdir/$file");
         printf "%s size %d octets\n", $file, -s "$libdir/$file";
      }

      if (1) { # upload a map
         my $mapname = $::CONN->{map_info}[0];

         my $mappath = "$mapdir/$mapname";

         -e $mappath and die "$mappath already exists\n";

         print "getting map revision for $mapname...\n";

         # try to get the most recent head revision, what a hack,
         # this should have been returned while downloading *sigh*
         my $log = (CFPlus::lwp_check $ua->get ("$editsup->{cvs_root}/$mapname?view=log&logsort=rev"))->decoded_content;

         if ($log =~ /\?rev=(\d+\.\d+)"/) {
            my $rev = $1;

            print "downloading revision $rev...\n";

            my $map = (CFPlus::lwp_check $ua->get ("$editsup->{cvs_root}/$mapname?rev=$rev"))->decoded_content;

            my $meta = {
               %$editsup,
               path     => $mapname,
               revision => $rev,
               cf_login => $::PROFILE->{user},
            };

            require File::Basename;
            require File::Path;

            File::Path::mkpath (File::Basename::dirname ($mappath));
            open my $fh, ">:raw:perlio", "$mappath.meta"
               or die "$mappath.meta: $!\n";
            print $fh CFPlus::to_json $meta;
            close $fh;
            open my $fh, ">:raw:perlio:utf8", $mappath
               or die "$mappath: $!\n";
            print $fh $map;
            close $fh;

            print "saved as $mappath\n";

            print "invoking editor...\n";
            exec "/root/s2/gce $mappath";#d#

            # now upload it
#           require HTTP::Request::Common;
#
#           my $res = $ua->post (
#              $ENV{CFPLUS_UPLOAD},
#              Content_Type => 'multipart/form-data',
#              Content      => [
#                 path        => $mapname,
#                 mapdir      => $ENV{CROSSFIRE_MAPDIR},
#                 map         => $map,
#                 revision    => $rev,
#                 cf_login    => $ENV{CFPLUS_LOGIN},
#                 cf_password => $ENV{CFPLUS_PASSWORD},
#                 comment     => "",
#              ]
#           );
#
#           if ($res->is_error) {
#              # fatal condition
#              warn $res->status_line;
#           } else {
#              # script replies are marked as {{..}}
#              my @msgs = $res->decoded_content =~ m/\{\{(.*?)\}\}/g;
#              warn map "$_\n", @msgs;
#           }
         } else {
            die "viewvc parse error, unable to detect revision\n";
         }
      }
   }
}

sub invoke_button_down {
   my ($self, $ev, $x, $y) = @_;

   if ($ev->{button} == 1) {
      $self->grab_focus;
      return unless $::CONN;

      my $x = $self->{dx} + CFPlus::floor +($ev->{x} - $self->{sx0}) / $self->{ctilesize};
      my $y = $self->{dy} + CFPlus::floor +($ev->{y} - $self->{sy0}) / $self->{ctilesize};

      $x -= CFPlus::floor $::MAP->w * 0.5;
      $y -= CFPlus::floor $::MAP->h * 0.5;

      if ($::CONN) {
         $::CONN->lookat ($x, $y)
      }

   } elsif ($ev->{button} == 2) {
      $self->grab_focus;
      return unless $::CONN;
      
      my ($ox, $oy) = ($ev->{x}, $ev->{y});
      my ($bw, $bh) = ($::CFG->{map_shift_x}, $::CFG->{map_shift_y});

      $self->{motion} = sub {
         my ($ev, $x, $y) = @_;

         ($x, $y) = ($ev->{x}, $ev->{y});

         $::CFG->{map_shift_x} = $bw + $x - $ox;
         $::CFG->{map_shift_y} = $bh + $y - $oy;

         $self->update;
      };
   } elsif ($ev->{button} == 3) {
      my @items = (
            ["Help Browser…\tF1", sub { $::HELP_WINDOW->toggle_visibility }],
            ["Statistics\tF2",    sub { ::toggle_player_page ($::STATS_PAGE) }],
            ["Skills\tF3",        sub { ::toggle_player_page ($::SKILL_PAGE) }],
            ["Spells…\tF4",       sub { ::toggle_player_page ($::SPELL_PAGE) }],
            ["Inventory…\tF5",    sub { ::toggle_player_page ($::INVENTORY_PAGE) }],
            ["Setup… \tF9",       sub { $::SETUP_DIALOG->toggle_visibility }],
            ["Server Messages…",  sub { $::MESSAGE_WINDOW->toggle_visibility }],
            [
               $::PICKUP_ENABLE->{state}
                  ? "Disable automatic pickup"
                  : "Enable automatic pickup",
               sub { $::PICKUP_ENABLE->toggle }
            ],
      );

      if ($::CONN && $::CONN->{editor_support}) {
         push @items, [
            "Edit this map <span size='xx-small'>(" . (CFPlus::asxml $::CONN->{map_info}[0]) . ")</span>",
            \&editor_invoke,
         ];

         for my $type (qw(test name)) {
            $::CONN->{editor_support}{type} ne $type
               or next;
            my $server = $::CONN->{editor_support}{"${type}server"}
               or next;

            push @items, [
               "Login on $type server <span size='xx-small'>(" . (CFPlus::asxml $server) . ")</span>",
               sub { server_login $server },
            ];
         }
      }

      push @items,
         ["Quit",
            sub {
               if ($::CONN) {
                  &::open_quit_dialog;
               } else {
                  exit;
               }
            }
         ],
      ;

      (new CFPlus::UI::Menu
         items => \@items,
      )->popup ($ev);
   }

   1
}

sub invoke_button_up {
   my ($self, $ev, $x, $y) = @_;

   delete $self->{motion};

   1
}

sub invoke_mouse_motion {
   my ($self, $ev, $x, $y) = @_;

   if ($self->{motion}) {
      $self->{motion}->($ev, $x, $y);
   } else {
      return 0;
   }

   1
}

sub size_request {
   my ($self) = @_;

   (
      $self->{tilesize} * CFPlus::ceil $::WIDTH  / $self->{tilesize},
      $self->{tilesize} * CFPlus::ceil $::HEIGHT / $self->{tilesize},
   )
}

sub update {
   my ($self) = @_;

   $self->{need_update} = 1;
   $self->SUPER::update;
}

my %DIR = (
   ( "," . CFPlus::SDLK_KP5  ), [0, "stay fire"],
   ( "," . CFPlus::SDLK_KP8  ), [1, "north"],
   ( "," . CFPlus::SDLK_KP9  ), [2, "northeast"],
   ( "," . CFPlus::SDLK_KP6  ), [3, "east"],
   ( "," . CFPlus::SDLK_KP3  ), [4, "southeast"],
   ( "," . CFPlus::SDLK_KP2  ), [5, "south"],
   ( "," . CFPlus::SDLK_KP1  ), [6, "southwest"],
   ( "," . CFPlus::SDLK_KP4  ), [7, "west"],
   ( "," . CFPlus::SDLK_KP7  ), [8, "northwest"],

   ( "," . CFPlus::SDLK_UP   ), [1, "north"],
   ("1," . CFPlus::SDLK_UP   ), [2, "northeast"],
   ( "," . CFPlus::SDLK_RIGHT), [3, "east"],
   ("1," . CFPlus::SDLK_RIGHT), [4, "southeast"],
   ( "," . CFPlus::SDLK_DOWN ), [5, "south"],
   ("1," . CFPlus::SDLK_DOWN ), [6, "southwest"],
   ( "," . CFPlus::SDLK_LEFT ), [7, "west"],
   ("1," . CFPlus::SDLK_LEFT ), [8, "northwest"],
);

sub invoke_key_down {
   my ($self, $ev) = @_;

   my $mod = $ev->{mod};
   my $sym = $ev->{sym};
   my $uni = $ev->{unicode};

   $mod &= CFPlus::KMOD_CTRL | CFPlus::KMOD_ALT | CFPlus::KMOD_SHIFT;

   if ($::CONN && (my $dir = $DIR{(!!($mod & CFPlus::KMOD_ALT)) . ",$sym"})) {
      if ($mod & CFPlus::KMOD_SHIFT) {
         $self->{shft}++;
         if ($dir->[0] != $self->{fire_dir}) {
            $::CONN->user_send ("fire $dir->[0]");
         }
         $self->{fire_dir} = $DIR{$sym}[0];
      } elsif ($mod & CFPlus::KMOD_CTRL) {
         $self->{ctrl}++;
         $::CONN->user_send ("run $dir->[0]");
      } else {
         $::CONN->user_send ("$dir->[1]");
      }

      return 1;
   }

   0
}

sub invoke_key_up {
   my ($self, $ev) = @_;

   my $res = 0;
   my $mod = $ev->{mod};
   my $sym = $ev->{sym};

   if ($::CFG->{shift_fire_stop}) {
      if (!($mod & CFPlus::KMOD_SHIFT) && delete $self->{shft}) {
         $::CONN->user_send ("fire_stop");
         delete $self->{fire_dir};
         $res = 1;
      }
   } else {
      if (exists $DIR{$sym} && delete $self->{shft}) {
         $::CONN->user_send ("fire_stop");
         delete $self->{fire_dir};
         $res = 1;
      } elsif (($sym == CFPlus::SDLK_LSHIFT || $sym == CFPlus::SDLK_RSHIFT) && delete $self->{shft}) { # XXX: is RSHIFT ok?
         $::CONN->user_send ("fire_stop");
         delete $self->{fire_dir};
         $res = 1;
      }
   }

   if (!($mod & CFPlus::KMOD_CTRL ) && delete $self->{ctrl}) {
      $::CONN->user_send ("run_stop");
      $res = 1;
   }

   $res
}

sub invoke_visibility_change {
   my ($self) = @_;

   $self->refresh_hook;

   0
}

sub set_magicmap {
   my ($self, $w, $h, $x, $y, $data) = @_;

   $x -= $::MAP->ox + 1 + int 0.5 * $::MAP->w;
   $y -= $::MAP->oy + 1 + int 0.5 * $::MAP->h;

   $self->{magicmap} = [$x, $y, $w, $h, $data];

   $self->update;
}

sub refresh_hook {
   my ($self) = @_;

   if ($::MAP && $::CONN) {
      if (delete $self->{need_update}) {
         my $tilesize = $self->{ctilesize} = (int $self->{tilesize} * $::CFG->{map_scale}) || 1;

         my $sw = $self->{sw} = 1 + CFPlus::ceil $self->{w} / $tilesize;
         my $sh = $self->{sh} = 1 + CFPlus::ceil $self->{h} / $tilesize;

         my $sx = CFPlus::ceil $::CFG->{map_shift_x} / $tilesize;
         my $sy = CFPlus::ceil $::CFG->{map_shift_y} / $tilesize;

         my $sx0 = $self->{sx0} = $::CFG->{map_shift_x} - $sx * $tilesize;
         my $sy0 = $self->{sy0} = $::CFG->{map_shift_y} - $sy * $tilesize;

         my $dx = $self->{dx} = CFPlus::ceil 0.5 * ($::MAP->w - $sw) - $sx;
         my $dy = $self->{dy} = CFPlus::ceil 0.5 * ($::MAP->h - $sh) - $sy;

         if ($::CFG->{fow_enable}) {
            my ($w, $h, $data) = $::MAP->fow_texture ($dx, $dy, $sw, $sh);

            $self->{fow_texture} = new CFPlus::Texture
               w              => $w,
               h              => $h,
               data           => $data,
               internalformat => GL_ALPHA,
               format         => GL_ALPHA;
         } else {
            delete $self->{fow_texture};
         }

         glNewList ($self->{list} ||= glGenList);

         glPushMatrix;
         glTranslate $sx0, $sy0;
         glScale $::CFG->{map_scale}, $::CFG->{map_scale};

         $::MAP->draw ($dx, $dy, $sw, $sh, $self->{tilesize});

         glScale $self->{tilesize}, $self->{tilesize};

         if (my $tex = $self->{fow_texture}) {
            glPushMatrix;
            glScale 1/3, 1/3;
            glEnable GL_TEXTURE_2D;
            glTexEnv GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE;

            glColor +($::CFG->{fow_intensity}) x 3, 0.9;
            $self->{fow_texture}->draw_quad_alpha (0, 0);

            glDisable GL_TEXTURE_2D;
            glPopMatrix;
         }

         if ($self->{magicmap}) {
            my ($x, $y, $w, $h, $data) = @{ $self->{magicmap} };

            $x += $::MAP->ox + $self->{dx};
            $y += $::MAP->oy + $self->{dy};

            glTranslate - $x - 1, - $y - 1;
            glBindTexture GL_TEXTURE_2D, $magicmap_tex->{name};
            $::MAP->draw_magicmap ($x, $y, $w, $h, $data);
         }

         glPopMatrix;
         glEndList;
      }
   } else {
      glDeleteList delete $self->{list}
         if $self->{list};
   }
}

sub draw {
   my ($self) = @_;

   $self->{root}->on_post_alloc (prepare => sub { $self->refresh_hook });

   return unless $self->{list};

   my $focused = $CFPlus::UI::FOCUS == $self
                 || $CFPlus::UI::FOCUS == $::COMPLETER->{entry};

   return
      unless $focused || !$::FAST;

   glCallList $self->{list};

   # TNT2 emulates logops in software (or worse :)
   unless ($focused) {
      glColor_premultiply 0, 0, 1, 0.25;
      glEnable GL_BLEND;
      glBlendFunc GL_ONE, GL_ONE_MINUS_SRC_ALPHA;
      glBegin GL_QUADS;
      glVertex 0, 0;
      glVertex 0, $::HEIGHT;
      glVertex $::WIDTH, $::HEIGHT;
      glVertex $::WIDTH, 0;
      glEnd;
      glDisable GL_BLEND;
   }
}

sub DESTROY {
   my $self = shift;

   glDeleteList $self->{list};

   $self->SUPER::DESTROY;
}

package CFPlus::MapWidget::MapMap;

use strict;
use utf8;

our @ISA = CFPlus::UI::Base::;

use Time::HiRes qw(time);
use CFPlus::OpenGL;

sub size_request {
   ($::HEIGHT * 0.2, $::HEIGHT * 0.2)
}

sub refresh_hook {
   my ($self) = @_;

   if ($::MAP && $self->{texture_atime} < time) {
      my ($w, $h) = @$self{qw(w h)};

      my $sw = int $::WIDTH  / ($::MAPWIDGET->{tilesize} * $::CFG->{map_scale}) + 0.99;
      my $sh = int $::HEIGHT / ($::MAPWIDGET->{tilesize} * $::CFG->{map_scale}) + 0.99;

      my $ox = 0.5 * ($w - $sw);
      my $oy = 0.5 * ($h - $sh);

      my $sx = int $::CFG->{map_shift_x} / $::MAPWIDGET->{tilesize};
      my $sy = int $::CFG->{map_shift_y} / $::MAPWIDGET->{tilesize};

      #TODO: map scale is completely borked

      my $x0 = int $ox - $sx + 0.5;
      my $y0 = int $oy - $sy + 0.5;

      $self->{sw} = $sw;
      $self->{sh} = $sh;

      $self->{x0} = $x0;
      $self->{y0} = $y0;

      $self->{texture_atime} = time + 1/3;

      $self->{texture} =
         new CFPlus::Texture
            w    => $w,
            h    => $h,
            data => $::MAP->mapmap (-$ox, -$oy, $w, $h),
            type => $CFPlus::GL_VERSION >= 1.2 ? GL_UNSIGNED_INT_8_8_8_8_REV : GL_UNSIGNED_BYTE;
   }
}

sub invoke_visibility_change {
   my ($self) = @_;

   $self->refresh_hook;

   0
}

sub invoke_size_allocate {
   my ($self, $w, $h) = @_;

   $self->update;

   1
}

sub update {
   my ($self) = @_;

   delete $self->{texture_atime};
   $self->SUPER::update;
}

sub _draw {
   my ($self) = @_;

   $self->{root}->on_post_alloc (texture => sub { $self->refresh_hook });

   $self->{texture} or return;

   glEnable GL_BLEND;
   glBlendFunc GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA;
   glEnable GL_TEXTURE_2D;
   glTexEnv GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE;

   $self->{texture}->draw_quad (0, 0);

   glDisable GL_TEXTURE_2D;

   glTranslate 0.375, 0.375;

   glColor 1, 1, 0, 1;
   glBegin GL_LINE_LOOP;
   glVertex $self->{x0}              , $self->{y0}              ;
   glVertex $self->{x0}              , $self->{y0} + $self->{sh};
   glVertex $self->{x0} + $self->{sw}, $self->{y0} + $self->{sh};
   glVertex $self->{x0} + $self->{sw}, $self->{y0}              ;
   glEnd;
   
   glDisable GL_BLEND;
}

package CFPlus::MapWidget::Command;

use strict;

use CFPlus::OpenGL;

our @ISA = CFPlus::UI::Frame::;

sub new {
   my $class = shift;

   my $self = $class->SUPER::new (
      bg => [0, 0, 0, 0.8],
      @_,
   );

   $self->add ($self->{vbox} = new CFPlus::UI::VBox);

   $self->{label} = [
      map
         CFPlus::UI::Label->new (
            can_hover     => 1,
            can_events    => 1,
            tooltip_width => 0.33,
            fontsize      => $_,
         ), (0.8) x 16
   ];

   $self->{entry} = new CFPlus::UI::Entry
      on_changed => sub {
         $self->update_labels;
         0
      },
      on_button_down => sub {
         my ($entry, $ev, $x, $y) = @_;

         if ($ev->{button} == 3) {
            (new CFPlus::UI::Menu
               items => [
                  ["bind <i>" . (CFPlus::asxml $self->{select}) . "</i> to a key"
                   => sub { CFPlus::Macro::quick_macro [$self->{select}], sub { $entry->grab_focus } }]
               ],
            )->popup ($ev);
            return 1;
         }
         0
      },
      on_key_down => sub {
         my ($entry, $ev) = @_;

         my $self = $entry->{parent}{parent};

         if ($ev->{sym} == 13) {
            if (exists $self->{select}) {
               $self->{last_command} = $self->{select};
               $::CONN->user_send ($self->{select});

               unshift @{$self->{history}}, $self->{entry}->get_text;
               $self->{hist_ptr} = 0;

               $self->hide;
            }
         } elsif ($ev->{sym} == 27) {
            $self->{hist_ptr} = 0;
            $self->hide;
         } elsif ($ev->{sym} == CFPlus::SDLK_DOWN) {
            if ($self->{hist_ptr} > 1) {
               $self->{hist_ptr}--;
               $self->{entry}->set_text ($self->{history}->[$self->{hist_ptr} - 1]);
            } elsif ($self->{hist_ptr} > 0) {
               $self->{hist_ptr}--;
               $self->{entry}->set_text ($self->{hist_saveback});
            } else {
               ++$self->{select_offset}
                  if $self->{select_offset} < $#{ $self->{last_match} || [] };
            }
            $self->update_labels;
         } elsif ($ev->{sym} == CFPlus::SDLK_UP) {
            if ($self->{select_offset}) {
               --$self->{select_offset}
            } else {
               unless ($self->{hist_ptr}) {
                  $self->{hist_saveback} = $self->{entry}->get_text;
               }
               if ($self->{hist_ptr} <= $#{$self->{history}}) {
                  $self->{hist_ptr}++;
               }
               $self->{entry}->set_text ($self->{history}->[$self->{hist_ptr} - 1])
                  if exists $self->{history}->[$self->{hist_ptr} - 1];
            }
            $self->update_labels;
         } else {
            return 0;
         }

         1
      }
   ;

   $self->{vbox}->add (
      $self->{entry},
      @{$self->{label}},
   );

   $self
}

sub set_prefix {
   my ($self, $prefix) = @_;

   $self->{entry}->set_text ($prefix);
   $self->show;
}

sub invoke_size_allocate {
   my ($self, $w, $h) = @_;

   $self->move_abs (($::WIDTH - $w) * 0.5, ($::HEIGHT - $h) * 0.6, 10);

   $self->SUPER::invoke_size_allocate ($w, $h)
}

sub show {
   my ($self) = @_;

   $self->SUPER::show;
   $self->{entry}->grab_focus;
}

sub hide {
   my ($self) = @_;

   $self->{hist_ptr} = 0;

   $self->SUPER::hide;
   $self->{entry}->set_text ("");
}

sub inject_key_down {
   my ($self, $ev) = @_;

   $self->{entry}->grab_focus;
   $self->{entry}->emit (key_down => $ev);
}

sub update_labels {
   my ($self) = @_;

   my $text = $self->{entry}->get_text;

   length $text
      or return $self->hide;

   my ($cmd, $arg) = $text =~ /^\s*([^[:space:]]*)(.*)$/;

   if ($text ne $self->{last_search}) {
      my @match;

      if ($text =~ /^(.*?)\s+$/) {
         @match = [$cmd, "(appended whitespace suppresses completion)"];
      } else {
         my $regexp = do {
            my ($beg, @chr) = split //, lc $cmd;

            # the following regex is used to match our "completion entry"
            # to an actual command - the parentheses match kind of "overhead"
            # - the more characters the parentheses match, the less attractive
            # is the match.
            my $regexp = "^\Q$beg\E"
                       . join "", map "(?:.*?[ \\\\]\Q$_\E|(.*?)\Q$_\E)", @chr;
            qr<$regexp>
         };

         my @penalty;

         for (keys %{$self->{command}}) {
            if (@penalty = $_ =~ $regexp) {
               push @match, [$_, length join "", map "::$_", grep defined, @penalty];
            }
         }

         @match = map $self->{command}{$_->[0]},
                     sort {
                        $a->[1] <=> $b->[1]
                           or $self->{command}{$a->[0]}[4] <=> $self->{command}{$b->[0]}[4]
                           or (length $b->[0]) <=> (length $a->[0])
                     } @match;
      }

      $self->{last_search} = $text;
      $self->{last_match} = \@match;

      $self->{select_offset} = 0;
   }

   my @labels = @{ $self->{label} };
   my @matches = @{ $self->{last_match} || [] };

   if ($self->{select_offset}) {
      splice @matches, 0, $self->{select_offset}, ();

      my $label = shift @labels;
      $label->set_text ("...");
      $label->set_tooltip ("Use Cursor-Up to view previous matches");
   }

   for my $label (@labels) {
      $label->{fg} = [1, 1, 1, 1];
      $label->{bg} = [0, 0, 0, 0];
   }

   if (@matches) {
      $self->{select} = "$matches[0][0]$arg";

      $labels[0]->{fg} = [0, 0, 0, 1];
      $labels[0]->{bg} = [1, 1, 1, 0.8];
   } else {
      $self->{select} = "$cmd$arg";
   }

   for my $match (@matches) {
      my $label = shift @labels;

      if (@labels) {
         $label->set_text ("$match->[0]$arg");
         $label->set_tooltip ($match->[1]);
      } else {
         $label->set_text ("...");
         $label->set_tooltip ("Use Cursor-Down to view more matches");
         last;
      }
   }

   for my $label (@labels) {
      $label->set_text ("");
      $label->set_tooltip ("");
   }

   $self->update;
}

sub _draw {
   my ($self) = @_;

   # hack
   local $CFPlus::UI::FOCUS = $self->{entry};

   $self->SUPER::_draw;
}

1

