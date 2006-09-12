package CFPlus::Protocol;

use utf8;
use strict;

use Crossfire::Protocol::Constants;

use CFPlus;
use CFPlus::UI;
use CFPlus::Pod;

use base 'Crossfire::Protocol::Base';

sub new {
   my $class = shift;

   my $self = $class->SUPER::new (@_, setup_req => { extmap => 1 });

   $self->{map_widget}->clr_commands;

   my @cmd_help = map {
      $_->{kw}[0] =~ /^(\S+) (?:\s+ \( ([^\)]*) \) )?/x
         or die "unparseable command help: $_->{kw}[0]";

      my $cmd = $1;
      my @args = split /\|/, $2;
      @args = (".*") unless @args;

      my (undef, @par) = CFPlus::Pod::section_of $_;
      my $text = CFPlus::Pod::as_label @par;

      $_ = $_ eq ".*" ? "" : " $_"
         for @args;

      map ["$cmd$_", $text],
         sort { (length $a) <=> (length $b) }
            @args
  } sort { $a->{par} <=> $b->{par} }
         CFPlus::Pod::find command => "*";

  $self->{map_widget}->add_command (@$_)
     for @cmd_help;

   $self->{noface} = new_from_file CFPlus::Texture
      CFPlus::find_rcfile "noface.png", minify => 1, mipmap => 1;

   $self->{open_container} = 0;

   # "global"
   $self->{tilecache} = CFPlus::db_table "tilecache"
      or die "tilecache: unable to open database table";
   $self->{facemap}   = CFPlus::db_table "facemap"
      or die "facemap: unable to open database table";

   # per server
   $self->{mapcache}  = CFPlus::db_table "mapcache_$self->{host}_$self->{port}"
      or die "mapcache_$self->{host}_$self->{port}: unable to open database table";

   $self
}

sub logprint {
   my ($self, @a) = @_;

   $self->{log_fh} ||= do {
      my $path = "$Crossfire::VARDIR/log.$self->{host}";

      open my $fh, ">>:utf8", $path
         or die "Couldn't open logfile $path: $!";

      $fh->autoflush (1);

      $fh;
   };

   my ($sec, $min, $hour, $mday, $mon, $year) = localtime time;

   my $ts = sprintf "%04d-%02d-%02d %02d:%02d:%02d",
               $year + 1900, $mon + 1, $mday, $hour, $min, $sec;

   print {$self->{log_fh}} "$ts ", @a, "\n";
}

sub _stat_numdiff {
   my ($self, $name, $old, $new) = @_;

   my $diff = $new - $old;

   $diff = 0.01 * int $diff * 100;

   0.1 >= abs $diff ? ()
      : $diff < 0 ? "$name$diff" : "$name+$diff"
}

sub _stat_skillmaskdiff {
   my ($self, $name, $old, $new) = @_;

   my $diff = $old ^ $new
      or return;

   my @diff = map
                 {
                    $diff & $_
                       ?  (($new & $_ ? "+" : "-") . $self->{spell_paths}{$_})
                       : ()
                 }
              sort { $a <=> $b } keys %{$self->{spell_paths}};

   join "", @diff
}

# all stats that are chacked against changes
my @statchange = (
   [&CS_STAT_STR          => \&_stat_numdiff, "Str"],
   [&CS_STAT_INT          => \&_stat_numdiff, "Int"],
   [&CS_STAT_WIS          => \&_stat_numdiff, "Wis"],
   [&CS_STAT_DEX          => \&_stat_numdiff, "Dex"],
   [&CS_STAT_CON          => \&_stat_numdiff, "Con"],
   [&CS_STAT_CHA          => \&_stat_numdiff, "Cha"],
   [&CS_STAT_POW          => \&_stat_numdiff, "Pow"],
   [&CS_STAT_WC           => \&_stat_numdiff, "Wc"],
   [&CS_STAT_AC           => \&_stat_numdiff, "Ac"],
   [&CS_STAT_DAM          => \&_stat_numdiff, "Dam"],
   [&CS_STAT_SPEED        => \&_stat_numdiff, "Speed"],
   [&CS_STAT_WEAP_SP      => \&_stat_numdiff, "WSp"],
   [&CS_STAT_MAXHP        => \&_stat_numdiff, "HP"],
   [&CS_STAT_MAXSP        => \&_stat_numdiff, "Mana"],
   [&CS_STAT_MAXGRACE     => \&_stat_numdiff, "Grace"],
   [&CS_STAT_WEIGHT_LIM   => \&_stat_numdiff, "Weight"],
   [&CS_STAT_SPELL_ATTUNE => \&_stat_skillmaskdiff, "attuned"],
   [&CS_STAT_SPELL_REPEL  => \&_stat_skillmaskdiff, "repelled"],
   [&CS_STAT_SPELL_DENY   => \&_stat_skillmaskdiff, "denied"],
   [&CS_STAT_RES_PHYS     => \&_stat_numdiff, "phys"],
   [&CS_STAT_RES_MAG      => \&_stat_numdiff, "magic"],
   [&CS_STAT_RES_FIRE     => \&_stat_numdiff, "fire"],
   [&CS_STAT_RES_ELEC     => \&_stat_numdiff, "electricity"],
   [&CS_STAT_RES_COLD     => \&_stat_numdiff, "cold"],
   [&CS_STAT_RES_CONF     => \&_stat_numdiff, "confusion"],
   [&CS_STAT_RES_ACID     => \&_stat_numdiff, "acid"],
   [&CS_STAT_RES_DRAIN    => \&_stat_numdiff, "drain"],
   [&CS_STAT_RES_GHOSTHIT => \&_stat_numdiff, "ghosthit"],
   [&CS_STAT_RES_POISON   => \&_stat_numdiff, "poison"],
   [&CS_STAT_RES_SLOW     => \&_stat_numdiff, "slow"],
   [&CS_STAT_RES_PARA     => \&_stat_numdiff, "paralyse"],
   [&CS_STAT_TURN_UNDEAD  => \&_stat_numdiff, "turnundead"],
   [&CS_STAT_RES_FEAR     => \&_stat_numdiff, "fear"],
   [&CS_STAT_RES_DEPLETE  => \&_stat_numdiff, "depletion"],
   [&CS_STAT_RES_DEATH    => \&_stat_numdiff, "death"],
   [&CS_STAT_RES_HOLYWORD => \&_stat_numdiff, "godpower"],
   [&CS_STAT_RES_BLIND    => \&_stat_numdiff, "blind"],
);

