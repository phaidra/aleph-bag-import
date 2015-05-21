package AlephBagImport::Controller::Import;

use strict;
use warnings;
use diagnostics;
use v5.10;
use utf8;
use Mango::BSON ':bson';
use Mango::BSON::ObjectID;
use Mojo::JSON qw(encode_json);
use Storable qw(dclone);
use base 'Mojolicious::Controller';
use AlephBagImport::Model::Bkl;

# Konkordanz Beziehungskennzeichnung-MARC Relator Code im Rahmen von UB Maps
our %role_mapping = (

  # Schubert: Fällt im Englischen mit editor zusammen
  "[Bearb.]"            => "edt",
  "[Hrsg.]"             => "edt",
  "[Drucker]"           => "prt",
  "[Ill.]"              => "ill",
  "[Widmungsempfänger]" => "dte",
  # Schubert: drm steht eigentlich für Technischer Zeichner, es gibt aber ansonsten nur Künstler - in beiden Fällen ist etwas anderes gemeint, aber Technischer Zeichner trifft es m.E.n. noch eher
  "[Zeichner]"          => "drm",
  "[Mitarb.]"           => "ctb",
  "[Kartograph]"        => "ctg",
  "[Lithograph]"        => "ltg",
  "[Stecher]"           => "egr"

);

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
      my $found = $self->mango_alephbagimport->db->collection('acnumbers')->find({ac_number => $ac}, {ac_number => 1})->next;
      if($found){
        $self->app->log->error("skipping $ac, already created");
      }else{
        $self->app->log->debug("adding $ac");
        $self->mango_alephbagimport->db->collection('acnumbers')->update({ac_number => $ac}, { '$set' => { ac_number => $ac, created => time, updated => time} }, { upsert => 1 });
      }
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
    ->sort({ac_number => 1})
		->fields({ _id => 1, ac_number => 1, created => 1, updated => 1, mapping_alerts => 1})
		->all();

  foreach my $a (@{$res}){
    #$self->app->log->debug("Checking requests ".$a->{ac_number});
    ($a->{fetch_status}, $a->{fetched}, $a->{requested}) = $self->get_fetch_status($a->{ac_number});
    #$self->app->log->debug("Checking bags ".$a->{ac_number});
    $a->{bag_created} = $self->get_bag_status($a->{ac_number});
  }

  $self->render(json => { acnumbers => $res }, status => 200);
}

sub get_fetch_status {
  my $self = shift;
  my $ac = shift;

  my $req_stat = $self->mango_stage->db->collection('requests')->find({ac_number => $ac})->sort({ts_iso => -1})->fields({status => 1, created => 1})->next;
  my $md_stat = $self->mango_stage->db->collection('aleph.mab')->find({ac_number => $ac})->sort({fetched => -1})->fields({fetched => 1})->next;

  #$self->app->log->debug($self->app->dumper($req_stat));
  #$self->app->log->debug($self->app->dumper($md_stat));

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

  my $payload = $self->req->json;
  my $acnumbers = $payload->{acnumbers};

  my $res = { alerts => [], status => 200 };

  if(ref($acnumbers) ne 'ARRAY'){
   $acnumbers = [$acnumbers];
  }

  foreach my $acnumber (@{$acnumbers}){

	  unless($acnumber =~ /AC(\d)+/g){
	    push @{$res->{alerts}}, { type => "danger", msg =>  "Creating request failed, $acnumber is not an AC number" };
	    next;
	  }

	  my $time = time ();
	  my @ts = localtime ($time);
	  my $ts_ISO = sprintf ("%04d%02d%02dT%02d%02d%02d", $ts[5]+1900, $ts[4]+1, $ts[3], $ts[2], $ts[1], $ts[0]);

	  my %req = (
	   ts_iso => $ts_ISO,
	   created => time,
	   status => 'new',
	   agent => 'aleph_cat',
	   action => 'update_aleph_2xml',
	   ac_number => $acnumber
	  );

	  $self->app->log->debug("Inserting request: ".$self->app->dumper(\%req));

	  $self->mango_stage->db->collection('requests')->insert(\%req);

  }

  $self->render(json => $res, status => $res->{status});
}

