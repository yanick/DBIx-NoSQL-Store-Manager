package DBIx::NoSQL::Store::Manager::Model;
#ABSTRACT: Role for classes to be handled by DBIx::NoSQL::Store::Manager

use 5.20.0;

use strict;
use warnings;

use Moose::Role;

use MooseX::ClassAttribute;
use MooseX::Storage 0.31;
use MooseX::SetOnce;

use Scalar::Util qw/ refaddr /;

with Storage;

use DBIx::NoSQL::Store::Manager::StoreKey;
use DBIx::NoSQL::Store::Manager::StoreIndex;
use DBIx::NoSQL::Store::Manager::StoreModel;

use experimental 'signatures';

# TODO: ad-hoc model registration

=attr store_db

The L<DBIx::NoSQL::Store::Manager> store to which the object belongs
to. 

=cut

=method store_db

Returns the L<DBIx::NoSQL::Store::Manager> store to which the object belongs
to.

=cut

has store_db => (
    traits => [ 'DoNotSerialize', 'SetOnce' ],
    is       => 'rw',
    predicate =>  'has_store_db',
);

around store_db => sub ( $orig, $self, @rest ) {
    if ( @rest and $self->has_store_db ) {
        shift @rest if refaddr $self->store_db == refaddr $rest[0];
    }

    return $orig->($self,@rest);
};

=attr store_model

Class-level attribute holding the model name of the class.
If not given, defaults to the class name with everything up
to a C<*::Model::> truncated (e.g., C<MyStore::Model::Thingy>
would become C<Thingy>).

Not that as it's a class-level attribute, it can't be passed to
C<new()>, but has to be set via C<class_has>:

    class_has '+store_model' => (
        default => 'SomethingElse',
    );

=cut

class_has store_model => (
    isa => 'Str',
    is => 'rw',
    default => sub ($self) {
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
    default => sub($self) {
        no warnings 'uninitialized';
       return join( '-', map { $self->$_ } sort map {
        $_->get_read_method
       } grep { $_->does('DBIx::NoSQL::Store::Manager::StoreKey') }
         $self->meta->get_all_attributes )
         // die "no store key set for $self";
    },
);

=method store()

DEPRECATED - use C<save()> instead.

Serializes the object into the store. 

=cut

sub store($self) {
    # TODO put deprecation notice
    $self->save;
}

=method delete()

Deletes the object from the store.

=cut

sub delete($self) {
    $self->store_db->delete( $self->store_model => $self->store_key );
}

sub _entity($self) {
   return $self->pack; 
}

around pack => sub($orig,$self) {
    local $DBIx::NoSQL::Store::Manager::Model::INNER_PACKING = $DBIx::NoSQL::Store::Manager::Model::INNER_PACKING;

    return $DBIx::NoSQL::Store::Manager::Model::INNER_PACKING++ ? $self->store_key : $orig->($self);
};

sub indexes($self) {
    return map  { [ $_->name, ( isa => $_->store_isa ) x $_->has_store_isa ] }
           grep { $_->does('DBIx::NoSQL::Store::Manager::StoreIndex') } 
                $self->meta->get_all_attributes;
}

=method save( $store )

Saves the object in the store. The C<$store> object can be given as an argument if 
the object was not created via a master C<DBIx::NoSQL::Store::Manager> object
and C<store_db> was not already provided via the constructor.

=cut

sub save($self,$store=undef) {
    $self->store_db( $store ) if $store;

    $self->store_db->set($self);
}

1;
