package CFPlus::UI;

use utf8;
use strict;

use Scalar::Util ();
use List::Util ();
use Event;

use CFPlus;
use CFPlus::Texture;

our ($FOCUS, $HOVER, $GRAB); # various widgets

our $LAYOUT;
our $ROOT;
our $TOOLTIP;
our $BUTTON_STATE;

our %WIDGET; # all widgets, weak-referenced

our $TOOLTIP_WATCHER = Event->idle (min => 1/60, cb => sub {
   if (!$GRAB) {
      for (my $widget = $HOVER; $widget; $widget = $widget->{parent}) {
         if (length $widget->{tooltip}) {
            if ($TOOLTIP->{owner} != $widget) {
               $TOOLTIP->hide;

               $TOOLTIP->{owner} = $widget;

               return if $ENV{CFPLUS_DEBUG} & 8;

               my $tip = $widget->{tooltip};

               $tip = $tip->($widget) if CODE:: eq ref $tip;
               
               $TOOLTIP->set_tooltip_from ($widget);
               $TOOLTIP->show;
            }

            return;
         }
      }
   }

   $TOOLTIP->hide;
   delete $TOOLTIP->{owner};
});

sub get_layout {
   my $layout;

   for (grep { $_->{name} } values %WIDGET) {
      my $win = $layout->{$_->{name}} = { };
      
      $win->{x} = ($_->{x} + $_->{w} * 0.5) / $::WIDTH   if $_->{x} =~ /^[0-9.]+$/;
      $win->{y} = ($_->{y} + $_->{h} * 0.5) / $::HEIGHT  if $_->{y} =~ /^[0-9.]+$/;
      $win->{w} = $_->{w} / $::WIDTH                     if defined $_->{w};
      $win->{h} = $_->{h} / $::HEIGHT                    if defined $_->{h};

      $win->{show} = $_->{visible} && $_->{is_toplevel};
   }

   $layout
}

sub set_layout {
   my ($layout) = @_;

   $LAYOUT = $layout;
}

# class methods for events
sub feed_sdl_key_down_event { 
   $FOCUS->emit (key_down => $_[0])
      if $FOCUS;
}

sub feed_sdl_key_up_event {
   $FOCUS->emit (key_up => $_[0])
      if $FOCUS;
}

sub check_hover {
   my ($widget) = @_;

   if ($widget != $HOVER) {
      my $hover = $HOVER; $HOVER = $widget;

      $hover->update if $hover && $hover->{can_hover};
      $HOVER->update if $HOVER && $HOVER->{can_hover};

      $TOOLTIP_WATCHER->start;
   }
}

sub feed_sdl_button_down_event {
   my ($ev) = @_;
   my ($x, $y) = ($ev->{x}, $ev->{y});

   $BUTTON_STATE |= 1 << ($ev->{button} - 1);

   unless ($GRAB) {
      my $widget = $ROOT->find_widget ($x, $y);

      $GRAB = $widget;
      $GRAB->update if $GRAB;

      $TOOLTIP_WATCHER->cb->();
   }

   if ($GRAB) {
      if ($ev->{button} == 4 || $ev->{button} == 5) {
         # mousewheel
         $ev->{dx} = 0;
         $ev->{dy} = $ev->{button} * 2 - 9;
         $GRAB->emit (mouse_wheel => $ev);
      } else {
         $GRAB->emit (button_down => $ev)
      }
   }
}

sub feed_sdl_button_up_event {
   my ($ev) = @_;

   my $widget = $GRAB || $ROOT->find_widget ($ev->{x}, $ev->{y});

   $BUTTON_STATE &= ~(1 << ($ev->{button} - 1));

   $GRAB->emit (button_up => $ev)
      if $GRAB && $ev->{button} != 4 && $ev->{button} != 5;

   unless ($BUTTON_STATE) {
      my $grab = $GRAB; undef $GRAB;
      $grab->update if $grab;
      $GRAB->update if $GRAB;

      check_hover $widget;
      $TOOLTIP_WATCHER->cb->();
   }
}

sub feed_sdl_motion_event {
   my ($ev) = @_;
   my ($x, $y) = ($ev->{x}, $ev->{y});

   my $widget = $GRAB || $ROOT->find_widget ($x, $y);

   check_hover $widget;

   $HOVER->emit (mouse_motion => $ev)
      if $HOVER;
}

# convert position array to integers
sub harmonize {
   my ($vals) = @_;

   my $rem = 0;

   for (@$vals) {
      my $i = int $_ + $rem;
      $rem += $_ - $i;
      $_ = $i;
   }
}

sub full_refresh {
   # make a copy, otherwise for complains about freed values.
   my @widgets = values %WIDGET;

   $_->update
      for @widgets;
}

sub reconfigure_widgets {
   # make a copy, otherwise C<for> complains about freed values.
   my @widgets = values %WIDGET;

   $_->reconfigure
      for @widgets;
}

# call when resolution changes etc.
sub rescale_widgets {
   my ($sx, $sy) = @_;

   for my $widget (values %WIDGET) {
      if ($widget->{is_toplevel}) {
         $widget->{x} += int $widget->{w} * 0.5 if $widget->{x} =~ /^[0-9.]+$/;
         $widget->{y} += int $widget->{h} * 0.5 if $widget->{y} =~ /^[0-9.]+$/;

         $widget->{x}       = int 0.5 + $widget->{x}        * $sx if $widget->{x} =~ /^[0-9.]+$/;
         $widget->{w}       = int 0.5 + $widget->{w}        * $sx if exists $widget->{w};
         $widget->{force_w} = int 0.5 + $widget->{force_w}  * $sx if exists $widget->{force_w};
         $widget->{y}       = int 0.5 + $widget->{y}        * $sy if $widget->{y} =~ /^[0-9.]+$/;
         $widget->{h}       = int 0.5 + $widget->{h}        * $sy if exists $widget->{h};
         $widget->{force_h} = int 0.5 + $widget->{force_h}  * $sy if exists $widget->{force_h};

         $widget->{x} -= int $widget->{w} * 0.5 if $widget->{x} =~ /^[0-9.]+$/;
         $widget->{y} -= int $widget->{h} * 0.5 if $widget->{y} =~ /^[0-9.]+$/;

      }
   }

   reconfigure_widgets;
}

#############################################################################

package CFPlus::UI::Event;

sub xy {
   $_[1]->coord2local ($_[0]{x}, $_[0]{y})
}

#############################################################################

package CFPlus::UI::Base;

use strict;

use CFPlus::OpenGL;

sub new {
   my $class = shift;

   my $self = bless {
      x          => "center",
      y          => "center",
      z          => 0,
      w          => undef,
      h          => undef,
      can_events => 1,
      @_
   }, $class;

   Scalar::Util::weaken ($CFPlus::UI::WIDGET{$self+0} = $self);

   for (keys %$self) {
      if (/^on_(.*)$/) {
         $self->connect ($1 => delete $self->{$_});
      }
   }

   if (my $layout = $CFPlus::UI::LAYOUT->{$self->{name}}) {
      $self->{x}       = $layout->{x} * $CFPlus::UI::ROOT->{alloc_w} if exists $layout->{x};
      $self->{y}       = $layout->{y} * $CFPlus::UI::ROOT->{alloc_h} if exists $layout->{y};
      $self->{force_w} = $layout->{w} * $CFPlus::UI::ROOT->{alloc_w} if exists $layout->{w};
      $self->{force_h} = $layout->{h} * $CFPlus::UI::ROOT->{alloc_h} if exists $layout->{h};

      $self->{x} -= $self->{force_w} * 0.5 if exists $layout->{x};
      $self->{y} -= $self->{force_h} * 0.5 if exists $layout->{y};

      $self->show if $layout->{show};
   }

   $self
}

sub destroy {
   my ($self) = @_;

   $self->hide;
   %$self = ();
}

sub show {
   my ($self) = @_;

   return if $self->{parent};

   $CFPlus::UI::ROOT->add ($self);
}

sub set_visible {
   my ($self) = @_;

   return if $self->{visible};

   $self->{root}    = $self->{parent}{root};
   $self->{visible} = $self->{parent}{visible} + 1;

   $self->emit (visibility_change => 1);

   $self->realloc if !exists $self->{req_w};

   $_->set_visible for $self->children;
}

sub set_invisible {
   my ($self) = @_;

   return unless $self->{visible};

   $_->set_invisible for $self->children;

   delete $self->{visible};
   delete $self->{root};

   undef $GRAB  if $GRAB  == $self;
   undef $HOVER if $HOVER == $self;

   $CFPlus::UI::TOOLTIP_WATCHER->cb->()
      if $TOOLTIP->{owner} == $self;

   $self->emit ("focus_out");
   $self->emit (visibility_change => 0);
}

sub set_visibility {
   my ($self, $visible) = @_;

   return if $self->{visible} == $visible;

   $visible ? $self->hide
            : $self->show;
}

sub toggle_visibility {
   my ($self) = @_;

   $self->{visible}
      ? $self->hide
      : $self->show;
}

sub hide {
   my ($self) = @_;

   $self->set_invisible;

   $self->{parent}->remove ($self)
      if $self->{parent};
}

sub move_abs {
   my ($self, $x, $y, $z) = @_;

   $self->{x} = List::Util::max 0, List::Util::min $self->{root}{w} - $self->{w}, int $x;
   $self->{y} = List::Util::max 0, List::Util::min $self->{root}{h} - $self->{h}, int $y;
   $self->{z} = $z if defined $z;

   $self->update;
}

sub set_size {
   my ($self, $w, $h) = @_;

   $self->{force_w} = $w;
   $self->{force_h} = $h;

   $self->realloc;
}

sub size_request {
   require Carp;
   Carp::confess "size_request is abstract";
}

sub baseline_shift {
   0
}

sub configure {
   my ($self, $x, $y, $w, $h) = @_;

   if ($self->{aspect}) {
      my ($ow, $oh) = ($w, $h);

      $w = List::Util::min $w, CFPlus::ceil $h * $self->{aspect};
      $h = List::Util::min $h, CFPlus::ceil $w / $self->{aspect};

      # use alignment to adjust x, y

      $x += int 0.5 * ($ow - $w);
      $y += int 0.5 * ($oh - $h);
   }

   if ($self->{x} ne $x || $self->{y} ne $y) {
      $self->{x} = $x;
      $self->{y} = $y;
      $self->update;
   }

   if ($self->{alloc_w} != $w || $self->{alloc_h} != $h) {
      return unless $self->{visible};

      $self->{alloc_w} = $w;
      $self->{alloc_h} = $h;

      $self->{root}{size_alloc}{$self+0} = $self;
   }
}

sub children {
   # nop
}

sub visible_children {
   $_[0]->children
}

sub set_max_size {
   my ($self, $w, $h) = @_;

   $self->{max_w} = int $w if defined $w;
   $self->{max_h} = int $h if defined $h;

   $self->realloc;
}

sub set_tooltip {
   my ($self, $tooltip) = @_;

   $tooltip =~ s/^\s+//;
   $tooltip =~ s/\s+$//;

   return if $self->{tooltip} eq $tooltip;

   $self->{tooltip} = $tooltip;

   if ($CFPlus::UI::TOOLTIP->{owner} == $self) {
      delete $CFPlus::UI::TOOLTIP->{owner};
      $CFPlus::UI::TOOLTIP_WATCHER->cb->();
   }
}

# translate global coordinates to local coordinate system
sub coord2local {
   my ($self, $x, $y) = @_;

   Carp::confess unless $self->{parent};#d#

   $self->{parent}->coord2local ($x  - $self->{x}, $y - $self->{y})
}

# translate local coordinates to global coordinate system
sub coord2global {
   my ($self, $x, $y) = @_;

   Carp::confess unless $self->{parent};#d#

   $self->{parent}->coord2global ($x + $self->{x}, $y + $self->{y})
}

sub invoke_focus_in {
   my ($self) = @_;

   return if $FOCUS == $self;
   return unless $self->{can_focus};

   $FOCUS = $self;

   $self->update;

   0
}

