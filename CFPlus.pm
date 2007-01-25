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
   $VERSION = '0.97';

   use XSLoader;
   XSLoader::load "CFPlus", $VERSION;
}

use utf8;

use AnyEvent ();
use BerkeleyDB;
use Pod::POM ();
use File::Path ();
use Storable (); # finally

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
      or die "cannot establish bidiretcional pipe: $!\n";

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
            $cb->(from_json $1);
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

   $msg = "\x{e877}json_msg " . to_json $msg;
   $msg =~ s/\n//g;
   utf8::encode $msg;
   print $msg, "\n";
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

   my $hkey = $db + 0;
   CFPlus::weaken $db;
   $DB_SYNC{$hkey} ||= AnyEvent->timer (after => 30, cb => sub {
      delete $DB_SYNC{$hkey};
      $db->db_sync if $db;
   });

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

our $DB_ENV;
our $DB_STATE;

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

our $DB_HOME = "$Crossfire::VARDIR/cfplus";

sub open_db {
   use strict;

   mkdir $DB_HOME, 0777;
   my $recover = $BerkeleyDB::db_version >= 4.4 
                 ? eval "DB_REGISTER | DB_RECOVER"
                 : 0;

   $DB_ENV = new BerkeleyDB::Env
                    -Home => $DB_HOME,
                    -Cachesize => 8_000_000,
                    -ErrFile => "$DB_HOME/errorlog.txt",
#                 -ErrPrefix => "DATABASE",
                    -Verbose => 1,
                    -Flags => DB_CREATE | DB_RECOVER | DB_INIT_MPOOL | DB_INIT_LOCK | DB_INIT_TXN | $recover,
                    -SetFlags => DB_AUTO_COMMIT | DB_LOG_AUTOREMOVE,
                       or die "unable to create/open database home $DB_HOME: $BerkeleyDB::Error";

   $DB_STATE = db_table "state";

   1
}

unless (eval { open_db }) {
   File::Path::rmtree $DB_HOME;
   open_db;
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

