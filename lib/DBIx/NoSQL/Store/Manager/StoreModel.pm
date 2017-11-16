package DBIx::NoSQL::Store::Manager::StoreModel;
# ABSTRACT: trait for attributes linking to store objects.

=head1 SYNOPSIS

    # in a class consuming the DBIx::NoSQL::Store::Manager::Model role

    has something => (
        traits => [ 'StoreModel' ],
        store_model =>  'MyStore::Model::Thingy',
        is => 'rw',
    );

=head1 DESCRIPTION

I<DBIx::NoSQL::Store::Manager::StoreModel> (also aliased to I<StoreModel>)

=cut

use Moose::Role;
Moose::Util::meta_attribute_alias('StoreModel');

use experimental 'signatures';

has store_model => (
    is => 'ro',
    isa => 'Str',
    predicate => 'has_store_model',
);

has cascade_save => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

before _process_options => sub ( $meta, $name, $options ) {
    $options->{isa} ||= $options->{store_model}.'|Str';
};

after install_accessors => sub { 
    my $attr = shift;

    my $reader = $attr->get_read_method;

    $attr->associated_class->add_before_method_modifier( $attr->get_read_method => sub ( $self, @rest ) {
        return if @rest;

        my $value = $attr->get_value( $self );
        return unless defined $value and not ref $value;


        my $class = $attr->store_model;
        $class =~ s/^.*::Model:://;
        $class =~ s/::/_/g;

        $attr->set_raw_value( $self, 
            $self->store_db->get( $class => $value )
        );
    });

    $attr->associated_class->add_around_method_modifier( pack => sub($orig,$self) {
            my $packed = $orig->($self);
            my $val = $attr->get_read_method_ref->($self);
            if ( $val ) {
                $packed->{ $attr->name } = $val->store_key;
            }
            return $packed;
    } );

    if( $attr->cascade_save ) {
        $attr->associated_class->add_after_method_modifier( 'save' => sub ( $self, $store=undef ) {

            my $value = $self->$reader or return;

            $store ||= $self->store_db;

            $value->store_db( $store );

            # TODO check if the store_db of $self and attribute match

            $value->save;
        });
    }
};


1;