sub invoke_focus_out {
   my ($self) = @_;

   return unless $FOCUS == $self;

   undef $FOCUS;

   $self->update;

   $::MAPWIDGET->grab_focus #d# focus mapwidget if no other widget has focus
      unless $FOCUS;

   0
}

sub grab_focus {
   my ($self) = @_;

   $FOCUS->emit ("focus_out") if $FOCUS;
   $self->emit ("focus_in");
}

sub invoke_mouse_motion { 0 }
sub invoke_button_up    { 0 }
sub invoke_key_down     { 0 }
sub invoke_key_up       { 0 }
sub invoke_mouse_wheel  { 0 }

sub invoke_button_down {
   my ($self, $ev, $x, $y) = @_;

   $self->grab_focus;

   0
}

sub connect {
   my ($self, $signal, $cb) = @_;

   push @{ $self->{signal_cb}{$signal} }, $cb;

   defined wantarray and CFPlus::guard {
      @{ $self->{signal_cb}{$signal} } = grep $_ != $cb,
         @{ $self->{signal_cb}{$signal} };
   }
}

my %has_coords = (
   button_down  => 1,
   button_up    => 1,
   mouse_motion => 1,
   mouse_wheel  => 1,
);

sub emit {
   my ($self, $signal, @args) = @_;

   # I do not really like this solution, but I dislike duplication
   # and needlessly verbose code, too.
   my @append
      = $has_coords{$signal}
        ? $args[0]->xy ($self)
        : ();

   #warn +(caller(1))[3] . "emit $signal on $self (parent $self->{parent})\n";#d#

   #d##TODO# stop propagating at first true, do not use sum
   (List::Util::sum map $_->($self, @args, @append), @{$self->{signal_cb}{$signal} || []}) # before
      || ($self->can ("invoke_$signal") || sub { 1 })->($self, @args, @append)             # closure
      || ($self->{parent} && $self->{parent}->emit ($signal, @args))                       # parent
}

sub find_widget {
   my ($self, $x, $y) = @_;

   return () unless $self->{can_events};

   return $self
      if $x >= $self->{x} && $x < $self->{x} + $self->{w}
          && $y >= $self->{y} && $y < $self->{y} + $self->{h};

   ()
}

sub set_parent {
   my ($self, $parent) = @_;

   Scalar::Util::weaken ($self->{parent} = $parent);
   $self->set_visible if $parent->{visible};
}

sub realloc {
   my ($self) = @_;

   if ($self->{visible}) {
      return if $self->{root}{realloc}{$self+0};

      $self->{root}{realloc}{$self+0} = $self;
      $self->{root}->update;
   } else {
      delete $self->{req_w};
      delete $self->{req_h};
   }
}

sub update {
   my ($self) = @_;

   $self->{parent}->update
      if $self->{parent};
}

sub reconfigure {
   my ($self) = @_;

   $self->realloc;
   $self->update;
}

# using global variables seems a bit hacky, but passing through all drawing
# functions seems pointless.
our ($draw_x, $draw_y, $draw_w, $draw_h); # screen rectangle being drawn

sub draw {
   my ($self) = @_;

   return unless $self->{h} && $self->{w};

   # update screen rectangle
   local $draw_x = $draw_x + $self->{x};
   local $draw_y = $draw_y + $self->{y};

   # skip widgets that are entirely outside the drawing area
   return if ($draw_x + $self->{w} < 0) || ($draw_x >= $draw_w)
          || ($draw_y + $self->{h} < 0) || ($draw_y >= $draw_h);

   glPushMatrix;
   glTranslate $self->{x}, $self->{y}, 0;

   if ($self == $HOVER && $self->{can_hover}) {
      glColor 1*0.2, 0.8*0.2, 0.5*0.2, 0.2;
      glEnable GL_BLEND;
      glBlendFunc GL_ONE, GL_ONE_MINUS_SRC_ALPHA;
      glBegin GL_QUADS;
      glVertex 0         , 0;
      glVertex $self->{w}, 0;
      glVertex $self->{w}, $self->{h};
      glVertex 0         , $self->{h};
      glEnd;
      glDisable GL_BLEND;
   }

   if ($ENV{CFPLUS_DEBUG} & 1) {
      glPushMatrix;
      glColor 1, 1, 0, 1;
      glTranslate 0.375, 0.375;
      glBegin GL_LINE_LOOP;
      glVertex 0             , 0;
      glVertex $self->{w} - 1, 0;
      glVertex $self->{w} - 1, $self->{h} - 1;
      glVertex 0             , $self->{h} - 1;
      glEnd;
      glPopMatrix;
      #CFPlus::UI::Label->new (w => $self->{w}, h => $self->{h}, text => $self, fontsize => 0)->_draw;
   }

   $self->_draw;
   glPopMatrix;
}

sub _draw {
   my ($self) = @_;

   warn "no draw defined for $self\n";
}

sub DESTROY {
   my ($self) = @_;

   return if CFPlus::in_destruct;

   delete $WIDGET{$self+0};

   eval { $self->destroy };
   warn "exception during widget destruction: $@" if $@ & $@ != /during global destruction/;
}

#############################################################################

package CFPlus::UI::DrawBG;

our @ISA = CFPlus::UI::Base::;

use strict;
use CFPlus::OpenGL;

sub new {
   my $class = shift;

   # range [value, low, high, page]

   $class->SUPER::new (
      #bg        => [0, 0, 0, 0.2],
      #active_bg => [1, 1, 1, 0.5],
      @_
   )
}

sub _draw {
   my ($self) = @_;

   my $color = $FOCUS == $self && $self->{active_bg}
             ? $self->{active_bg}
             : $self->{bg};

   if ($color && (@$color < 4 || $color->[3])) {
      my ($w, $h) = @$self{qw(w h)};

      glEnable GL_BLEND;
      glBlendFunc GL_ONE, GL_ONE_MINUS_SRC_ALPHA;
      glColor_premultiply @$color;

      glBegin GL_QUADS;
      glVertex 0 , 0;
      glVertex 0 , $h;
      glVertex $w, $h;
      glVertex $w, 0;
      glEnd;

      glDisable GL_BLEND;
   }
}

#############################################################################

package CFPlus::UI::Empty;

our @ISA = CFPlus::UI::Base::;

sub new {
   my ($class, %arg) = @_;
   $class->SUPER::new (can_events => 0, %arg);
}

sub size_request {
   my ($self) = @_;

   ($self->{w} + 0, $self->{h} + 0)
}

sub draw { }

#############################################################################

package CFPlus::UI::Container;

our @ISA = CFPlus::UI::Base::;

sub new {
   my ($class, %arg) = @_;

   my $children = delete $arg{children};

   my $self = $class->SUPER::new (
      children   => [],
      can_events => 0,
      %arg,
   );

   $self->add (@$children)
      if $children;

   $self
}

sub realloc {
   my ($self) = @_;

   $self->{force_realloc} = 1;
   $self->{force_size_alloc} = 1;
   $self->SUPER::realloc;
}

sub add {
   my ($self, @widgets) = @_;

   $_->set_parent ($self)
      for @widgets;

   use sort 'stable';

   $self->{children} = [
      sort { $a->{z} <=> $b->{z} }
         @{$self->{children}}, @widgets
   ];

   $self->realloc;
}

sub children {
   @{ $_[0]{children} }
}

sub remove {
   my ($self, $child) = @_;

   delete $child->{parent};
   $child->hide;

   $self->{children} = [ grep $_ != $child, @{ $self->{children} } ];

   $self->realloc;
}

sub clear {
   my ($self) = @_;

   my $children = delete $self->{children};
   $self->{children} = [];

   for (@$children) {
      delete $_->{parent};
      $_->hide;
   }

   $self->realloc;
}

sub find_widget {
   my ($self, $x, $y) = @_;

   $x -= $self->{x};
   $y -= $self->{y};

   my $res;

   for (reverse $self->visible_children) {
      $res = $_->find_widget ($x, $y)
         and return $res;
   }

   $self->SUPER::find_widget ($x + $self->{x}, $y + $self->{y})
}

sub _draw {
   my ($self) = @_;

   $_->draw for @{$self->{children}};
}

#############################################################################

package CFPlus::UI::Bin;

our @ISA = CFPlus::UI::Container::;

sub new {
   my ($class, %arg) = @_;

   my $child = (delete $arg{child}) || new CFPlus::UI::Empty::;

   $class->SUPER::new (children => [$child], %arg)
}

sub add {
   my ($self, $child) = @_;

   $self->SUPER::remove ($_) for @{ $self->{children} };
   $self->SUPER::add ($child);
}

sub remove {
   my ($self, $widget) = @_;

   $self->SUPER::remove ($widget);

   $self->{children} = [new CFPlus::UI::Empty]
      unless @{$self->{children}};
}

sub child { $_[0]->{children}[0] }

sub size_request {
   $_[0]{children}[0]->size_request
}

sub invoke_size_allocate {
   my ($self, $w, $h) = @_;

   $self->{children}[0]->configure (0, 0, $w, $h);

   1
}

#############################################################################

# back-buffered drawing area

package CFPlus::UI::Window;

our @ISA = CFPlus::UI::Bin::;

use CFPlus::OpenGL;

sub new {
   my ($class, %arg) = @_;

   my $self = $class->SUPER::new (%arg);
}

sub update {
   my ($self) = @_;

   $ROOT->on_post_alloc ($self => sub { $self->render_child });
   $self->SUPER::update;
}

sub invoke_size_allocate {
   my ($self, $w, $h) = @_;

   $self->update;

   $self->SUPER::invoke_size_allocate ($w, $h)
}

sub _render {
   my ($self) = @_;

   $self->{children}[0]->draw;
}

sub render_child {
   my ($self) = @_;

   $self->{texture} = new_from_opengl CFPlus::Texture $self->{w}, $self->{h}, sub {
      glClearColor 0, 0, 0, 0;
      glClear GL_COLOR_BUFFER_BIT;

      {
         package CFPlus::UI::Base;

         ($draw_x, $draw_y, $draw_w, $draw_h) =
            (0, 0, $self->{w}, $self->{h});
      }

      $self->_render;
   };
}

sub _draw {
   my ($self) = @_;

   my ($w, $h) = @$self{qw(w h)};

   my $tex = $self->{texture}
      or return;

   glEnable GL_TEXTURE_2D;
   glTexEnv GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE;
   glColor 0, 0, 0, 1;

   $tex->draw_quad_alpha_premultiplied (0, 0, $w, $h);

   glDisable GL_TEXTURE_2D;
}

#############################################################################

package CFPlus::UI::ViewPort;

our @ISA = CFPlus::UI::Window::;

sub new {
   my $class = shift;

   $class->SUPER::new (
      scroll_x => 0,
      scroll_y => 1,
      @_,
   )
}

sub size_request {
   my ($self) = @_;

   my ($w, $h) = @{$self->child}{qw(req_w req_h)};

   $w = 10 if $self->{scroll_x};
   $h = 10 if $self->{scroll_y};

   ($w, $h)
}

sub invoke_size_allocate {
   my ($self, $w, $h) = @_;

   my $child = $self->child;

   $w = $child->{req_w} if $self->{scroll_x} && $child->{req_w};
   $h = $child->{req_h} if $self->{scroll_y} && $child->{req_h};

   $self->child->configure (0, 0, $w, $h);
   $self->update;

   1
}

sub set_offset {
   my ($self, $x, $y) = @_;

   $self->{view_x} = int $x;
   $self->{view_y} = int $y;

   $self->update;
}

# hmm, this does not work for topleft of $self... but we should not ask for that
sub coord2local {
   my ($self, $x, $y) = @_;

   $self->SUPER::coord2local ($x + $self->{view_x}, $y + $self->{view_y})
}

sub coord2global {
   my ($self, $x, $y) = @_;

   $x = List::Util::min $self->{w}, $x - $self->{view_x};
   $y = List::Util::min $self->{h}, $y - $self->{view_y};

   $self->SUPER::coord2global ($x, $y)
}

sub find_widget {
   my ($self, $x, $y) = @_;

   if (   $x >= $self->{x} && $x < $self->{x} + $self->{w}
       && $y >= $self->{y} && $y < $self->{y} + $self->{h}
   ) {
       $self->child->find_widget ($x + $self->{view_x}, $y + $self->{view_y})
   } else {
      $self->CFPlus::UI::Base::find_widget ($x, $y)
   }
}

