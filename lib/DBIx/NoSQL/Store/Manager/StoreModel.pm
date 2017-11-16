package DBIx::NoSQL::Store::Manager::StoreModel;
# ABSTRACT: trait for attributes linking to store objects.

=head1 SYNOPSIS

    package Blog::Model::Entry;

    has author => (
        traits => [ 'StoreModel' ],
        store_model =>  'Blog::Model::Author',
        cascade_save => 1,
        cascade_delete => 0,
        is => 'rw',
    );

=head1 DESCRIPTION

I<DBIx::NoSQL::Store::Manager::StoreModel> (also aliased to I<StoreModel>)

This trait ties the value of the attribute to a model of the store.

The value of the attribute can be set via either a model object, or via 
the store key of an object already existing in the store. The getter always
returns the inflated model object.

    my $blog_entry = $store->create( 'Entry', 
        author => 'yanick',
    );

    my $author_object = $blog_entry->author; # will be a Blog::Model::Author object

=head1 ATTRIBUTES

=head2 store_model => $model_class

Required. Takes in the model associated with the target attribute.
Will automatically populate the C<isa> attribute to 
C<$model_class|Str>.

=head2 cascade_model => $boolean

Sets the default of C<cascade_save> and C<cascade_delete>.
Defaults to C<false>.


=cut

use Moose::Role;
Moose::Util::meta_attribute_alias('StoreModel');

use experimental 'signatures';

has store_model => (
    is => 'ro',
    isa => 'Str',
    required => 1,
    predicate => 'has_store_model',
);

has cascade_model => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

has cascade_save => (
    is      => 'ro',
    isa     => 'Bool',
    default => sub { $_[0]->cascade_model },
);

has cascade_delete => (
    is      => 'ro',
    isa     => 'Bool',
    default => sub { $_[0]->cascade_model },
);

before _process_options => sub ( $meta, $name, $options ) {
    $options->{isa} ||= $options->{store_model}.'|Str';
};

after install_accessors => sub { 
    my $attr = shift;

    my $reader = $attr->get_read_method;

    $attr->associated_class->add_before_method_modifier( delete => sub ( $self, @) {
        my $obj = $self->$reader or return;
        $obj->delete;
    }) if $attr->cascade_delete;

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