sub createbag {
  my $self = shift;

  my $payload = $self->req->json;
  my $acnumbers = $payload->{acnumbers};


  if(ref($acnumbers) ne 'ARRAY'){
   $acnumbers = [$acnumbers];
  }

  my $res = { alerts => [], status => 200 };

  foreach my $acnumber (@{$acnumbers}){

	  unless($acnumber =~ /AC(\d)+/g){
	    push @{$res->{alerts}}, { type => "danger", msg =>  "Creating bag failed, $acnumber is not an AC number" };
	    next;
	  }

	  my $bag_stat = $self->mango_bagger->db->collection('bags')->find({ac_number => $acnumber})->sort({created => -1})->fields({created => 1})->next;
	  if(exists($bag_stat->{created})){
	    push @{$res->{alerts}}, { type => "danger", msg =>  "Creating bag failed, Bag with $acnumber already exists, created: ".$self->get_tsISO($bag_stat->{created})};
	    next;
	  }

	  $self->app->log->debug("Getting mab for ".$acnumber);
	  my $md_stat = $self->mango_stage->db->collection('aleph.mab')->find({ac_number => $acnumber})->sort({fetched => -1})->fields({fetched => 1, xmlref2 => 1})->next;

	  unless($md_stat->{xmlref2}){
	    push @{$res->{alerts}}, { type => "danger", msg =>  "Creating bag for $acnumber failed, no mab metadata found"};
	    next;
	  }

	  my $mab = $md_stat->{xmlref2};

	  $self->app->log->debug("Mapping mab (fetched ".$self->get_tsISO($md_stat->{fetched}).") to mods ".$acnumber);
	  my ($mods, $geo) = $self->mab2mods($mab, $acnumber);

	  $self->app->log->debug("Creating bag ".$acnumber);
	  my $project = $self->app->config->{project};
	  my $folderid = $self->app->config->{folderid};
	  my $bagid = $project.$folderid.$acnumber.'tif';
	  my $reply = $self->mango_bagger->db->collection('bags')->insert({ ac_number => $acnumber, bagid => $bagid, file => $acnumber.'.tif', label => $acnumber, folderid => $folderid, tags => [], project => $project, metadata => {mods => $mods, geo => $geo}, status => 'new', assignee => '', created => time, updated => time } );
	  my $oid = $reply->{oid};
	  unless($oid){
	    push @{$res->{alerts}}, { type => "danger", msg => "Inserting bag $bagid failed" };
  	}

  }

  $self->render(json => $res, status => $res->{status});
}

sub get_tsISO {
  my $self = shift;
  my $tsin = shift;
  my @ts = localtime ($tsin);
  return sprintf ("%02d.%02d.%04d %02d:%02d:%02d", $ts[3], $ts[4]+1, $ts[5]+1900, $ts[2], $ts[1], $ts[0]);
}

