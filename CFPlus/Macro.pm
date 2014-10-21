package CFPlus::Macro;

use strict;

use List::Util ();
use CFPlus::UI;

our $REFRESH_MACRO_LIST;

our %DEFAULT_KEYMAP = (
   (map +("($_)" => "!completer $_"), "a" .. "z"),
   "(!)"       => "!completer shout ",
   "(\")"      => "!completer say ",
   "(')"       => "!completer",

   "LShift-tab" => "!toggle-messagewindow",
   "RShift-tab" => "!toggle-messagewindow",
   "tab"        => "!toggle-playerbook",
   "f1"         => "!toggle-help",
   "f2"         => "!toggle-stats",
   "f3"         => "!toggle-skills",
   "f4"         => "!toggle-spells",
   "f5"         => "!toggle-inventory",
   "f9"         => "!toggle-setup",
   (map +("LAlt-$_" => "!switch-tab $_"), 0..9),
   (map +("RAlt-$_" => "!switch-tab $_"), 0..9),
   "LAlt-x"     => "!close-current-tab",
   "return"     => "!activate-chat",
   "."          => "!repeat-command",

   ","          => "take",
   "space"      => "apply",
   "enter"	=> "examine",
   "[+]"        => "rotateshoottype +",
   "[-]"        => "rotateshoottype -",
   "LAlt-e"	=> "examine",
   "LAlt-s"	=> "ready_skill find traps",
   "LAlt-d"	=> "ready_skill disarm traps",
   "LAlt-p"	=> "ready_skill praying",
);

# allowed modifiers
our %MODIFIER = (
   "LShift" => CFPlus::KMOD_LSHIFT,
   "RShift" => CFPlus::KMOD_RSHIFT,
#   "Shift"  => CFPlus::KMOD_LSHIFT | CFPlus::KMOD_RSHIFT,
   "LCtrl"  => CFPlus::KMOD_LCTRL,
   "RCtrl"  => CFPlus::KMOD_RCTRL,
#   "Ctrl"   => CFPlus::KMOD_LCTRL | CFPlus::KMOD_RCTRL,
   "LAlt"   => CFPlus::KMOD_LALT,
   "RAlt"   => CFPlus::KMOD_RALT,
#   "Alt"    => CFPlus::KMOD_LALT | CFPlus::KMOD_RALT,
   "LMeta"  => CFPlus::KMOD_LMETA,
   "RMeta"  => CFPlus::KMOD_RMETA,
#   "Meta"   => CFPlus::KMOD_LMETA | CFPlus::KMOD_RMETA,
);

# allowed modifiers
our $MODIFIER_MASK |= $_ for values %MODIFIER;

# can bind to these without any modifier
our @DIRECT_CHARS = qw(0 1 2 3 4 5 6 7 8 9);

our @DIRECT_KEYS = (
   CFPlus::SDLK_F1,
   CFPlus::SDLK_F2,
   CFPlus::SDLK_F3,
   CFPlus::SDLK_F4,
   CFPlus::SDLK_F5,
   CFPlus::SDLK_F6,
   CFPlus::SDLK_F7,
   CFPlus::SDLK_F8,
   CFPlus::SDLK_F9,
   CFPlus::SDLK_F10,
   CFPlus::SDLK_F11,
   CFPlus::SDLK_F12,
   CFPlus::SDLK_F13,
   CFPlus::SDLK_F14,
   CFPlus::SDLK_F15,
);

