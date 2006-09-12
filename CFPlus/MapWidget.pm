package CFPlus::MapWidget;

use strict;
use utf8;

use List::Util qw(min max);

use CFPlus;
use CFPlus::OpenGL;
use CFPlus::UI;

our @ISA = CFPlus::UI::Base::;

my $magicmap_tex =
      new_from_file CFPlus::Texture CFPlus::find_rcfile "magicmap.png",
         mipmap => 1, wrap => 0, internalformat => GL_ALPHA;

sub new {
   my $class = shift;

   my $self = $class->SUPER::new (
      z         => -1,
      can_focus => 1,
      list      => glGenList,

      smooth_matrix => [
         0.05, 0.13, 0.05,
         0.13, 0.30, 0.13,
         0.05, 0.13, 0.05,
      ],

      @_
   );

   $self->{completer} = new CFPlus::MapWidget::Command::
      command   => $self->{command},
      tooltip   => "#completer_help",
   ;

   $self
}

sub add_command {
   my ($self, $command, $tooltip, $widget, $cb) = @_;

   (my $data = $command) =~ s/\\//g;

   $tooltip =~ s/^\s+//;
   $tooltip = "<big>$data</big>\n\n$tooltip";
   $tooltip =~ s/\s+$//;

   $self->{completer}{command}{$command} = [$data, $tooltip, $widget, $cb, ++$self->{command_id}];
}

sub clr_commands {
   my ($self) = @_;

   %{$self->{completer}{command}} = ();

   $self->{completer}->hide
      if $self->{completer};
}