sub _render {
   my ($self) = @_;

   local $CFPlus::UI::Base::draw_x = $CFPlus::UI::Base::draw_x - $self->{view_x};
   local $CFPlus::UI::Base::draw_y = $CFPlus::UI::Base::draw_y - $self->{view_y};

   CFPlus::OpenGL::glTranslate -$self->{view_x}, -$self->{view_y};

   $self->SUPER::_render;
}

#############################################################################

package CFPlus::UI::ScrolledWindow;

our @ISA = CFPlus::UI::HBox::;

sub new {
   my ($class, %arg) = @_;

   my $child = delete $arg{child};

   my $self;

   my $slider = new CFPlus::UI::Slider
      vertical   => 1,
      range      => [0, 0, 1, 0.01], # HACK fix
      on_changed => sub {
         $self->{vp}->set_offset (0, $_[1]);
      },
   ;

   $self = $class->SUPER::new (
      vp         => (new CFPlus::UI::ViewPort expand => 1),
      can_events => 1,
      slider     => $slider,
      %arg,
   );

   $self->SUPER::add ($self->{vp}, $self->{slider});
   $self->add ($child) if $child;

   $self
}

#TODO# update range on size_allocate depending on child

sub add {
   my ($self, $widget) = @_;

   $self->{vp}->add ($self->{child} = $widget);
}

sub invoke_mouse_wheel {
   my ($self, $ev) = @_;

   return 0 unless $ev->{dy}; # only vertical movements

   $self->{slider}->emit (mouse_wheel => $ev);

   1
}

sub update_slider {
   my ($self) = @_;

   $self->{slider}->set_range ([$self->{slider}{range}[0], 0, $self->{vp}->child->{h}, $self->{vp}{h}, 1]);
}

sub update {
   my ($self) = @_;

   $self->SUPER::update;

   $self->update_slider;
}

sub invoke_size_allocate {
   my ($self, $w, $h) = @_;

   $self->update_slider;

   $self->SUPER::invoke_size_allocate ($w, $h)
}

#############################################################################

package CFPlus::UI::Frame;

our @ISA = CFPlus::UI::Bin::;

use CFPlus::OpenGL;

sub new {
   my $class = shift;

   $class->SUPER::new (
      bg => undef,
      @_,
   )
}

sub _draw {
   my ($self) = @_;

   if ($self->{bg}) {
      my ($w, $h) = @$self{qw(w h)};

      glEnable GL_BLEND;
      glBlendFunc GL_ONE, GL_ONE_MINUS_SRC_ALPHA;
      glColor_premultiply @{ $self->{bg} };

      glBegin GL_QUADS;
      glVertex 0 , 0;
      glVertex 0 , $h;
      glVertex $w, $h;
      glVertex $w, 0;
      glEnd;

      glDisable GL_BLEND;
   }

   $self->SUPER::_draw;
}

#############################################################################

package CFPlus::UI::FancyFrame;

our @ISA = CFPlus::UI::Bin::;

use CFPlus::OpenGL;

my $bg = 
      new_from_file CFPlus::Texture CFPlus::find_rcfile "d1_bg.png",
         mipmap => 1, wrap => 1;

my @border = 
      map { new_from_file CFPlus::Texture CFPlus::find_rcfile $_, mipmap => 1 }
         qw(d1_border_top.png d1_border_right.png d1_border_left.png d1_border_bottom.png);

sub new {
   my ($class, %arg) = @_;

   my $self = $class->SUPER::new (
      bg          => [1, 1, 1, 1],
      border_bg   => [1, 1, 1, 1],
      border      => 0.6,
      can_events  => 1,
      min_w       => 64,
      min_h       => 32,
      %arg,
   );

   $self->{title_widget} = new CFPlus::UI::Label
      align    => 0,
      valign   => 1,
      text     => $self->{title},
      fontsize => $self->{border},
         if exists $self->{title};

   if ($self->{has_close_button}) {
      $self->{close_button} =
         new CFPlus::UI::ImageButton
            path        => 'x1_close.png',
            on_activate => sub { $self->emit ("delete") };

      $self->CFPlus::UI::Container::add ($self->{close_button});
   }

   $self
}

sub add {
   my ($self, @widgets) = @_;

   $self->SUPER::add (@widgets);
   $self->CFPlus::UI::Container::add ($self->{close_button}) if $self->{close_button};
   $self->CFPlus::UI::Container::add ($self->{title_widget}) if $self->{title_widget};
}

sub border {
   int $_[0]{border} * $::FONTSIZE
}

sub size_request {
   my ($self) = @_;

   $self->{title_widget}->size_request
      if $self->{title_widget};

   $self->{close_button}->size_request
      if $self->{close_button};

   my ($w, $h) = $self->SUPER::size_request;

   (
      $w + $self->border * 2,
      $h + $self->border * 2,
   )
}

sub invoke_size_allocate {
   my ($self, $w, $h) = @_;

   if ($self->{title_widget}) {
      $self->{title_widget}{w} = $w;
      $self->{title_widget}{h} = $h;
      $self->{title_widget}->invoke_size_allocate ($w, $h);
   }

   my $border = $self->border;

   $h -= List::Util::max 0, $border * 2;
   $w -= List::Util::max 0, $border * 2;

   $self->child->configure ($border, $border, $w, $h);

   $self->{close_button}->configure ($self->{w} - $border, 0, $border, $border)
      if $self->{close_button};

   1
}

sub invoke_delete {
   my ($self) = @_;

   $self->hide;
   
   1
}

sub invoke_button_down {
   my ($self, $ev, $x, $y) = @_;

   my ($w, $h) = @$self{qw(w h)};
   my $border = $self->border;

   my $lr = ($x >= 0 && $x < $border) || ($x > $w - $border && $x < $w);
   my $td = ($y >= 0 && $y < $border) || ($y > $h - $border && $y < $h);

   if ($lr & $td) {
      my ($wx, $wy) = ($self->{x}, $self->{y});
      my ($ox, $oy) = ($ev->{x}, $ev->{y});
      my ($bw, $bh) = ($self->{w}, $self->{h});

      my $mx = $x < $border;
      my $my = $y < $border;

      $self->{motion} = sub {
         my ($ev, $x, $y) = @_;

         my $dx = $ev->{x} - $ox;
         my $dy = $ev->{y} - $oy;

         $self->{force_w} = $bw + $dx * ($mx ? -1 : 1);
         $self->{force_h} = $bh + $dy * ($my ? -1 : 1);

         $self->move_abs ($wx + $dx * $mx, $wy + $dy * $my);
         $self->realloc;
      };

   } elsif ($lr ^ $td) {
      my ($ox, $oy) = ($ev->{x}, $ev->{y});
      my ($bx, $by) = ($self->{x}, $self->{y});

      $self->{motion} = sub {
         my ($ev, $x, $y) = @_;

         ($x, $y) = ($ev->{x}, $ev->{y});

         $self->move_abs ($bx + $x - $ox, $by + $y - $oy);
         # HACK: the next line is required to enforce placement
         $self->{parent}->invoke_size_allocate ($self->{parent}{w}, $self->{parent}{h});
      };
   } else {
      return 0;
   }

   1
}

sub invoke_button_up {
   my ($self, $ev, $x, $y) = @_;

   ! ! delete $self->{motion}
}

sub invoke_mouse_motion {
   my ($self, $ev, $x, $y) = @_;

   $self->{motion}->($ev, $x, $y) if $self->{motion};

   ! ! $self->{motion}
}

sub invoke_visibility_change {
   my ($self, $visible) = @_;

   delete $self->{motion} unless $visible;

   0
}

sub _draw {
   my ($self) = @_;

   my $child = $self->{children}[0];

   my ($w,  $h ) = ($self->{w}, $self->{h});
   my ($cw, $ch) = ($child->{w}, $child->{h});

   glEnable GL_TEXTURE_2D;
   glTexEnv GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE;

   my $border = $self->border;

   glColor @{ $self->{border_bg} };
   $border[0]->draw_quad_alpha (0, 0, $w, $border);
   $border[1]->draw_quad_alpha (0, $border, $border, $ch);
   $border[2]->draw_quad_alpha ($w - $border, $border, $border, $ch);
   $border[3]->draw_quad_alpha (0, $h - $border, $w, $border);

   if (@{$self->{bg}} < 4 || $self->{bg}[3]) {
      glColor @{ $self->{bg} };

      # TODO: repeat texture not scale
      # solve this better(?)
      $bg->{s} = $cw / $bg->{w};
      $bg->{t} = $ch / $bg->{h};
      $bg->draw_quad_alpha ($border, $border, $cw, $ch);
   }

   glDisable GL_TEXTURE_2D;

   $child->draw;

   if ($self->{title_widget}) {
      glTranslate 0, $border - $self->{h};
      $self->{title_widget}->_draw;

      glTranslate 0, - ($border - $self->{h});
   }

   $self->{close_button}->draw
      if $self->{close_button};
}

#############################################################################

package CFPlus::UI::Table;

our @ISA = CFPlus::UI::Base::;

use List::Util qw(max sum);

use CFPlus::OpenGL;

sub new {
   my $class = shift;

   $class->SUPER::new (
      col_expand => [],
      @_,
   )
}

sub children {
   grep $_, map @$_, grep $_, @{ $_[0]{children} }
}

sub add {
   my ($self) = shift;

   while (@_) {
      my ($x, $y, $child) = splice @_, 0, 3, ();
      $child->set_parent ($self);
      $self->{children}[$y][$x] = $child;
   }

   $self->{force_realloc} = 1;
   $self->{force_size_alloc} = 1;
   $self->realloc;
}

sub remove {
   my ($self, $child) = @_;

   # TODO: not yet implemented
}

# TODO: move to container class maybe? send children a signal on removal?
sub clear {
   my ($self) = @_;

   my @children = $self->children;
   delete $self->{children};
   
   for (@children) {
      delete $_->{parent};
      $_->hide;
   }

   $self->realloc;
}

sub get_wh {
   my ($self) = @_;

   my (@w, @h);

   for my $y (0 .. $#{$self->{children}}) {
      my $row = $self->{children}[$y]
         or next;

      for my $x (0 .. $#$row) {
         my $widget = $row->[$x]
            or next;
         my ($w, $h) = @$widget{qw(req_w req_h)};

         $w[$x] = max $w[$x], $w;
         $h[$y] = max $h[$y], $h;
      }
   }

   (\@w, \@h)
}

sub size_request {
   my ($self) = @_;

   my ($ws, $hs) = $self->get_wh;

   (
      (sum @$ws),
      (sum @$hs),
   )
}

sub invoke_size_allocate {
   my ($self, $w, $h) = @_;

   my ($ws, $hs) = $self->get_wh;

   my $req_w = (sum @$ws) || 1;
   my $req_h = (sum @$hs) || 1;

   # TODO: nicer code && do row_expand
   my @col_expand = @{$self->{col_expand}};
   @col_expand = (1) x @$ws unless @col_expand;
   my $col_expand = (sum @col_expand) || 1;

   # linearly scale sizes
   $ws->[$_] += $col_expand[$_] / $col_expand * ($w - $req_w) for 0 .. $#$ws;
   $hs->[$_] *= 1 * $h / $req_h for 0 .. $#$hs;

   CFPlus::UI::harmonize $ws;
   CFPlus::UI::harmonize $hs;

   my $y;

   for my $r (0 .. $#{$self->{children}}) {
      my $row = $self->{children}[$r]
         or next;

      my $x = 0;
      my $row_h = $hs->[$r];
      
      for my $c (0 .. $#$row) {
         my $col_w = $ws->[$c];

         if (my $widget = $row->[$c]) {
            $widget->configure ($x, $y, $col_w, $row_h);
         }

         $x += $col_w;
      }

      $y += $row_h;
   }

   1
}

