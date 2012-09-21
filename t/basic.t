use strict;
use warnings;

use lib 't/lib';

use Test::More;
use File::Temp qw/ tempdir /;

use MyComics;

plan tests => 4;

my $store = MyComics->new;

is_deeply [ sort $store->model_names ], [ 'Comic' ], "all_models";
is_deeply [ sort $store->model_classes ], [ 'MyComics::Model::Comic' ], "all_model_classes";

my $db = tempdir( CLEANUP => 1 ) . '/comics.sqlite';

$store = MyComics->connect( $db );

$store->new_model_object( 'Comic', 
    penciler => 'Yanick Paquette',
    writer => 'Alan Moore',
    issue => 2,
    series => 'Terra Obscura',
)->store;

$store->new_model_object( 'Comic', 
    penciler => 'Michel Lacombe',
    writer => 'Michel Lacombe',
    issue => 1,
    series => 'One Bloody Year',
)->store;

ok $store->exists( Comic => 'One Bloody Year-1' ), 'OBY';
ok $store->exists( Comic => 'Terra Obscura-2' ), 'TO';


