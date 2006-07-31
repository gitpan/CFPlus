=head1 NAME

CFPlus - undocumented utility garbage for our crossfire client

=head1 SYNOPSIS

 use CFPlus;

=head1 DESCRIPTION

=over 4

=cut

package CFPlus;

BEGIN {
   $VERSION = '0.2';

   use XSLoader;
   XSLoader::load "CFPlus", $VERSION;
}

use utf8;

use Carp ();
use AnyEvent ();
use BerkeleyDB;
use Pod::POM ();
use Scalar::Util ();
use Storable (); # finally

our %STAT_TOOLTIP = (
   Str => "<b>Physical Strength</b>, determines damage dealt with weapons, how much you can carry, and how often you can attack",
   Dex => "<b>Dexterity</b>, your physical agility. Determines chance of being hit and affects armor class and speed",
   Con => "<b>Constitution</b>, physical health and toughness. Determines how many healthpoints you can have",
   Int => "<b>Intelligence</b>, your ability to learn and use skills and incantations (both prayers and magic) and determines how much spell points you can have",
   Wis => "<b>Wisdom</b>, the ability to learn and use divine magic (prayers). Determines how many grace points you can have",
   Pow => "<b>Power</b>, your magical potential. Influences the strength of spell effects, and also how much your spell and grace points increase when leveling up",
   Cha => "<b>Charisma</b>, how well you are received by NPCs. Affects buying and selling prices in shops.",

   Wc  => "<b>Weapon Class</b>, effectiveness of melee/missile attacks. Lower is more potent. Current weapon, level and Str are some things which effect the value of Wc. The value of Wc may range between 25 and -72.",
   Ac  => "<b>Armour Class</b>, how protected you are from being hit by any attack. Lower values are better. Ac is based on your race and is modified by the Dex and current armour worn. For characters that cannot wear armour, Ac improves as their level increases.",
   Dam => "<b>Damage</b>, how much damage your melee/missile attack inflicts. Higher values indicate a greater amount of damage will be inflicted with each attack.",
   Arm => "<b>Armour</b>, how much damage (from physical attacks) will be subtracted from successful hits made upon you. This value ranges between 0 to 99%. Current armour worn primarily determines Arm value. This is the same as the physical resistance.",
   Spd => "<b>Speed</b>, how fast you can move. The value of speed may range between nearly 0 (\"very slow\") to higher than 5 (\"lightning fast\"). Base speed is determined from the Dex and modified downward proportionally by the amount of weight carried which exceeds the Max Carry limit. The armour worn also sets the upper limit on speed.",
   WSp => "<b>Weapon Speed</b>, how many attacks you may make per unit of time (0.120s). Higher values indicate faster attack speed. Current weapon and Dex effect the value of weapon speed.",
);

=item guard { BLOCK }

Returns an object that executes the given block as soon as it is destroyed.

=cut

sub guard(&) {
   bless \(my $cb = $_[0]), "CFPlus::Guard"
}

sub CFPlus::Guard::DESTROY {
   ${$_[0]}->()
}

sub asxml($) {
   local $_ = $_[0];

   s/&/&amp;/g;
   s/>/&gt;/g;
   s/</&lt;/g;

   $_
}

package CFPlus::Database;

our @ISA = BerkeleyDB::Btree::;

sub get($$) {
   my $data;

   $_[0]->db_get ($_[1], $data) == 0
      ? $data
      : ()
}

my %DB_SYNC;

sub put($$$) {
   my ($db, $key, $data) = @_;

   $DB_SYNC{$db} = AnyEvent->timer (after => 5, cb => sub { $db->db_sync });

   $db->db_put ($key => $data)
}

package CFPlus;

sub find_rcfile($) {
   my $path;

   for (grep !ref, @INC) {
      $path = "$_/CFPlus/resources/$_[0]";
      return $path if -r $path;
   }

   die "FATAL: can't find required file $_[0]\n";
}

BEGIN {
   use Crossfire::Protocol::Base ();
   *to_json   = \&Crossfire::Protocol::Base::to_json;
   *from_json = \&Crossfire::Protocol::Base::from_json;
}