sub find_widget {
   my ($self, $x, $y) = @_;

   $x -= $self->{x};
   $y -= $self->{y};

   my $res;

   for (grep $_, map @$_, grep $_, @{ $self->{children} }) {
      $res = $_->find_widget ($x, $y)
         and return $res;
   }

   $self->SUPER::find_widget ($x + $self->{x}, $y + $self->{y})
}

sub _draw {
   my ($self) = @_;

   for (grep $_, @{$self->{children}}) {
      $_->draw for grep $_, @$_;
   }
}

#############################################################################

package CFPlus::UI::Box;

our @ISA = CFPlus::UI::Container::;

sub size_request {
   my ($self) = @_;

   $self->{vertical}
      ?  (
            (List::Util::max map $_->{req_w}, @{$self->{children}}),
            (List::Util::sum map $_->{req_h}, @{$self->{children}}),
         )
      :  (
            (List::Util::sum map $_->{req_w}, @{$self->{children}}),
            (List::Util::max map $_->{req_h}, @{$self->{children}}),
         )
}

sub invoke_size_allocate {
   my ($self, $w, $h) = @_;

   my $space = $self->{vertical} ? $h : $w;
   my @children = $self->visible_children;

   my @req;

   if ($self->{homogeneous}) {
      @req = ($space / (@children || 1)) x @children;
   } else {
      @req = map $_->{$self->{vertical} ? "req_h" : "req_w"}, @children;
      my $req = List::Util::sum @req;

      if ($req > $space) {
         # ah well, not enough space
         $_ *= $space / $req for @req;
      } else {
         my $expand = (List::Util::sum map $_->{expand}, @children) || 1;
         
         $space = ($space - $req) / $expand; # remaining space to give away

         $req[$_] += $space * $children[$_]{expand}
            for 0 .. $#children;
      }
   }

   CFPlus::UI::harmonize \@req;

   my $pos = 0;
   for (0 .. $#children) {
      my $alloc = $req[$_];
      $children[$_]->configure ($self->{vertical} ? (0, $pos, $w, $alloc) : ($pos, 0, $alloc, $h));

      $pos += $alloc;
   }

   1
}

#############################################################################

package CFPlus::UI::HBox;

our @ISA = CFPlus::UI::Box::;

sub new {
   my $class = shift;

   $class->SUPER::new (
      vertical => 0,
      @_,
   )
}

#############################################################################

package CFPlus::UI::VBox;

our @ISA = CFPlus::UI::Box::;

sub new {
   my $class = shift;

   $class->SUPER::new (
      vertical => 1,
      @_,
   )
}

#############################################################################

package CFPlus::UI::Label;

our @ISA = CFPlus::UI::DrawBG::;

use CFPlus::OpenGL;

sub new {
   my ($class, %arg) = @_;

   my $self = $class->SUPER::new (
      fg         => [1, 1, 1],
      #bg        => none
      #active_bg => none
      #font      => default_font
      #text      => initial text
      #markup    => initial narkup
      #max_w     => maximum pixel width
      ellipsise  => 3, # end
      layout     => (new CFPlus::Layout),
      fontsize   => 1,
      align      => -1,
      valign     => -1,
      padding_x  => 2,
      padding_y  => 2,
      can_events => 0,
      %arg
   );

   if (exists $self->{template}) {
      my $layout = new CFPlus::Layout;
      $layout->set_text (delete $self->{template});
      $self->{template} = $layout;
   }

   if (exists $self->{markup}) {
      $self->set_markup (delete $self->{markup});
   } else {
      $self->set_text (delete $self->{text});
   }

   $self
}

sub update {
   my ($self) = @_;

   delete $self->{texture};
   $self->SUPER::update;
}

sub realloc {
   my ($self) = @_;

   delete $self->{ox};
   $self->SUPER::realloc;
}

sub set_text {
   my ($self, $text) = @_;

   return if $self->{text} eq "T$text";
   $self->{text} = "T$text";

   $self->{layout}->set_text ($text);

   delete $self->{size_req};
   $self->realloc;
   $self->update;
}

sub set_markup {
   my ($self, $markup) = @_;

   return if $self->{text} eq "M$markup";
   $self->{text} = "M$markup";

   my $rgba = $markup =~ /span.*(?:foreground|background)/;

   $self->{layout}->set_markup ($markup);

   delete $self->{size_req};
   $self->realloc;
   $self->update;
}

sub size_request {
   my ($self) = @_;

   $self->{size_req} ||= do {
      $self->{layout}->set_font ($self->{font}) if $self->{font};
      $self->{layout}->set_width ($self->{max_w} || -1);
      $self->{layout}->set_ellipsise ($self->{ellipsise});
      $self->{layout}->set_single_paragraph_mode ($self->{ellipsise});
      $self->{layout}->set_height ($self->{fontsize} * $::FONTSIZE);

      my ($w, $h) = $self->{layout}->size;

      if (exists $self->{template}) {
         $self->{template}->set_font ($self->{font}) if $self->{font};
         $self->{template}->set_width ($self->{max_w} || -1);
         $self->{template}->set_height ($self->{fontsize} * $::FONTSIZE);

         my ($w2, $h2) = $self->{template}->size;

         $w = List::Util::max $w, $w2;
         $h = List::Util::max $h, $h2;
      }

      [$w, $h]
   };

   @{ $self->{size_req} }
}

sub baseline_shift {
   $_[0]{layout}->descent
}

sub invoke_size_allocate {
   my ($self, $w, $h) = @_;

   delete $self->{ox};

   delete $self->{texture}
      unless $w >= $self->{req_w} && $self->{old_w} >= $self->{req_w};

   1
}

sub set_fontsize {
   my ($self, $fontsize) = @_;

   $self->{fontsize} = $fontsize;
   delete $self->{size_req};
   delete $self->{texture};

   $self->realloc;
}

sub reconfigure {
   my ($self) = @_;

   delete $self->{size_req};
   delete $self->{texture};

   $self->SUPER::reconfigure;
}

sub _draw {
   my ($self) = @_;

   $self->SUPER::_draw; # draw background, if applicable

   my $size = $self->{texture} ||= do {
      $self->{layout}->set_foreground (@{$self->{fg}});
      $self->{layout}->set_font ($self->{font}) if $self->{font};
      $self->{layout}->set_width ($self->{w});
      $self->{layout}->set_ellipsise ($self->{ellipsise});
      $self->{layout}->set_single_paragraph_mode ($self->{ellipsise});
      $self->{layout}->set_height ($self->{fontsize} * $::FONTSIZE);

      [$self->{layout}->size]
   };

   unless (exists $self->{ox}) {
      $self->{ox} = int ($self->{align} < 0 ? $self->{padding_x}
                       : $self->{align} > 0 ? $self->{w} - $size->[0] - $self->{padding_x}
                       :                      ($self->{w} - $size->[0]) * 0.5);

      $self->{oy} = int ($self->{valign} < 0 ? $self->{padding_y}
                       : $self->{valign} > 0 ? $self->{h} - $size->[1] - $self->{padding_y}
                       :                       ($self->{h} - $size->[1]) * 0.5);
   };

   my $w = List::Util::min $self->{w} + 4, $size->[0];
   my $h = List::Util::min $self->{h} + 2, $size->[1];

   $self->{layout}->render ($self->{ox}, $self->{oy});
}

#############################################################################

package CFPlus::UI::EntryBase;

our @ISA = CFPlus::UI::Label::;

use CFPlus::OpenGL;

sub new {
   my $class = shift;

   $class->SUPER::new (
      fg         => [1, 1, 1],
      bg         => [0, 0, 0, 0.2],
      active_bg  => [1, 1, 1, 0.5],
      active_fg  => [0, 0, 0],
      can_hover  => 1,
      can_focus  => 1,
      valign     => 0,
      can_events => 1,
      #text      => ...
      #hidden    => "*",
      @_
   )
}

