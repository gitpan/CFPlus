package CFPlus::BindingEditor;

use strict;

use CFPlus::UI;

our @ISA = CFPlus::UI::Toplevel::;

my @ALLOWED_MODIFIER_KEYS = (
   CFPlus::SDLK_LSHIFT,
   CFPlus::SDLK_LCTRL ,
   CFPlus::SDLK_LALT  ,
   CFPlus::SDLK_LMETA ,

   CFPlus::SDLK_RSHIFT,
   CFPlus::SDLK_RCTRL ,
   CFPlus::SDLK_RALT  ,
   CFPlus::SDLK_RMETA ,
);

my %ALLOWED_MODIFIERS = (
   CFPlus::KMOD_LSHIFT => "LSHIFT",
   CFPlus::KMOD_LCTRL  => "LCTRL",
   CFPlus::KMOD_LALT   => "LALT",
   CFPlus::KMOD_LMETA  => "LMETA",

   CFPlus::KMOD_RSHIFT => "RSHIFT",
   CFPlus::KMOD_RCTRL  => "RCTRL",
   CFPlus::KMOD_RALT   => "RALT",
   CFPlus::KMOD_RMETA  => "RMETA",
);

my %DIRECT_BIND_CHARS = map { $_ => 1 } qw/0 1 2 3 4 5 6 7 8 9/;
my @DIRECT_BIND_KEYS = (
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

sub keycombo_to_name {
   my ($mod, $sym) = @_;

   my $mods = join '+',
                 map { $ALLOWED_MODIFIERS{$_} }
                    grep { ($_ + 0) & ($mod + 0) }
                       keys %ALLOWED_MODIFIERS;
   $mods .= "+" if $mods ne '';

   return $mods . CFPlus::SDL_GetKeyName ($sym);
}

sub new {
   my $class = shift;

   my $self = $class->SUPER::new (
      binding  => [],
      commands => [],
      title    => "Macro/Keybinding Recorder",
      @_
   );

   $self->add (my $vb = new CFPlus::UI::VBox);

   $vb->add ($self->{rec_btn} = new CFPlus::UI::Button
      text => "start recording",
      tooltip => "Start/Stops recording of actions."
                ."All subsequent actions after the recording started will be captured."
                ."The actions are displayed after the record was stopped."
                ."To bind the action you have to click on the 'Bind' button",
      on_activate => sub {
         unless ($self->{recording}) {
            $self->start;
         } else {
            $self->stop;
         }
      });

   $vb->add (new CFPlus::UI::Label text => "Actions:");
   $vb->add ($self->{cmdbox} = new CFPlus::UI::VBox);

   $vb->add (new CFPlus::UI::Label text => "Bound to: ");
   $vb->add (my $hb = new CFPlus::UI::HBox);
   $hb->add ($self->{keylbl} = new CFPlus::UI::Label expand => 1);
   $hb->add (new CFPlus::UI::Button
      text => "bind",
      tooltip => "This opens a query where you have to press the key combination to bind the recorded actions",
      on_activate => sub {
         $self->ask_for_bind;
      });

   $vb->add (my $hb = new CFPlus::UI::HBox);
   $hb->add (new CFPlus::UI::Button
      text => "OK",
      expand => 1,
      tooltip => "This closes the binding editor and saves the binding",
      on_activate => sub {
         (delete $self->{binder})->destroy if $self->{binder};
         $self->hide;
         $self->commit;
         0
      });

   $hb->add (new CFPlus::UI::Button
      text => "Cancel",
      expand => 1,
      tooltip => "This closes the binding editor without saving",
      on_activate => sub {
         (delete $self->{binder})->destroy if $self->{binder};
         $self->hide;
         $self->{binding_cancel}->()
            if $self->{binding_cancel};
         0
      });

   $self->update_binding_widgets;

   $self
}

sub cfg_bind {
   my ($self, $mod, $sym, $cmds) = @_;
   $::CFG->{profile}{default}{bindings}{$mod}{$sym} = $cmds;
   ::update_bindings ();
}

sub cfg_unbind {
   my ($self, $mod, $sym, $cmds) = @_;
   delete $::CFG->{profile}{default}{bindings}{$mod}{$sym};
   ::update_bindings ();
}

sub commit {
   my ($self) = @_;

   my ($mod, $sym, $cmds) = $self->get_binding;

   if ($sym != 0 && @$cmds > 0) {
      $::STATUSBOX->add ("Bound actions to <i>" . keycombo_to_name ($mod, $sym) . "</i>. "
                       . "Do not forget to 'Save Config'!");
      $self->{binding_change}->($mod, $sym, $cmds)
         if $self->{binding_change};
   } else {
      $::STATUSBOX->add ("No action bound, no key or action specified!");
      $self->{binding_cancel}->()
         if $self->{binding_cancel};
   }
}

sub start {
   my ($self) = @_;

   $self->{rec_btn}->set_text ("stop recording");
   $self->{recording} = 1;
   $self->clear_command_list;
   $::CONN->start_record if $::CONN;
}

sub stop {
   my ($self) = @_;

   $self->{rec_btn}->set_text ("start recording");
   $self->{recording} = 0;

   my $rec;
   $rec = $::CONN->stop_record if $::CONN;
   return unless ref $rec eq 'ARRAY';
   $self->set_command_list ($rec);
}

sub ask_for_bind {
   my ($self, $commit, $end_cb) = @_;

   return if $self->{binder};

   Scalar::Util::weaken $self;

   $self->{binder} = new CFPlus::UI::Toplevel
      title => "Bind Action",
      x     => "center",
      y     => "center",
      z     => 1000,
      has_close_button => 1,
      on_delete => sub {
         (delete $self->{binder})->destroy;
         1
      },
   ;

   $self->{binder}->add (my $vb = new CFPlus::UI::VBox);
   $vb->add (new CFPlus::UI::Label
      text => "Press a modifier (CTRL, ALT and/or SHIFT) and a key."
            . "You can only bind 0-9 and F1-F15 without modifiers."
   );
   $vb->add (my $entry = new CFPlus::UI::Entry
      text => "",
      on_key_down => sub {
         my ($entry, $ev) = @_;

         my $mod = $ev->{mod};
         my $sym = $ev->{sym};

         # XXX: This seems a little bit hackisch to me, but I have to ignore them
         return if grep { $_ == $sym } @ALLOWED_MODIFIER_KEYS;

         if ($mod == CFPlus::KMOD_NONE
             and not $DIRECT_BIND_CHARS{chr ($ev->{unicode})}
             and not grep { $sym == $_ } @DIRECT_BIND_KEYS)
         {
            $::STATUSBOX->add (
               "Cannot bind key " . CFPlus::SDL_GetKeyName ($sym) . " directly without modifier, "
             . "as those keys are reserved for the command completer."
            );
            return;
         }

         $entry->grab_focus;

         $self->{binding} = [$mod, $sym];
         $self->update_binding_widgets;
         $self->commit if $commit;
         $end_cb->() if $end_cb;

         (delete $self->{binder})->destroy;
         1
      },
      on_focus_out => sub {
         # segfaults and worse :()
         #(delete $self->{binder})->destroy if $self->{binder};
         1
      },
   );

   $entry->grab_focus;
   $self->{binder}->show;
}

# $mod and $sym are the modifiers and key symbol
# $cmds is a array ref of strings (the commands)
# $cb is the callback that is executed on OK
# $ccb is the callback that is executed on CANCEL and 
# when the binding was unsuccessful on OK
sub set_binding {
   my ($self, $mod, $sym, $cmds, $cb, $ccb) = @_;

   $self->clear_command_list;
   $self->{recording} = 0;
   $self->{rec_btn}->set_text ("start recording");

   $self->{binding} = [$mod, $sym];
   $self->{commands} = $cmds;

   $self->{binding_change} = $cb;
   $self->{binding_cancel} = $ccb;

   $self->update_binding_widgets;
}

# this is a shortcut method that asks for a binding
# and then just binds it.
sub do_quick_binding {
   my ($self, $cmds, $end_cb) = @_;
   $self->set_binding (undef, undef, $cmds, sub { $self->cfg_bind (@_) });
   $self->ask_for_bind (1, $end_cb);
}

sub update_binding_widgets {
   my ($self) = @_;
   my ($mod, $sym, $cmds) = $self->get_binding;
   $self->{keylbl}->set_text (keycombo_to_name ($mod, $sym));
   $self->set_command_list ($cmds);
}

sub get_binding {
   my ($self) = @_;
   return (
      $self->{binding}->[0],
      $self->{binding}->[1],
      [ grep { defined $_ } @{$self->{commands}} ]
   );
}

sub clear_command_list {
   my ($self) = @_;
   $self->{cmdbox}->clear ();
}

sub set_command_list {
   my ($self, $cmds) = @_;

   $self->{cmdbox}->clear ();
   $self->{commands} = $cmds;

   my $idx = 0;

   for (@$cmds) {
      $self->{cmdbox}->add (my $hb = new CFPlus::UI::HBox);

      my $i = $idx;
      $hb->add (new CFPlus::UI::Label text => $_);
      $hb->add (new CFPlus::UI::Button
         text => "delete",
         tooltip => "Deletes the action from the record",
         on_activate => sub {
            $self->{cmdbox}->remove ($hb);
            $cmds->[$i] = undef;
         });


      $idx++
   }
}

1
