package CFPlus::Pod;

use strict;

use Pod::POM;

use CFPlus;
use CFPlus::UI;

our $VERSION = 1.02; # bump if resultant formatting changes

our @result;
our $indent;

package CFPlus::Pod::AsMarkup;

use strict;

use base "Pod::POM::View::Text";

*view_seq_file   =
*view_seq_code   =
*view_seq_bold   = sub { "<b>$_[1]</b>" };
*view_seq_italic = sub { "<i>$_[1]</i>" };
*view_seq_space  =
*view_seq_link   = sub { CFPlus::asxml $_[1] };
*view_seq_zero   =
*view_seq_index  = sub { };

sub view_seq_text {
   my $text = $_[1];
   $text =~ s/\s+/ /g;
   CFPlus::asxml $text
}

sub view_item {
   ("\t" x ($indent / 4))
   . $_[1]->title->present ($_[0])
   . "\n\n"
   . $_[1]->content->present ($_[0])
}

sub view_verbatim {
   (join "",
       map +("\t" x ($indent / 2)) . "<tt>$_</tt>\n",
          split /\n/, CFPlus::asxml $_[1])
   . "\n"
}

sub view_textblock {
   ("\t" x ($indent / 2)) . "$_[1]\n"
}

sub view_head1 {
   "\n\n<span foreground='#ffff00' size='x-large'>" . $_[1]->title->present ($_[0]) . "</span>\n\n"
   . $_[1]->content->present ($_[0])
};

sub view_head2 {
   "\n<span foreground='#ccccff' size='large'>" . $_[1]->title->present ($_[0]) . "</span>\n\n"
   . $_[1]->content->present ($_[0])
};

sub view_head3 {
   "\n<span size='large'>" . $_[1]->title->present ($_[0]) . "</span>\n\n"
   . $_[1]->content->present ($_[0])
};

sub view_over {
   local $indent = $indent + $_[1]->indent;
   $_[1]->content->present ($_[0])
}

package CFPlus::Pod::AsParagraphs;

use strict;

use base "Pod::POM::View";

*view_seq_file   =
*view_seq_code   =
*view_seq_bold   = sub { "<b>$_[1]</b>" };
*view_seq_italic = sub { "<i>$_[1]</i>" };
*view_seq_zero   = sub { };
*view_seq_space  = sub { my $text = $_[1]; $text =~ s/ /&#160;/g; $text };
*view_seq_index  = sub { warn "index<@_>\n"; $result[-1]{index}{$_[1]} = undef };

sub view_seq_text {
   my $text = $_[1];
   $text =~ s/\s+/ /g;
   CFPlus::asxml $text
}

sub view_seq_link {
   my (undef, $link) = @_;

   # TODO:
   # http://...
   # ref
   # pod/ref

   "<u>" . (CFPlus::asxml $_[1]) . "</u>";
}

sub view_item {
   push @result, {
      indent => $indent * 8,
      markup => $_[1]->title->present ($_[0]) . "\n\n",
   };
   $_[1]->content->present ($_[0]);
   ()
}

sub view_verbatim {
   push @result, {
      indent => $indent * 16,
      markup => "<tt>" . (CFPlus::asxml $_[1]) . "</tt>\n",
   };
   ()
}

sub view_textblock {
   push @result, {
      indent => $indent * 16,
      markup => "$_[1]\n",
   };
   ()
}

sub view_head1 {
   push @result, {
      indent => $indent * 16,
      markup => "\n\n<span foreground='#ffff00' size='x-large'>" . $_[1]->title->present ($_[0]) . "</span>\n",
   };
   $_[1]->content->present ($_[0]);
   ()
};

sub view_head2 {
   push @result, {
      indent => $indent * 16,
      markup => "\n\n<span foreground='#ccccff' size='large'>" . $_[1]->title->present ($_[0]) . "</span>\n",
   };
   $_[1]->content->present ($_[0]);
   ()
};

sub view_head3 {
   push @result, {
      indent => $indent * 16,
      markup => "\n\n<span size='large'>" . $_[1]->title->present ($_[0]) . "</span>\n",
   };
   $_[1]->content->present ($_[0]);
   ()
};

sub view_over {
   local $indent = $indent + $_[1]->indent;
   push @result, { indent => $indent };
   $_[1]->content->present ($_[0]);
   ()
}

sub view_for {
   if ($_[1]->format eq "image") {
      push @result, {
         indent => $indent * 16,
         markup => "\x{fffc}",
         widget => [new CFPlus::UI::Image path => "pod/" . $_[1]->text],
      };
   }
   ()
}

sub view {
   my ($self, $type, $item) = @_;

   $item->content->present ($self);
}

package CFPlus::Pod;

my $pod_cache = CFPlus::db_table "pod_cache";

sub load($$$$) {
   my ($path, $filtertype, $filterversion, $filtercb) = @_;

   stat $path
      or die "$path: $!";

   my $phash = join ",", $filterversion, $VERSION, (stat _)[7,9];

   my ($chash, $pom) = eval {
      local $SIG{__DIE__};
      @{ Storable::thaw $pod_cache->get ("$path/$filtertype") }
   };

   return $pom if $chash eq $phash;

   my $pod = do {
      local $/;
      open my $pod, "<:utf8", $_[0]
         or die "$_[0]: $!";
      <$pod>
   };

   #utf8::downgrade $pod;

   $pom = $filtercb->(Pod::POM->new->parse_text ($pod));

   $pod_cache->put ("$path/$filtertype" => Storable::nfreeze [$phash, $pom]);

   $pom
}

sub section($$) {
   my ($pod, $section) = @_;
}

sub as_markup($) {
   my ($pom) = @_;

   local $indent = 0;

   $pom->present ("CFPlus::Pod::AsMarkup")
}

sub as_paragraphs($) {
   my ($pom) = @_;

   local @result = ( { } );
   local $indent = 0;

   $pom->present ("CFPlus::Pod::AsParagraphs");

   [grep exists $_->{markup}, @result]
}

sub pod_paragraphs($) {
   load CFPlus::find_rcfile "pod/$_[0].pod",
      pod_paragraphs => 1, sub { as_paragraphs $_[0] };
}

