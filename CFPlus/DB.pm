=head1 NAME

CFPlus::DB - async. database and filesystem access for cfplus

=head1 SYNOPSIS

 use CFPlus::DB;

=head1 DESCRIPTION

=over 4

=cut

package CFPlus::DB;

use strict;
use utf8;

use Carp ();
use Storable ();
use Config;

use CFPlus;

our $DB_HOME = "$Crossfire::VARDIR/cfplus-$BerkeleyDB::db_version-$Config{archname}";

sub path_of_res($) {
   utf8::downgrade $_[0]; # bug in unpack "H*"
   "$DB_HOME/res-data-" . unpack "H*", $_[0]
}

sub sync {
   # for debugging
   #CFPlus::DB::Server::req (sync => sub { });
   CFPlus::DB::Server::sync ();
}

sub exists($$$) {
   CFPlus::DB::Server::req (exists => @_);
}

sub get($$$) {
   CFPlus::DB::Server::req (get => @_);
}

sub put($$$$) {
   CFPlus::DB::Server::req (put => @_);
}

sub unlink($$) {
   CFPlus::DB::Server::req (unlink => @_);
}

sub read_file($$) {
   CFPlus::DB::Server::req (read_file => @_);
}

sub write_file($$$) {
   CFPlus::DB::Server::req (write_file => @_);
}

sub prefetch_file($$$) {
   CFPlus::DB::Server::req (prefetch_file => @_);
}

sub logprint($$$) {
   CFPlus::DB::Server::req (logprint => @_);
}

our $tilemap;

sub get_tile_id_sync($) {
   my ($name) = @_;

   # fetch the full face table first
   unless ($tilemap) {
      CFPlus::DB::Server::req (table => facemap => sub {
         $tilemap = $_[0];
         delete $tilemap->{id};
         my %maptile = reverse %$tilemap;#d#
         if ((scalar keys %$tilemap) != (scalar keys %maptile)) {#d#
            $tilemap = { };#d#
            CFPlus::error "FATAL: facemap is not a 1:1 mapping, please report this and delete your $DB_HOME directory!\n";#d#
         }#d#
      });
      sync;
   }

   $tilemap->{$name} ||= do {
      my $id;
      CFPlus::DB::Server::req (get_tile_id => $name, sub { $id = $_[0] });
      sync;
      $id
   }
}

package CFPlus::DB::Server;

use strict;

use EV ();
use Fcntl;
use BerkeleyDB;

our $DB_ENV;
our $DB_STATE;
our %DB_TABLE;

sub open_db {
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
                    -SetFlags => DB_AUTO_COMMIT | DB_LOG_AUTOREMOVE | DB_TXN_WRITE_NOSYNC,
                       or die "unable to create/open database home $DB_HOME: $BerkeleyDB::Error";

   1
}

sub table($) {
   $DB_TABLE{$_[0]} ||= do {
      my ($table) = @_;

      $table =~ s/([^a-zA-Z0-9_\-])/sprintf "=%x=", ord $1/ge;

      new BerkeleyDB::Btree
         -Env      => $DB_ENV,
         -Filename => $table,
#      -Filename => "database",
#      -Subname  => $table,
         -Property => DB_CHKSUM,
         -Flags    => DB_AUTO_COMMIT | DB_CREATE | DB_UPGRADE,
            or die "unable to create/open database table $_[0]: $BerkeleyDB::Error"
   }
}

our %CB;
our $FH;
our $ID = "aaa0";
our ($fh_r_watcher, $fh_w_watcher);
our $sync_timer;
our $write_buf;
our $read_buf;

our $SYNC = EV::timer_ns 0, 60, sub {
   $_[0]->stop;
   CFPlus::DB::Server::req (sync => sub { });
};

sub fh_write {
   my $len = syswrite $FH, $write_buf;

   substr $write_buf, 0, $len, "";

   $fh_w_watcher->stop
      unless length $write_buf;
}

sub fh_read {
   my $status = sysread $FH, $read_buf, 16384, length $read_buf;

   die "FATAL: database process died\n"
      if $status == 0 && defined $status;

   while () {
      return if 4 > length $read_buf;
      my $len = unpack "N", $read_buf;

      return if $len + 4 > length $read_buf;

      substr $read_buf, 0, 4, "";
      my $res = Storable::thaw substr $read_buf, 0, $len, "";

      my ($id, @args) = @$res;
      (delete $CB{$id})->(@args);
   }
}

sub sync {
   # biggest mess evarr
   my $fds; (vec $fds, fileno $FH, 1) =  1;

   while (1 < scalar keys %CB) {
      my $r = $fds;
      my $w = length $write_buf ? $fds : undef;
      select $r, $w, undef, undef;

      fh_write if vec $w, fileno $FH, 1;
      fh_read  if vec $r, fileno $FH, 1;
   }
}

sub req {
   my ($type, @args) = @_;
   my $cb = pop @args;

   my $id = ++$ID;
   $write_buf .= pack "N/a*", Storable::freeze [$id, $type, @args];
   $CB{$id} = $cb;

   $fh_w_watcher->start;
   $SYNC->again unless $SYNC->is_active;
}