sub mab2mods {
  my $self = shift;
  my $mab = shift;
  my $ac = shift;
  my @mods;
  my $geo;
  #my $fixfields = $mab->{record}->{0}->{metadata}->{0}->{oai_marc}->{0}->{fixfield};
  my $fields = $mab->{record}[0]->{metadata}[0]->{oai_marc}[0]->{varfield};

  #$self->app->log->debug("varfields: ".$self->app->dumper($fields));

  $self->{mapping_alerts} = [];

  my $subject_node = $self->get_subject_node();

  # 001
  if(exists($fields->{'001'})){
    if($fields->{'001'}->{'i1'} ne '-'){
      push @{$self->{mapping_alerts}}, { type => 'danger', msg => "'001-' not found"};
    }else{
      foreach my $sf (@{$fields->{'001'}->{subfield}}){
        if($sf->{label} ne 'a'){
          push @{$self->{mapping_alerts}}, { type => 'danger', msg => "'001-".$sf->{label}."' found, missing mapping. Value:".$sf->{content}};
        }else{
          my $acnumber = $sf->{content};
          my $id_node = $self->get_id_node('ac-number', $acnumber);
          push @mods, $id_node;
        }
      }
    }
  }

  # 003
  # FIXME: check
  if(exists($fields->{'003'})){
    if($fields->{'003'}->{'i1'} ne '-'){
      push @{$self->{mapping_alerts}}, { type => 'danger', msg => "'003-' not found"};
    }else{
      foreach my $sf (@{$fields->{'003'}->{subfield}}){
        if($sf->{label} ne 'a'){
          push @{$self->{mapping_alerts}}, { type => 'danger', msg => "'003-".$sf->{label}."' found, missing mapping. Value:".$sf->{content}};
        }else{
          my $parent_id = $sf->{content};
          my $relateditem_node = $self->get_relateditem_node('host');
          my $id_node = $self->get_id_node('local', $parent_id);
          push @{$relateditem_node->{children}}, $id_node;
          push @mods, $relateditem_node;
        }
      }
    }
  }

  # 037 b a
  if(exists($fields->{'037'})){
    if($fields->{'037'}->{'i1'} ne 'b'){
      push @{$self->{mapping_alerts}}, { type => 'danger', msg => "'037b' not found"};
    }else{
      foreach my $sf (@{$fields->{'037'}->{subfield}}){
        if($sf->{label} ne 'a'){
          push @{$self->{mapping_alerts}}, { type => 'danger', msg => "'037b".$sf->{label}."' found, missing mapping. Value:".$sf->{content}};
        }else{
          my $lang = $sf->{content};
          my $lang_node = $self->get_lang_node($lang);
          push @mods, $lang_node;
        }
      }
    }
  }

  # 034 -
  # geocoordinates (new field)
  if(exists($fields->{'034'})){
    if($fields->{'034'}->{'i1'} eq '-'){
      my $geores = $self->get_coordinates($fields, '034');
      $geo = $geores->{geo};
      # TODO: add projection if possible!
      my $cart_node = $self->get_cartographics_node($geores->{scale});
      push @{$subject_node->{children}}, $cart_node;
    }else{
      push @{$self->{mapping_alerts}}, { type => 'info', msg => "'034 -' not found"};
    }

  }else{

    # 078 k
    # geocoordinates (old field)
    if(exists($fields->{'078'})){

      if($fields->{'078'}->{'i1'} eq 'k'){
        my $geores = $self->get_coordinates($fields, '078');
        $geo = $geores->{geo};
        # TODO: add projection if possible!
        my $cart_node = $self->get_cartographics_node($geores->{scale});
        push @{$subject_node->{children}}, $cart_node;
      }else{
        push @{$self->{mapping_alerts}}, { type => 'danger', msg => "'078 k' not found"};
      }

    }
  }

  # 100-/100b
  for(my $i=100; $i <= 196; $i=$i+4){
    if($fields->{"$i"}){
      my $name_node = $self->get_name_node($fields, $i);
      push @mods, $name_node;
    }
  }

  # 200-/200b
  for(my $i=200; $i <= 296; $i=$i+4){
    if(exists($fields->{"$i"})){
      my $name_node = $self->get_corporatename_node($fields, $i);
      push @mods, $name_node;
    }
  }

  # 304
  if(exists($fields->{"304"})){
    my $title_uniform = $self->get_titleinfo_node($fields, '304', undef, 'uniform');
    push @mods, $title_uniform;
  }

  # 310
  if(exists($fields->{"310"})){
    my $title_alternative = $self->get_titleinfo_node($fields, '310', undef, 'alternative');
    push @mods, $title_alternative;
  }

  # 331-335
  if(exists($fields->{"331"})){
    my $title = $self->get_titleinfo_node($fields, '331', '335');
    push @mods, $title;
  }
  # 341-343
  if(exists($fields->{"341"})){
    my $title = $self->get_titleinfo_node($fields, '341', '343', 'translated');
    push @mods, $title;
  }
  # 345-347
  if(exists($fields->{"345"})){
    my $title = $self->get_titleinfo_node($fields, '345', '347', 'translated');
    push @mods, $title;
  }
  # 349-351
  if(exists($fields->{"349"})){
    my $title = $self->get_titleinfo_node($fields, '349', '351', 'translated');
    push @mods, $title;
  }
  # 353-355
  if(exists($fields->{"353"})){
    my $title = $self->get_titleinfo_node($fields, '353', '355', 'translated');
    push @mods, $title;
  }

  if(exists($fields->{'361'})){
    my $relateditem_node = $self->get_relateditem_node('constituent');
    my $title_node = $self->get_titleinfo_node($fields, '361');
    push @{$relateditem_node->{children}}, $title_node;
    push @mods, $relateditem_node;
  }

  if(exists($fields->{'451'})){
    my $relateditem_node = $self->get_relateditem_node('series');
    my $title_node = $self->get_titleinfo_node($fields, '451');
    push @{$relateditem_node->{children}}, $title_node;
    push @mods, $relateditem_node;
  }

  my $origin_info_node = {
    "xmlname" => "originInfo",
    "input_type" => "node",
    "children" => []
  };

  # edition
  if(exists($fields->{'403'})){
    my $edition_node = $self->get_edition_node($fields, '403');
    push @{$origin_info_node->{children}}, $edition_node;
  }

  # fixed description for all maps
  my $note_node = {
    "xmlname" => "note",
    "input_type" => "input_text",
    "ui_value" => "Bestand der Kartensammlung der Fachbereichsbibliothek Geographie und Regionalforschung, Universität Wien",
    "attributes" => [
      {
        "xmlname" => "type",
        "input_type" => "select",
        "ui_value" => "statement of responsibility"
      },
      {
        "xmlname" => "lang",
        "input_type" => "input_text",
        "ui_value" => "ger"
      }
    ]
  };
  push @mods, $note_node;

  # fixed license for all maps
  my $license_node = {
    "xmlname" => "accessCondition",
    "input_type" => "input_text",
    "ui_value" => "http://creativecommons.org/publicdomain/mark/1.0/",
    "attributes" => [
      {
        "xmlname" => "type",
        "input_type" => "select",
        "ui_value" => "use and reproduction"
      }
    ]
  };
  push @mods, $license_node;

  # place of publication or printing
  if(exists($fields->{'410'})){
    my $place_node = $self->get_placeterm_node($fields, '410');
    push @{$origin_info_node->{children}}, $place_node;
  }

  # publisher or printer
  if(exists($fields->{'412'})){
    my $publisher_node = $self->get_publisher_node($fields, '412');
    push @{$origin_info_node->{children}}, $publisher_node;
  }

  # date of publication
  if(exists($fields->{'425'})){
    my $date_node = $self->get_date_node($fields, '425');
    push @{$origin_info_node->{children}}, $date_node;
  }

  if(scalar @{$origin_info_node->{children}} > 0){
    push @mods, $origin_info_node;
  }

  # extent
  if(exists($fields->{'433'})){
    my $extent_node = $self->get_extent_node($fields, '433');
    push @mods, $extent_node;
  }

  # notes 501, 512, 507, 511, 517, 525
  foreach my $code (['501', '512', '507', '511', '517', '525']){
    if(exists($fields->{$code})){
      my $note_node = $self->get_note_node($fields, $code);
      push @mods, $note_node;
    }
  }

  # keywords 902, 907, 912 … 947g (..s,z,f)
  for(my $i=902; $i <= 947; $i=$i+5){
    if(exists($fields->{$i})){
      my $keyword_nodes = $self->get_keyword_node($fields, $i);
      push @{$subject_node->{children}}, @$keyword_nodes;
    }
  }

  # bkl classification
  my $bklmodel = AlephBagImport::Model::Bkl->new;
  if(exists($fields->{'700'})){
    if($fields->{'700'}->{'i1'} eq 'f'){
      my $bkl_nodes = $self->get_bkl_nodes($fields, '700', $bklmodel);
      push @mods, @$bkl_nodes;        
    }
  }

  push @mods, $subject_node;

  push @mods, $self->get_recordInfo_node();

  if(scalar @{$self->{mapping_alerts}} > 0){
    $self->app->log->error($self->app->dumper($self->{mapping_alerts}));
  }

  $self->mango_alephbagimport->db->collection('acnumbers')->update({ac_number => $ac}, { '$set' => { mapping_alerts => $self->{mapping_alerts}, updated => time } });

  return \@mods, $geo;
}

