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

  # Fällt im Englischen mit editor zusammen
  "[Bearb.]"            => "edt",
  "[Hrsg.]"             => "edt",
  "[Drucker]"           => "prt",
  "[Ill.]"              => "ill",
  "[Widmungsempfänger]" => "dte",
  # drm steht eigentlich für Technischer Zeichner, es gibt aber ansonsten nur Künstler - in beiden Fällen ist etwas anderes gemeint, aber Technischer Zeichner trifft es m.E.n. noch eher
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
  my $keyword_chains;

  #my $fixfields = $mab->{record}->{0}->{metadata}->{0}->{oai_marc}->{0}->{fixfield};
  my $fields = $mab->{record}[0]->{metadata}[0]->{oai_marc}[0]->{varfield};

=cut
  my $fields;
  for my $f (@$fields_arr){
    if(exists($f->{'id'})){
      if(exists($f->{subfield})){
	push @{$fields->{$f->{'id'}}->{subfield}}, $f->{subfield};
      }
      push @{$fields->{$f->{'id'}}->{subfield}}, $f->{subfield};
    }else{
      $fields->{$f->{'id'}} = $f;
    }
  }
=cut

  #$self->app->log->debug("varfields: ".$self->app->dumper($fields));

  $self->{mapping_alerts} = [];

  my $bklmodel = AlephBagImport::Model::Bkl->new;

  my $origin_info_node = {
    "xmlname" => "originInfo",
    "input_type" => "node",
    "children" => []
  };

  my $physical_description_node = {
    "xmlname" => "physicalDescription",
    "input_type" => "node",
    "children" => []
  };

  # date of publication, we first sort this, because if there are more dates, we use only 425a
  my $found_a = 0;
  for my $f (@$fields){
    if($f->{id} eq '425'){
       if($f->{'i1'} eq 'a'){
          $found_a = 1;
          my $date_node = $self->get_date_node($f);
          push @{$origin_info_node->{children}}, $date_node;
          last;
        }
    }
  }
  unless($found_a){
   for my $f (@$fields){
    if($f->{id} eq '425'){
      my $date_node = $self->get_date_node($f);
      push @{$origin_info_node->{children}}, $date_node;
      push @{$self->{mapping_alerts}}, { type => 'danger', msg => "425a not found, using 425".$f->{'i1'}};
      last;
    }
   }
  }

  for my $field (@$fields){ 

    my $fieldid = $field->{'id'};
    my $fieldidint = int($field->{'id'});

    # 001
    if($fieldid eq '001'){
      if($field->{'i1'} ne '-'){
        push @{$self->{mapping_alerts}}, { type => 'danger', msg => "'001-' not found"};
      }else{
        foreach my $sf (@{$field->{subfield}}){
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

    # 003 - is ignored
=cut    
    if($fieldid eq '003'){
      if($field->{'i1'} ne '-'){
        push @{$self->{mapping_alerts}}, { type => 'danger', msg => "'003-' not found"};
      }else{
        foreach my $sf (@{$field->{subfield}}){
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
=cut

    # 037 b a
    if($fieldid eq '037'){
      if($field->{'i1'} ne 'b'){
        push @{$self->{mapping_alerts}}, { type => 'danger', msg => "'037b' not found"};
      }else{
        foreach my $sf (@{$field->{subfield}}){
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
    if($fieldid eq '034'){
      if($field->{'i1'} eq '-'){
        my $geores = $self->get_coordinates($field);
        $geo = $geores->{geo};
        # TODO: add projection if possible!
        my $cart_node = $self->get_cartographics_node($geores->{scale});
        my $subject_node = $self->get_subject_node();
        push @{$subject_node->{children}}, $cart_node;
        push @mods, $subject_node;
      }else{
        push @{$self->{mapping_alerts}}, { type => 'info', msg => "'034 -' not found"};
      }

    }else{

      # 078 k
      # geocoordinates (old field)
      if($fieldid eq '078'){
        if($field->{'i1'} eq 'k'){
          my $geores = $self->get_coordinates($field);
          $geo = $geores->{geo};
          # TODO: add projection if possible!
          my $cart_node = $self->get_cartographics_node($geores->{scale});          
          my $subject_node = $self->get_subject_node();
          push @{$subject_node->{children}}, $cart_node;
          push @mods, $subject_node;
        }else{
          push @{$self->{mapping_alerts}}, { type => 'danger', msg => "'078 k' not found"};
        }

      }
    }

    # 100-/100b
    if($fieldidint >= 100 && $fieldidint <= 196 && ($fieldidint % 4 == 0 )){
      my $name_node = $self->get_name_node($field);
      push @mods, $name_node;
    }

    # 200-/200b
    if($fieldidint >= 200 && $fieldidint <= 296 && ($fieldidint % 4 == 0 )){ 
      my $name_node = $self->get_corporatename_node($field);
      push @mods, $name_node;
    }

    # 304
    if($fieldid eq "304"){
      my $title_uniform = $self->get_titleinfo_node($field, undef, 'uniform');
      push @mods, $title_uniform;
    }

    # 310
    if($fieldid eq "310"){
      my $title_alternative = $self->get_titleinfo_node($field, undef, 'alternative');
      push @mods, $title_alternative;
    }

    # 331-335
    if($fieldid eq "331"){
      my $subtitle_field;
      for my $f (@$fields){ 
        if($f->{id} eq '335'){
  	      $subtitle_field = $f; last;
        }
      }

      my $title = $self->get_titleinfo_node($field, $subtitle_field);
      push @mods, $title;
    }
    # 341-343
    if($fieldid eq "341"){
      my $subtitle_field;
      for my $f (@$fields){  
        if($f->{id} eq '343'){
          $subtitle_field = $f; last;
        }
      }
      my $title = $self->get_titleinfo_node($field, $subtitle_field, 'translated');
      push @mods, $title;
    }
    # 345-347
    if($fieldid eq "345"){
      my $subtitle_field;
      for my $f (@$fields){
        if($f->{id} eq '347'){
          $subtitle_field = $f; last;
        }
      }
      my $title = $self->get_titleinfo_node($field, $subtitle_field, 'translated');
      push @mods, $title;
    }
    # 349-351
    if($fieldid eq "349"){
      my $subtitle_field;
      for my $f (@$fields){
        if($f->{id} eq '351'){
          $subtitle_field = $f; last;
        }
      }
      my $title = $self->get_titleinfo_node($field, $subtitle_field, 'translated');
      push @mods, $title;
    }
    # 353-355
    if($fieldid eq "353"){
      my $subtitle_field;
      for my $f (@$fields){
        if($f->{id} eq '355'){
          $subtitle_field = $f; last;
        }
      }
      my $title = $self->get_titleinfo_node($field, $subtitle_field, 'translated');
      push @mods, $title;
    }

    if($fieldid eq "361"){
      my $relateditem_node = $self->get_relateditem_node('constituent');
      my $title_node = $self->get_titleinfo_node($field);
      push @{$relateditem_node->{children}}, $title_node;
      push @mods, $relateditem_node;
    }

    if($fieldid eq "451"){
      my $relateditem_node = $self->get_relateditem_node('series');
      my $title_node = $self->get_titleinfo_node($field);
      push @{$relateditem_node->{children}}, $title_node;
      push @mods, $relateditem_node;
    }

    # edition
    if($fieldid eq "403"){
      my $edition_node = $self->get_edition_node($field);
      push @{$origin_info_node->{children}}, $edition_node;
    }

    # place of publication or printing
    if($fieldid eq '410'){
      my $place_node = $self->get_placeterm_node($field);
      push @{$origin_info_node->{children}}, $place_node;
    }

    # publisher or printer
    if($fieldid eq '412'){
      my $publisher_node = $self->get_publisher_node($field);
      push @{$origin_info_node->{children}}, $publisher_node;
    }

    # extent
    if(($fieldid eq '433') || ($fieldid eq '435')){
      my $extent_node = $self->get_extent_node($field);
      push @{$physical_description_node->{children}}, $extent_node;
    }

    # production method
    if($fieldid eq '434'){
      my $form_node = $self->get_form_node($field);
      push @{$physical_description_node->{children}}, $form_node;
    }

    # notes 501, 512, 507, 511, 517, 525    
    foreach my $code (('501', '512', '507', '511', '517', '525')){
      if($fieldid eq $code){
        my $note_node = $self->get_note_node($field, $fieldidint);
        push @mods, $note_node;
      }
    }

    # keywords 902, 907, 912 … 947g (..s,z,f)    
    if($fieldidint >= 902 && $fieldidint <= 947 && (($fieldidint+3) % 5 == 0 )){
      push @{$keyword_chains->{fieldidint}}, $self->get_keyword_nodes($field);      
    }

    # bkl classification
    if($fieldid eq '700'){
      if($field->{'i1'} eq 'f'){
        my $bkl_nodes = $self->get_bkl_nodes($field, $bklmodel);
        push @mods, @$bkl_nodes;        
      }
    }

  }
  
  for my $field (keys %{$keyword_chains}){
    
    my $subject_node = $self->get_subject_node();

    for my $kws (@{$keyword_chains->{$field}}){
      for my $k (@{$kws}){
        push @{$subject_node->{children}}, $k;
      }
    }

    push @mods, $subject_node;
  }

  if(scalar @{$origin_info_node->{children}} > 0){
    push @mods, $origin_info_node;
  }

  if(scalar @{$physical_description_node->{children}} > 0){
    push @mods, $physical_description_node;
  }

  # static data added to every map
  push @mods, $self->get_fixed_recordInfo_node();  
  push @mods, $self->get_fixed_note_node();
  push @mods, $self->get_fixed_license_node();

  if(scalar @{$self->{mapping_alerts}} > 0){
    $self->app->log->error($self->app->dumper($self->{mapping_alerts}));
  }

  $self->mango_alephbagimport->db->collection('acnumbers')->update({ac_number => $ac}, { '$set' => { mapping_alerts => $self->{mapping_alerts}, updated => time } });

  return \@mods, $geo;
}

sub get_subject_node {
  my ($self) = @_;

  return {
    "xmlname" => "subject",
    "input_type" => "node",
    "children" => []
  };
}

sub get_keyword_nodes {
  my ($self, $field) = @_;

  my $keywords;
  foreach my $sf (@{$field->{subfield}}){

    my $xmlname;
    my $gnd_id;
    my $name_node;
    my $z_value;
    my $val = $sf->{content};
    my $lab = $sf->{label};
    my $ind = $field->{i1};    

    # '9' and 'h' contain only additional information to another keyword, inspect only in a subloop
    next if $lab eq '9';
    next if $lab eq 'h';
    my $non_z_subfield_found = 0;
    foreach my $sf1 (@{$field->{subfield}}){

      if($sf1->{label} eq 'h'){
        $val = "$val, ".$sf1->{content};        
      }

      if($sf1->{label} eq '9'){
        if($sf1->{content} =~ m/\([\w+-]+\)([\d-]+)/){
          $gnd_id = $1;
        }
      }    

      if(($sf1->{label} ne '9') && ($sf1->{label} ne 'h') && ($sf1->{label} ne 'z')){
        $non_z_subfield_found = 1;
      }

      if($sf1->{label} eq 'z'){
        $z_value = $sf1->{content};        
      }
    }

    # in this case 'z' is just additional information
    # add it to value with a comma
    if($lab ne 'z' && defined($gnd_id) && defined($z_value)){
      $val = "$val, ".$z_value
    }

    if($lab eq 'z'){
      # in this case 'z' is just additional information
      # it will be added later, skip
      if($non_z_subfield_found && defined($gnd_id)){        
        next;
      }else{
        # in the other case it's a standalone 'temporal' keyword
        $xmlname = 'temporal';
      }
    }  

    # Personal name (GND)    
    if($lab eq 'p'){   
      $name_node = $self->_get_name_node('personal', $val, 1, $gnd_id);
    }

    # Corporate name (GND)
    if($lab eq 'k'){    
      $name_node = $self->_get_name_node('corporate', $val, 1, $gnd_id);
    }

    # Gebietskörperschaftsname (GND)
    if($lab eq 'g'){
      $xmlname = 'geographic';
    }

    # Sachbegriff (GND)
    if($lab eq 's'){
      $xmlname = 'topic';
    }

    if($lab eq 'f'){
      if(defined($gnd_id)){
        # f - Titel: Erscheinungsjahr eines Werkes (GND)
        next;
      }else{
        # f - Formschlagwort (ohne GND-IDNR)
        $xmlname = 'topic';
      }
    }

    unless(defined($xmlname)){      
      push @{$self->{mapping_alerts}}, { type => 'danger', msg => "mapping missing for field ".$field->{'id'}." ind[$ind] lab[$lab] val[$val]"};
      next;
    }

    my $kw = {
      "xmlname" => $xmlname,
      "input_type" => "input_text",
      "ui_value" => $val
    };

    # all keywords are always GND    
    push @{$kw->{attributes}}, {
      "xmlname" => "authority",
      "input_type" => "select",
      "ui_value" => "gnd"
    };
    
    if($gnd_id){
      push @{$kw->{attributes}}, {
        "xmlname" => "authorityURI",
        "input_type" => "input_text",
        "ui_value" => "http://d-nb.info/gnd/"
      };
      push @{$kw->{attributes}}, {
        "xmlname" => "valueURI",
        "input_type" => "input_text",
        "ui_value" => "http://d-nb.info/gnd/$gnd_id"
      };
    }

    if($name_node){
      push @$keywords, $name_node;
    }else{
      push @$keywords, $kw;
    }

  }

  return $keywords;

}

sub get_note_node {
  my ($self, $field, $fieldidint) = @_;

  # | Field | Indicator  | Subfield |  
  # | ------|----------  | -------- |  
  # | 501   | _          | a        |  
  # | 507   | _          | a, p     |  
  # | 511   | _          | a        |  
  # | 512   | _, a       | a        |  
  # | 517   | _, a, b, c | p        |  
  # | 525   | _          | p + a    |   
  my $val;
  if(($fieldidint eq 511) || ($fieldidint eq 501)){
    unless($field->{'i1'} eq '-'){
      push @{$self->{mapping_alerts}}, { type => 'danger', msg => "note (".$field->{id}.") found, but indicator not -, instead: ".$field->{'i1'}};
    }

    foreach my $sf (@{$field->{subfield}}){
      if($sf->{label} eq 'a'){
        $val = $sf->{content};        
      }else{
        push @{$self->{mapping_alerts}}, { type => 'danger', msg => "note (".$field->{id}.") found, but subfield not a, instead: ".$sf->{label} };
      }
    }
  }

  if($fieldidint eq 507){
    unless($field->{'i1'} eq '-'){
      push @{$self->{mapping_alerts}}, { type => 'danger', msg => "note (".$field->{id}.") found, but indicator not -, instead: ".$field->{'i1'}};
    }

    foreach my $sf (@{$field->{subfield}}){
      if($sf->{label} eq 'a'){
        $val = $sf->{content};        
      }else{
        push @{$self->{mapping_alerts}}, { type => 'danger', msg => "note (".$field->{id}.") found, but subfield not a, instead: ".$sf->{label} };
      }
    }
  }

  if($fieldidint eq 512){
    unless($field->{'i1'} eq '-' || $field->{'i1'} eq 'a'){
      push @{$self->{mapping_alerts}}, { type => 'danger', msg => "note (".$field->{id}.") found, but indicator not - or a, instead: ".$field->{'i1'}};
    }

    foreach my $sf (@{$field->{subfield}}){
      if($sf->{label} eq 'a'){
        $val = $sf->{content};        
      }else{
        push @{$self->{mapping_alerts}}, { type => 'danger', msg => "note (".$field->{id}.") found, but subfield not a, instead: ".$sf->{label} };
      }
    }
  }

  if($fieldidint eq 517){
    unless($field->{'i1'} eq '-' || $field->{'i1'} eq 'a' || $field->{'i1'} eq 'b' || $field->{'i1'} eq 'c'){
      push @{$self->{mapping_alerts}}, { type => 'danger', msg => "note (".$field->{id}.") found, but indicator not - or a or b or c, instead: ".$field->{'i1'}};
    }

    foreach my $sf (@{$field->{subfield}}){
      if($sf->{label} eq 'a'){
        $val = $sf->{content};        
      }else{
        push @{$self->{mapping_alerts}}, { type => 'danger', msg => "note (".$field->{id}.") found, but subfield not a, instead: ".$sf->{label} };
      }
    }
  }

  if($fieldidint eq 525){
    $val = '';
    unless($field->{'i1'} eq '-'){
      push @{$self->{mapping_alerts}}, { type => 'danger', msg => "note (".$field->{id}.") found, but indicator not -, instead: ".$field->{'i1'}};
    }

    foreach my $sf (@{$field->{subfield}}){
      if($sf->{label} eq 'a'){
        $val = $val.$sf->{content};
      }elsif($sf->{label} eq 'p'){
        $val = $sf->{content}." ".$val;
      }else{
        push @{$self->{mapping_alerts}}, { type => 'danger', msg => "note (".$field->{id}.") found, but subfield not a or p, instead: ".$sf->{label} };
      }      
    }

  }
  
  return {
    "xmlname" => "note",
    "input_type" => "input_text",
    "ui_value" => $val
  };

}

sub get_bkl_nodes {
  my ($self, $field, $bklmodel) = @_;

  my $i = $field->{'i1'};

  my $bkls;
  
  if($i eq 'f'){

    foreach my $sf (@{$field->{subfield}}){

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
  my ($self, $field) = @_;

  if($field->{'i1'} ne '-'){
    push @{$self->{mapping_alerts}}, { type => 'danger', msg => "extent (".$field->{id}.") found, but indicator not -, instead: ".$field->{'i1'}};
  }

  foreach my $sf (@{$field->{subfield}}){

    if($sf->{label} eq 'a'){
      my $val = $sf->{content};

      return {
        "xmlname" => "extent",
        "input_type" => "input_text",
        "ui_value" => $val
      };
    }else{
      push @{$self->{mapping_alerts}}, { type => 'danger', msg => "extent (".$field->{id}.") found, but subfield not a, instead: ".$sf->{label} };
    }
  }

}

sub get_form_node {
  my ($self, $field) = @_;

  if($field->{'i1'} ne '-'){
    push @{$self->{mapping_alerts}}, { type => 'danger', msg => "form (".$field->{id}.") found, but indicator not -, instead: ".$field->{'i1'}};
  }

  foreach my $sf (@{$field->{subfield}}){

    if($sf->{label} eq 'a'){
      my $val = $sf->{content};

      return {
        "xmlname" => "form",
        "input_type" => "input_text",
        "ui_value" => $val
      };
    }else{
      push @{$self->{mapping_alerts}}, { type => 'danger', msg => "form (".$field->{id}.") found, but subfield not a, instead: ".$sf->{label} };
    }
  }

}

sub get_date_node {
  my ($self, $field) = @_;

  if($field->{'i1'} ne '-' && $field->{'i1'} ne 'a'){
    push @{$self->{mapping_alerts}}, { type => 'danger', msg => "date (".$field->{id}.") found, but indicator not - or a, instead: ".$field->{'i1'}};
  }

  my $val;
  foreach my $sf (@{$field->{subfield}}){

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
  my ($self, $field) = @_;

  if($field->{'i1'} ne '-' && $field->{'i1'} ne 'a'){
    push @{$self->{mapping_alerts}}, { type => 'danger', msg => "publisher (".$field->{id}.") found, but indicator not - or a, instead: ".$field->{'i1'}};
  }

  my $val;
  foreach my $sf (@{$field->{subfield}}){

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
  my ($self, $field) = @_;

  if($field->{'i1'} ne '-' && $field->{'i1'} ne 'a'){
    push @{$self->{mapping_alerts}}, { type => 'danger', msg => "placeterm (".$field->{id}.") found, but indicator not - or a, instead: ".$field->{'i1'}};
  }

  my $val;
  foreach my $sf (@{$field->{subfield}}){

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
  my ($self, $field) = @_;

  unless($field->{'i1'} eq '-'){
    push @{$self->{mapping_alerts}}, { type => 'danger', msg => "edition statement (".$field->{id}.") found, but indicator not -, instead: ".$field->{'i1'}};
  }

  foreach my $sf (@{$field->{subfield}}){

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
  my ($self, $field, $subtitle_field, $type) = @_;

  # for titles, the indicator is ignored
  # $field->{'i1'}

  my $titleinfo_node = {
    "xmlname" => "titleInfo",
    "input_type" => "node"
  };

  if(defined($type)){
    $titleinfo_node->{attributes} = [ { "xmlname" => "type", "input_type" => "select", "ui_value" => $type } ];
  }

  foreach my $sf (@{$field->{subfield}}){
    if($sf->{label} eq 'a'){
      my $val = $sf->{content};
      $val =~ s/\<//g;
      $val =~ s/\>//g;
      push @{$titleinfo_node->{children}}, { "xmlname" => "title", "input_type" => "input_text", "ui_value" => $val };
    }else{
      push @{$self->{mapping_alerts}}, { type => 'danger', msg => "title ($field->{id}) found, but subfield not 'a', instead: ".$sf->{label}};
    }
  }

  if(defined($subtitle_field)){
    foreach my $sf (@{$subtitle_field->{subfield}}){
      if($sf->{label} eq 'a'){
        my $val = $sf->{content};
        $val =~ s/\<//g;
        $val =~ s/\>//g;
        push @{$titleinfo_node->{children}}, { "xmlname" => "subTitle", "input_type" => "input_text", "ui_value" => $val };
      }else{
        push @{$self->{mapping_alerts}}, { type => 'danger', msg => "subtitle ($subtitle_field->{id}) found, but subfield not 'a', instead: ".$sf->{label}};
      }
    }
  }

  return $titleinfo_node;
}

sub get_name_node {
  my ($self, $field) = @_;

  my $entity_type = $field->{'i1'};

  my $role_node;
  my $name;
  my $gnd = 0;
  my $gnd_id;
  foreach my $sf (@{$field->{subfield}}){

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
    if(($field->{id} eq '100' && $entity_type eq '-') || $entity_type eq 'a'){
      $role_node = $self->get_role_node('aut');
    }elsif($entity_type eq 'b'){
      $role_node = $self->get_role_node('ctb');
    }else{
      push @{$self->{mapping_alerts}}, { type => 'danger', msg => "unrecognized indicator [$entity_type] in field [".$field->{id}."]"};
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
  my ($self, $field) = @_;

  my $entity_type = $field->{'i1'};

  if(($entity_type ne '-') && ($entity_type ne 'b') ){
    push @{$self->{mapping_alerts}}, { type => 'danger', msg => "unrecognized indicator [$entity_type] in 200 field"};
  }

  my $role_node;
  my $name;
  my $gnd = 0;
  my $gnd_id;
  foreach my $sf (@{$field->{subfield}}){

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

  if(($field->{id} eq '200' && $entity_type eq '-') || $entity_type eq 'a'){
    $role_node = $self->get_role_node('aut');
  }elsif($entity_type eq 'b'){
    $role_node = $self->get_role_node('ctb');
  }else{
    push @{$self->{mapping_alerts}}, { type => 'danger', msg => "unrecognized indicator [$entity_type] in field [".$field->{id}."]"};
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
      #if($name =~ m/\s?(\w+)\s?,\s?([\w\.]+)\s?/){
      if($name =~ m/\s?(\w+)\s?,(.+)/){
        my $lastname = $1;
        my $firstname = $2;
        $firstname =~ s/\<//g;
        $firstname =~ s/\>//g;
	      if($firstname ne '...'){
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
	      }
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
        push @{$self->{mapping_alerts}}, { type => 'warning', msg => "Personal name without 'lastname, firstname' format: $name"};

        push @{$node->{children}}, {
          "xmlname" => "namePart",
          "input_type" => "input_text",
          "ui_value" => $name          
        };
      }
    }else{
      push @{$node->{children}}, { "xmlname" => "namePart",  "ui_value" => $name, "input_type" => "input_text" };
    }
  }

  if($gnd == 1){
    push @{$node->{attributes}}, { "xmlname" => "authority", "ui_value" => "gnd", "input_type" => "select" };
  }

  if(defined($gnd_id)){
    if($gnd_id =~ m/\([\w+-]+\)(\d+-?\d+)/){
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
  my ($self, $field) = @_;

  my ($scale, $W, $E, $N, $S);

  foreach my $sf (@{$field->{subfield}}){
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
      push @{$self->{mapping_alerts}}, { type => 'danger', msg => $field->{id}.$sf->{label}."' found, missing mapping. Value:".$sf->{content}};
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

sub get_fixed_license_node {

  my ($self) = @_;
 
  return {
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

}

sub get_fixed_note_node {

  my ($self) = @_;
 
  return {
    "xmlname" => "note",
    "input_type" => "input_text",
    "ui_value" => "Bestand der Kartensammlung der Fachbereichsbibliothek Geographie und Regionalforschung, Universität Wien",
    "attributes" => [
      {
        "xmlname" => "type",
        "input_type" => "select",
        "ui_value" => "statement of responsibility"
      }
    ]
  };

}


sub get_fixed_recordInfo_node {

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