our %MACRO_FUNCTION = (
   "toggle-messagewindow" => sub { $::MESSAGE_WINDOW->toggle_visibility },
   "toggle-playerbook"    => sub { $::PL_WINDOW->toggle_visibility },
   "toggle-help"          => sub { $::HELP_WINDOW->toggle_visibility },
   "toggle-stats"         => sub { ::toggle_player_page ($::STATS_PAGE) },
   "toggle-skills"        => sub { ::toggle_player_page ($::SKILL_PAGE) },
   "toggle-spells"        => sub { ::toggle_player_page ($::SPELL_PAGE) },
   "toggle-inventory"     => sub { ::toggle_player_page ($::INVENTORY_PAGE) },
   "toggle-pickup"        => sub { ::toggle_player_page ($::PICKUP_PAGE) },
   "toggle-setup"         => sub { $::SETUP_DIALOG->toggle_visibility },
   "toggle-setup"         => sub { $::SETUP_DIALOG->toggle_visibility },
   "switch-tab"           => sub { $::MESSAGE_WINDOW->user_switch_to_page (0 + shift) },
   "close-current-tab"    => sub { $::MESSAGE_WINDOW->close_current_tab },
   "activate-chat"        => sub { $::MESSAGE_WINDOW->activate_current },
   "repeat-command"       => sub {
      $::CONN->user_send ($::COMPLETER->{last_command})
         if $::CONN && exists $::COMPLETER->{last_command};
   },
   "completer"            => sub {
      if ($::CONN) {
         $::COMPLETER->set_prefix (shift);
         $::COMPLETER->show;
      }
   },
);

our $DEFAULT_KEYMAP;

sub init {
   $DEFAULT_KEYMAP ||= do {
      my %sym = map +(CFPlus::SDL_GetKeyName $_, $_), CFPlus::SDLK_FIRST .. CFPlus::SDLK_LAST;
      my $map;

      while (my ($k, $v) = each %DEFAULT_KEYMAP) {
         if ($k =~ /^\((.)\)$/) {
            $map->{U}{ord $1} = $v;
         } else {
            my @mod = split /-/, $k;
            my $sym = $sym{pop @mod}
               or warn "unknown keysym $k\n";

            my $mod = 0; $mod |= $MODIFIER{$_} for @mod;

            $map->{K}[CFPlus::popcount $mod]{$mod}{$sym} = $v;
         }
      }

      %DEFAULT_KEYMAP = ();
      $map
   };
}

sub accelkey_to_string($) {
   join "-",
      (grep $_[0][0] & $MODIFIER{$_}, keys %MODIFIER),
      CFPlus::SDL_GetKeyName $_[0][1]
}

sub trigger_to_string($) {
   my ($macro) = @_;

   $macro->{accelkey}
      ? accelkey_to_string $macro->{accelkey}
      : "(none)"
}

sub macro_to_text($) {
   my ($macro) = @_;

   join "", map "$_\n", @{ $macro->{action} }
}

sub macro_from_text($$) {
   my ($macro, $text) = @_;

   $macro->{action} = [
      grep /\S/, $text =~ /^\s*(.*?)\s*$/mg
   ];
}

sub trigger_edit {
   my ($macro, $end_cb) = @_;

   my $window;
   
   my $done = sub {
      $window->disconnect_all ("delete");
      $window->disconnect_all ("focus_out");
      $window->destroy;
      &$end_cb;
   };

   $window = new CFPlus::UI::Toplevel
      title => "Edit Macro Trigger",
      x     => "center",
      y     => "center",
      z     => 1000,
      can_events => 1,
      can_focus  => 1,
      has_close_button => 1,
      on_delete => sub {
         $done->(0);
         1
      },
      on_focus_out => sub {
         $done->(0);
         1
      },
   ;

   $window->add (my $vb = new CFPlus::UI::VBox);

   $vb->add (new CFPlus::UI::Label
      text => "To bind the macro to a key,\n"
            . "press a modifier (Ctrl, Alt\n"
            . "and/or Shift) and a key, or\n"
            . "0-9 and F1-F15 without any modifier\n\n"
            . "To cancel press Escape or close this.\n\n"
            . "Accelerator key combo:",
      ellipsise  => 0,
   );

   $vb->add (my $entry = new CFPlus::UI::Label
      fg => [0, 0, 0, 1],
      bg => [1, 1, 0, 1],
   );

   my $key_cb = sub {
      my (undef, $ev) = @_;

      my $mod = $ev->{cmod} & $MODIFIER_MASK;
      my $sym = $ev->{sym};

      if ($sym == 27) {
         $done->(0);
         return 1;
      }

      $entry->set_text (
         join "",
            map "$_-",
               grep $mod & $MODIFIER{$_},
                  keys %MODIFIER
      );

      return if $sym >= CFPlus::SDLK_MODIFIER_MIN
             && $sym <= CFPlus::SDLK_MODIFIER_MAX;

      if ($mod
          || ((grep $_ eq chr $ev->{unicode}, @DIRECT_CHARS)
               || (grep $_ == $sym, @DIRECT_KEYS)))
      {
         $macro->{accelkey} = [$mod, $sym];
         $done->(1);
      } else {
         $entry->set_text ("cannot bind " . (CFPlus::SDL_GetKeyName $sym) . " without modifier.");
      }
      1
   };

   $window->connect (key_up   => $key_cb);
   $window->connect (key_down => $key_cb);

   $window->grab_focus;
   $window->show;
}

