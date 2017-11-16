package Blog::Model::Entry2;

use strict;
use warnings;

use Moose;

with 'DBIx::NoSQL::Store::Manager::Model';

has url => (
    traits   => [ 'StoreKey' ],
    is       => 'ro',
    required => 1,
);

has author => (
    traits => [ 'StoreModel' ],
    cascade_model => 1,
    store_model => 'Blog::Model::Author',
    is     => 'rw',
);




__PACKAGE__->meta->make_immutable;

1;