sub invoke_button_down {
   my ($self, $ev, $x, $y) = @_;

   if ($ev->{button} == 1) {
      $self->grab_focus;
      return unless $::CONN;

      my $x = 1 + CFPlus::floor +($ev->{x} - $self->{sx0}) / $self->{tilesize} - $self->{sx};
      my $y = 1 + CFPlus::floor +($ev->{y} - $self->{sy0}) / $self->{tilesize} - $self->{sy};

      $x -= int 0.5 * $self->{sw};
      $y -= int 0.5 * $self->{sh};

      $::CONN->lookat ($x, $y)
         if $::CONN;

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
      (new CFPlus::UI::Menu
         items => [
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
            ["Quit",
               sub {
                  if ($::CONN) {
                     &::open_quit_dialog;
                  } else {
                     exit;
                  }
               }
            ],
         ],
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
   (
      32 * CFPlus::ceil $::WIDTH  / 32,
      32 * CFPlus::ceil $::HEIGHT / 32,
   )
}

sub update {
   my ($self) = @_;

   $self->{need_update} = 1;
   $self->SUPER::update;
}

my %DIR = (
   CFPlus::SDLK_KP8, [1, "north"],
   CFPlus::SDLK_KP9, [2, "northeast"],
   CFPlus::SDLK_KP6, [3, "east"],
   CFPlus::SDLK_KP3, [4, "southeast"],
   CFPlus::SDLK_KP2, [5, "south"],
   CFPlus::SDLK_KP1, [6, "southwest"],
   CFPlus::SDLK_KP4, [7, "west"],
   CFPlus::SDLK_KP7, [8, "northwest"],

   CFPlus::SDLK_UP,    [1, "north"],
   CFPlus::SDLK_RIGHT, [3, "east"],
   CFPlus::SDLK_DOWN,  [5, "south"],
   CFPlus::SDLK_LEFT,  [7, "west"],
);

sub invoke_key_down {
   my ($self, $ev) = @_;

   my $mod = $ev->{mod};
   my $sym = $ev->{sym};
   my $uni = $ev->{unicode};

   $mod &= CFPlus::KMOD_CTRL | CFPlus::KMOD_ALT | CFPlus::KMOD_SHIFT;

   if ($uni == ord "\t") {
      $::PL_WINDOW->toggle_visibility;
   } elsif ($sym == CFPlus::SDLK_F1 && !$mod) {
      $::HELP_WINDOW->toggle_visibility;
   } elsif ($sym == CFPlus::SDLK_F2 && !$mod) {
      ::toggle_player_page ($::STATS_PAGE);
   } elsif ($sym == CFPlus::SDLK_F3 && !$mod) {
      ::toggle_player_page ($::SKILL_PAGE);
   } elsif ($sym == CFPlus::SDLK_F4 && !$mod) {
      ::toggle_player_page ($::SPELL_PAGE);
   } elsif ($sym == CFPlus::SDLK_F5 && !$mod) {
      ::toggle_player_page ($::INVENTORY_PAGE);
   } elsif ($sym == CFPlus::SDLK_F9 && !$mod) {
      $::SETUP_DIALOG->toggle_visibility;
   } elsif ($sym == CFPlus::SDLK_INSERT && $mod & CFPlus::KMOD_CTRL) {
      $::BIND_EDITOR->set_binding (undef, undef, [],
         sub {
            my ($mod, $sym, $cmds) = @_;
            $::BIND_EDITOR->cfg_bind ($mod, $sym, $cmds);
         });
      $::BIND_EDITOR->start;
      $::BIND_EDITOR->show;
   } elsif ($sym == CFPlus::SDLK_INSERT && not ($mod & CFPlus::KMOD_CTRL)) {
      $::BIND_EDITOR->stop;
      $::BIND_EDITOR->ask_for_bind_and_commit;
      $::BIND_EDITOR->hide;
   } elsif (!$::CONN) {
      return 0; # bindings further down need a valid connection

   } elsif ($sym == CFPlus::SDLK_KP5 && !$mod) {
      $::CONN->user_send ("stay fire");
   } elsif ($uni == ord ",") {
      $::CONN->user_send ("take");
   } elsif ($uni == ord " ") {
      $::CONN->user_send ("apply");
   } elsif ($uni == ord ".") {
      $::CONN->user_send ($self->{completer}{last_command})
         if exists $self->{completer}{last_command};
   } elsif (my $bind_cmd = $::CFG->{profile}{default}{bindings}{$mod}{$sym}) {
      $::CONN->user_send ($_) for @$bind_cmd;
   } elsif (($sym == CFPlus::SDLK_KP_PLUS  && !$mod) || $uni == ord "+") {
      $::CONN->user_send ("rotateshoottype +");
   } elsif (($sym == CFPlus::SDLK_KP_MINUS && !$mod) || $uni == ord "-") {
      $::CONN->user_send ("rotateshoottype -");
   } elsif ($uni == ord '"') {
      $self->{completer}->set_prefix ("$::CFG->{say_command} ");
      $self->{completer}->show;
   } elsif ($uni == ord "'") {
      $self->{completer}->set_prefix ("");
      $self->{completer}->show;
   } elsif (exists $DIR{$sym}) {
      if ($mod & CFPlus::KMOD_SHIFT) {
         $self->{shft}++;
         if ($DIR{$sym}[0] != $self->{fire_dir}) {
            $::CONN->user_send ("fire $DIR{$sym}[0]");
         }
         $self->{fire_dir} = $DIR{$sym}[0];
      } elsif ($mod & CFPlus::KMOD_CTRL) {
         $self->{ctrl}++;
         $::CONN->user_send ("run $DIR{$sym}[0]");
      } else {
         $::CONN->user_send ("$DIR{$sym}[1]");
      }
   } elsif ((ord 'a') <= $uni && $uni <= (ord 'z')) {
      $self->{completer}->inject_key_down ($ev);
      $self->{completer}->show;
   } else {
      return 0;
   }

   1
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

sub set_magicmap {
   my ($self, $w, $h, $x, $y, $data) = @_;

   $x -= $::MAP->ox + int 0.5 * $::MAP->w;
   $y -= $::MAP->oy + int 0.5 * $::MAP->h;

   $self->{magicmap} = [$x, $y, $w, $h, $data];

   $self->update;
}

sub draw {
   my ($self) = @_;

   return unless $::MAP;

   my $focused = $CFPlus::UI::FOCUS == $self
                 || $CFPlus::UI::FOCUS == $self->{completer}{entry};

   return
      unless $focused || !$::FAST;

   if (delete $self->{need_update}) {
      my $tilesize = $self->{tilesize} = int 32 * $::CFG->{map_scale};

      my $sx = $self->{sx} = CFPlus::ceil $::CFG->{map_shift_x} / $tilesize;
      my $sy = $self->{sy} = CFPlus::ceil $::CFG->{map_shift_y} / $tilesize;

      my $sx0 = $self->{sx0} = $::CFG->{map_shift_x} - $sx * $tilesize;
      my $sy0 = $self->{sy0} = $::CFG->{map_shift_y} - $sy * $tilesize;

      my $sw = $self->{sw} = 1 + CFPlus::ceil $self->{w} / $tilesize;
      my $sh = $self->{sh} = 1 + CFPlus::ceil $self->{h} / $tilesize;

      if ($::CFG->{fow_enable}) {
         my ($w, $h, $data) = $::MAP->fow_texture ($sx, $sy, 0, 0, $sw, $sh);

         if ($::CFG->{fow_smooth} && $CFPlus::OpenGL::GL_VERSION >= 1.2) { # smooth fog of war
            glConvolutionParameter (GL_CONVOLUTION_2D, GL_CONVOLUTION_BORDER_MODE, GL_CONSTANT_BORDER);
            glConvolutionFilter2D (
               GL_CONVOLUTION_2D,
               GL_ALPHA,
               3, 3,
               GL_ALPHA, GL_FLOAT,
               (pack "f*", @{ $self->{smooth_matrix} }),
            );
            glEnable GL_CONVOLUTION_2D;
         }

         $self->{fow_texture} = new CFPlus::Texture
            w              => $w,
            h              => $h,
            data           => $data,
            internalformat => GL_ALPHA,
            format         => GL_ALPHA;

         glDisable GL_CONVOLUTION_2D if $::CFG->{fow_smooth};
      } else {
         delete $self->{fow_texture};
      }

      glNewList $self->{list};

      glPushMatrix;
      glTranslate $sx0, $sy0;
      glScale $::CFG->{map_scale}, $::CFG->{map_scale};

      $::MAP->draw ($sx, $sy, 0, 0, $sw, $sh);

      glScale 32, 32;

      if (my $tex = $self->{fow_texture}) {
         glEnable GL_TEXTURE_2D;
         glTexEnv GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE;

         glColor +($::CFG->{fow_intensity}) x 3, 0.9;
         $self->{fow_texture}->draw_quad_alpha (0, 0);

         glDisable GL_TEXTURE_2D;
      }

      if ($self->{magicmap}) {
         my ($x, $y, $w, $h, $data) = @{ $self->{magicmap} };

         $x += $::MAP->ox - $sx + int 0.5 * ($::MAP->w - $sw + 1);
         $y += $::MAP->oy - $sy + int 0.5 * ($::MAP->h - $sh + 1);

         glTranslate - $x - 1, - $y - 1;
         glBindTexture GL_TEXTURE_2D, $magicmap_tex->{name};
         $::MAP->draw_magicmap ($x, $y, $w, $h, $data);
      }

      glPopMatrix;
      glEndList;
   }

   glCallList $self->{list};

   # TNT2 emulates logops in software (or worse :)
   unless ($focused) {
      glColor 0.4, 0.2, 0.2, 0.6;
      glEnable GL_BLEND;
      glBlendFunc GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA;
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

our @ISA = CFPlus::UI::Base::;

use Time::HiRes qw(time);
use CFPlus::OpenGL;

sub size_request {
   ($::HEIGHT * 0.25, $::HEIGHT * 0.25)
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

   $::MAP or return;

   my ($w, $h) = @$self{qw(w h)};

   my $sw = int $::WIDTH  / (32 * $::CFG->{map_scale}) + 0.99;
   my $sh = int $::HEIGHT / (32 * $::CFG->{map_scale}) + 0.99;

   my $sx = int $::CFG->{map_shift_x} / 32;
   my $sy = int $::CFG->{map_shift_y} / 32;

   my $ox = 0.5 * ($w - $sw);
   my $oy = 0.5 * ($h - $sh);

   glEnable GL_BLEND;
   glBlendFunc GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA;
   glEnable GL_TEXTURE_2D;
   glTexEnv GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE;

   if ($self->{texture_atime} < time) {
      $self->{texture_atime} = time + 1/3;

      $self->{texture} =
         new CFPlus::Texture
            w    => $w,
            h    => $h,
            data => $::MAP->mapmap (-$ox, -$oy, $w, $h),
            type => $CFPlus::GL_VERSION >= 1.2 ? GL_UNSIGNED_INT_8_8_8_8_REV : GL_UNSIGNED_BYTE;
   }

   $self->{texture}->draw_quad (0, 0);

   glDisable GL_TEXTURE_2D;

   glTranslate 0.375, 0.375;

   #TODO: map scale is completely borked

   my $x0 = int $ox - $sx + 0.5;
   my $y0 = int $oy - $sy + 0.5;

   glColor 1, 1, 0, 1;
   glBegin GL_LINE_LOOP;
   glVertex $x0      , $y0      ;
   glVertex $x0      , $y0 + $sh;
   glVertex $x0 + $sw, $y0 + $sh;
   glVertex $x0 + $sw, $y0      ;
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
                   => sub { $::BIND_EDITOR->do_quick_binding ([$self->{select}], sub { $entry->grab_focus }) }]
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