sub stats_update {
   my ($self, $stats) = @_;

   my $prev = $self->{prev_stats} || { };

   if (my @diffs =
          (
             ($stats->{+CS_STAT_EXP64} > $prev->{+CS_STAT_EXP64} ? ($stats->{+CS_STAT_EXP64} - $prev->{+CS_STAT_EXP64}) . " experience gained" : ()),
             map {
                $stats->{$_} && $prev->{$_} 
                   && $stats->{$_}[1] > $prev->{$_}[1] ? "($self->{skill_info}{$_}+" . ($stats->{$_}[1] - $prev->{$_}[1]) . ")" : ()
             } sort { $a <=> $b } keys %{$self->{skill_info}}
          )
   ) {
      my $msg = join " ", @diffs;
      $self->{statusbox}->add ($msg, group => "experience $msg", fg => [0.5, 1, 0.5, 0.8], timeout => 5);
   }

   if (
      my @diffs = map $_->[1]->($self, $_->[2], $prev->{$_->[0]}, $stats->{$_->[0]}), @statchange
   ) {
      my $msg = "<b>stat change</b>: " . (join " ", @diffs);
      $self->{statusbox}->add ($msg, group => "stat $msg", fg => [0.8, 1, 0.2, 1], timeout => 10);
   }

   $self->update_stats_window ($stats, $prev);

   $self->{prev_stats} = { %$stats };
}

my %RES_TBL = (
   phys  => CS_STAT_RES_PHYS,
   magic => CS_STAT_RES_MAG,
   fire  => CS_STAT_RES_FIRE,
   elec  => CS_STAT_RES_ELEC,
   cold  => CS_STAT_RES_COLD,
   conf  => CS_STAT_RES_CONF,
   acid  => CS_STAT_RES_ACID,
   drain => CS_STAT_RES_DRAIN,
   ghit  => CS_STAT_RES_GHOSTHIT,
   pois  => CS_STAT_RES_POISON,
   slow  => CS_STAT_RES_SLOW,
   para  => CS_STAT_RES_PARA,
   tund  => CS_STAT_TURN_UNDEAD,
   fear  => CS_STAT_RES_FEAR,
   depl  => CS_STAT_RES_DEPLETE,
   deat  => CS_STAT_RES_DEATH,
   holyw => CS_STAT_RES_HOLYWORD,
   blind => CS_STAT_RES_BLIND,
);

