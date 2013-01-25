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
    handles => {
        model_names   => 'keys',
        model_classes => 'values',
        model_class   => 'get',
        _set_model    => 'set',
    },
);

method _register_models( @models ) {
    # expand namespaces into their plugins
    @models = map { 
        s/::$// ? do {
        $self->search_path( new => $_ );
        $self->plugins } : $_
    } @models;


    for my $model ( @models ) {
        eval "use $model; 1" or die "couldn't load '$_': $@\n";
        $self->_set_model( $model->store_model => $model );

        my $store_model = $self->model($model->store_model);


        $store_model->_wrap( sub {
            my $ref = shift;
            $ref = $ref->[0] if ref($ref) eq 'ARRAY';
            $model->unpack($ref, inject => { store_db => $self } );
        });

        $store_model->index(@$_) for $model->indexes;
    }
}

method BUILD($args) {
    $args->{models} ||= [ 
        join "::", ($self->meta->class_precedence_list)[0], 'Model', '' 
    ];

    $self->_register_models( @{ $args->{models} } );
};

=method create( $model_name, @args )

=method new_model_object( $model_name, @args )

Shortcut constructor for a model class of the store. Equivalent to

    my $class = $store->model_class( $model_name );
    my $thingy = $class->new( store_db => $store, @args );

=cut

method new_model_object(@args) { $self->create(@args) }

method create ( $model, @args ) {
    $self->model_class($model)->new( store_db => $self, @args);   
}

1;

