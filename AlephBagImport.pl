#!/usr/bin/env perl

use strict;
use warnings;

$ENV{MOJO_MAX_MESSAGE_SIZE} = 1073741824;
$ENV{MOJO_INACTIVITY_TIMEOUT} = 7200;

# Start command line interface for application
require Mojolicious::Commands;
Mojolicious::Commands->start_app('AlephBagImport');
