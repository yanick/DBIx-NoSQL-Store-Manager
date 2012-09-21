package MyComics::Model::Comic;

use strict;
use warnings;

use Moose;

with 'DBIx::NoSQL::Store::Manager::Model';

has series => (
    traits => [ 'StoreKey' ],
    is => 'ro',
);

has issue =>  (
    traits => [ 'StoreKey' ],
    is => 'ro',
    isa => 'Int',
);

has penciller => (
    is => 'ro',
);

has writer => (
    is => 'ro',
);

__PACKAGE__->meta->make_immutable;

1;