sub update_stats_window {
   my ($self, $stats, $prev) = @_;

   # I love text protocols...

   my $hp   = $stats->{+CS_STAT_HP} * 1;
   my $hp_m = $stats->{+CS_STAT_MAXHP} * 1;
   my $sp   = $stats->{+CS_STAT_SP} * 1;
   my $sp_m = $stats->{+CS_STAT_MAXSP} * 1;
   my $fo   = $stats->{+CS_STAT_FOOD} * 1;
   my $fo_m = 999;
   my $gr   = $stats->{+CS_STAT_GRACE} * 1;
   my $gr_m = $stats->{+CS_STAT_MAXGRACE} * 1;

   $::GAUGES->{hp}      ->set_value ($hp, $hp_m);
   $::GAUGES->{mana}    ->set_value ($sp, $sp_m);
   $::GAUGES->{food}    ->set_value ($fo, $fo_m);
   $::GAUGES->{grace}   ->set_value ($gr, $gr_m);
   $::GAUGES->{exp}     ->set_text ("Exp: " . (::formsep ($stats->{+CS_STAT_EXP64}))
                                    . " (lvl " . ($stats->{+CS_STAT_LEVEL} * 1) . ")");
   my $rng = $stats->{+CS_STAT_RANGE};
   $rng =~ s/^Range: //;    # thank you so much dear server
   $::GAUGES->{range}   ->set_text ("Rng: " . $rng);
   my $title = $stats->{+CS_STAT_TITLE};
   $title =~ s/^Player: //;
   $::STATWIDS->{title} ->set_text ("Title: " . $title);

   $::STATWIDS->{st_str} ->set_text (sprintf "%d"  , $stats->{+CS_STAT_STR});
   $::STATWIDS->{st_dex} ->set_text (sprintf "%d"  , $stats->{+CS_STAT_DEX});
   $::STATWIDS->{st_con} ->set_text (sprintf "%d"  , $stats->{+CS_STAT_CON});
   $::STATWIDS->{st_int} ->set_text (sprintf "%d"  , $stats->{+CS_STAT_INT});
   $::STATWIDS->{st_wis} ->set_text (sprintf "%d"  , $stats->{+CS_STAT_WIS});
   $::STATWIDS->{st_pow} ->set_text (sprintf "%d"  , $stats->{+CS_STAT_POW});
   $::STATWIDS->{st_cha} ->set_text (sprintf "%d"  , $stats->{+CS_STAT_CHA});
   $::STATWIDS->{st_wc}  ->set_text (sprintf "%d"  , $stats->{+CS_STAT_WC});
   $::STATWIDS->{st_ac}  ->set_text (sprintf "%d"  , $stats->{+CS_STAT_AC});
   $::STATWIDS->{st_dam} ->set_text (sprintf "%d"  , $stats->{+CS_STAT_DAM});
   $::STATWIDS->{st_arm} ->set_text (sprintf "%d"  , $stats->{+CS_STAT_RES_PHYS});
   $::STATWIDS->{st_spd} ->set_text (sprintf "%.1f", $stats->{+CS_STAT_SPEED});
   $::STATWIDS->{st_wspd}->set_text (sprintf "%.1f", $stats->{+CS_STAT_WEAP_SP});
 
   $self->update_weight;

   $::STATWIDS->{"res_$_"}->set_text (sprintf "%d%", $stats->{$RES_TBL{$_}})
      for keys %RES_TBL;

   my $sktbl = $::STATWIDS->{skill_tbl};
   my @skills = keys %{ $self->{skill_info} };

   if (grep +(exists $stats->{$_}) != (exists $prev->{$_}), @skills) {
      $sktbl->clear;

      $sktbl->add (0, 0, new CFPlus::UI::Label text => "Experience", align => 1);
      $sktbl->add (1, 0, new CFPlus::UI::Label text => "Lvl.", align => 1);
      $sktbl->add (2, 0, new CFPlus::UI::Label text => "Skill", expand => 1);
      $sktbl->add (3, 0, new CFPlus::UI::Label text => "Experience", align => 1);
      $sktbl->add (4, 0, new CFPlus::UI::Label text => "Lvl.", align => 1);
      $sktbl->add (5, 0, new CFPlus::UI::Label text => "Skill", expand => 1);

      my $TOOLTIP_ALL = "\n\n<small>Left click - ready skill\nMiddle click - use spell\nRight click - further options</small>";

      my @TOOLTIP_LVL  = (tooltip => "<b>Level</b>. The level of the skill.$TOOLTIP_ALL", can_events => 1, can_hover => 1);
      my @TOOLTIP_EXP  = (tooltip => "<b>Experience</b>. The experience points you have in this skill.$TOOLTIP_ALL", can_events => 1, can_hover => 1);

      my ($x, $y) = (0, 1);
      for (
         sort { $stats->{$b->[0]}[1] <=> $stats->{$a->[0]}[1] or $a->[1] cmp $b->[1] }
         map [$_, $self->{skill_info}{$_}],
         grep exists $stats->{$_},
           @skills
      ) {
         my ($idx, $name) = @$_;

         my $spell_cb = sub {
            my ($widget, $ev) = @_;

            if ($ev->{button} == 1) {
               $::CONN->user_send ("ready_skill $name");
            } elsif ($ev->{button} == 2) {
               $::CONN->user_send ("use_skill $name");
            } elsif ($ev->{button} == 3) {
               (new CFPlus::UI::Menu
                  items => [
                     ["bind <i>ready_skill $name</i> to a key"   => sub { $::BIND_EDITOR->do_quick_binding (["ready_skill $name"]) }],
                     ["bind <i>use_skill $name</i> to a key" => sub { $::BIND_EDITOR->do_quick_binding (["use_skill $name"]) }],
                  ],
               )->popup ($ev);
            } else {
               return 0;
            }

            1
         };

         $sktbl->add ($x * 3 + 0, $y, $self->{stat_widget_exp}{$idx} = new CFPlus::UI::Label
            text => "0", align => 1, font => $::FONT_FIXED, fg => [1, 1, 0], on_button_down => $spell_cb, @TOOLTIP_EXP);
         $sktbl->add ($x * 3 + 1, $y, $self->{stat_widget_lvl}{$idx} = new CFPlus::UI::Label
            text => "0", align => 1, font => $::FONT_FIXED, fg => [0, 1, 0], padding_x => 4, on_button_down => $spell_cb, @TOOLTIP_LVL);
         $sktbl->add ($x * 3 + 2, $y, new CFPlus::UI::Label text => $name, on_button_down => $spell_cb,
                      can_events => 1, can_hover => 1, tooltip => (CFPlus::Pod::section_label skill_description => $name) . $TOOLTIP_ALL);

         $x++ and ($x, $y) = (0, $y + 1);
      }
   }

   for (grep exists $stats->{$_}, @skills) {
      $self->{stat_widget_exp}{$_}->set_text (::formsep ($stats->{$_}[1]));
      $self->{stat_widget_lvl}{$_}->set_text ($stats->{$_}[0] * 1);
   }
}