sub read_cfg {
   my ($file) = @_;

   open my $fh, $file
      or return;

   local $/;
   my $CFG = <$fh>;

   if ($CFG =~ /^---/) { ## TODO compatibility cruft, remove
      require YAML;
      utf8::decode $CFG;
      $::CFG = YAML::Load ($CFG);
   } elsif ($CFG =~ /^\{/) {
      $::CFG = from_json $CFG;
   } else {
      $::CFG = eval $CFG; ## todo comaptibility cruft
   }
}

sub write_cfg {
   my ($file) = @_;

   $::CFG->{VERSION} = $::VERSION;

   open my $fh, ">:utf8", $file
      or return;
   print $fh to_json $::CFG;
}

our $DB_ENV;

{
   use strict;

   mkdir "$Crossfire::VARDIR/cfplus", 0777;
   my $recover = $BerkeleyDB::db_version >= 4.4 
                 ? eval "DB_REGISTER | DB_RECOVER"
                 : 0;

   $DB_ENV = new BerkeleyDB::Env
                    -Home => "$Crossfire::VARDIR/cfplus",
                    -Cachesize => 1_000_000,
                    -ErrFile => "$Crossfire::VARDIR/cfplus/errorlog.txt",
#                 -ErrPrefix => "DATABASE",
                    -Verbose => 1,
                    -Flags => DB_CREATE | DB_RECOVER | DB_INIT_MPOOL | DB_INIT_LOCK | DB_INIT_TXN | $recover,
                    -SetFlags => DB_AUTO_COMMIT | DB_LOG_AUTOREMOVE,
                       or die "unable to create/open database home $Crossfire::VARDIR/cfplus: $BerkeleyDB::Error";
}

sub db_table($) {
   my ($table) = @_;

   $table =~ s/([^a-zA-Z0-9_\-])/sprintf "=%x=", ord $1/ge;

   new CFPlus::Database
      -Env      => $DB_ENV,
      -Filename => $table,
#      -Filename => "database",
#      -Subname  => $table,
      -Property => DB_CHKSUM,
      -Flags    => DB_CREATE | DB_UPGRADE,
         or die "unable to create/open database table $_[0]: $BerkeleyDB::Error"
}

package CFPlus::Layout;

$CFPlus::OpenGL::SHUTDOWN_HOOK{"CFPlus::Layout"} = sub {
   reset_glyph_cache;
};

package CFPlus::Item;

use strict;
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

   my $w = new CFPlus::UI::FancyFrame
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
   Scalar::Util::weaken $self;

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
                     $::CONN->send ("command use_skill inscription $txt");
                  });
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
         );

         CFPlus::UI::Menu->new (items => \@menu_items)->popup ($ev);
      }

      1
   };

   my $tooltip_std = "<small>"
                   . "Left click - examine item\n"
                   . "Shift-Left click - " . ($self->{container} ? "move or drop" : "take") . " item\n"
                   . "Middle click - apply\n"
                   . "Shift-Middle click - lock/unlock\n"
                   . "Right click - further options"
                   . "</small>\n";

   my $bg = $self->{flags} & F_CURSED ? [1  , 0  , 0, 0.5]
          : $self->{flags} & F_MAGIC  ? [0.2, 0.2, 1, 0.5]
          : undef;

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
   $self->{face_widget}->set_tooltip (
      "<b>Face/Animation.</b>\n"
    . "Item uses face #$self->{face}. "
    . ($self->{animspeed} ? "Item uses animation #$self->{anim} at " . (1 / $self->{animspeed}) . "fps. " : "Item is not animated. ")
    . "\n\n$tooltip_std"
   );
   
   $self->{desc_widget} ||= new CFPlus::UI::Label
      can_events => 1,
      can_hover  => 1,
      ellipsise  => 2,
      align      => -1,
      on_button_down => $button_cb,
   ;
   my $desc = CFPlus::Item::desc_string $self;
   $self->{desc_widget}{bg} = $bg;
   $self->{desc_widget}->set_text ($desc);
   $self->{desc_widget}->set_tooltip ("<b>$desc</b>.\n$tooltip_std");

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

1;

=back

=head1 AUTHOR

 Marc Lehmann <schmorp@schmorp.de>
 http://home.schmorp.de/

=cut

