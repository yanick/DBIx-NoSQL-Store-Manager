package DBIx::NoSQL::Store::Manager;
our $AUTHORITY = 'cpan:YANICK';
#ABSTRACT: DBIx::NoSQL as a Moose object store 
$DBIx::NoSQL::Store::Manager::VERSION = '1.0.0';
use 5.20.0;

use strict;
use warnings;

use Moose;

# TODO  type tiny
use Moose::Util::TypeConstraints;

use DBIx::NoSQL 0.0020;
use Module::Pluggable require => 1;

extends 'DBIx::NoSQL::Store';

use experimental 'signatures';


subtype Model
    => as 'ArrayRef[Str]';

coerce Model
    => from 'Str'
    => via { [ $_ ] };

has models => (
    traits => [ 'Array' ],
    is => 'ro',
    isa => 'Model',
    default => sub($self) {
        [ join "::", ($self->meta->class_precedence_list)[0], 'Model', '' ];
    },
    handles => {
        arg_models => 'elements',    
    },
);


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

sub _register_models( $self, @models ) {
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

sub BUILD($self,$args) {
    $args->{models} ||= [ 
        join "::", ($self->meta->class_precedence_list)[0], 'Model', '' 
    ];

    $self->_register_models( @{ $args->{models} } );
};



sub new_model_object($self,$model,@args) { 
    $self->model_class($model)->new( store_db => $self, @args);   
}


sub create ( $self,  $model, @args ) {
    my $object = $self->new_model_object( $model => @args );
    $object->save;
    return $object;
}

# $store->set( $model, $key, $hashref )
# $store->set( $object )  
around set => sub($orig,$self,@rest) {

    if( @rest == 1 ) {  # object call
        my $object = shift @rest;
        $object->store_db($self) unless $object->has_store_db;
        
        return $orig->( $self, map { $object->$_ } qw/ store_model store_key pack / ); 
    }
    $orig->($self, @rest );
};

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

DBIx::NoSQL::Store::Manager - DBIx::NoSQL as a Moose object store 

=head1 VERSION

version 1.0.0

=head1 SYNOPSIS

    package MyStore;

    use Moose;

    extends 'DBIx::NoSQL::Store::Manager';

    __PACKAGE__->meta->make_immutable;

=head1 DESCRIPTION

Just like L<DBIx::NoSQL> is a layer providing the
flexibility of a NoSQL store on top of L<DBIx::Class>, I<DBIx::NoSQL::Store::Manager>
provides a mechanism to drop and retrieve L<Moose> objects from that store.

As can be seen in the L</SYNOPSIS>, the store class itself is typically fairly
bare; most of the work is done by L<DBIx::NoSQL::Store::Manager::Model>, the
role the models (i.e., the classes to be stored in the database) must consume.

I<DBIx::NoSQL::Store::Manager> extends L<DBIx::NoSQL> and inherits all its
methods.

=head1 METHODS

=head2 new( models => \@classes )

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

=head2 model_names()

Returns the name of all models known to the store.

=head2 model_classes()

Returns the full class name of all models known to the store.

=head2 model_class( $name )

Returns the full class name of the given model.

=head2 new_model_object( $model_name, @args )

Shortcut constructor for a model class of the store. Equivalent to

    my $class = $store->model_class( $model_name );
    my $thingy = $class->new( store_db => $store, @args );

=head2 create( $model, @args )

Create a new model object and save it. Morally equivalent to

    $store->new_model_object( $model, @args )->save;

Returns the new object.

=head1 SEE ALSO

* Original blog entry introducing the module: L<http://babyl.dyndns.org/techblog/entry/shaving-the-white-whale>

=head2 Similar Modules

* L<KiokuDB>

* L<Elastic::Model>

=head1 AUTHOR

Yanick Champoux <yanick@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2018, 2013, 2012 by Yanick Champoux.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