sub user_send {
   my ($self, $command) = @_;

   if ($self->{record}) {
      push @{$self->{record}}, $command;
   }

   $self->logprint ("send: ", $command);
   $self->send_command ($command);
   ::status ($command);
}

sub start_record {
   my ($self) = @_;

   $self->{record} = [];
}

sub stop_record {
   my ($self) = @_;
   return delete $self->{record};
}

sub map_scroll {
   my ($self, $dx, $dy) = @_;

   $self->{map}->scroll ($dx, $dy);
}

sub feed_map1a {
   my ($self, $data) = @_;

   $self->{map}->map1a_update ($data, $self->{setup}{extmap});
   $self->{map_widget}->update;
}

sub magicmap {
   my ($self, $w, $h, $x, $y, $data) = @_;

   $self->{map_widget}->set_magicmap ($w, $h, $x, $y, $data);
}

sub flush_map {
   my ($self) = @_;

   my $map_info = delete $self->{map_info}
      or return;

   my ($hash, $x, $y, $w, $h) = @$map_info;

   my $data = $self->{map}->get_rect ($x, $y, $w, $h);
   $self->{mapcache}->put ($hash => Compress::LZF::compress $data);
   #warn sprintf "SAVEmap[%s] length %d\n", $hash, length $data;#d#
}

sub map_clear {
   my ($self) = @_;

   $self->flush_map;
   delete $self->{neigh_map};

   $self->{map}->clear;
   delete $self->{map_widget}{magicmap};
}


sub load_map($$$) {
   my ($self, $hash, $x, $y) = @_;

   if (defined (my $data = $self->{mapcache}->get ($hash))) {
      $data = Compress::LZF::decompress $data;
      #warn sprintf "LOADmap[%s,%d,%d] length %d\n", $hash, $x, $y, length $data;#d#
      for my $id ($self->{map}->set_rect ($x, $y, $data)) {
         my $data = $self->{tilecache}->get ($id)
            or next;

         $self->set_texture ($id => $data);
      }
   }
}

# hardcode /world/world_xxx_xxx map names, the savings are enourmous,
# (server resource,s latency, bandwidth), so this hack is warranted.
# the right fix is to make real tiled maps with an overview file
sub send_mapinfo {
   my ($self, $data, $cb) = @_;

   if ($self->{map_info}[0] =~ m%^/world/world_(\d\d\d)_(\d\d\d)$%) {
      my ($wx, $wy) = ($1, $2);

      if ($data =~ /^spatial ([1-4]+)$/) {
         my @dx = (0, 0, 1, 0, -1);
         my @dy = (0, -1, 0, 1, 0);
         my ($dx, $dy);

         for (split //, $1) {
            $dx += $dx[$_];
            $dy += $dy[$_];
         }

         $cb->(spatial => 15,
            $self->{map_info}[1] - $self->{map}->ox + $dx * 50,
            $self->{map_info}[2] - $self->{map}->oy + $dy * 50,
            50, 50,
            sprintf "/world/world_%03d_%03d", $wx + $dx, $wy + $dy
         );

         return;
      }
   }

   $self->SUPER::send_mapinfo ($data, $cb);
}

