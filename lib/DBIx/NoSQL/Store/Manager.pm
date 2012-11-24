package DBIx::NoSQL::Store::Manager;
#ABSTRACT: DBIx::NoSQL as a Moose object store 

use strict;
use warnings;

use Moose;

use Moose::Util::TypeConstraints;

use DBIx::NoSQL::Store;
use Method::Signatures;
use Module::Pluggable require => 1;

extends 'DBIx::NoSQL::Store';

=method new( models => \@classes )

Creates a new store manager.

=head3 Arguments

=over

=item models => \@classes
=item models => $class

Classes to be imported as models for the store. Namespaces can also be given
with a trailing C<::>, in which case all modules found under that namespace
will be imported.  If only one class is to be used, it can be passed as a
single string.

If not given, defaults
to the C<Model> sub-namespace under the store's (e.g., for store
class C<MyStore>, that would be C<MyStore::Model::>). 

    my $store = MyStore->new; 
        # will import MyStore::Model::*
    
    my $store = MyStore->new( models => [ 'Foo::Bar', 'Something::Else' ] );
        # imports specific classes
        
    my $store = MyStore->new( models => [ 'Foo::Bar', 'MyStore::Model::' ] );
        # imports Foo::Bar and all classes under MyStore::Model::*

=back

=cut

subtype Model
    => as 'ArrayRef[Str]';

coerce Model
    => from 'Str'
    => via { [ $_ ] };

has models => (
    traits => [ 'Array' ],
    is => 'ro',
    isa => 'Model',
    default => method {
        [ join "::", ($self->meta->class_precedence_list)[0], 'Model', '' ];
    },
    handles => {
        arg_models => 'elements',    
    },
);

=method model_names()

Returns the name of all models known to the store.

=method model_classes()

Returns the full class name of all models known to the store.

=method model_class( $name )

Returns the full class name of the given model.

=cut

has _models => (
    traits => [ 'Hash' ],
    is => 'ro',
    isa => 'HashRef',
    lazy => 1,
    default => method {
        my %model;
        for my $m ( $self->arg_models ) {
            if ( $m =~ s/::$// ) {
                $self->search_path( new => $m );
                for ( $self->plugins ) {
                    $model{$_->store_model} = $_;
                }
            }
            else {
                require $m;
                $model{$m->store_model} = $m;
            }
        }
        return \%model;
    },
    handles => {
        model_names => 'keys',
        model_classes => 'values',
        model_class => 'get',
    },
);

method BUILD(@args) {

    for my $p ( $self->model_classes ) {
        my $model = $self->model( $p->store_model );
        
        $model->_wrap( sub {
            $p->unpack($_[0], inject => { store_db => $self } );
        });

        $model->index(@$_) for $p->indexes;
    }
};

=method new_model_object( $model_name, @args )

Shortcut constructor for a model class of the store. Equivalent to

    my $class = $store->model_class( $model_name );
    my $thingy = $class->new( store_db => $store, @args );

=cut

method new_model_object ( $model, @args ) {
    $self->model_class($model)->new( store_db => $self, @args);   
}

1;