sub find_default($) {
   my ($ev) = @_;

   for my $m (reverse grep $_, @{ $DEFAULT_KEYMAP->{K} }) {
      for (keys %$m) {
         if ($_ == ($ev->{mod} & $_)) {
            if (defined (my $cmd = $m->{$_}{$ev->{sym}})) {
               return $cmd;
            }
         }
      }
   }

   if (my $cmd = $DEFAULT_KEYMAP->{U}{$ev->{unicode}}) {
      return $cmd;
   }

   ()
}

# find macro by event
sub find($) {
   my ($ev) = @_;

   # try user-defined macros
   if (my @user =
      grep {
         if (my $key = $_->{accelkey}) {
            $key->[1] == $ev->{sym}
               && $key->[0] == ($ev->{mod} & $MODIFIER_MASK)
         } else {
            0
         }
      } @{ $::PROFILE->{macro} || [] }
   ) {
      return @user;
   }

   # now try default keymap
   if (defined (my $def = find_default $ev)) {
      return {
         action => [$def],
      };
   }

   ()
}

sub execute {
   my ($macro) = @_;

   for (@{ $macro->{action} }) {
      if (/^\!(\S+)\s?(.*)$/) {
         $MACRO_FUNCTION{$1}->($2)
            if exists $MACRO_FUNCTION{$1};
      } else {
         $::CONN->send_command ($_)
            if $::CONN;
      }
   }
}