sub _set_text {
   my ($self, $text) = @_;

   delete $self->{cur_h};

   return if $self->{text} eq $text;

   $self->{last_activity} = $::NOW;
   $self->{text} = $text;

   $text =~ s/./*/g if $self->{hidden};
   $self->{layout}->set_text ("$text ");
   delete $self->{size_req};

   $self->emit (changed => $self->{text});

   $self->realloc;
   $self->update;
}

sub set_text {
   my ($self, $text) = @_;

   $self->{cursor} = length $text;
   $self->_set_text ($text);
}

sub get_text {
   $_[0]{text}
}

sub size_request {
   my ($self) = @_;

   my ($w, $h) = $self->SUPER::size_request;

   ($w + 1, $h) # add 1 for cursor
}

sub invoke_key_down {
   my ($self, $ev) = @_;

   my $mod = $ev->{mod};
   my $sym = $ev->{sym};
   my $uni = $ev->{unicode};

   my $text = $self->get_text;

   if ($uni == 8) {
      substr $text, --$self->{cursor}, 1, "" if $self->{cursor};
   } elsif ($uni == 127) {
      substr $text, $self->{cursor}, 1, "";
   } elsif ($sym == CFPlus::SDLK_LEFT) {
      --$self->{cursor} if $self->{cursor};
   } elsif ($sym == CFPlus::SDLK_RIGHT) {
      ++$self->{cursor} if $self->{cursor} < length $self->{text};
   } elsif ($sym == CFPlus::SDLK_HOME) {
      $self->{cursor} = 0;
   } elsif ($sym == CFPlus::SDLK_END) {
      $self->{cursor} = length $text;
   } elsif ($uni == 27) {
      $self->emit ('escape');
   } elsif ($uni) {
      substr $text, $self->{cursor}++, 0, chr $uni;
   } else {
      return 0;
   }

   $self->_set_text ($text);

   $self->realloc;

   1
}

sub invoke_focus_in {
   my ($self) = @_;

   $self->{last_activity} = $::NOW;

   $self->SUPER::invoke_focus_in
}

sub invoke_button_down {
   my ($self, $ev, $x, $y) = @_;

   $self->SUPER::invoke_button_down ($ev, $x, $y);

   my $idx = $self->{layout}->xy_to_index ($x, $y);

   # byte-index to char-index
   my $text = $self->{text};
   utf8::encode $text; $text = substr $text, 0, $idx; utf8::decode $text;
   $self->{cursor} = length $text;

   $self->_set_text ($self->{text});
   $self->update;
   
   1
}

sub invoke_mouse_motion {
   my ($self, $ev, $x, $y) = @_;
#   printf "M %d,%d %d,%d\n", $ev->motion_x, $ev->motion_y, $x, $y;#d#

   1
}

sub _draw {
   my ($self) = @_;

   local $self->{fg} = $self->{fg};

   if ($FOCUS == $self) {
      glColor_premultiply @{$self->{active_bg}};
      $self->{fg} = $self->{active_fg};
   } else {
      glColor_premultiply @{$self->{bg}};
   }

   glEnable GL_BLEND;
   glBlendFunc GL_ONE, GL_ONE_MINUS_SRC_ALPHA;
   glBegin GL_QUADS;
   glVertex 0         , 0;
   glVertex 0         , $self->{h};
   glVertex $self->{w}, $self->{h};
   glVertex $self->{w}, 0;
   glEnd;
   glDisable GL_BLEND;

   $self->SUPER::_draw;

   #TODO: force update every cursor change :(
   if ($FOCUS == $self && (($::NOW - $self->{last_activity}) & 1023) < 600) {

      unless (exists $self->{cur_h}) {
         my $text = substr $self->{text}, 0, $self->{cursor};
         utf8::encode $text;

         @$self{qw(cur_x cur_y cur_h)} = $self->{layout}->cursor_pos (length $text)
      }

      glColor @{$self->{fg}};
      glBegin GL_LINES;
      glVertex $self->{cur_x} + $self->{ox}, $self->{cur_y} + $self->{oy};
      glVertex $self->{cur_x} + $self->{ox}, $self->{cur_y} + $self->{oy} + $self->{cur_h};
      glEnd;
   }
}

package CFPlus::UI::Entry;

our @ISA = CFPlus::UI::EntryBase::;

use CFPlus::OpenGL;

sub invoke_key_down {
   my ($self, $ev) = @_;

   my $sym = $ev->{sym};

   if ($sym == 13) {
      unshift @{$self->{history}},
         my $txt = $self->get_text;

      $self->{history_pointer} = -1;
      $self->{history_saveback} = '';
      $self->emit (activate => $txt);
      $self->update;

   } elsif ($sym == CFPlus::SDLK_UP) {
      if ($self->{history_pointer} < 0) {
         $self->{history_saveback} = $self->get_text;
      }
      if (@{$self->{history} || []} > 0) {
         $self->{history_pointer}++;
         if ($self->{history_pointer} >= @{$self->{history} || []}) {
            $self->{history_pointer} = @{$self->{history} || []} - 1;
         }
         $self->set_text ($self->{history}->[$self->{history_pointer}]);
      }

   } elsif ($sym == CFPlus::SDLK_DOWN) {
      $self->{history_pointer}--;
      $self->{history_pointer} = -1 if $self->{history_pointer} < 0;

      if ($self->{history_pointer} >= 0) {
         $self->set_text ($self->{history}->[$self->{history_pointer}]);
      } else {
         $self->set_text ($self->{history_saveback});
      }

   } else {
      return $self->SUPER::invoke_key_down ($ev)
   }

   1
}

#############################################################################

package CFPlus::UI::Button;

our @ISA = CFPlus::UI::Label::;

use CFPlus::OpenGL;

my @tex =
      map { new_from_file CFPlus::Texture CFPlus::find_rcfile $_, mipmap => 1 }
         qw(b1_button_active.png);

sub new {
   my $class = shift;

   $class->SUPER::new (
      padding_x  => 4,
      padding_y  => 4,
      fg         => [1, 1, 1],
      active_fg  => [0, 0, 1],
      can_hover  => 1,
      align      => 0,
      valign     => 0,
      can_events => 1,
      @_
   )
}

sub invoke_button_up {
   my ($self, $ev, $x, $y) = @_;

   $self->emit ("activate")
      if $x >= 0 && $x < $self->{w}
         && $y >= 0 && $y < $self->{h};

   1
}

sub _draw {
   my ($self) = @_;

   local $self->{fg} = $GRAB == $self ? $self->{active_fg} : $self->{fg};

   glEnable GL_TEXTURE_2D;
   glTexEnv GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE;
   glColor 0, 0, 0, 1;

   $tex[0]->draw_quad_alpha (0, 0, $self->{w}, $self->{h});

   glDisable GL_TEXTURE_2D;

   $self->SUPER::_draw;
}

#############################################################################

package CFPlus::UI::CheckBox;

our @ISA = CFPlus::UI::DrawBG::;

my @tex =
      map { new_from_file CFPlus::Texture CFPlus::find_rcfile $_, mipmap => 1 }
         qw(c1_checkbox_bg.png c1_checkbox_active.png);

use CFPlus::OpenGL;

sub new {
   my $class = shift;

   $class->SUPER::new (
      padding_x => 2,
      padding_y => 2,
      fg        => [1, 1, 1],
      active_fg => [1, 1, 0],
      bg        => [0, 0, 0, 0.2],
      active_bg => [1, 1, 1, 0.5],
      state     => 0,
      can_hover => 1,
      @_
   )
}

sub size_request {
   my ($self) = @_;

   (6) x 2
}

sub toggle {
   my ($self) = @_;

   $self->{state} = !$self->{state};
   $self->emit (changed => $self->{state});
   $self->update;
}

sub invoke_button_down {
   my ($self, $ev, $x, $y) = @_;

   if ($x >= $self->{padding_x} && $x < $self->{w} - $self->{padding_x}
       && $y >= $self->{padding_y} && $y < $self->{h} - $self->{padding_y}) {
      $self->toggle;
   } else {
      return 0
   }

   1
}

sub _draw {
   my ($self) = @_;

   $self->SUPER::_draw;

   glTranslate $self->{padding_x} + 0.375, $self->{padding_y} + 0.375, 0;

   my ($w, $h) = @$self{qw(w h)};

   my $s = List::Util::min $w - $self->{padding_x} * 2, $h - $self->{padding_y} * 2;

   glColor @{ $FOCUS == $self ? $self->{active_fg} : $self->{fg} };

   my $tex = $self->{state} ? $tex[1] : $tex[0];

   glEnable GL_TEXTURE_2D;
   $tex->draw_quad_alpha (0, 0, $s, $s);
   glDisable GL_TEXTURE_2D;
}

#############################################################################

package CFPlus::UI::Image;

our @ISA = CFPlus::UI::Base::;

use CFPlus::OpenGL;

our %texture_cache;

sub new {
   my $class = shift;

   my $self = $class->SUPER::new (
      can_events => 0,
      @_,
   );

   $self->{path} || $self->{tex}
      or Carp::croak "'path' or 'tex' attributes required";

   $self->{tex} ||= $texture_cache{$self->{path}} ||=
      new_from_file CFPlus::Texture CFPlus::find_rcfile $self->{path}, mipmap => 1;

   Scalar::Util::weaken $texture_cache{$self->{path}};

   $self->{aspect} ||= $self->{tex}{w} / $self->{tex}{h};

   $self
}

sub STORABLE_freeze {
   my ($self, $cloning) = @_;

   $self->{path}
      or die "cannot serialise CFPlus::UI::Image on non-loadable images\n";

   $self->{path}
}

sub STORABLE_attach {
   my ($self, $cloning, $path) = @_;

   $self->new (path => $path)
}

sub size_request {
   my ($self) = @_;

   ($self->{tex}{w}, $self->{tex}{h})
}

sub _draw {
   my ($self) = @_;

   my $tex = $self->{tex};

   my ($w, $h) = ($self->{w}, $self->{h});

   if ($self->{rot90}) {
      glRotate 90, 0, 0, 1;
      glTranslate 0, -$self->{w}, 0;

      ($w, $h) = ($h, $w);
   }

   glEnable GL_TEXTURE_2D;
   glTexEnv GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE;

   $tex->draw_quad (0, 0, $w, $h);

   glDisable GL_TEXTURE_2D;
}

#############################################################################

package CFPlus::UI::ImageButton;

our @ISA = CFPlus::UI::Image::;

use CFPlus::OpenGL;

my %textures;

sub new {
   my $class = shift;

   my $self = $class->SUPER::new (
      padding_x  => 4,
      padding_y  => 4,
      fg         => [1, 1, 1],
      active_fg  => [0, 0, 1],
      can_hover  => 1,
      align      => 0,
      valign     => 0,
      can_events => 1,
      @_
   );
}

sub invoke_button_up {
   my ($self, $ev, $x, $y) = @_;

   $self->emit ("activate")
      if $x >= 0 && $x < $self->{w}
         && $y >= 0 && $y < $self->{h};

   1
}

#############################################################################

package CFPlus::UI::VGauge;

our @ISA = CFPlus::UI::Base::;

use List::Util qw(min max);

use CFPlus::OpenGL;

my %tex = (
   food => [
      map { new_from_file CFPlus::Texture CFPlus::find_rcfile $_, mipmap => 1 }
         qw/g1_food_gauge_empty.png g1_food_gauge_full.png/
   ],
   grace => [
      map { new_from_file CFPlus::Texture CFPlus::find_rcfile $_, mipmap => 1 }
         qw/g1_grace_gauge_empty.png g1_grace_gauge_full.png g1_grace_gauge_overflow.png/
   ],
   hp => [
      map { new_from_file CFPlus::Texture CFPlus::find_rcfile $_, mipmap => 1 }
         qw/g1_hp_gauge_empty.png g1_hp_gauge_full.png/
   ],
   mana => [
      map { new_from_file CFPlus::Texture CFPlus::find_rcfile $_, mipmap => 1 }
         qw/g1_mana_gauge_empty.png g1_mana_gauge_full.png g1_mana_gauge_overflow.png/
   ],
);

# eg. VGauge->new (gauge => 'food'), default gauge: food
sub new {
   my $class = shift;

   my $self = $class->SUPER::new (
      type  => 'food',
      @_
   );

   $self->{aspect} = $tex{$self->{type}}[0]{w} / $tex{$self->{type}}[0]{h};

   $self
}

sub size_request {
   my ($self) = @_;

   #my $tex = $tex{$self->{type}}[0];
   #@$tex{qw(w h)}
   (0, 0)
}

sub set_max {
   my ($self, $max) = @_;

   return if $self->{max_val} == $max;

   $self->{max_val} = $max;
   $self->update;
}

sub set_value {
   my ($self, $val, $max) = @_;

   $self->set_max ($max)
      if defined $max;

   return if $self->{val} == $val;

   $self->{val} = $val;
   $self->update;
}

sub _draw {
   my ($self) = @_;

   my $tex = $tex{$self->{type}};
   my ($t1, $t2, $t3) = @$tex;

   my ($w, $h) = ($self->{w}, $self->{h});

   if ($self->{vertical}) {
      glRotate 90, 0, 0, 1;
      glTranslate 0, -$self->{w}, 0;

      ($w, $h) = ($h, $w);
   }

   my $ycut = $self->{val} / ($self->{max_val} || 1);

   my $ycut1 = max 0, min 1, $ycut;
   my $ycut2 = max 0, min 1, $ycut - 1;

   my $h1 = $self->{h} * (1 - $ycut1);
   my $h2 = $self->{h} * (1 - $ycut2);
   my $h3 = $self->{h};

   $_ = $_ * (284-4)/288 + 4/288 for ($h1, $h2, $h3);

   glEnable GL_BLEND;
   glBlendFuncSeparate GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA,
                       GL_ONE, GL_ONE_MINUS_SRC_ALPHA;
   glEnable GL_TEXTURE_2D;
   glTexEnv GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE;

   glBindTexture GL_TEXTURE_2D, $t1->{name};
   glBegin GL_QUADS;
   glTexCoord 0       , 0;                       glVertex 0 , 0;
   glTexCoord 0       , $t1->{t} * (1 - $ycut1); glVertex 0 , $h1;
   glTexCoord $t1->{s}, $t1->{t} * (1 - $ycut1); glVertex $w, $h1;
   glTexCoord $t1->{s}, 0;                       glVertex $w, 0;
   glEnd;

   my $ycut1 = List::Util::min 1, $ycut;
   glBindTexture GL_TEXTURE_2D, $t2->{name};
   glBegin GL_QUADS;
   glTexCoord 0       , $t2->{t} * (1 - $ycut1); glVertex 0 , $h1;
   glTexCoord 0       , $t2->{t} * (1 - $ycut2); glVertex 0 , $h2;
   glTexCoord $t2->{s}, $t2->{t} * (1 - $ycut2); glVertex $w, $h2;
   glTexCoord $t2->{s}, $t2->{t} * (1 - $ycut1); glVertex $w, $h1;
   glEnd;

   if ($t3) {
      glBindTexture GL_TEXTURE_2D, $t3->{name};
      glBegin GL_QUADS;
      glTexCoord 0       , $t3->{t} * (1 - $ycut2); glVertex 0 , $h2;
      glTexCoord 0       , $t3->{t};                glVertex 0 , $h3;
      glTexCoord $t3->{s}, $t3->{t};                glVertex $w, $h3;
      glTexCoord $t3->{s}, $t3->{t} * (1 - $ycut2); glVertex $w, $h2;
      glEnd;
   }

   glDisable GL_BLEND;
   glDisable GL_TEXTURE_2D;
}

#############################################################################

package CFPlus::UI::Gauge;

our @ISA = CFPlus::UI::VBox::;

sub new {
   my ($class, %arg) = @_;

   my $self = $class->SUPER::new (
      tooltip    => $arg{type},
      can_hover  => 1,
      can_events => 1,
      %arg,
   );

   $self->add ($self->{value} = new CFPlus::UI::Label valign => +1, align => 0, template => "999");
   $self->add ($self->{gauge} = new CFPlus::UI::VGauge type => $self->{type}, expand => 1, can_hover => 1);
   $self->add ($self->{max}   = new CFPlus::UI::Label valign => -1, align => 0, template => "999");

   $self
}

sub set_fontsize {
   my ($self, $fsize) = @_;

   $self->{value}->set_fontsize ($fsize);
   $self->{max}  ->set_fontsize ($fsize);
}

sub set_max {
   my ($self, $max) = @_;

   $self->{gauge}->set_max ($max);
   $self->{max}->set_text ($max);
}

sub set_value {
   my ($self, $val, $max) = @_;

   $self->set_max ($max)
      if defined $max;

   $self->{gauge}->set_value ($val, $max);
   $self->{value}->set_text ($val);
}

#############################################################################

package CFPlus::UI::Slider;

use strict;

use CFPlus::OpenGL;

our @ISA = CFPlus::UI::DrawBG::;

my @tex =
      map { new_from_file CFPlus::Texture CFPlus::find_rcfile $_ }
         qw(s1_slider.png s1_slider_bg.png);

sub new {
   my $class = shift;

   # range [value, low, high, page, unit]

   # TODO: 0-width page
   # TODO: req_w/h are wrong with vertical
   # TODO: calculations are off
   my $self = $class->SUPER::new (
      fg        => [1, 1, 1],
      active_fg => [0, 0, 0],
      bg        => [0, 0, 0, 0.2],
      active_bg => [1, 1, 1, 0.5],
      range     => [0, 0, 100, 10, 0],
      min_w     => $::WIDTH / 80,
      min_h     => $::WIDTH / 80,
      vertical  => 0,
      can_hover => 1,
      inner_pad => 0.02,
      @_
   );

   $self->set_value ($self->{range}[0]);
   $self->update;

   $self
}

sub set_range {
   my ($self, $range) = @_;

   ($range, $self->{range}) = ($self->{range}, $range);

   if ("@$range" ne "@{$self->{range}}") {
      $self->update;
      $self->set_value ($self->{range}[0]);
   }
}

sub set_value {
   my ($self, $value) = @_;

   my ($old_value, $lo, $hi, $page, $unit) = @{$self->{range}};

   $hi = $lo + 1 if $hi <= $lo;

   $page = $hi - $lo if $page > $hi - $lo;

   $value = $lo         if $value < $lo;
   $value = $hi - $page if $value > $hi - $page;

   $value = $lo + $unit * int +($value - $lo + $unit * 0.5) / $unit
      if $unit;

   @{$self->{range}} = ($value, $lo, $hi, $page, $unit);

   if ($value != $old_value) {
      $self->emit (changed => $value);
      $self->update;
   }
}

sub size_request {
   my ($self) = @_;

   ($self->{req_w}, $self->{req_h})
}

sub invoke_button_down {
   my ($self, $ev, $x, $y) = @_;

   $self->SUPER::invoke_button_down ($ev, $x, $y);

   $self->{click} = [$self->{range}[0], $self->{vertical} ? $y : $x];
   
   $self->invoke_mouse_motion ($ev, $x, $y)
}

sub invoke_mouse_motion {
   my ($self, $ev, $x, $y) = @_;

   if ($GRAB == $self) {
      my ($x, $w) = $self->{vertical} ? ($y, $self->{h}) : ($x, $self->{w});

      my (undef, $lo, $hi, $page) = @{$self->{range}};

      $x = ($x - $self->{click}[1]) / ($w * $self->{scale});

      $self->set_value ($self->{click}[0] + $x * ($hi - $page - $lo));
   } else {
      return 0;
   }

   1
}

sub invoke_mouse_wheel {
   my ($self, $ev) = @_;

   my $delta = $self->{vertical} ? $ev->{dy} : $ev->{dx};

   $self->set_value ($self->{range}[0] + $delta * $self->{range}[3] * 0.2);

   ! ! $delta
}

sub update {
   my ($self) = @_;

   delete $self->{knob_w};
   $self->SUPER::update;
}

sub _draw {
   my ($self) = @_;

   unless ($self->{knob_w}) {
      $self->set_value ($self->{range}[0]);

      my ($value, $lo, $hi, $page) = @{$self->{range}};
      my $range = ($hi - $page - $lo) || 1e-100;

      my $knob_w = List::Util::min 1, $page / ($hi - $lo) || 0.1;

      $self->{offset} = List::Util::max $self->{inner_pad}, $knob_w * 0.5;
      $self->{scale} = 1 - 2 * $self->{offset} || 1e-100;

      $value = ($value - $lo) / $range;
      $value = $value * $self->{scale} + $self->{offset};

      $self->{knob_x} = $value - $knob_w * 0.5;
      $self->{knob_w} = $knob_w;
   }

   $self->SUPER::_draw ();

   glScale $self->{w}, $self->{h};

   if ($self->{vertical}) {
      # draw a vertical slider like a rotated horizontal slider
 
      glTranslate 1, 0, 0;
      glRotate 90, 0, 0, 1;
   }

   my $fg = $FOCUS == $self ? $self->{active_fg} : $self->{fg};
   my $bg = $FOCUS == $self ? $self->{active_bg} : $self->{bg};

   glEnable GL_TEXTURE_2D;
   glTexEnv GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE;

   # draw background
   $tex[1]->draw_quad_alpha (0, 0, 1, 1);

   # draw handle
   $tex[0]->draw_quad_alpha ($self->{knob_x}, 0, $self->{knob_w}, 1);

   glDisable GL_TEXTURE_2D;
}

#############################################################################

package CFPlus::UI::ValSlider;

our @ISA = CFPlus::UI::HBox::;

sub new {
   my ($class, %arg) = @_;

   my $range = delete $arg{range};

   my $self = $class->SUPER::new (
      slider     => (new CFPlus::UI::Slider expand => 1, range => $range),
      entry      => (new CFPlus::UI::Label text => "", template => delete $arg{template}),
      to_value   => sub { shift },
      from_value => sub { shift },
      %arg,
   );

   $self->{slider}->connect (changed => sub {
      my ($self, $value) = @_;
      $self->{parent}{entry}->set_text ($self->{parent}{to_value}->($value));
      $self->{parent}->emit (changed => $value);
   });

#   $self->{entry}->connect (changed => sub {
#      my ($self, $value) = @_;
#      $self->{parent}{slider}->set_value ($self->{parent}{from_value}->($value));
#      $self->{parent}->emit (changed => $value);
#   });

   $self->add ($self->{slider}, $self->{entry});

   $self->{slider}->emit (changed => $self->{slider}{range}[0]);

   $self
}

sub set_range { shift->{slider}->set_range (@_) }
sub set_value { shift->{slider}->set_value (@_) }

#############################################################################

package CFPlus::UI::TextScroller;

our @ISA = CFPlus::UI::HBox::;

use CFPlus::OpenGL;

sub new {
   my $class = shift;

   my $self = $class->SUPER::new (
      fontsize   => 1,
      can_events => 1,
      indent     => 0,
      #font      => default_font
      @_,
                 
      layout     => (new CFPlus::Layout),
      par        => [],
      height     => 0,
      children   => [
         (new CFPlus::UI::Empty expand => 1),
         (new CFPlus::UI::Slider vertical => 1),
      ],
   );

   $self->{children}[1]->connect (changed => sub { $self->update });

   $self
}

sub set_fontsize {
   my ($self, $fontsize) = @_;

   $self->{fontsize} = $fontsize;
   $self->reflow;
}

sub size_request {
   my ($self) = @_;

   my ($empty, $slider) = @{ $self->{children} };

   local $self->{children} = [$empty, $slider];
   $self->SUPER::size_request
}

sub invoke_size_allocate {
   my ($self, $w, $h) = @_;

   my ($empty, $slider, @other) = @{ $self->{children} };
   $_->configure (@$_{qw(x y req_w req_h)}) for @other;

   $self->{layout}->set_font ($self->{font}) if $self->{font};
   $self->{layout}->set_height ($self->{fontsize} * $::FONTSIZE);
   $self->{layout}->set_width ($empty->{w});
   $self->{layout}->set_indent ($self->{fontsize} * $::FONTSIZE * $self->{indent});

   $self->reflow;

   local $self->{children} = [$empty, $slider];
   $self->SUPER::invoke_size_allocate ($w, $h)
}

sub invoke_mouse_wheel {
   my ($self, $ev) = @_;

   return 0 unless $ev->{dy}; # only vertical movements

   $self->{children}[1]->emit (mouse_wheel => $ev);

   1
}

sub get_layout {
   my ($self, $para) = @_;

   my $layout = $self->{layout};

   $layout->set_font ($self->{font}) if $self->{font};
   $layout->set_foreground (@{$para->{fg}});
   $layout->set_height ($self->{fontsize} * $::FONTSIZE);
   $layout->set_width ($self->{children}[0]{w} - $para->{indent});
   $layout->set_indent ($self->{fontsize} * $::FONTSIZE * $self->{indent});
   $layout->set_markup ($para->{markup});

   $layout->set_shapes (
      map
         +(0, $_->baseline_shift +$_->{padding_y} - $_->{h}, $_->{w}, $_->{h}),
         @{$para->{widget}}
   );

   $layout
}

sub reflow {
   my ($self) = @_;

   $self->{need_reflow}++;
   $self->update;
}

sub set_offset {
   my ($self, $offset) = @_;

   # todo: base offset on lines or so, not on pixels
   $self->{children}[1]->set_value ($offset);
}

sub clear {
   my ($self) = @_;

   my (undef, undef, @other) = @{ $self->{children} };
   $self->remove ($_) for @other;

   $self->{par} = [];
   $self->{height} = 0;
   $self->{children}[1]->set_range ([0, 0, 0, 1, 1]);
}

sub add_paragraph {
   my $self = shift;

   for my $para (@_) {
      $para = {
         fg      => [1, 1, 1, 1],
         indent  => 0,
         markup  => "",
         widget  => [],
         ref $para ? %$para : (markup => $para),
         w       => 1e10,
         wrapped => 1,
      };

      $self->add (@{ $para->{widget} }) if @{ $para->{widget} };
      push @{$self->{par}}, $para;
   }

   $self->{need_reflow}++;
   $self->update;
}

sub scroll_to_bottom {
   my ($self) = @_;

   $self->{scroll_to_bottom} = 1;
   $self->update;
}

sub update {
   my ($self) = @_;

   $self->SUPER::update;

   return unless $self->{h} > 0;

   delete $self->{texture};

   $ROOT->on_post_alloc ($self => sub {
      my ($W, $H) = @{$self->{children}[0]}{qw(w h)};

      if (delete $self->{need_reflow}) {
         my $height = 0;

         for my $para (@{$self->{par}}) {
            if ($para->{w} != $W && ($para->{wrapped} || $para->{w} > $W)) {
               my $layout = $self->get_layout ($para);
               my ($w, $h) = $layout->size;

               $para->{w}       = $w + $para->{indent};
               $para->{h}       = $h;
               $para->{wrapped} = $layout->has_wrapped;
            }

            $height += $para->{h};
         }

         $self->{height} = $height;

         $self->{children}[1]->set_range ([$self->{children}[1]{range}[0], 0, $height, $H, 1]);

         delete $self->{texture};
      }

      if (delete $self->{scroll_to_bottom}) {
         $self->{children}[1]->set_value (1e10);
      }

      $self->{texture} ||= new_from_opengl CFPlus::Texture $W, $H, sub {
         glClearColor 0, 0, 0, 0;
         glClear GL_COLOR_BUFFER_BIT;

         my $top = int $self->{children}[1]{range}[0];

         my $y0 = $top;
         my $y1 = $top + $H;

         my $y = 0;

         for my $para (@{$self->{par}}) {
            my $h = $para->{h};

            if ($y0 < $y + $h && $y < $y1) {

               my $layout = $self->get_layout ($para);

               $layout->render ($para->{indent}, $y - $y0);

               if (my @w = @{ $para->{widget} }) {
                  my @s = $layout->get_shapes;

                  for (@w) {
                     my ($dx, $dy) = splice @s, 0, 2, ();

                     $_->{x} = $dx + $para->{indent};
                     $_->{y} = $dy + $y - $y0;

                     $_->draw;
                  }
               }
            }

            $y += $h;
         }
      };
   });
}

sub reconfigure {
   my ($self) = @_;

   $self->SUPER::reconfigure;

   $_->{w} = 1e10 for @{ $self->{par} };
   $self->reflow;
}

sub _draw {
   my ($self) = @_;

   glEnable GL_TEXTURE_2D;
   glTexEnv GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE;
   glColor 0, 0, 0, 1;
   $self->{texture}->draw_quad_alpha_premultiplied (0, 0, $self->{children}[0]{w}, $self->{children}[0]{h});
   glDisable GL_TEXTURE_2D;

   $self->{children}[1]->draw;
}

#############################################################################

package CFPlus::UI::Animator;

use CFPlus::OpenGL;

our @ISA = CFPlus::UI::Bin::;

sub moveto {
   my ($self, $x, $y) = @_;

   $self->{moveto} = [$self->{x}, $self->{y}, $x, $y];
   $self->{speed}  = 0.001;
   $self->{time}   = 1;
   
   ::animation_start $self;
}

sub animate {
   my ($self, $interval) = @_;

   $self->{time} -= $interval * $self->{speed};
   if ($self->{time} <= 0) {
      $self->{time} = 0;
      ::animation_stop $self;
   }

   my ($x0, $y0, $x1, $y1) = @{$self->{moveto}};
      
   $self->{x} = $x0 * $self->{time} + $x1 * (1 - $self->{time});
   $self->{y} = $y0 * $self->{time} + $y1 * (1 - $self->{time});
}

sub _draw {
   my ($self) = @_;

   glPushMatrix;
   glRotate $self->{time} * 1000, 0, 1, 0;
   $self->{children}[0]->draw;
   glPopMatrix;
}

#############################################################################

package CFPlus::UI::Flopper;

our @ISA = CFPlus::UI::Button::;

sub new {
   my $class = shift;

   my $self = $class->SUPER::new (
      state       => 0,
      on_activate => \&toggle_flopper,
      @_
   );

   $self
}

sub toggle_flopper {
   my ($self) = @_;

   $self->{other}->toggle_visibility;
}

#############################################################################

package CFPlus::UI::Tooltip;

our @ISA = CFPlus::UI::Bin::;

use CFPlus::OpenGL;

sub new {
   my $class = shift;

   $class->SUPER::new (
      @_,
      can_events => 0,
   )
}

sub set_tooltip_from {
   my ($self, $widget) = @_;

   my $tooltip = $widget->{tooltip};

   if ($ENV{CFPLUS_DEBUG} & 2) {
      $tooltip .= "\n\n" . (ref $widget) . "\n"
                . "$widget->{x} $widget->{y} $widget->{w} $widget->{h}\n"
                . "req $widget->{req_w} $widget->{req_h}\n"
                . "visible $widget->{visible}";
   }

   $tooltip =~ s/^\n+//;
   $tooltip =~ s/\n+$//;

   $self->add (new CFPlus::UI::Label
      markup    => $tooltip,
      max_w     => ($widget->{tooltip_width} || 0.25) * $::WIDTH,
      fontsize  => 0.8,
      fg        => [0, 0, 0, 1],
      ellipsise => 0,
      font      => ($widget->{tooltip_font} || $::FONT_PROP),
   );
}

sub size_request {
   my ($self) = @_;

   my ($w, $h) = @{$self->child}{qw(req_w req_h)};

   ($w + 4, $h + 4)
}

sub invoke_size_allocate {
   my ($self, $w, $h) = @_;

   $self->SUPER::invoke_size_allocate ($w - 4, $h - 4)
}

sub invoke_visibility_change {
   my ($self, $visible) = @_;

   return unless $visible;

   $self->{root}->on_post_alloc ("move_$self" => sub {
      my $widget = $self->{owner}
         or return;

      if ($widget->{visible}) {
         my ($x, $y) = $widget->coord2global ($widget->{w}, 0);

         ($x, $y) = $widget->coord2global (-$self->{w}, 0)
            if $x + $self->{w} > $self->{root}{w};

         $self->move_abs ($x, $y);
      } else {
         $self->hide;
      }
   });
}

sub _draw {
   my ($self) = @_;

   glTranslate 0.375, 0.375;

   my ($w, $h) = @$self{qw(w h)};

   glColor 1, 0.8, 0.4;
   glBegin GL_QUADS;
   glVertex 0 , 0;
   glVertex 0 , $h;
   glVertex $w, $h;
   glVertex $w, 0;
   glEnd;
   
   glColor 0, 0, 0;
   glBegin GL_LINE_LOOP;
   glVertex 0 , 0;
   glVertex 0 , $h;
   glVertex $w, $h;
   glVertex $w, 0;
   glEnd;
   
   glTranslate 2 - 0.375, 2 - 0.375;

   $self->SUPER::_draw;
}

#############################################################################

package CFPlus::UI::Face;

our @ISA = CFPlus::UI::DrawBG::;

use CFPlus::OpenGL;

sub new {
   my $class = shift;

   my $self = $class->SUPER::new (
      aspect     => 1,
      can_events => 0,
      @_,
   );

   if ($self->{anim} && $self->{animspeed}) {
      Scalar::Util::weaken (my $widget = $self);

      $self->{timer} = Event->timer (
         at       => $self->{animspeed} * int $::NOW / $self->{animspeed},
         hard     => 1,
         interval => $self->{animspeed},
         cb       => sub {
            ++$widget->{frame};
            $widget->update;
         },
      );
   }
   
   $self
}

sub size_request {
   (32, 8)
}

sub update {
   my ($self) = @_;

   return unless $self->{visible};

   $self->SUPER::update;
}

sub _draw {
   my ($self) = @_;

   return unless $::CONN;

   $self->SUPER::_draw;

   my $face;

   if ($self->{frame}) {
      my $anim = $::CONN->{anim}[$self->{anim}];

      $face = $anim->[ $self->{frame} % @$anim ]
         if $anim && @$anim;
   }
   
   my $tex = $::CONN->{texture}[$::CONN->{faceid}[$face || $self->{face}]];

   if ($tex) {
      glEnable GL_TEXTURE_2D;
      glTexEnv GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE;
      glColor 0, 0, 0, 1;
      $tex->draw_quad_alpha (0, 0, $self->{w}, $self->{h});
      glDisable GL_TEXTURE_2D;
   }
}

sub destroy {
   my ($self) = @_;

   $self->{timer}->cancel
      if $self->{timer};

   $self->SUPER::destroy;
}

#############################################################################

package CFPlus::UI::Buttonbar;

our @ISA = CFPlus::UI::HBox::;

# TODO: should actualyl wrap buttons and other goodies.

#############################################################################

package CFPlus::UI::Menu;

our @ISA = CFPlus::UI::FancyFrame::;

use CFPlus::OpenGL;

sub new {
   my $class = shift;

   my $self = $class->SUPER::new (
      items => [],
      z     => 100,
      @_,
   );

   $self->add ($self->{vbox} = new CFPlus::UI::VBox);

   for my $item (@{ $self->{items} }) {
      my ($widget, $cb, $tooltip) = @$item;

      # handle various types of items, only text for now
      if (!ref $widget) {
         if ($widget =~ /\t/) {
            my ($left, $right) = split /\t/, $widget, 2;

            $widget = new CFPlus::UI::HBox
               can_hover  => 1,
               can_events => 1,
               tooltip    => $tooltip,
               children   => [
                  (new CFPlus::UI::Label markup => $left, expand => 1),
                  (new CFPlus::UI::Label markup => $right, align => +1),
               ],
            ;
               
         } else {
            $widget = new CFPlus::UI::Label
               can_hover  => 1,
               can_events => 1,
               markup     => $widget,
               tooltip    => $tooltip;
         }
      }

      $self->{item}{$widget} = $item;

      $self->{vbox}->add ($widget);
   }

   $self
}

# popup given the event (must be a mouse button down event currently)
sub popup {
   my ($self, $ev) = @_;

   $self->emit ("popdown");

   # maybe save $GRAB? must be careful about events...
   $GRAB = $self;
   $self->{button} = $ev->{button};

   $self->show;
   $self->move_abs ($ev->{x} - $self->{w} * 0.5, $ev->{y} - $self->{h} * 0.5);
}

sub invoke_mouse_motion {
   my ($self, $ev, $x, $y) = @_;

   # TODO: should use vbox->find_widget or so
   $HOVER = $ROOT->find_widget ($ev->{x}, $ev->{y});
   $self->{hover} = $self->{item}{$HOVER};

   0
}

sub invoke_button_up {
   my ($self, $ev, $x, $y) = @_;

   if ($ev->{button} == $self->{button}) {
      undef $GRAB;
      $self->hide;

      $self->emit ("popdown");
      $self->{hover}[1]->() if $self->{hover};
   } else {
      return 0
   }

   1
}

#############################################################################

package CFPlus::UI::Multiplexer;

our @ISA = CFPlus::UI::Container::;

sub new {
   my $class = shift;

   my $self = $class->SUPER::new (
      @_,
   );

   $self->{current} = $self->{children}[0]
      if @{ $self->{children} };

   $self
}

sub add {
   my ($self, @widgets) = @_;

   $self->SUPER::add (@widgets);

   $self->{current} = $self->{children}[0]
      if @{ $self->{children} };
}

sub get_current_page {
   my ($self) = @_;

   $self->{current}
}

sub set_current_page {
   my ($self, $page_or_widget) = @_;

   my $widget = ref $page_or_widget
                   ? $page_or_widget
                   : $self->{children}[$page_or_widget];

   $self->{current} = $widget;
   $self->{current}->configure (0, 0, $self->{w}, $self->{h});

   $self->emit (page_changed => $self->{current});

   $self->realloc;
}

sub visible_children {
   $_[0]{current}
}

sub size_request {
   my ($self) = @_;

   $self->{current}->size_request
}

sub invoke_size_allocate {
   my ($self, $w, $h) = @_;

   $self->{current}->configure (0, 0, $w, $h);

   1
}

sub _draw {
   my ($self) = @_;

   $self->{current}->draw;
}

#############################################################################

package CFPlus::UI::Notebook;

our @ISA = CFPlus::UI::VBox::;

sub new {
   my $class = shift;

   my $self = $class->SUPER::new (
      buttonbar   => (new CFPlus::UI::Buttonbar),
      multiplexer => (new CFPlus::UI::Multiplexer expand => 1),
      # filter => # will be put between multiplexer and $self
      @_,
   );
   
   $self->{filter}->add ($self->{multiplexer}) if $self->{filter};
   $self->SUPER::add ($self->{buttonbar}, $self->{filter} || $self->{multiplexer});

   $self
}

sub add {
   my ($self, $title, $widget, $tooltip) = @_;

   Scalar::Util::weaken $self;

   $self->{buttonbar}->add (new CFPlus::UI::Button
      markup      => $title,
      tooltip     => $tooltip,
      on_activate => sub { $self->set_current_page ($widget) },
   );

   $self->{multiplexer}->add ($widget);
}

sub get_current_page {
   my ($self) = @_;

   $self->{multiplexer}->get_current_page
}

sub set_current_page {
   my ($self, $page) = @_;

   $self->{multiplexer}->set_current_page ($page);
   $self->emit (page_changed => $self->{multiplexer}{current});
}

#############################################################################

package CFPlus::UI::Selector;

use utf8;

our @ISA = CFPlus::UI::Button::;

sub new {
   my $class = shift;

   my $self = $class->SUPER::new (
      options => [], # [value, title, longdesc], ...
      value   => undef,
      @_,
   );

   $self->_set_value ($self->{value});

   $self
}

sub invoke_button_down {
   my ($self, $ev) = @_;

   my @menu_items;

   for (@{ $self->{options} }) {
      my ($value, $title, $tooltip) = @$_;

      push @menu_items, [$tooltip || $title, sub { $self->set_value ($value) }];
   }

   CFPlus::UI::Menu->new (items => \@menu_items)->popup ($ev);
}

sub _set_value {
   my ($self, $value) = @_;

   my ($item) = grep $_->[0] eq $value, @{ $self->{options} }
      or return;

   $self->{value} = $item->[0];
   $self->set_markup ("$item->[1] ⇓");
   $self->set_tooltip ($item->[2]);
}

sub set_value {
   my ($self, $value) = @_;

   return unless $self->{value} ne $value;

   $self->_set_value ($value);
   $self->emit (changed => $value);
}

#############################################################################

package CFPlus::UI::Statusbox;

our @ISA = CFPlus::UI::VBox::;

sub new {
   my $class = shift;

   my $self = $class->SUPER::new (
      fontsize => 0.8,
      @_,
   );

   Scalar::Util::weaken (my $this = $self);

   $self->{timer} = Event->timer (after => 1, interval => 1, cb => sub { $this->reorder });

   $self
}

sub reorder {
   my ($self) = @_;
   my $NOW = Time::HiRes::time;

   # freeze display when hovering over any label
   return if $CFPlus::UI::TOOLTIP->{owner}
             && grep $CFPlus::UI::TOOLTIP->{owner} == $_->{label},
                   values %{ $self->{item} };

   while (my ($k, $v) = each %{ $self->{item} }) {
      delete $self->{item}{$k} if $v->{timeout} < $NOW;
   }

   my @widgets;

   my @items = sort {
                  $a->{pri} <=> $b->{pri}
                     or $b->{id} <=> $a->{id}
               } values %{ $self->{item} };

   $self->{timer}->interval (1);

   my $count = 10 + 1;
   for my $item (@items) {
      last unless --$count;

      my $label = $item->{label} ||= do {
         # TODO: doesn't handle markup well (read as: at all)
         my $short = $item->{count} > 1
                     ? "<b>$item->{count} ×</b> $item->{text}"
                     : $item->{text};

         for ($short) {
            s/^\s+//;
            s/\s+/ /g;
         }

         new CFPlus::UI::Label
            markup        => $short,
            tooltip       => $item->{tooltip},
            tooltip_font  => $::FONT_PROP,
            tooltip_width => 0.67,
            fontsize      => $item->{fontsize} || $self->{fontsize},
            max_w         => $::WIDTH * 0.44,
            fg            => [@{ $item->{fg} }],
            can_events    => 1,
            can_hover     => 1
      };

      if ((my $diff = $item->{timeout} - $NOW) < 2) {
         $label->{fg}[3] = ($item->{fg}[3] || 1) * $diff / 2;
         $label->update;
         $label->set_max_size (undef, $label->{req_h} * $diff)
            if $diff < 1;
         $self->{timer}->interval (1/30);
      } else {
         $label->{fg}[3] = $item->{fg}[3] || 1;
      }

      push @widgets, $label;
   }

   $self->clear;
   $self->SUPER::add (reverse @widgets);
}

sub add {
   my ($self, $text, %arg) = @_;

   $text =~ s/^\s+//;
   $text =~ s/\s+$//;

   return unless $text;

   my $timeout = (int time) + ((delete $arg{timeout}) || 60);

   my $group = exists $arg{group} ? $arg{group} : ++$self->{id};

   if (my $item = $self->{item}{$group}) {
      if ($item->{text} eq $text) {
         $item->{count}++;
      } else {
         $item->{count} = 1;
         $item->{text} = $item->{tooltip} = $text;
      }
      $item->{id} += 0.2;#d#
      $item->{timeout} = $timeout;
      delete $item->{label};
   } else {
      $self->{item}{$group} = {
         id       => ++$self->{id},
         text     => $text,
         timeout  => $timeout,
         tooltip  => $text,
         fg       => [0.8, 0.8, 0.8, 0.8],
         pri      => 0,
         count    => 1,
         %arg,
      };
   }

   $ROOT->on_refresh (reorder => sub {
      $self->reorder;
   });
}

sub reconfigure {
   my ($self) = @_;

   delete $_->{label}
      for values %{ $self->{item} || {} };

   $self->reorder;
   $self->SUPER::reconfigure;
}

sub destroy {
   my ($self) = @_;

   $self->{timer}->cancel;

   $self->SUPER::destroy;
}

#############################################################################

package CFPlus::UI::Inventory;

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

#############################################################################

package CFPlus::UI::SpellList;

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

      $self->add (1, 0, new CFPlus::UI::Label text => "Spell Name", @TOOLTIP_NAME);
      $self->add (2, 0, new CFPlus::UI::Label text => "Skill", @TOOLTIP_SKILL);
      $self->add (3, 0, new CFPlus::UI::Label text => "Lvl"  , @TOOLTIP_LVL);
      $self->add (4, 0, new CFPlus::UI::Label text => "Sp/Gp", @TOOLTIP_SP);
      $self->add (5, 0, new CFPlus::UI::Label text => "Dmg"  , @TOOLTIP_DMG);

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
               (new CFPlus::UI::Menu
                  items => [
                     ["bind <i>cast $spell->{name}</i> to a key"   => sub { $::BIND_EDITOR->do_quick_binding (["cast $spell->{name}"]) }],
                     ["bind <i>invoke $spell->{name}</i> to a key" => sub { $::BIND_EDITOR->do_quick_binding (["invoke $spell->{name}"]) }],
                  ],
               )->popup ($ev);
            } else {
               return 0;
            }

            1
         };

         my $tooltip = "$spell->{message}$TOOLTIP_ALL";

         #TODO: add path info to tooltip
         #$self->add (6, $row, new CFPlus::UI::Label text => $spell->{path});

         $self->add (0, $row, new CFPlus::UI::Face
            face       => $spell->{face},
            can_hover  => 1,
            can_events => 1,
            tooltip    => $tooltip,
            on_button_down => $spell_cb,
         );

         $self->add (1, $row, new CFPlus::UI::Label
            expand     => 1,
            text       => $spell->{name},
            can_hover  => 1,
            can_events => 1,
            tooltip    => $tooltip,
            on_button_down => $spell_cb,
         );

         $self->add (2, $row, new CFPlus::UI::Label text => $::CONN->{skill_info}{$spell->{skill}}, @TOOLTIP_SKILL);
         $self->add (3, $row, new CFPlus::UI::Label text => $spell->{level}, @TOOLTIP_LVL);
         $self->add (4, $row, new CFPlus::UI::Label text => $spell->{mana} || $spell->{grace}, @TOOLTIP_SP);
         $self->add (5, $row, new CFPlus::UI::Label text => $spell->{damage}, @TOOLTIP_DMG);
      }
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

#############################################################################

package CFPlus::UI::Root;

our @ISA = CFPlus::UI::Container::;

use List::Util qw(min max);

use CFPlus::OpenGL;

sub new {
   my $class = shift;

   my $self = $class->SUPER::new (
      visible => 1,
      @_,
   );

   Scalar::Util::weaken ($self->{root} = $self);

   $self
}

sub size_request {
   my ($self) = @_;

   ($self->{w}, $self->{h})
}

sub _to_pixel {
   my ($coord, $size, $max) = @_;

   $coord =
      $coord eq "center" ? ($max - $size) * 0.5
    : $coord eq "max"    ? $max
    :                      $coord;

   $coord = 0            if $coord < 0;
   $coord = $max - $size if $coord > $max - $size;

   int $coord + 0.5
}

sub invoke_size_allocate {
   my ($self, $w, $h) = @_;

   for my $child ($self->children) {
      my ($X, $Y, $W, $H) = @$child{qw(x y req_w req_h)};

      $X = $child->{force_x} if exists $child->{force_x};
      $Y = $child->{force_y} if exists $child->{force_y};

      $X = _to_pixel $X, $W, $self->{w};
      $Y = _to_pixel $Y, $H, $self->{h};

      $child->configure ($X, $Y, $W, $H);
   }

   1
}

sub coord2local {
   my ($self, $x, $y) = @_;

   ($x, $y)
}

sub coord2global {
   my ($self, $x, $y) = @_;

   ($x, $y)
}

sub update {
   my ($self) = @_;

   $::WANT_REFRESH++;
}

sub add {
   my ($self, @children) = @_;

   $_->{is_toplevel} = 1
      for @children;

   $self->SUPER::add (@children);
}

sub remove {
   my ($self, @children) = @_;

   $self->SUPER::remove (@children);

   delete $self->{is_toplevel}
      for @children;

   while (@children) {
      my $w = pop @children;
      push @children, $w->children;
      $w->set_invisible;
   }
}

sub on_refresh {
   my ($self, $id, $cb) = @_;

   $self->{refresh_hook}{$id} = $cb;
}

sub on_post_alloc {
   my ($self, $id, $cb) = @_;

   $self->{post_alloc_hook}{$id} = $cb;
}

sub draw {
   my ($self) = @_;

   while ($self->{refresh_hook}) {
      $_->()
         for values %{delete $self->{refresh_hook}};
   }

   if ($self->{realloc}) {
      my %queue;
      my @queue;
      my $widget;

      outer:
      while () {
         if (my $realloc = delete $self->{realloc}) {
            for $widget (values %$realloc) {
               $widget->{visible} or next; # do not resize invisible widgets

               $queue{$widget+0}++ and next; # duplicates are common

               push @{ $queue[$widget->{visible}] }, $widget;
            }
         }

         while () {
            @queue or last outer;

            $widget = pop @{ $queue[-1] || [] }
               and last;
            
            pop @queue;
         }

         delete $queue{$widget+0};

         my ($w, $h) = $widget->size_request;

         $w = max $widget->{min_w}, $w + $widget->{padding_x} * 2;
         $h = max $widget->{min_h}, $h + $widget->{padding_y} * 2;

         $w = min $widget->{max_w}, $w if exists $widget->{max_w};
         $h = min $widget->{max_h}, $h if exists $widget->{max_h};

         $w = $widget->{force_w} if exists $widget->{force_w};
         $h = $widget->{force_h} if exists $widget->{force_h};

         if ($widget->{req_w} != $w || $widget->{req_h} != $h
             || delete $widget->{force_realloc}) {
            $widget->{req_w} = $w;
            $widget->{req_h} = $h;

            $self->{size_alloc}{$widget+0} = $widget;

            if (my $parent = $widget->{parent}) {
               $self->{realloc}{$parent+0} = $parent
                  unless $queue{$parent+0};

               $parent->{force_size_alloc} = 1;
               $self->{size_alloc}{$parent+0} = $parent;
            }
         }

         delete $self->{realloc}{$widget+0};
       }
   }

   while (my $size_alloc = delete $self->{size_alloc}) {
      my @queue = sort { $b->{visible} <=> $a->{visible} }
                       values %$size_alloc;

      while () {
         my $widget = pop @queue || last;

         my ($w, $h) = @$widget{qw(alloc_w alloc_h)};

         $w = 0 if $w < 0;
         $h = 0 if $h < 0;

         $w = max $widget->{min_w}, $w;
         $h = max $widget->{min_h}, $h;

#         $w = min $self->{w} - $widget->{x}, $w if $self->{w};
#         $h = min $self->{h} - $widget->{y}, $h if $self->{h};

         $w = min $widget->{max_w}, $w if exists $widget->{max_w};
         $h = min $widget->{max_h}, $h if exists $widget->{max_h};

         $w = int $w + 0.5;
         $h = int $h + 0.5;

         if ($widget->{w} != $w || $widget->{h} != $h || delete $widget->{force_size_alloc}) {
            $widget->{old_w} = $widget->{w};
            $widget->{old_h} = $widget->{h};

            $widget->{w} = $w;
            $widget->{h} = $h;

            $widget->emit (size_allocate => $w, $h);
         }
      }
   }

   while ($self->{post_alloc_hook}) {
      $_->()
         for values %{delete $self->{post_alloc_hook}};
   }


   glViewport 0, 0, $::WIDTH, $::HEIGHT;
   glClearColor +($::CFG->{fow_intensity}) x 3, 1;
   glClear GL_COLOR_BUFFER_BIT;

   glMatrixMode GL_PROJECTION;
   glLoadIdentity;
   glOrtho 0, $::WIDTH, $::HEIGHT, 0, -10000, 10000;
   glMatrixMode GL_MODELVIEW;
   glLoadIdentity;

   {
      package CFPlus::UI::Base;

      ($draw_x, $draw_y, $draw_w, $draw_h) =
         (0, 0, $self->{w}, $self->{h});
   }

   $self->_draw;
}

#############################################################################

package CFPlus::UI;

$ROOT = new CFPlus::UI::Root;
$TOOLTIP = new CFPlus::UI::Tooltip z => 900;

1