# this method does a "flood fill" into every tile direction
# it assumes that tiles are arranged in a rectangular grid,
# i.e. a map is the same as the left of the right map etc.
# failure to comply are harmless and result in display errors
# at worst.
sub flood_fill {
   my ($self, $block, $gx, $gy, $path, $hash, $flags) = @_;

   # the server does not allow map paths > 6
   return if 7 <= length $path;

   my ($x0, $y0, $x1, $y1) = @{$self->{neigh_rect}};

   for (
      [1, 3,  0, -1],
      [2, 4,  1,  0],
      [3, 1,  0,  1],
      [4, 2, -1,  0],
   ) {
      my ($tile, $tile2, $dx, $dy) = @$_;

      next if $block & (1 << $tile);
      my $block = $block | (1 << $tile2);

      my $gx = $gx + $dx;
      my $gy = $gy + $dy;

      next unless $flags & (1 << ($tile - 1));
      next if $self->{neigh_grid}{$gx, $gy}++;

      my $neigh = $self->{neigh_map}{$hash} ||= [];
      if (my $info = $neigh->[$tile]) {
         my ($flags, $x, $y, $w, $h, $hash) = @$info;

         $self->flood_fill ($block, $gx, $gy, "$path$tile", $hash, $flags)
            if $x >= $x0 && $x + $w < $x1 && $y >= $y0  && $y + $h < $y1;

      } else {
         $self->send_mapinfo ("spatial $path$tile", sub {
            my ($mode, $flags, $x, $y, $w, $h, $hash) = @_;

            return if $mode ne "spatial";

            $x += $self->{map}->ox;
            $y += $self->{map}->oy;

            $self->load_map ($hash, $x, $y)
               unless $self->{neigh_map}{$hash}[5]++;#d#

            $neigh->[$tile] = [$flags, $x, $y, $w, $h, $hash];

            $self->flood_fill ($block, $gx, $gy, "$path$tile", $hash, $flags)
               if $x >= $x0 && $x + $w < $x1 && $y >= $y0  && $y + $h < $y1;
         });
      }
   }
}

sub map_change {
   my ($self, $mode, $flags, $x, $y, $w, $h, $hash) = @_;

   $self->flush_map;

   my ($ox, $oy) = ($::MAP->ox, $::MAP->oy);

   my $mapmapw = $self->{mapmap}->{w};
   my $mapmaph = $self->{mapmap}->{h};

   $self->{neigh_rect} = [
      $ox - $mapmapw * 0.5,      $oy - $mapmapw * 0.5,
      $ox + $mapmapw * 0.5 + $w, $oy + $mapmapw * 0.5 + $h,
   ];
   
   delete $self->{neigh_grid};

   $x += $ox;
   $y += $oy;

   $self->{map_info} = [$hash, $x, $y, $w, $h];

   (my $map = $hash) =~ s/^.*?\/([^\/]+)$/\1/;
   $::STATWIDS->{map}->set_text ("Map: " . $map);

   $self->load_map ($hash, $x, $y);
   $self->flood_fill (0, 0, 0, "", $hash, $flags);
}

sub face_find {
   my ($self, $facenum, $face) = @_;

   my $hash = "$face->{chksum},$face->{name}";

   my $id = $self->{facemap}->get ($hash);

   unless ($id) {
      # create new id for face
      # I love transactions
      for (1..100) {
         my $txn = $CFPlus::DB_ENV->txn_begin;
         my $status = $self->{facemap}->db_get (id => $id);
         if ($status == 0 || $status == BerkeleyDB::DB_NOTFOUND) {
            $id = ($id || 64) + 1;
            if ($self->{facemap}->put (id => $id) == 0
                && $self->{facemap}->put ($hash => $id) == 0) {
               $txn->txn_commit;

               goto gotid;
            }
         }
         $txn->txn_abort;
      }

      CFPlus::fatal "maximum number of transaction retries reached - database problems?";
   }

gotid:
   $face->{id} = $id;
   $self->{map}->set_face ($facenum => $id);
   $self->{faceid}[$facenum] = $id;#d#

   my $face = $self->{tilecache}->get ($id);
   
   if ($face) {
      #$self->face_prefetch;
      $face
   } else {
      my $tex = $self->{noface};
      $self->{map}->set_texture ($id, @$tex{qw(name w h s t)}, @{$tex->{minified}});
      undef
   };
}

sub face_update {
   my ($self, $facenum, $face, $changed) = @_;

   $self->{tilecache}->put ($face->{id} => $face->{image}) if $changed;

   $self->set_texture ($face->{id} => delete $face->{image});
}

sub set_texture {
   my ($self, $id, $data) = @_;

   $self->{texture}[$id] ||= do {
      my $tex =
         new_from_image CFPlus::Texture
            $data, minify => 1, mipmap => 1;

      $self->{map}->set_texture ($id, @$tex{qw(name w h s t)}, @{$tex->{minified}});
      $self->{map_widget}->update;

      $tex
   };
}

sub sound_play {
   my ($self, $x, $y, $soundnum, $type) = @_;

   $self->{sound_play}->($x, $y, $soundnum, $type);
}

my $LAST_QUERY; # server is stupid, stupid, stupid

sub query {
   my ($self, $flags, $prompt) = @_;

   $prompt = $LAST_QUERY unless length $prompt;
   $LAST_QUERY = $prompt;

   $self->{query}-> ($self, $flags, $prompt);
}

