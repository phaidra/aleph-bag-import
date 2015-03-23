package AlephBagImport;


use strict;
use warnings;
use Mojo::Base 'Mojolicious';
use Mojo::Log;
use Mojolicious::Plugin::I18N;
use Mojolicious::Plugin::Authentication;
use Mojolicious::Plugin::Session;
use Mojo::Loader;
use AlephBagImport::Model::Session::Store::Mongo;

# This method will run once at server start
sub startup {
    my $self = shift;

    my $config = $self->plugin( 'JSONConfig' => { file => 'AlephBagImport.json' } );
  $self->config($config);
  $self->mode($config->{mode});
    $self->secrets([$config->{secret}]);

    # init log
    $self->log(Mojo::Log->new(path => $config->{log_path}, level => $config->{log_level}));



  unless($config->{phaidra}){
    $self->log->error("Cannot find phaidra api config");
  }

    # init auth
    $self->plugin(authentication => {
    load_user => sub {
      my $self = shift;
      my $username  = shift;

       my $login_data = $self->app->chi->get($username);

        unless($login_data){
          $self->app->log->debug("[cache miss] $username");

          my $login_data;

          my $url = Mojo::URL->new;
        $url->scheme('https');
        $url->userinfo($self->app->config->{directory_user}->{username}.":".$self->app->config->{directory_user}->{password});
        my @base = split('/',$self->app->config->{phaidra}->{apibaseurl});
        $url->host($base[0]);
        $url->path($base[1]."/directory/user/$username/data") if exists($base[1]);
          my $tx = $self->ua->get($url);

         if (my $res = $tx->success) {
           $login_data = $tx->res->json->{user_data};
        } else {
           my ($err, $code) = $tx->error;
           $self->app->log->error("Getting user data failed for user $username. Error code: $code, Error: ".$self->app->dumper($err));
           if($tx->res->json && exists($tx->res->json->{alerts})){
            $self->stash({phaidra_auth_result => { alerts => $tx->res->json->{alerts}, status  =>  $code ? $code : 500 }});
           }else{
            $self->stash({phaidra_auth_result => { alerts => [{ type => 'danger', msg => $err }], status  =>  $code ? $code : 500 }});
          }
           return undef;
        }


        $self->app->log->info("Loaded user: ".$self->app->dumper($login_data));
          $self->app->chi->set($username, $login_data, '1 day');
          # keep this here, the set method may change the structure a bit so we better read it again
          $login_data = $self->app->chi->get($username);
        }else{
          $self->app->log->debug("[cache hit] $username");
        }

      return $login_data;
    },

    validate_user => sub {
      my ($self, $username, $password, $extradata) = @_;
      $self->app->log->info("Validating user: ".$username);

      # delete from cache
      $self->app->chi->remove($username);

      # if the user is not in configuration -> wiederschauen
      my $is_in_config = 0;

      foreach my $u (@{$self->app->config->{users}}){
          if($u->{username} eq $username){
            $is_in_config = 1; last;
          }
      }

      unless ($is_in_config){
        $self->app->log->error("User $username not found in any project");
        return undef;
      }

      my $url = Mojo::URL->new;
      $url->scheme('https');
      $url->userinfo($username.":".$password);
      my @base = split('/',$self->app->config->{phaidra}->{apibaseurl});
      $url->host($base[0]);
      $url->path($base[1]."/signin") if exists($base[1]);
        my $tx = $self->ua->get($url);

       if (my $res = $tx->success) {

            # save token
            my $token = $tx->res->cookie($self->app->config->{authentication}->{token_cookie})->value;

            my $session = $self->stash('mojox-session');
          $session->load;
          unless($session->sid){
            $session->create;
          }
          $self->save_token($token);

            $self->app->log->info("User $username successfuly authenticated");
            $self->stash({phaidra_auth_result => { token => $token , alerts => $tx->res->json->{alerts}, status  =>  200 }});

            return $username;
       }else {
           my ($err, $code) = $tx->error;
           $self->app->log->error("Authentication failed for user $username. Error code: $code, Error: ".$self->app->dumper($err));
           if($tx->res->json && exists($tx->res->json->{alerts})){
            $self->stash({phaidra_auth_result => { alerts => $tx->res->json->{alerts}, status  =>  $code ? $code : 500 }});
           }else{
            $self->stash({phaidra_auth_result => { alerts => [{ type => 'danger', msg => $err }], status  =>  $code ? $code : 500 }});
          }

           return undef;
      }

    },
  });

  $self->attr(_mango_stage => sub { return Mango->new('mongodb://'.$config->{mongodb_stage}->{username}.':'.$config->{mongodb_stage}->{password}.'@'.$config->{mongodb_stage}->{host}.'/'.$config->{mongodb_stage}->{database}) });
  $self->helper(mango_stage => sub { return shift->app->_mango_stage});

  $self->attr(_mango_alephbagimport => sub { return Mango->new('mongodb://'.$config->{mongodb_alephbagimport}->{username}.':'.$config->{mongodb_alephbagimport}->{password}.'@'.$config->{mongodb_alephbagimport}->{host}.'/'.$config->{mongodb_alephbagimport}->{database}) });
  $self->helper(mango_alephbagimport => sub { return shift->app->_mango_alephbagimport});

  $self->attr(_mango_bagger => sub { return Mango->new('mongodb://'.$config->{mongodb_bagger}->{username}.':'.$config->{mongodb_bagger}->{password}.'@'.$config->{mongodb_bagger}->{host}.'/'.$config->{mongodb_bagger}->{database}) });
  $self->helper(mango_bagger => sub { return shift->app->_mango_bagger});

    # we might possibly save a lot of data to session
    # so we are not going to use cookies, but a database instead
    $self->plugin(
        session => {
          stash_key     => 'mojox-session',
          store  => AlephBagImport::Model::Session::Store::Mongo->new(
            mango => $self->mango_alephbagimport,
            'log' => $self->log
          ),
          transport => MojoX::Session::Transport::Cookie->new(name => 'b_'.$config->{installation_id}),
          expires_delta => $config->{session_expiration},
          ip_match      => 1
        }
    );

  $self->hook('before_dispatch' => sub {
    my $self = shift;

    my $session = $self->stash('mojox-session');
    $session->load;
    if($session->sid){
      # we need mojox-session only for signed-in users
      if($self->signature_exists){
        $session->extend_expires;
        $session->flush;
      }else{
        # this will set expire on cookie as well as in store
        $session->expire;
        $session->flush;
      }
    }else{
      if($self->signature_exists){
        $session->create;
      }
    }

  });

  $self->hook('after_dispatch' => sub {
    my $self = shift;
    my $json = $self->res->json;
    if($json){
      if($json->{alerts}){
        if(scalar(@{$json->{alerts}}) > 0){
          $self->app->log->debug("Alerts:\n".$self->dumper($json->{alerts}));
        }
      }
    }
  });

  $self->sessions->default_expiration($config->{session_expiration});
  # 0 if the ui is not running on https, otherwise the cookies won't be sent and session won't work
  $self->sessions->secure($config->{secure_cookies});
  $self->sessions->cookie_name('a_'.$config->{installation_id});

    $self->helper(save_token => sub {
      my $self = shift;
    my $token = shift;

    my $session = $self->stash('mojox-session');
    $session->load;
    unless($session->sid){
      $session->create;
    }

    $session->data(token => $token);
    });

    $self->helper(load_token => sub {
      my $self = shift;

      my $session = $self->stash('mojox-session');
      $session->load;
      unless($session->sid){
        return undef;
      }

      return $session->data('token');
    });

    # init I18N
    $self->plugin(charset => {charset => 'utf8'});

    # init cache
    $self->plugin(CHI => {
      default => {
          driver		=> 'Memory',
          global => 1,
      },
    });

    # if we are proxied from base_apache/ui eg like
    # ProxyPass /ui http://localhost:3000/
    # then we have to add /ui/ to base of every req url
    # (set $config->{proxy_path} in config)
    if($config->{proxy_path}){
      $self->hook('before_dispatch' => sub {
    my $self = shift;
          push @{$self->req->url->base->path->trailing_slash(1)}, $config->{proxy_path};
      });
    }

    my $r = $self->routes;
    $r->namespaces(['AlephBagImport::Controller']);

    $r->route('') 			  	  ->via('get')   ->to('import#home');
    $r->route('signin') 			->via('get')   ->to('authentication#signin');
    $r->route('signout') 			->via('get')   ->to('authentication#signout');

    # if not authenticated, users will be redirected to login page
    my $auth = $r->under('/')->to('authentication#check');

    $auth->route('import')                        ->via('get')    ->to('import#import');
    $auth->route('import/acnumbers')              ->via('post')   ->to('import#addacnumbers');
    $auth->route('import/acnumbers')              ->via('get')    ->to('import#getacnumbers');
    $auth->route('import/fetch')                  ->via('post')   ->to('import#fetch');
    $auth->route('import/createbag')              ->via('post')   ->to('import#createbag');

    return $self;
}

1;

__END__
