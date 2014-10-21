package CFPlus::Item;

use strict;
use utf8;
use Encode;

use Crossfire::Protocol::Constants;

my $last_enter_count = 1;

sub desc_string {
   my ($self) = @_;

   my $desc =
      $self->{nrof} < 2
         ? $self->{name}
         : "$self->{nrof} × $self->{name_pl}";

   $self->{flags} & F_OPEN
      and $desc .= " (open)";
   $self->{flags} & F_APPLIED
      and $desc .= " (applied)";
   $self->{flags} & F_UNPAID
      and $desc .= " (unpaid)";
   $self->{flags} & F_MAGIC
      and $desc .= " (magic)";
   $self->{flags} & F_CURSED
      and $desc .= " (cursed)";
   $self->{flags} & F_DAMNED
      and $desc .= " (damned)";
   $self->{flags} & F_LOCKED
      and $desc .= " *";

   $desc
}

sub weight_string {
   my ($self) = @_;

   my $weight = ($self->{nrof} || 1) * $self->{weight};

   $weight < 0 ? "?" : $weight * 0.001
}

sub do_n_dialog {
   my ($cb) = @_;

   my $w = new CFPlus::UI::Toplevel
      on_delete => sub { $_[0]->destroy; 1 },
      has_close_button => 1,
   ;

   $w->add (my $vb = new CFPlus::UI::VBox x => "center", y => "center");
   $vb->add (new CFPlus::UI::Label text => "Enter item count:");
   $vb->add (my $entry = new CFPlus::UI::Entry
      text => $last_enter_count,
      on_activate => sub {
         my ($entry) = @_;
         $last_enter_count = $entry->get_text;
         $cb->($last_enter_count);
         $w->hide;
         $w->destroy;

         0
      },
      on_escape => sub { $w->destroy; 1 },
   );
   $entry->grab_focus;
   $w->show;
}