sub drawinfo {
   my ($self, $color, $text) = @_;

   my @color = (
      [1.00, 1.00, 1.00], #[0.00, 0.00, 0.00],
      [1.00, 1.00, 1.00],
      [0.50, 0.50, 1.00], #[0.00, 0.00, 0.55]
      [1.00, 0.00, 0.00],
      [1.00, 0.54, 0.00],
      [0.11, 0.56, 1.00],
      [0.93, 0.46, 0.00],
      [0.18, 0.54, 0.34],
      [0.56, 0.73, 0.56],
      [0.80, 0.80, 0.80],
      [0.75, 0.61, 0.20],
      [0.99, 0.77, 0.26],
      [0.74, 0.65, 0.41],
   );

   $self->logprint ("info: ", $text);

   my $time = sprintf "%02d:%02d:%02d", (localtime time)[2,1,0];

   # try to create single paragraphs of multiple lines sent by the server
   $text =~ s/(?<=\S)\n(?=\w)/ /g;

   $text = CFPlus::asxml $text;
   $text =~ s/\[b\](.*?)\[\/b\]/<b>\1<\/b>/g;
   $text =~ s/\[color=(.*?)\](.*?)\[\/color\]/<span foreground='\1'>\2<\/span>/g;

   $self->{logview}->add_paragraph ({ fg => $color[$color], markup => $_ })
      for map "<span foreground='#ffffff'>$time</span> $_", split /\n/, $text;
   $self->{logview}->scroll_to_bottom;

   $self->{statusbox}->add ($text,
      group        => $text,
      fg           => $color[$color],
      timeout      => $color >= 2 ? 180 : 10,
      tooltip_font => $::FONT_FIXED,
   );
}

sub drawextinfo {
   my ($self, $color, $type, $subtype, $message) = @_;

   $self->drawinfo ($color, $message);
}

sub spell_add {
   my ($self, $spell) = @_;

   # try to create single paragraphs out of the multiple lines sent by the server
   $spell->{message} =~ s/(?<=\S)\n(?=\w)/ /g;
   $spell->{message} =~ s/\n+$//;
   $spell->{message} ||= "Server did not provide a description for this spell.";

   $::SPELL_PAGE->add_spell ($spell);

   $self->{map_widget}->add_command ("invoke $spell->{name}", CFPlus::asxml $spell->{message});
   $self->{map_widget}->add_command ("cast $spell->{name}", CFPlus::asxml $spell->{message});
}

sub spell_delete {
   my ($self, $spell) = @_;

   $::SPELL_PAGE->remove_spell ($spell);
}

sub addme_success {
   my ($self) = @_;

   my %skill_help;

   for my $node (CFPlus::Pod::find skill_description => "*") {
      my (undef, @par) = CFPlus::Pod::section_of $node;
      $skill_help{$node->{kw}[0]} = CFPlus::Pod::as_label @par;
   };
 
   for my $skill (values %{$self->{skill_info}}) {
      $self->{map_widget}->add_command ("ready_skill $skill",
                                        (CFPlus::asxml "Ready the skill '$skill'\n\n")
                                        . $skill_help{$skill});
      $self->{map_widget}->add_command ("use_skill $skill",
                                        (CFPlus::asxml "Immediately use the skill '$skill'\n\n")
                                        . $skill_help{$skill});
   }
}

sub eof {
   my ($self) = @_;

   $self->{map_widget}->clr_commands;

   ::stop_game ();
}

sub image_info {
   my ($self, $numfaces) = @_;

   $self->{num_faces} = $numfaces;
   $self->{face_prefetch} = [1 .. $numfaces];
   $self->face_prefetch;
}

sub face_prefetch {
   my ($self) = @_;

   return unless $::CFG->{face_prefetch};

   if ($self->{num_faces}) {
      return if @{ $self->{send_queue} || [] };
      my $todo = @{ $self->{face_prefetch} }
         or return;

      my ($face) = splice @{ $self->{face_prefetch} }, + rand @{ $self->{face_prefetch} }, 1, ();

      $self->send ("requestinfo image_sums $face $face");

      $self->{statusbox}->add (CFPlus::asxml "prefetching $todo",
         group => "prefetch", timeout => 3, fg => [1, 1, 0, 0.5]);
   } elsif (!exists $self->{num_faces}) {
      $self->send ("requestinfo image_info");

      $self->{num_faces} = 0;

      $self->{statusbox}->add (CFPlus::asxml "starting to prefetch",
         group => "prefetch", timeout => 3, fg => [1, 1, 0, 0.5]);
   }
}

sub update_floorbox {
   $CFPlus::UI::ROOT->on_refresh ($::FLOORBOX => sub {
      return unless $::CONN;

      $::FLOORBOX->clear;

      my $row;
      for (sort { $a->{count} <=> $b->{count} } values %{ $::CONN->{container}{$::CONN->{open_container} || 0} }) {
         if ($row < 6) {
            local $_->{face_widget}; # hack to force recreation of widget
            local $_->{desc_widget}; # hack to force recreation of widget
            CFPlus::Item::update_widgets $_;

            $::FLOORBOX->add (0, $row, $_->{face_widget});
            $::FLOORBOX->add (1, $row, $_->{desc_widget});

            $row++;
         } else {
            $::FLOORBOX->add (1, $row, new CFPlus::UI::Button
               text        => "More...",
               on_activate => sub { ::toggle_player_page ($::INVENTORY_PAGE); 0 },
            );
            last;
         }
      }
      if ($::CONN->{open_container}) {
         $::FLOORBOX->add (1, $row++, new CFPlus::UI::Button
            text        => "Close container",
            on_activate => sub { $::CONN->send ("apply $::CONN->{open_container}") }
         );
      }
   });

   $::WANT_REFRESH++;
}