sub get_keyword_node {
  my ($self, $fields, $code) = @_;

  my $keywords;
  foreach my $sf (@{$fields->{$code}->{subfield}}){

    my $val;
    my $xmlname;
    my $authority;
    if($sf->{label} eq 'g'){
      $val = $sf->{content};
      $authority = 'gnd';
      $xmlname = 'geographic';
    }
    if($sf->{label} eq 's'){
      $val = $sf->{content};
      $xmlname = 'topic';
    }
    if($sf->{label} eq 'z'){
      $val = $sf->{content};
      $xmlname = 'temporal';
    }
    if($sf->{label} eq 'f'){
      $val = $sf->{content};
      $xmlname = 'topic';
    }

    my $kw = {
      "xmlname" => $xmlname,
      "input_type" => "input_text",
      "ui_value" => $val
    };

    if($authority){
      push @{$kw->{attributes}}, {
        "xmlname" => "authority",
        "input_type" => "select",
        "ui_value" => "gnd"
      }
    }

    push @$keywords, $kw;

  }

  return $keywords;

}

sub get_note_node {
  my ($self, $fields, $code) = @_;

  unless($fields->{$code}->{'i1'} eq '-'){
    push @{$self->{mapping_alerts}}, { type => 'danger', msg => "note ($code) found, but not -, instead: ".$fields->{$code}->{'i1'}};
  }

  foreach my $sf (@{$fields->{$code}->{subfield}}){

    if($sf->{label} eq 'a'){
      my $val = $sf->{content};

      return {
        "xmlname" => "note",
        "input_type" => "input_text",
        "ui_value" => $val
      };
    }
  }

}

