package AlephBagImport::Controller::Import;

use strict;
use warnings;
use v5.10;
use Mango::BSON ':bson';
use Mango::BSON::ObjectID;
use Mojo::JSON qw(encode_json);
use base 'Mojolicious::Controller';

sub home {
  my $self = shift;

  unless($self->flash('redirect_to')){
    # if no redirect was set, reload the current url
    $self->flash({redirect_to => $self->url_for('/')});
  }

  if($self->stash('opensignin')){
    $self->flash({opensignin => 1});
  }

  my $init_data = { current_user => $self->current_user };
  $self->stash(init_data => encode_json($init_data));
  $self->stash(init_data_perl => $init_data);

  $self->render('home');
};

sub import {
  my $self = shift;
  my $init_data = {
    current_user => $self->current_user,
    load_bags => 1
  };
  $self->stash(init_data => encode_json($init_data));
  $self->stash(init_data_perl => $init_data);
  $self->render('import');
}

sub addacnumbers {
  my $self = shift;

  my $payload = $self->req->json;
  my $acnumbers = $payload->{acnumbers};

  my @values = split(/\W+/, $acnumbers);
  foreach my $ac (@values){
    if($ac =~ /AC(\d)+/g){
      $self->app->log->debug("adding $ac");
      $self->mango_alephbagimport->db->collection('acnumbers')->update({ac_number => $ac}, { ac_number => $ac, created => time, updated => time}, { upsert => 1 });
    }else{
      $self->app->log->error("$ac is not an AC number");
    }
  }

  $self->render(json => { alerts => [] }, status => 200);
}

sub getacnumbers {
  my $self = shift;
  my $res = $self->mango_alephbagimport->db->collection('acnumbers')
    ->find()
    ->sort({updated => 1})
		->fields({ _id => 1, ac_number => 1, created => 1, updated => 1})
		->all();

  foreach my $a (@{$res}){

    $self->app->log->debug("Checking requests ".$a->{ac_number});
    ($a->{fetch_status}, $a->{fetched}, $a->{requested}) = $self->get_fetch_status($a->{ac_number});
    $self->app->log->debug("Checking bags ".$a->{ac_number});
    $a->{bag_created} = $self->get_bag_status($a->{ac_number});
  }

  $self->render(json => { acnumbers => $res }, status => 200);
}

sub get_fetch_status {
  my $self = shift;
  my $ac = shift;

  my $req_stat = $self->mango_stage->db->collection('requests')->find({ac_number => $ac})->sort({ts_iso => -1})->fields({status => 1, created => 1})->next;
  my $md_stat = $self->mango_stage->db->collection('aleph.mab')->find({ac_number => $ac})->sort({fetched => -1})->fields({fetched => 1})->next;

  $self->app->log->debug($self->app->dumper($req_stat));
  $self->app->log->debug($self->app->dumper($md_stat));

  return ($req_stat->{status}, $md_stat->{fetched}, $req_stat->{created});
}

sub get_bag_status {
  my $self = shift;
  my $ac = shift;

  my $bag_stat = $self->mango_bagger->db->collection('bags')->find({ac_number => $ac})->sort({created => -1})->fields({created => 1})->next;

  return exists($bag_stat->{created}) ? $bag_stat->{created} : undef;
}

sub fetch {
  my $self = shift;
  my $acnumber = $self->stash('acnumber');

  unless($acnumber =~ /AC(\d)+/g){
    $self->render(json => { alerts => [{ type => 'danger', msg => "Creating request failed, $acnumber is not an AC number" }]}, status => 400);
    return;
  }

  my $time = time ();
  my @ts = localtime ($time);
  my $ts_ISO = sprintf ("%04d%02d%02dT%02d%02d%02d", $ts[5]+1900, $ts[4]+1, $ts[3], $ts[2], $ts[1], $ts[0]);

  $self->mango_stage->db->collection('requests')->insert({ts_iso => $ts_ISO, created => time, status => 'new', agent => 'aleph_cat', action => 'update_aleph_2xml', ac_number => $acnumber});

  $self->render(json => {  }, status => 200);
}

sub createbag {
  my $self = shift;
  my $acnumber = $self->stash('acnumber');

  my $res = { alerts => [], status => 200 };

  unless($acnumber =~ /AC(\d)+/g){
    $self->render(json => { alerts => [{ type => 'danger', msg => "Creating bag failed, $acnumber is not an AC number" }]}, status => 400);
    return;
  }

  $self->app->log->debug("Getting mab for ".$acnumber);
  my $md_stat = $self->mango_stage->db->collection('aleph.mab')->find({ac_number => $acnumber})->sort({fetched => -1})->fields({xmlref2 => 1})->next;

  unless($md_stat->{xmlref2}){
    $self->render(json => { alerts => [{ type => 'danger', msg => "Creating bag for $acnumber failed, no mab metadata found" }]}, status => 400);
    return;
  }

  my $mab = $md_stat->{xmlref2};

  $self->app->log->debug("Mapping mab to mods ".$acnumber);
  my $mods = $self->mab2mods($mab);

  $self->app->log->debug("Creating bag ".$acnumber);
  my $bagid = "UBMaps$acnumber";
  my $reply = $self->mango_bagger->db->collection('bags')->insert({ bagid => $bagid, file => $acnumber.'.tif', label => $acnumber, folderid => "UBMaps", tags => [], project => "UBMaps", metadata => {mods => $mods}, status => 'new', assignee => '', created => time, updated => time } );
  my $oid = $reply->{oid};
  if($oid){
    push @{$res->{alerts}}, "Inserting bag $bagid [oid: $oid]";
  }else{
    push @{$res->{alerts}}, "Inserting bag $bagid failed";
  }

  $self->render(json => $res, status => $res->{status});
}

sub mab2mods {
  my $self = shift;
  my $mab = shift;
  my $mods = {};
  return $mods;
}

1;
