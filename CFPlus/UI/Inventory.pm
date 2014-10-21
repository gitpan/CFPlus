package CFPlus::UI::Inventory;

use strict;
use utf8;

use CFPlus::Macro;
use CFPlus::Item;

our @ISA = CFPlus::UI::Table::;

sub new {
   my $class = shift;

   my $self = $class->SUPER::new (
      col_expand => [0, 1, 0],
      items      => [],
      @_,
   );

   $self->set_sort_order (undef);

   $self
}

sub update_items {
   my ($self) = @_;

   $self->clear;

   my @item = $self->{sort}->(@{ $self->{items} });

   my @adds;
   my $row = 0;
   for my $item ($self->{sort}->(@{ $self->{items} })) {
      CFPlus::Item::update_widgets $item;

      push @adds, 0, $row, $item->{face_widget};
      push @adds, 1, $row, $item->{desc_widget};
      push @adds, 2, $row, $item->{weight_widget};

      $row++;
   }

   $self->add (@adds);
}

sub set_sort_order {
   my ($self, $order) = @_;

   $self->{sort} = $order ||= sub {
      sort {
         $a->{type} <=> $b->{type}
            or $a->{name} cmp $b->{name}
      } @_
   };

   $self->update_items;
}

sub set_items {
   my ($self, $items) = @_;

   $self->{items} = [$items ? values %$items : ()];
   $self->update_items;
}

