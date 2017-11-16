package Blog::Model::Entry2;

use strict;
use warnings;

use MooseX::ClassAttribute;

use Moose;
extends 'Blog::Model::Entry';

class_has '+store_model' => (
    default => 'Entry2',
);

has '+author' => (
    traits => [ 'StoreModel' ],
    cascade_save => 1,
);


__PACKAGE__->meta->make_immutable;

1;
