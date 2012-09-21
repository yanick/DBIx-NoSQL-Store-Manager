package DBIx::NoSQL::Store::Manager::StoreKey;
# ABSTRACT: Marks attributes defining the object's key in the store

=head1 SYNOPSIS

    # in a class consuming the DBIx::NoSQL::Store::Manager::Model role

    has my_id => (
        traits => [ 'StoreKey' ],
        is => 'ro',
    );

=head1 DESCRIPTION

I<DBIx::NoSQL::Store::Manager::StoreKey> (also aliased to I<StoreKey>)
is used to mark attributes that will be used as the object id in the 
L<DBIx::NoSQL::Store::Manager> store.

If more than one attribute has the
trait, the id will be the concatenated values of those attributes.

=cut

use Moose::Role;
Moose::Util::meta_attribute_alias('StoreKey');

1;
