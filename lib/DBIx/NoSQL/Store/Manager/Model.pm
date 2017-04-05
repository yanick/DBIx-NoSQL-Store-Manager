package DBIx::NoSQL::Store::Manager::Model;
#ABSTRACT: Role for classes to be handled by DBIx::NoSQL::Store::Manager

use 5.10.0;

use strict;
use warnings;

use Moose::Role;

use Method::Signatures;
use MooseX::ClassAttribute;
use MooseX::Storage 0.31;

with Storage;
with 'DBIx::NoSQL::Store::Manager::StoreKey',
     'DBIx::NoSQL::Store::Manager::StoreIndex';


=attr store_db

The L<DBIx::NoSQL::Store::Manager> store to which the object belongs
to. Required.

=cut

=method store_db

Returns the L<DBIx::NoSQL::Store::Manager> store to which the object belongs
to.

=cut

has store_db => (
    traits => [ 'DoNotSerialize' ],
    is       => 'ro',
    required => 1,
);

=attr store_model

Class-level attribute holding the model name of the class.
If not given, defaults to the class name with everything up
to a C<*::Model::> truncated (e.g., C<MyStore::Model::Thingy>
would become C<Thingy>).

Not that as it's a class-level attribute, it can't be passed to
C<new()>, but has to be set via C<class_has>:

    class_has +store_model => (
        default => 'SomethingElse',
    );

=cut

class_has store_model => (
    isa => 'Str',
    is => 'rw',
    default => method {
        # TODO probably over-complicated
       my( $class ) = $self->class_precedence_list;

       $class =~ s/^.*::Model:://;
       $class =~ s/::/_/g;
       return $class;
    },
);

=attr store_key

The store id of the object. Defaults to the concatenation of the value of all
attributes having the L<DBIx::NoSQL::Store::Manager::StoreKey> trait.

=cut

has store_key => (
    traits => [ 'DoNotSerialize' ],
    is => 'ro',
    lazy => 1,
    default => method {
       return join( '-', map { $self->$_ } sort map {
        $_->get_read_method
       } grep { $_->does('DBIx::NoSQL::Store::Manager::StoreKey') }
         $self->meta->get_all_attributes )
         // die "no store key set for $self";
    },
);

=method store()

Serializes the object into the store.

=cut

method store {
    $self->store_db->set( 
        $self->store_model =>
            $self->store_key => $self,
    );
}

=method delete()

Deletes the object from the store.

=cut

method delete {
    $self->store_db->delete( $self->store_model => $self->store_key );
}

method _entity {
   return $self->pack; 
}

method indexes {
    return map  { [ $_->name, ( isa => $_->store_isa ) x $_->has_store_isa ] }
           grep { $_->does('DBIx::NoSQL::Store::Manager::StoreIndex') } 
                $self->meta->get_all_attributes;
}

1;