sub set_opencont {
   my ($conn, $tag, $name) = @_;
   $conn->{open_container} = $tag;
   update_floorbox;

   $::INV_RIGHT_HB->clear ();
   $::INV_RIGHT_HB->add (new CFPlus::UI::Label align => 0, expand => 1, text => $name);

   if ($tag != 0) { # Floor isn't closable, is it?
      $::INV_RIGHT_HB->add (new CFPlus::UI::Button
         text     => "Close container",
         tooltip  => "Close the currently open container (if one is open)",
         on_activate => sub {
            $::CONN->send ("apply $tag") # $::CONN->{open_container}")
               if $tag != 0;
            #if $CONN->{open_container} != 0;
            0
         },
      );
   }

   $::INVR->set_items ($conn->{container}{$tag});
}

sub update_containers {
   my ($self) = @_;

   $CFPlus::UI::ROOT->on_refresh ("update_containers_$self" => sub {
      my $todo = delete $self->{update_container}
         or return;

      for my $tag (keys %$todo) {
         update_floorbox if $tag == 0 or $tag == $self->{open_container};
         if ($tag == 0) {
            $::INVR->set_items ($self->{container}{0})
               if $tag == $self->{open_container};
         } elsif ($tag == $self->{player}{tag}) {
            $::INV->set_items ($self->{container}{$tag})
         } else {
            $::INVR->set_items ($self->{container}{$tag})
               if $tag == $self->{open_container};
         }
      }
   });
}

sub container_add {
   my ($self, $tag, $items) = @_;

   $self->{update_container}{$tag}++;
   $self->update_containers;
}

sub container_clear {
   my ($self, $tag) = @_;

   $self->{update_container}{$tag}++;
   $self->update_containers;
}

sub item_delete {
   my ($self, @items) = @_;

   $self->{update_container}{$_->{container}}++
      for @items;
   
   $self->update_containers;
}

sub item_update {
   my ($self, $item) = @_;

   #d# print "item_update: $item->{tag} in $item->{container} ($self->{player}{tag}) ($::CONN->{open_container})\n";

   CFPlus::Item::update_widgets $item;

   if ($item->{tag} == $::CONN->{open_container} && not ($item->{flags} & F_OPEN)) {
      set_opencont ($::CONN, 0, "Floor");

   } elsif ($item->{flags} & F_OPEN) {
      set_opencont ($::CONN, $item->{tag}, CFPlus::Item::desc_string $item);

   } else {
      $self->{update_container}{$item->{container}}++;
      $self->update_containers;
   }
}

sub player_update {
   my ($self, $player) = @_;

   $self->update_weight;
}

sub update_weight {
   my ($self) = @_;

   my $weight = .001 * $self->{player}{weight};
   my $limit  = .001 * $self->{stat}{+CS_STAT_WEIGHT_LIM};

   $::STATWIDS->{weight}->set_text (sprintf "Weight: %.1fkg", $weight);
   $::STATWIDS->{m_weight}->set_text (sprintf "%.1fkg", $limit);
   $::STATWIDS->{i_weight}->set_text (sprintf "%.1f/%.1fkg", $weight, $limit);
}

sub update_server_info {
   my ($self) = @_;

   my @yesno = ("<span foreground='red'>no</span>", "<span foreground='green'>yes</span>");

   $::SERVER_INFO->set_markup (
      "server <tt>$self->{host}:$self->{port}</tt>\n"
    . "protocol version <tt>$self->{version}</tt>\n"
    . "minimap support $yesno[$self->{setup}{mapinfocmd} > 0]\n"
    . "extended command support $yesno[$self->{setup}{extcmd} > 0]\n"
    . "map attributes $yesno[$self->{setup}{extmap} > 0]\n"
    . "cfplus support $yesno[$self->{cfplus_ext} > 0]"
      . ($self->{cfplus_ext} > 0 ? ", version $self->{cfplus_ext}" : "") ."\n"
    . "map size $self->{mapw}×$self->{maph}\n"
   );
}

sub logged_in {
   my ($self) = @_;

   $self->send_ext_req (cfplus_support => version => 1, sub {
      $self->{cfplus_ext} = $_[0]{version};
      $self->update_server_info;

      0
   });

   $self->update_server_info;

   $self->send_command ("output-sync $::CFG->{output_sync}");
   $self->send_command ("output-count $::CFG->{output_count}");
   $self->send_command ("pickup $::CFG->{pickup}");
}