sub do_sync {
   $DB_ENV->txn_checkpoint (0, 0, 0);
   ()
}

sub do_exists {
   my ($db, $key) = @_;

   utf8::downgrade $key;
   my $data;
   (table $db)->db_get ($key, $data) == 0
      ? length $data
      : ()
}

sub do_get {
   my ($db, $key) = @_;

   utf8::downgrade $key;
   my $data;
   (table $db)->db_get ($key, $data) == 0
      ? $data
      : ()
}

sub do_put {
   my ($db, $key, $data) = @_;

   utf8::downgrade $key;
   utf8::downgrade $data;
   (table $db)->db_put ($key => $data)
}

sub do_table {
   my ($db) = @_;

   $db = table $db;

   my $cursor = $db->db_cursor;
   my %kv;
   my ($k, $v);
   $kv{$k} = $v while $cursor->c_get ($k, $v, BerkeleyDB::DB_NEXT) == 0;

   \%kv
}

sub do_get_tile_id {
   my ($name) = @_;

   my $id;
   my $table = table "facemap";

   return $id
      if $table->db_get ($name, $id) == 0;

   for (1..100) {
      my $txn = $DB_ENV->txn_begin;
      my $status = $table->db_get (id => $id);
      if ($status == 0 || $status == BerkeleyDB::DB_NOTFOUND) {
         $id = ($id || 64) + 1;
         if ($table->db_put (id => $id) == 0
             && $table->db_put ($name => $id) == 0) {
            $txn->txn_commit;

            return $id;
         }
      }
      $txn->txn_abort;
      select undef, undef, undef, 0.01 * rand;
   }

   die "maximum number of transaction retries reached - database problems?";
}

sub do_unlink {
   unlink $_[0];
}

sub do_read_file {
   my ($path) = @_;

   utf8::downgrade $path;
   open my $fh, "<:raw", $path
      or return;
   sysread $fh, my $buf, -s $fh;

   $buf
}

sub do_write_file {
   my ($path, $data) = @_;

   utf8::downgrade $path;
   utf8::downgrade $data;
   open my $fh, ">:raw", $path
      or return;
   syswrite $fh, $data;
   close $fh;

   1
}

sub do_prefetch_file {
   my ($path, $size) = @_;

   utf8::downgrade $path;
   open my $fh, "<:raw", $path
      or return;
   sysread $fh, my $buf, $size;

   1
}

our %LOG_FH;

sub do_logprint {
   my ($path, $line) = @_;

   $LOG_FH{$path} ||= do {
      open my $fh, ">>:utf8", $path
         or warn "Couldn't open logfile $path: $!";

      $fh->autoflush (1);

      $fh
   };

   my ($sec, $min, $hour, $mday, $mon, $year) = localtime time;

   my $ts = sprintf "%04d-%02d-%02d %02d:%02d:%02d",
               $year + 1900, $mon + 1, $mday, $hour, $min, $sec;

   print { $LOG_FH{$path} } "$ts $line\n"
}

sub run {
   ($FH, my $fh) = CFPlus::socketpipe;

   my $oldfh = select $FH; $| = 1; select $oldfh;
   my $oldfh = select $fh; $| = 1; select $oldfh;

   my $pid = fork;
   
   if (defined $pid && !$pid) {
      local $SIG{QUIT};
      local $SIG{__DIE__};
      local $SIG{__WARN__};
      eval {
         close $FH;

         unless (eval { open_db }) {
            eval { File::Path::rmtree $DB_HOME };
            open_db;
         }

         while () {
            4 == read $fh, my $len, 4
               or last;
            $len = unpack "N", $len;
            $len == read $fh, my $req, $len
               or die "unexpected eof while reading request";

            $req = Storable::thaw $req;

            my ($id, $type, @args) = @$req;
            my $cb = CFPlus::DB::Server->can ("do_$type")
               or die "$type: unknown database request type\n";
            my $res = pack "N/a*", Storable::freeze [$id, $cb->(@args)];
            (syswrite $fh, $res) == length $res
               or die "DB::write: $!";
         }
      };

      my $error = $@;

      eval {
         $DB_ENV->txn_checkpoint (0, 0, 0);

         undef %DB_TABLE;
         undef $DB_ENV;

         Storable::store_fd [die => $error], $fh;
      };

      CFPlus::_exit 0;
   }

   close $fh;
   CFPlus::fh_nonblocking $FH, 1;

   $CB{die} = sub { die shift };

   $fh_r_watcher = EV::io $FH, EV::READ , \&fh_read;
   $fh_w_watcher = EV::io $FH, EV::WRITE, \&fh_write;
   $SYNC->again unless $SYNC->is_active;
}

sub stop {
   close $FH;
}

1;

=back

=head1 AUTHOR

 Marc Lehmann <schmorp@schmorp.de>
 http://home.schmorp.de/

=cut