sub keyboard_setup {
   my $kbd_setup = new CFPlus::UI::VBox;

   $kbd_setup->add (my $list = new CFPlus::UI::VBox);

   $list->add (new CFPlus::UI::FancyFrame
      label => "Options",
      child => (my $hb = new CFPlus::UI::HBox),
   );
   $hb->add (new CFPlus::UI::Label text => "only shift-up stops fire");
   $hb->add (new CFPlus::UI::CheckBox
      expand     => 1,
      state      => $::CFG->{shift_fire_stop},
      tooltip    => "If this checkbox is enabled you will stop fire only if you stop pressing shift.",
      on_changed => sub {
         my ($cbox, $value) = @_;
         $::CFG->{shift_fire_stop} = $value;
         0
      },
   );

   $list->add (new CFPlus::UI::FancyFrame
      label => "Macros",
      child => (my $macros = new CFPlus::UI::VBox),
   );

   my $refresh;

   my $tooltip_common = "\n\n<small>Left click - edit macro\nMiddle click - invoke macro\nRight click - further options</small>";
   my $tooltip_trigger = "The event that triggers execution of this macro, usually a key combination.";
   my $tooltip_commands = "The commands that comprise the macro.";

   my $edit_macro = sub {
      my ($macro) = @_;

      $kbd_setup->clear;
      $kbd_setup->add (new CFPlus::UI::Button
         text    => "Return",
         tooltip => "Return to the macro list.",
         on_activate => sub {
            $kbd_setup->clear;
            $kbd_setup->add ($list);
            $refresh->();
            1
         },
      );
      $kbd_setup->add (new CFPlus::UI::FancyFrame
         label => "Edit Macro",
         child => (my $editor = new CFPlus::UI::Table col_expand => [0, 1]),
      );

      $editor->add_at (0, 1, new CFPlus::UI::Label
         text    => "Trigger",
         tooltip => $tooltip_trigger,
         can_hover  => 1,
         can_events => 1,
      );
      $editor->add_at (0, 2, new CFPlus::UI::Label
         text    => "Actions",
         tooltip => $tooltip_commands,
         can_hover  => 1,
         can_events => 1,
      );

      $editor->add_at (1, 2, my $textedit = new CFPlus::UI::TextEdit
         text    => macro_to_text $macro,
         tooltip => $tooltip_commands,
         on_changed => sub {
            $macro->{action} = macro_from_text $macro, $_[1];
         },
      );

      $editor->add_at (1, 1, my $accel = new CFPlus::UI::Button
         text    => trigger_to_string $macro,
         tooltip => "To change the trigger for a macro, activate this button.",
         on_activate => sub {
            my ($accel) = @_;
            trigger_edit $macro, sub {
               $accel->set_text (trigger_to_string $macro);
            };
            1
         },
      );

      my $recording;
      $editor->add_at (1, 3, new CFPlus::UI::Button
         text    => "Start Recording",
         tooltip => "Start/Stop command recording: when recording, "
                  . "actions and commands you invoke are appended to this macro. "
                  . "You can only record when you are logged in.",
         on_destroy  => sub {
            $::CONN->record if $::CONN;
         },
         on_activate => sub {
            my ($widget) = @_;

            $recording = $::CONN && !$recording;
            if ($recording) {
               $widget->set_text ("Stop Recording");
               $::CONN->record (sub {
                  push @{ $macro->{action} }, $_[0];
                  $textedit->set_text (macro_to_text $macro);
               }) if $::CONN;
            } else {
               $widget->set_text ("Start Recording");
               $::CONN->record if $::CONN;
            }
         },
      );
   };

   $macros->add (new CFPlus::UI::Button
      text    => "New Macro",
      tooltip => "Creates a new, empty, macro you can edit.",
      on_activate => sub {
         my $macro = { };
         push @{ $::PROFILE->{macro} }, $macro;
         $edit_macro->($macro);
      },
   );

   $macros->add (my $macrolist = new CFPlus::UI::Table col_expand => [0, 1]);

   $REFRESH_MACRO_LIST = $refresh = sub {
      $macrolist->clear;

      $macrolist->add_at (0, 1, new CFPlus::UI::Label
         text    => "Trigger",
         align   => 0,
         tooltip => $tooltip_trigger . $tooltip_common,
      );
      $macrolist->add_at (1, 1, new CFPlus::UI::Label
         text    => "Commands",
         tooltip => $tooltip_commands . $tooltip_common,
      );

      for my $idx (0 .. $#{$::PROFILE->{macro} || []}) {
         my $macro = $::PROFILE->{macro}[$idx];
         my $y = $idx + 2;

         my $macro_cb = sub {
            my ($widget, $ev) = @_;

            if ($ev->{button} == 1) {
               $edit_macro->($macro),
            } elsif ($ev->{button} == 2) {
               $::CONN->macro_send ($macro) if $::CONN;
            } elsif ($ev->{button} == 3) {
               (new CFPlus::UI::Menu
                  items => [
                     ["Edit"   => sub { $edit_macro->($macro) }],
                     ["Invoke" => sub { $::CONN->macro_send ($macro) if $::CONN }],
                     ["Delete" => sub { 
                        # might want to use grep instead
                        splice @{$::PROFILE->{macro}}, $idx, 1, ();
                        $refresh->();
                     }],
                  ],
               )->popup ($ev);
            } else {
               return 0;
            }

            1
         };

         $macrolist->add_at (0, $y, new CFPlus::UI::Label
            text       => trigger_to_string $macro,
            tooltip    => $tooltip_trigger . $tooltip_common,
            align      => 0,
            can_hover  => 1,
            can_events => 1,
            on_button_down => $macro_cb,
         );

         $macrolist->add_at (1, $y, new CFPlus::UI::Label
            text       => (join "; ", @{ $macro->{action} || [] }),
            tooltip    => $tooltip_commands . $tooltip_common,
            expand     => 1,
            ellipsise  => 3,
            can_hover  => 1,
            can_events => 1,
            on_button_down => $macro_cb,
         );
      }
   };

   $refresh->();

   $kbd_setup
}

# this is a shortcut method that asks for a binding
# and then just binds it.
sub quick_macro {
   my ($cmds, $end_cb) = @_;

   my $macro = {
      action => $cmds,
   };

   trigger_edit $macro, sub {
      if ($_[0]) {
         push @{ $::PROFILE->{macro} }, $macro;
         $REFRESH_MACRO_LIST->();
      }

      &$end_cb if $end_cb;
   };
}

1
