package CFPlus::UI::SpellList;

use strict;
use utf8;

use CFPlus::Macro;

our @ISA = CFPlus::UI::Table::;

sub new {
   my $class = shift;

   my $self = $class->SUPER::new (
      binding  => [],
      commands => [],
      @_,
   )
}

my $TOOLTIP_ALL = "\n\n<small>Left click - ready spell\nMiddle click - invoke spell\nRight click - further options</small>";

my @TOOLTIP_NAME = (align => -1, can_events => 1, can_hover => 1, tooltip =>
   "<b>Name</b>. The name of the spell.$TOOLTIP_ALL");
my @TOOLTIP_SKILL = (align => -1, can_events => 1, can_hover => 1, tooltip =>
   "<b>Skill</b>. The skill (or magic school) required to be able to attempt casting this spell.$TOOLTIP_ALL");
my @TOOLTIP_LVL = (align => 1, can_events => 1, can_hover => 1, tooltip =>
   "<b>Level</b>. Minimum level the caster needs in the associated skill to be able to attempt casting this spell.$TOOLTIP_ALL");
my @TOOLTIP_SP  = (align => 1, can_events => 1, can_hover => 1, tooltip =>
   "<b>Spell points / Grace points</b>. Amount of spell or grace points used by each invocation.$TOOLTIP_ALL");
my @TOOLTIP_DMG = (align => 1, can_events => 1, can_hover => 1, tooltip =>
   "<b>Damage</b>. The amount of damage the spell deals when it hits.$TOOLTIP_ALL");

sub rebuild_spell_list {
   my ($self) = @_;

   $CFPlus::UI::ROOT->on_refresh ($self => sub {
      $self->clear;

      return unless $::CONN;

      my @add;

      push @add,
         1, 0, (new CFPlus::UI::Label text => "Spell Name", @TOOLTIP_NAME),
         2, 0, (new CFPlus::UI::Label text => "Skill", @TOOLTIP_SKILL),
         3, 0, (new CFPlus::UI::Label text => "Lvl"  , @TOOLTIP_LVL),
         4, 0, (new CFPlus::UI::Label text => "Sp/Gp", @TOOLTIP_SP),
         5, 0, (new CFPlus::UI::Label text => "Dmg"  , @TOOLTIP_DMG),
      ;

      my $row = 0;

      for (sort { $a cmp $b } keys %{ $self->{spell} }) {
         my $spell = $self->{spell}{$_};

         $row++;

         my $spell_cb = sub {
            my ($widget, $ev) = @_;

            if ($ev->{button} == 1) {
               $::CONN->user_send ("cast $spell->{name}");
            } elsif ($ev->{button} == 2) {
               $::CONN->user_send ("invoke $spell->{name}");
            } elsif ($ev->{button} == 3) {
               my $shortname = CFPlus::shorten $spell->{name}, 14;
               (new CFPlus::UI::Menu
                  items => [
                     ["bind <i>cast $shortname</i> to a key"   => sub { CFPlus::Macro::quick_macro ["cast $spell->{name}"] }],
                     ["bind <i>invoke $shortname</i> to a key" => sub { CFPlus::Macro::quick_macro ["invoke $spell->{name}"] }],
                  ],
               )->popup ($ev);
            } else {
               return 0;
            }

            1
         };

         my $tooltip = (CFPlus::asxml $spell->{message}) . $TOOLTIP_ALL;

         #TODO: add path info to tooltip
         #push @add, 6, $row, new CFPlus::UI::Label text => $spell->{path};

         push @add, 0, $row, new CFPlus::UI::Face
            face       => $spell->{face},
            can_hover  => 1,
            can_events => 1,
            tooltip    => $tooltip,
            on_button_down => $spell_cb,
         ;

         push @add, 1, $row, new CFPlus::UI::Label
            expand     => 1,
            text       => $spell->{name},
            can_hover  => 1,
            can_events => 1,
            tooltip    => $tooltip,
            on_button_down => $spell_cb,
         ;

         push @add,
            2, $row, (new CFPlus::UI::Label text => $::CONN->{skill_info}{$spell->{skill}}, @TOOLTIP_SKILL),
            3, $row, (new CFPlus::UI::Label text => $spell->{level}, @TOOLTIP_LVL),
            4, $row, (new CFPlus::UI::Label text => $spell->{mana} || $spell->{grace}, @TOOLTIP_SP),
            5, $row, (new CFPlus::UI::Label text => $spell->{damage}, @TOOLTIP_DMG),
         ;
      }

      $self->add_at (@add);
   });
}

sub add_spell {
   my ($self, $spell) = @_;

   $self->{spell}->{$spell->{name}} = $spell;
   $self->rebuild_spell_list;
}

sub remove_spell {
   my ($self, $spell) = @_;

   delete $self->{spell}->{$spell->{name}};
   $self->rebuild_spell_list;
}

sub clear_spells {
   my ($self) = @_;

   $self->{spell} = {};
   $self->rebuild_spell_list;
}

1

