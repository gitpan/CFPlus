package CFPlus::UI::Dockable;

use strict;
use utf8;

our @ISA = CFPlus::UI::Bin::;

sub new {
   my $class = shift;

   my $self = $class->SUPER::new (
      title     => "unset",
      can_close => 1,
      @_,
   );

   $self
}

1