sub get_bkl_nodes {
  my ($self, $fields, $code, $bklmodel) = @_;

  my $i = $fields->{$code}->{'i1'};

  my $bkls;
  
  if($i eq 'f'){

    foreach my $sf (@{$fields->{$code}->{subfield}}){

      if($sf->{label} eq 'a'){
        my $val = $sf->{content};
        push @$bkls, {
          "xmlname" => "classification",
          "input_type" => "input_text",
          "ui_value" => $val,
          "attributes" => [
            {
              "xmlname" => "authority",
              "input_type" => "select",
              "ui_value" => "bkl"
            }
          ]
        };

        push @$bkls, {
          "xmlname" => "classification",
          "input_type" => "input_text",
          "attributes" => [
            {
              "xmlname" => "authorityURI",
              "input_type" => "select",
              "ui_value" => "http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/classification/"
            },
            {
              "xmlname" => "valueURI",
              "input_type" => "select",
              "ui_value" => "http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/classification/cls_10/".$bklmodel->get_tid($self, $val)
            }
          ]
        };
      }
    }

  }

  return $bkls;

}

sub get_extent_node {
  my ($self, $fields, $code) = @_;

  # indicator is ignored for 433
  #$fields->{$code}->{'i1'}

  foreach my $sf (@{$fields->{$code}->{subfield}}){

    if($sf->{label} eq 'a'){
      my $val = $sf->{content};

      return {
        "xmlname" => "physicalDescription",
        "input_type" => "node",
        "children" => [
          {
            "xmlname" => "extent",
            "input_type" => "input_text",
            "ui_value" => $val
          }
        ]
      };
    }
  }

}

sub get_date_node {
  my ($self, $fields, $code) = @_;

  if($fields->{$code}->{'i1'} ne '-' && $fields->{$code}->{'i1'} ne 'a'){
    push @{$self->{mapping_alerts}}, { type => 'danger', msg => "date ($code) found, but not - or a, instead: ".$fields->{$code}->{'i1'}};
  }

  my $val;
  foreach my $sf (@{$fields->{$code}->{subfield}}){

    if($sf->{label} eq 'a'){
      $val = $sf->{content};
    }

    if($sf->{label} eq '-'){
      $val = $sf->{content};
    }
  }

  return {
    "xmlname" => "dateIssued",
    "input_type" => "input_datetime",
    "ui_value" => $val,
    "attributes" => [
        {
            "xmlname" => "encoding",
            "input_type" => "select",
            "ui_value" => "w3cdtf"
        },
        {
            "xmlname" => "keyDate",
            "input_type" => "select",
            "ui_value" => "yes"
        }
    ]
  };

}


sub get_publisher_node {
  my ($self, $fields, $code) = @_;

  if($fields->{$code}->{'i1'} ne '-' && $fields->{$code}->{'i1'} ne 'a'){
    push @{$self->{mapping_alerts}}, { type => 'danger', msg => "publisher ($code) found, but not - or a, instead: ".$fields->{$code}->{'i1'}};
  }

  my $val;
  foreach my $sf (@{$fields->{$code}->{subfield}}){

    if($sf->{label} eq 'a'){
      $val = $sf->{content};
    }

    if($sf->{label} eq '-'){
      $val = $sf->{content};
    }
  }

  return {
    "xmlname" => "publisher",
    "input_type" => "input_text",
    "ui_value" => $val
  };

}

sub get_placeterm_node {
  my ($self, $fields, $code) = @_;

  if($fields->{$code}->{'i1'} ne '-' && $fields->{$code}->{'i1'} ne 'a'){
    push @{$self->{mapping_alerts}}, { type => 'danger', msg => "placeterm ($code) found, but not - or a, instead: ".$fields->{$code}->{'i1'}};
  }

  my $val;
  foreach my $sf (@{$fields->{$code}->{subfield}}){

    if($sf->{label} eq 'a'){
      $val = $sf->{content};
    }

    if($sf->{label} eq '-'){
      $val = $sf->{content};
    }
  }

  return {
    "xmlname" => "place",
    "input_type" => "node",
    "children" => [
        {
            "xmlname" => "placeTerm",
            "input_type" => "input_text",
            "ui_value" => $val,
            "attributes" => [
                {
                    "xmlname" => "type",
                    "input_type" => "select",
                    "ui_value" => "text"
                }
            ]
        }
    ]
  };

}

