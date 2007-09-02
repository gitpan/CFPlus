package CFPlus::UI::ChatView;

use strict;
use utf8;

our @ISA = CFPlus::UI::Dockable::;

sub new {
   my $class = shift;

   my $self = $class->SUPER::new (
      @_,
      can_close => 1,
      child     => (my $vbox = new CFPlus::UI::VBox),
   );

   $vbox->add ($self->{txt} = new CFPlus::UI::TextScroller (
      expand     => 1,
      font       => $::FONT_FIXED,
      fontsize   => $::CFG->{log_fontsize},
      indent     => -4,
      can_hover  => 1,
      can_events => 1,
      max_par    => $::CFG->{logview_max_par},
      tooltip    =>
         $self->{text_tooltip}
         || "<b>Server Log</b>. This text viewer contains all recent messages "
           ."sent by the server.",
   ));

   $vbox->add (my $hb = CFPlus::UI::HBox->new);

   if ($self->{say_command}) {
      $hb->add (CFPlus::UI::Label->new (markup => $self->{say_command}));
   }

   $hb->add ($self->{input} = CFPlus::UI::Entry->new (
      expand  => 1,
      tooltip =>
          $self->{entry_tooltip}
          || "<b>Command Entry</b>. If you enter something and press return/enter here, "
             . "the line you entered will be sent to the server as a command.",
      on_focus_in => sub {
         my ($input, $prev_focus) = @_;

         delete $input->{refocus_map};

         if ($prev_focus == $::MAPWIDGET && $input->{auto_activated}) {
            $input->{refocus_map} = 1;
         }
         delete $input->{auto_activated};

         0
      },
      on_activate => sub {
         my ($input, $text) = @_;
         $input->set_text ('');

         return unless $::CONN;

         if ($text =~ /^\/(.*)/) {
            $::CONN->user_send ($1);
         } elsif (length $text) {
            my $say_cmd = $self->{say_command};
            $::CONN->user_send ($say_cmd . $text);
         } else {
            $input->{refocus_map} = 1;
         }
         if (delete $input->{refocus_map}) {
            $::MAPWIDGET->grab_focus;
         }

         0
      },
      on_key_down => sub {
         my ($input, $ev) = @_;
         my $uni = $ev->{unicode};
         my $mod = $ev->{mod};

         if ($uni >= ord "0" && $uni <= ord "9" && $mod & CFPlus::KMOD_ALT) {
            $::MAPWIDGET->emit (key_down => $ev);
            return 1;
         }

         0
      },
      on_escape => sub {
         $::MAPWIDGET->grab_focus;

         0
      },
   ));

   $self
}

sub message {
   my ($self, $para) = @_;

   my $time = sprintf "%02d:%02d:%02d", (localtime time)[2,1,0];

   $para->{markup} = "<span foreground='#ffffff'>$time</span> $para->{markup}";

   my $txt = $self->{txt};
   $txt->add_paragraph ($para);
   $txt->scroll_to_bottom;
}

sub activate_console {
   my ($self, $preset) = @_;

   $self->{input}->{auto_activated} = 1;
   $self->{input}->grab_focus;

   if ($preset && $self->{input}->get_text eq '') {
      $self->{input}->set_text ($preset);
   }
}

sub set_fontsize {
   my ($self, $size) = @_;
   $self->{txt}->set_fontsize ($size);
}

sub set_max_para {
   my ($self, $max_par) = @_;
   $self->{txt}{max_par} = $max_par;
}

sub clear_log {
   my ($self) = @_;

   $self->{txt}->clear;
}

1
