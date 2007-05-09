=head1 NAME

CFPlus - undocumented utility garbage for our crossfire client

=head1 SYNOPSIS

 use CFPlus;

=head1 DESCRIPTION

=over 4

=cut

package CFPlus;

use Carp ();

BEGIN {
   $VERSION = '0.98';

   use XSLoader;
   XSLoader::load "CFPlus", $VERSION;
}

use utf8;

use AnyEvent ();
use Pod::POM ();
use File::Path ();
use Storable (); # finally
use Fcntl ();

BEGIN {
   use Crossfire::Protocol::Base ();
   *to_json   = \&Crossfire::Protocol::Base::to_json;
   *from_json = \&Crossfire::Protocol::Base::from_json;
}

=item guard { BLOCK }

Returns an object that executes the given block as soon as it is destroyed.

=cut

sub guard(&) {
   bless \(my $cb = $_[0]), "CFPlus::Guard"
}

sub CFPlus::Guard::DESTROY {
   ${$_[0]}->()
}

=item shorten $string[, $maxlength]

=cut

sub shorten($;$) {
   my ($str, $len) = @_;
   substr $str, $len, (length $str), "..." if $len + 3 <= length $str;
   $str
}

sub asxml($) {
   local $_ = $_[0];

   s/&/&amp;/g;
   s/>/&gt;/g;
   s/</&lt;/g;

   $_
}

sub socketpipe() {
   socketpair my $fh1, my $fh2, Socket::AF_UNIX, Socket::SOCK_STREAM, Socket::PF_UNSPEC
      or die "cannot establish bidirectional pipe: $!\n";

   ($fh1, $fh2)
}

sub background(&;&) {
   my ($bg, $cb) = @_;

   my ($fh_r, $fh_w) = CFPlus::socketpipe;

   my $pid = fork;

   if (defined $pid && !$pid) {
      local $SIG{__DIE__};

      open STDOUT, ">&", $fh_w;
      open STDERR, ">&", $fh_w;
      close $fh_r;
      close $fh_w;

      $| = 1;

      eval { $bg->() };

      if ($@) {
         my $msg = $@;
         $msg =~ s/\n+/\n/;
         warn "FATAL: $msg";
         CFPlus::_exit 1;
      }

      # win32 is fucked up, of course. exit will clean stuff up,
      # which destroys our database etc. _exit will exit ALL
      # forked processes, because of the dreaded fork emulation.
      CFPlus::_exit 0;
   }

   close $fh_w;

   my $buffer;

   my $w; $w = AnyEvent->io (fh => $fh_r, poll => 'r', cb => sub {
      unless (sysread $fh_r, $buffer, 4096, length $buffer) {
         undef $w;
         $cb->();
         return;
      }

      while ($buffer =~ s/^(.*)\n//) {
         my $line = $1;
         $line =~ s/\s+$//;
         utf8::decode $line;
         if ($line =~ /^\x{e877}json_msg (.*)$/s) {
            $cb->(JSON::XS->new->allow_nonref->decode ($1));
         } else {
            ::message ({
               markup => "background($pid): " . CFPlus::asxml $line,
            });
         }
      }
   });
}

sub background_msg {
   my ($msg) = @_;

   $msg = "\x{e877}json_msg " . JSON::XS->new->allow_nonref->encode ($msg);
   $msg =~ s/\n//g;
   utf8::encode $msg;
   print $msg, "\n";
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

sub http_proxy {
   my @proxy = win32_proxy_info;

   if (@proxy) {
      "http://" . (@proxy < 2 ? "" : @proxy < 3 ? "$proxy[1]\@" : "$proxy[1]:$proxy[2]\@") . $proxy[0]
   } elsif (exists $ENV{http_proxy}) {
      $ENV{http_proxy}
   } else {
     ()
   }
}

sub set_proxy {
   my $proxy = http_proxy
      or return;

   $ENV{http_proxy} = $proxy;
}

sub lwp_useragent {
   require LWP::UserAgent;
   
   CFPlus::set_proxy;

   my $ua = LWP::UserAgent->new (
      agent      => "cfplus $VERSION",
      keep_alive => 1,
      env_proxy  => 1,
      timeout    => 30,
   );
}

sub lwp_check($) {
   my ($res) = @_;

   $res->is_error
      and die $res->status_line;

   $res
}

sub fh_nonblocking($$) {
   my ($fh, $nb) = @_;

   if ($^O eq "MSWin32") {
      $nb = (! ! $nb) + 0;
      ioctl $fh, 0x8004667e, \$nb; # FIONBIO
   } else {
      fcntl $fh, &Fcntl::F_SETFL, $nb ? &Fcntl::O_NONBLOCK : 0;
   }

}

package CFPlus::Layout;

$CFPlus::OpenGL::SHUTDOWN_HOOK{"CFPlus::Layout"} = sub {
   reset_glyph_cache;
};

1;

=back

=head1 AUTHOR

 Marc Lehmann <schmorp@schmorp.de>
 http://home.schmorp.de/

=cut