sub get_edition_node {
  my ($self, $fields, $code) = @_;

  unless($fields->{$code}->{'i1'} eq '-'){
    push @{$self->{mapping_alerts}}, { type => 'danger', msg => "edition statement ($code) found, but not -, instead: ".$fields->{$code}->{'i1'}};
  }

  foreach my $sf (@{$fields->{$code}->{subfield}}){

    if($sf->{label} eq 'a'){
      my $val = $sf->{content};

      return {
        "xmlname" => "edition",
        "input_type" => "input_text",
        "ui_value" => $val
      };
    }
  }

}

sub get_titleinfo_node {
  my ($self, $fields, $title_code, $subtitle_code, $type) = @_;

  # for titles, the indicator is ignored
  # $fields->{$code}->{'i1'}

  my $titleinfo_node = {
    "xmlname" => "titleInfo",
    "input_type" => "node"
  };

  if(defined($type)){
    $titleinfo_node->{attributes} = [ { "xmlname" => "type", "input_type" => "select", "ui_value" => $type } ];
  }

  foreach my $sf (@{$fields->{$title_code}->{subfield}}){
    if($sf->{label} eq 'a'){
      my $val = $sf->{content};
      push @{$titleinfo_node->{children}}, { "xmlname" => "title", "input_type" => "input_text", "ui_value" => $val };
    }else{
      push @{$self->{mapping_alerts}}, { type => 'danger', msg => "title ($title_code) found, but subfield not 'a', instead: ".$sf->{label}};
    }
  }

  if($subtitle_code){
    foreach my $sf (@{$fields->{$subtitle_code}->{subfield}}){
      if($sf->{label} eq 'a'){
        my $val = $sf->{content};
        push @{$titleinfo_node->{children}}, { "xmlname" => "subTitle", "input_type" => "input_text", "ui_value" => $val };
      }else{
        push @{$self->{mapping_alerts}}, { type => 'danger', msg => "subtitle ($subtitle_code) found, but subfield not 'a', instead: ".$sf->{label}};
      }
    }
  }

  return $titleinfo_node;
}

sub get_name_node {
  my ($self, $fields, $i) = @_;

  my $entity_type = $fields->{"$i"}->{'i1'};

  my $role_node;
  my $name;
  my $gnd = 0;
  my $gnd_id;
  foreach my $sf (@{$fields->{"$i"}->{subfield}}){

    # not normalized name
    if($sf->{label} eq 'a'){
      $name = $sf->{content};
    }

    if($sf->{label} eq 'p'){
      $name = $sf->{content};
      $gnd = 1;
    }

    if($sf->{label} eq '9'){
      $gnd_id = $sf->{content};
    }

    # role
    my $role;
    if($sf->{label} eq 'b'){
      $role = $sf->{content};
      if(exists($role_mapping{$role})){
          $role = $role_mapping{$role};
      }else{
          push @{$self->{mapping_alerts}}, { type => 'danger', msg => "unrecognized role: $role"};
      }
      $role_node = $self->get_role_node($role);
    }
  }

  my $name_node = $self->_get_name_node('personal', $name, $gnd, $gnd_id);

  unless(defined($role_node)){
    if(($i eq '100' && $entity_type eq '-') || $entity_type eq 'a'){
      $role_node = $self->get_role_node('aut');
    }elsif($entity_type eq 'b'){
      $role_node = $self->get_role_node('ctb');
    }else{
      push @{$self->{mapping_alerts}}, { type => 'danger', msg => "unrecognized indicator [$entity_type] in field [$i]"};
    }
  }

  if(defined($role_node)){
    push @{$name_node->{children}}, $role_node;
  }else{
    push @{$self->{mapping_alerts}}, { type => 'danger', msg => "1XX role not found!"};
  }

  return $name_node;
}


