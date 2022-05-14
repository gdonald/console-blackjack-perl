#!/usr/bin/env perl

use v5.20;
use strict;
use warnings FATAL => 'all';

# use diagnostics;
# use Data::Dumper;
# use Carp 'verbose';
# $SIG{ __DIE__ } = sub {Carp::confess(@_)};

use lib 'lib';
use Console::Blackjack qw(run);

run();