sub lookat {
   my ($self, $x, $y) = @_;

   if ($self->{cfplus_ext}) {
      $self->send_ext_req (lookat => dx => $x, dy => $y, sub {
         my ($msg) = @_;

         if (exists $msg->{npc_dialog}) {
            # start npc chat dialog
            $self->{npc_dialog} = new CFPlus::NPCDialog::
               dx    => $x,
               dy    => $y,
               title => "$msg->{npc_dialog} (NPC)",
               conn  => $self,
            ;
         }
      });
   }

   $self->send ("lookat $x $y");
}

sub destroy {
   my ($self) = @_;

   (delete $self->{npc_dialog})->destroy
      if $self->{npc_dialog};

   $self->SUPER::destroy;
}

package CFPlus::NPCDialog;

our @ISA = 'CFPlus::UI::Toplevel';

sub new {
   my $class = shift;

   my $self = $class->SUPER::new (
      x       => 'center',
      y       => 'center',
      name    => "npc_dialog",
      force_w => $::WIDTH * 0.7,
      force_h => $::HEIGHT * 0.7,
      title   => "NPC Dialog",
      kw      => { hi => 0, yes => 0, no => 0 },
      has_close_button => 1,
      @_,
   );

   Scalar::Util::weaken (my $this = $self);

   $self->connect (delete => sub { $this->destroy; 1 });

   # better use a pane...
   $self->add (my $hbox = new CFPlus::UI::HBox);
   $hbox->add ($self->{textview} = new CFPlus::UI::TextScroller expand => 1);

   $hbox->add (my $vbox = new CFPlus::UI::VBox);

   $vbox->add (new CFPlus::UI::Label text => "Message Entry:");
   $vbox->add ($self->{entry} = new CFPlus::UI::Entry
      tooltip     => "#npc_message_entry",
      on_activate => sub {
         my ($entry, $text) = @_;

         return unless $text =~ /\S/;

         $entry->set_text ("");
         $this->send ($text);

         0
      },
   );

   $vbox->add ($self->{options} = new CFPlus::UI::VBox);

   $self->{bye_button} = new CFPlus::UI::Button
      text        => "Bye (close)",
      tooltip     => "Use this button to end talking to the NPC. This also closes the dialog window.",
      on_activate => sub { $this->destroy; 1 },
   ;

   $self->update_options;

   $self->{id} = $self->{conn}->send_ext_req (
      npc_dialog_begin => dx => $self->{dx}, dy => $self->{dy},
      sub { $this && $this->feed (@_) }
   );

   $self->{entry}->grab_focus;

   $self->{textview}->add_paragraph ({
      fg     => [1, 1, 0, 1],
      markup => "<small>[starting conversation with <b>$self->{title}</b>]</small>\n\n",
   });

   $self->show;
   $self
};

sub update_options {
   my ($self) = @_;

   Scalar::Util::weaken $self;

   $self->{options}->clear;
   $self->{options}->add ($self->{bye_button});

   for my $kw (sort keys %{ $self->{kw} }) {
      $self->{options}->add (new CFPlus::UI::Button
         text => $kw,
         on_activate => sub {
            $self->send ($kw);
            0
         },
      );
   }
}

sub feed {
   my ($self, $msg) = @_;

   Scalar::Util::weaken $self;

   if ($msg->{msgtype} eq "reply") {
      $self->{kw}{$_} = 1 for @{$msg->{add_topics} || []};
      $self->{kw}{$_} = 0 for @{$msg->{del_topics} || []};

      my $text = "\n" . CFPlus::asxml $msg->{msg};
      my $match = join "|", map "\\b\Q$_\E\\b", sort { (length $b) <=> (length $a) } keys %{ $self->{kw} };
      my @link;
      $text =~ s{
         ($match)
      }{
         my $kw = $1;

         push @link, new CFPlus::UI::Label
            markup     => "<span foreground='#c0c0ff' underline='single'>$kw</span>",
            can_hover  => 1,
            can_events => 1,
            padding_x  => 0,
            padding_y  => 0,
            on_button_up => sub {
               $self->send ($kw);
            };

         "\x{fffc}"
      }giex;
      
      $self->{textview}->add_paragraph ({ markup => $text, widget => \@link });
      $self->{textview}->scroll_to_bottom;
      $self->update_options;
   } else {
      $self->destroy;
   }

   1
}

sub send {
   my ($self, $msg) = @_;

   $self->{textview}->add_paragraph ({ markup => "\n" . CFPlus::asxml $msg });
   $self->{textview}->scroll_to_bottom;

   $self->{conn}->send_ext_msg (npc_dialog_tell => msgid => $self->{id}, msg => $msg);
}

sub destroy {
   my ($self) = @_;

   #Carp::cluck "debug\n";#d# #todo# enable: destroy gets called twice because scalar keys {} is 1

   if ($self->{conn}) {
      $self->{conn}->send_ext_msg (npc_dialog_end => msgid => $self->{id}) if $self->{id};
      delete $self->{conn}{npc_dialog};
      $self->{conn}->disconnect_ext ($self->{id});
   }

   $self->SUPER::destroy;
}

1