sub get_corporatename_node {
  my ($self, $fields, $i) = @_;

  my $entity_type = $fields->{"$i"}->{'i1'};

  if(($entity_type ne '-') && ($entity_type ne 'b') ){
    push @{$self->{mapping_alerts}}, { type => 'danger', msg => "unrecognized indicator [$entity_type] in 200 field"};
  }

  my $role_node;
  my $name;
  my $gnd = 0;
  my $gnd_id;
  foreach my $sf (@{$fields->{"$i"}->{subfield}}){

    # not normalized name
    if($sf->{label} eq 'a'){
      $name = $sf->{content};
    }

    if($sf->{label} eq 'k' || $sf->{label} eq 'g' || $sf->{label} eq 'b'){
      $name = $sf->{content};
      $gnd = 1;
    }

    if($sf->{label} eq '9'){
      $gnd_id = $sf->{content};
    }

  }

  my $name_node = $self->_get_name_node('corporate', $name, $gnd, $gnd_id);

  if(($i eq '200' && $entity_type eq '-') || $entity_type eq 'a'){
    $role_node = $self->get_role_node('aut');
  }elsif($entity_type eq 'b'){
    $role_node = $self->get_role_node('ctb');
  }else{
    push @{$self->{mapping_alerts}}, { type => 'danger', msg => "unrecognized indicator [$entity_type] in field [$i]"};
  }

  if(defined($role_node)){
    push @{$name_node->{children}}, $role_node;
  }else{
    push @{$self->{mapping_alerts}}, { type => 'danger', msg => "2XX role not found!"};
  }

  return $self->_get_name_node('corporate', $name, $gnd, $gnd_id);

}


sub _get_name_node {
  my ($self, $type, $name, $gnd, $gnd_id) = @_;

  my $node = {
      "xmlname" => "name",
      "input_type" => "node",
      "attributes" => [
        {
            "xmlname" => 'type',
            "input_type" => "select",
            "ui_value" => $type
        }
      ],
      "children" => []
  };

  if(defined($name)){
    if($type eq 'personal'){
      if($name =~ m/\s?(\w+)\s?,\s?(\w+)\s?/){
        my $lastname = $1;
        my $firstname = $2;
        push @{$node->{children}}, {
          "xmlname" => "namePart",
          "input_type" => "input_text",
          "ui_value" => $firstname,
          "attributes" => [
            {
              "xmlname" => "type",
              "input_type" => "select",
              "ui_value" => "given",
            }
          ]
        };
        push @{$node->{children}}, {
          "xmlname" => "namePart",
          "input_type" => "input_text",
          "ui_value" => $lastname,
          "attributes" => [
            {
              "xmlname" => "type",
              "input_type" => "select",
              "ui_value" => "family",
            }
          ]
        };
      }else{
        push @{$self->{mapping_alerts}}, { type => 'danger', msg => "Personal name without 'lastname, firstname' format: $name"};
      }
    }else{
      push @{$node->{children}}, { "xmlname" => "namePart",  "ui_value" => $name, "input_type" => "input_text" };
    }
  }

  if($gnd == 1){
    push @{$node->{attributes}}, { "xmlname" => "authority", "ui_value" => "gnd", "input_type" => "select" };
  }

  if(defined($gnd_id)){
    if($gnd_id =~ m/\([\w+-]+\)(\d+)/){
      $gnd_id = $1;
    }
    push @{$node->{attributes}}, { "xmlname" => "authorityURI", "ui_value" => "http://d-nb.info/gnd/", "input_type" => "input_text" };
    push @{$node->{attributes}}, { "xmlname" => "valueURI", "ui_value" => "http://d-nb.info/gnd/$gnd_id", "input_type" => "input_text" };
  }

  return $node;
}

sub get_role_node {
  my ($self, $role) = @_;

  return {
      "xmlname" => "role",
      "input_type" => "node",
      "children" => [
        {
            "xmlname" => "roleTerm",
            "input_type" => "input_text",
            "ui_value" => $role,
            "attributes" => [
              {
                  "xmlname" => "type",
                  "input_type" => "select",
                  "ui_value" => "code"
              },
              {
                  "xmlname" => "authority",
                  "input_type" => "select",
                  "ui_value" => "marcrelator"
              }
            ]
        }
      ]
  };
}

sub get_subject_node {
  my ($self) = @_;

  return {
    "xmlname" => "subject",
    "input_type" => "node",
    "children" => []
  };
}

sub get_cartographics_node {
  my ($self, $scale, $projection) = @_;

  my $cart = {
      "xmlname" => "cartographics",
      "input_type" => "node",
      "children" => []
  };

  if($scale){
    push @{$cart->{children}}, { "xmlname" => "scale", "ui_value" => $scale, "input_type" => "input_text" };
  }

  if($projection){
    push @{$cart->{children}}, { "xmlname" => "projection", "ui_value" => $projection, "input_type" => "input_text" };
  }

  return $cart;
}

