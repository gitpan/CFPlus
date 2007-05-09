=head1 NAME

CFPlus::DB - async. database access for cfplus

=head1 SYNOPSIS

 use CFPlus::DB;

=head1 DESCRIPTION

=over 4

=cut

package CFPlus::DB;

use strict;
use utf8;

use Carp ();
use AnyEvent ();
use Storable ();

use CFPlus;

sub sync {
   # for debugging
   #CFPlus::DB::Server::req (sync => sub { });
   CFPlus::DB::Server::sync ();
}

sub get($$$) {
   CFPlus::DB::Server::req (get => @_);
}

sub put($$$$) {
   CFPlus::DB::Server::req (put => @_);
}

our $tilemap;

sub get_tile_id_sync($) {
   my ($hash) = @_;

   # fetch the full face table first
   unless ($tilemap) {
      CFPlus::DB::Server::req (table => facemap => sub { $tilemap = $_[0] });
      sync;
   }

   $tilemap->{$hash} ||= do {
      my $id;
      CFPlus::DB::Server::req (get_tile_id => $hash, sub { $id = $_[0] });
      sync;
      $id
   }
}

package CFPlus::DB::Server;

use strict;

use Fcntl;
use BerkeleyDB;

our $DB_HOME = "$Crossfire::VARDIR/cfplus";
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
                    -SetFlags => DB_AUTO_COMMIT | DB_LOG_AUTOREMOVE,
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
         -Flags    => DB_CREATE | DB_UPGRADE,
            or die "unable to create/open database table $_[0]: $BerkeleyDB::Error"
   }
}

our $SYNC_INTERVAL = 60;

our %CB;
our $FH;
our $ID = "aaa0";
our ($fh_r_watcher, $fh_w_watcher);
our $sync_timer;
our $write_buf;
our $read_buf;

sub fh_write {
   my $len = syswrite $FH, $write_buf;

   substr $write_buf, 0, $len, "";

   undef $fh_w_watcher
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

   $fh_w_watcher = AnyEvent->io (fh => $FH, poll => 'w', cb => \&fh_write);
}

sub sync_tick {
   req "sync", sub { };
   $sync_timer = AnyEvent->timer (after => $SYNC_INTERVAL, cb => \&sync_tick);
}

sub do_sync {
   $DB_ENV->txn_checkpoint (0, 0, 0);
   ()
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
   my ($hash) = @_;

   my $id;
   my $table = table "facemap";

   return $id
      if $table->db_get ($hash, $id) == 0;

   for (1..100) {
      my $txn = $DB_ENV->txn_begin;
      my $status = $table->db_get (id => $id);
      if ($status == 0 || $status == BerkeleyDB::DB_NOTFOUND) {
         $id = ($id || 64) + 1;
         if ($table->db_put (id => $id) == 0
             && $table->db_put ($hash => $id) == 0) {
            $txn->txn_commit;

            return $id;
         }
      }
      $txn->txn_abort;
   }

   die "maximum number of transaction retries reached - database problems?";
}

sub run {
   ($FH, my $fh) = CFPlus::socketpipe;

   my $oldfh = select $FH; $| = 1; select $oldfh;
   my $oldfh = select $fh; $| = 1; select $oldfh;

   my $pid = fork;
   
   if (defined $pid && !$pid) {
      local $SIG{__DIE__};
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
               or die;
         }
      };

      my $error = $@;

      eval {
         undef %DB_TABLE;
         undef $DB_ENV;

         Storable::store_fd [die => $error], $fh;
      };

      CFPlus::_exit 0;
   }

   close $fh;
   CFPlus::fh_nonblocking $FH, 1;

   $CB{die} = sub { die shift };

   $fh_r_watcher = AnyEvent->io (fh => $FH, poll => 'r', cb => \&fh_read);

   sync_tick;
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