sub update_widgets {
   my ($self) = @_;

   # necessary to avoid cyclic references
   CFPlus::weaken $self;

   my $button_cb = sub {
      my (undef, $ev, $x, $y) = @_;

      my $targ = $::CONN->{player}{tag};

      if ($self->{container} == $::CONN->{player}{tag}) {
         $targ = $::CONN->{open_container};
      }

      if (($ev->{mod} & CFPlus::KMOD_SHIFT) && $ev->{button} == 1) {
         $::CONN->send ("move $targ $self->{tag} 0")
            if $targ || !($self->{flags} & F_LOCKED);
      } elsif (($ev->{mod} & CFPlus::KMOD_SHIFT) && $ev->{button} == 2) {
         $self->{flags} & F_LOCKED
            ? $::CONN->send ("lock " . pack "CN", 0, $self->{tag})
            : $::CONN->send ("lock " . pack "CN", 1, $self->{tag})
      } elsif ($ev->{button} == 1) {
         $::CONN->send ("examine $self->{tag}");
      } elsif ($ev->{button} == 2) {
         $::CONN->send ("apply $self->{tag}");
      } elsif ($ev->{button} == 3) {
         my $move_prefix = $::CONN->{open_container} ? 'put' : 'drop';
         if ($self->{container} == $::CONN->{open_container}) {
            $move_prefix = "take";
         }

         my $shortname = CFPlus::shorten $self->{name}, 14;

         my @menu_items = (
            ["examine", sub { $::CONN->send ("examine $self->{tag}") }],
            ["mark",    sub { $::CONN->send ("mark ". pack "N", $self->{tag}) }],
            ["ignite/thaw",  # first try of an easier use of flint&steel
               sub {
                  $::CONN->send ("mark ". pack "N", $self->{tag});
                  $::CONN->send ("command apply flint and steel");
               }
            ],
            ["inscribe",  # first try of an easier use of flint&steel
               sub {
                  &::open_string_query ("Text to inscribe", sub {
                     my ($entry, $txt) = @_;
                     $::CONN->send ("mark ". pack "N", $self->{tag});
                     $::CONN->send_utf8 ("command use_skill inscription $txt");
                  });
               }
            ],
            ["rename",  # first try of an easier use of flint&steel
               sub {
                  &::open_string_query ("Rename item to:", sub {
                     my ($entry, $txt) = @_;
                     $::CONN->send ("mark ". pack "N", $self->{tag});
                     $::CONN->send_utf8 ("command rename to <$txt>");
                  }, $self->{name},
                  "If you input no name or erase the current custom name, the custom name will be unset");
               }
            ],
            ["apply",   sub { $::CONN->send ("apply $self->{tag}") }],
            (
               $self->{flags} & F_LOCKED
               ? (
                  ["unlock", sub { $::CONN->send ("lock " . pack "CN", 0, $self->{tag}) }],
                 )
               : (
                  ["lock",   sub { $::CONN->send ("lock " . pack "CN", 1, $self->{tag}) }],
                  ["$move_prefix all",   sub { $::CONN->send ("move $targ $self->{tag} 0") }],
                  ["$move_prefix &lt;n&gt;", 
                     sub {
                        do_n_dialog (sub { $::CONN->send ("move $targ $self->{tag} $_[0]") })
                     }
                  ]
               )
            ),
            ["bind <i>apply $shortname</i> to a key"   => sub { CFPlus::Macro::quick_macro ["apply $self->{name}"] }],
         );

         CFPlus::UI::Menu->new (items => \@menu_items)->popup ($ev);
      }

      1
   };

   my $tooltip_std =
      "<small>"
      . "Left click - examine item\n"
      . "Shift-Left click - " . ($self->{container} ? "move or drop" : "take") . " item\n"
      . "Middle click - apply\n"
      . "Shift-Middle click - lock/unlock\n"
      . "Right click - further options"
      . "</small>\n";

   my $bg = $self->{flags} & F_CURSED ? [1  , 0  , 0, 0.5]
          : $self->{flags} & F_MAGIC  ? [0.2, 0.2, 1, 0.5]
          : undef;

   my $desc = CFPlus::Item::desc_string $self;

   $self->{face_widget} ||= new CFPlus::UI::Face 
      can_events => 1,
      can_hover  => 1,
      anim       => $self->{anim},
      animspeed  => $self->{animspeed}, # TODO# must be set at creation time
      on_button_down => $button_cb,
   ;
   $self->{face_widget}{bg}        = $bg;
   $self->{face_widget}{face}      = $self->{face};
   $self->{face_widget}{anim}      = $self->{anim};
   $self->{face_widget}{animspeed} = $self->{animspeed};
#   $self->{face_widget}->set_tooltip (
#      "<b>Face/Animation.</b>\n"
#    . "Item uses face #$self->{face}. "
#    . ($self->{animspeed} ? "Item uses animation #$self->{anim} at " . (1 / $self->{animspeed}) . "fps. " : "Item is not animated. ")
#    . "\n\n$tooltip_std"
#   );
   $self->{face_widget}->set_tooltip ("<b>$desc</b>\n\n$tooltip_std");
   
   $self->{desc_widget} ||= new CFPlus::UI::Label
      can_events => 1,
      can_hover  => 1,
      ellipsise  => 2,
      align      => -1,

      on_button_down  => $button_cb,
      on_tooltip_show => sub {
         my ($widget) = @_;

         $::CONN && $::CONN->ex ($self->{tag}, sub {
            my ($long_desc) = @_;

            $long_desc =~ s/\s+$//;

            $self->{long_desc} = $long_desc;
            $widget->set_tooltip ("<b>$long_desc</b>\n\n$tooltip_std");
         });
      },
   ;

   $self->{desc_widget}{bg} = $bg;
   $self->{desc_widget}->set_text ($desc);

   my $long_desc = $self->{long_desc} || $desc;
   $self->{desc_widget}->set_tooltip ("<b>$long_desc</b>\n\n$tooltip_std");

   $self->{weight_widget} ||= new CFPlus::UI::Label
      can_events => 1,
      can_hover  => 1,
      ellipsise  => 0,
      align      => 0,
      on_button_down => $button_cb,
   ;
   $self->{weight_widget}{bg} = $bg;
   $self->{weight_widget}->set_text (CFPlus::Item::weight_string $self);
   $self->{weight_widget}->set_tooltip (
      "<b>Weight</b>.\n"
    . ($self->{weight} >= 0 ? "One item weighs $self->{weight}g. " : "You have no idea how much this weighs. ")
    . ($self->{nrof} ? "You have $self->{nrof} of it. " : "Item cannot stack with others of it's kind. ")
    . "\n\n$tooltip_std"
   );
}