sub get_coordinates {
  my ($self, $fields, $code) = @_;

  my ($scale, $W, $E, $N, $S);

  foreach my $sf (@{$fields->{$code}->{subfield}}){
    if($sf->{label} eq 'a'){
      # ignore
    }
    elsif($sf->{label} eq 'b'){
      $scale = $sf->{content};
    }
    elsif($sf->{label} eq 'd'){
      $W = $sf->{content};
    }
    elsif($sf->{label} eq 'e'){
      $E = $sf->{content};
    }
    elsif($sf->{label} eq 'f'){
      $N = $sf->{content};
    }
    elsif($sf->{label} eq 'g'){
      $S = $sf->{content};
    }
    else{
      push @{$self->{mapping_alerts}}, { type => 'danger', msg => "'$code?".$sf->{label}."' found, missing mapping. Value:".$sf->{content}};
    }

  }

  my $W_dec = $self->degrees_to_decimal($W);
  my $E_dec = $self->degrees_to_decimal($E);
  my $N_dec = $self->degrees_to_decimal($N);
  my $S_dec = $self->degrees_to_decimal($S);

  return {
    scale => $scale,
    geo => {
      kml =>
        {
          document =>
          {
            placemark => [
              {
                polygon =>
                {
                  outerboundaryis =>
                  {
                      linearring =>
                      {
                        coordinates => [
                           {
                             latitude => $W_dec,
                             longitude => $S_dec
                           },
                           {
                             latitude => $E_dec,
                             longitude => $S_dec
                           },
                           {
                             latitude =>  $E_dec,
                             longitude => $N_dec
                           },
                           {
                             latitude => $W_dec,
                             longitude => $N_dec
                           }
                        ]
                    }
                  }
                }
              }
            ]
        }
      }
    }
  };

}

sub degrees_to_decimal {
  my ($self, $aleph_deg) = @_;

  $aleph_deg =~ /(W|E|N|S)(\d\d\d)(\d\d)(\d\d)/g;

  return int($2) + (int($3)/60) + (int($4)/3600);
}

sub get_lang_node {
  my ($self, $lang) = @_;

  return {

    "xmlname" => "language",
    "input_type" => "node",
    "children" => [
        {
            "xmlname" => "languageTerm",
            "input_type" => "input_text",
            "ui_value" => $lang,
            "attributes" => [
                {
                    "xmlname" => "type",
                    "input_type" => "select",
                    "ui_value" => "code"
                },
                {
                    "xmlname" => "authority",
                    "input_type" => "select",
                    "ui_value" => "iso639-2b"
                }
            ]
        }
    ]

  };
}

sub get_recordInfo_node {

  my ($self) = @_;
 
  return {

    "xmlname" => "recordInfo",
    "input_type" => "node",
    "children" => [
		{
		    "xmlname" => "recordContentSource",
                    "input_type" => "input_text",
                    "ui_value" => "Universitätsbibliothek Wien"
		},
                {
                    "xmlname" => "recordOrigin",
                    "input_type" => "input_text",
                    "ui_value" => "Maschinell erzeugt"
                },
                {
                    "xmlname" => "languageOfCataloging",
                    "input_type" => "node",
                    "children" => [
                      {
                        "xmlname" => "languageTerm",
                        "input_type" => "input_text",
                        "ui_value" => "ger",
                        "attributes" => [
                            {
                                "xmlname" => "type",
                                "input_type" => "select",
                                "ui_value" => "code"
                            },
                            {
                                "xmlname" => "authority",
                                "input_type" => "select",
                                "ui_value" => "iso639-2b"
                            }
                        ]
                      }
                    ]
                },
                {
                    "xmlname" => "descriptionStandard",
                    "input_type" => "select",
                    "ui_value" => "rakwb"
                }

    ]

  };
}

sub get_relateditem_node {
  my ($self, $type) = @_;
  return {
      "xmlname" => "relatedItem",
      "input_type" => "node",
      "children" => [

      ],
      "attributes" => [
          {
              "xmlname" => "type",
              "input_type" => "select",
              "ui_value" => $type
          }
      ]
  }
}

sub get_id_node {
  my ($self, $type, $value) = @_;

  return {
      "xmlname" => "identifier",
      "input_type" => "input_text",
      "ui_value" => $value,
      "attributes" => [
          {
              "xmlname" => "type",
              "input_type" => "select",
              "ui_value" => $type
          }
      ]
  };

}




1;
