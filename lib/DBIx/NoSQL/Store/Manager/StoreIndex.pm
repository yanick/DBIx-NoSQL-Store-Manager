package DBIx::NoSQL::Store::Manager::StoreIndex;
# ABSTRACT: Marks attributes to be indexed in the store

=head1 SYNOPSIS

    # in a class consuming the DBIx::NoSQL::Store::Manager::Model role

    has something => (
        traits => [ 'StoreIndex' ],
        is => 'ro',
    );

=head1 DESCRIPTION

I<DBIx::NoSQL::Store::Manager::StoreIndex> (also aliased to I<StoreIndex>)
is used to mark attributes that are to be indexed by the
L<DBIx::NoSQL::Store::Manager> store.

=cut

use Moose::Role;
Moose::Util::meta_attribute_alias('StoreIndex');

has store_isa => (
    is => 'rw',
    isa => 'Str',
    predicate => 'has_store_isa',
);

1;
