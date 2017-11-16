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

The value of the attribute can be set via either a model object, a hashref, or 
the store key of an object already existing in the store. The getter always
returns the inflated model object.

    my $blog_entry = $store->create( 'Entry', 
        author => 'yanick',
    );

    # or
    $blog_entry = $store->create( 'Entry', 
        author => Blog::Model::Author->new( name => 'yanick' )
    );

    # or
    $blog_entry = $store->create( 'Entry', 
        author => { name => 'yanick' }
    );

    my $author_object = $blog_entry->author; # will be a Blog::Model::Author object

=head1 ATTRIBUTES

=head2 store_model => $model_class

Required. Takes in the model associated with the target attribute.
Will automatically populate the C<isa> attribute to 
C<$model_class|Str_HashRef>.

=head2 cascade_model => $boolean

Sets the default of C<cascade_save> and C<cascade_delete>.
Defaults to C<false>.

=head2 cascade_save => $boolean

If C<true> the object associated with the attribute is automatically saved 
to the store when the main object is C<save()>d.

=head2 cascade_delete => $boolean

If C<true>, deletes the attribute object (if there is any)
from the store when the main object is C<delete()>d.

If both C<cascade_delete> and C<cascade_save> are C<true>,
then when saving the main object, if the attribute object has been
modified, its previous value will be deleted from the store.

    # assuming the author attribute has `cascade_model => 1`...

    my $blog_entry = $store->create( 'Entry', 
        author => Blog::Model::Author->new( 
            name => 'yanick',
            bio  => 'necrohacker',
        ),
    );

    # store now has yanick as an author

    my $pseudonym = $store->create( Author => 
        name => 'yenzie', bio => 'neo-necrohacker' 
    );

    # store has both 'yanick' and 'yenzie'

    # does not modify the store
    $blog_entry->author( $pseudonym );

    # removes 'yanick'
    $blog_entry->save;


    


=cut

use Log::Any qw/ $log /;

use Moose::Role;
use Scalar::Util qw/ blessed /;

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
    default => sub { 0 },
);

has cascade_save => (
    is      => 'ro',
    isa     => 'Bool',
    lazy => 1,
    default => sub { $_[0]->cascade_model },
);

has cascade_delete => (
    is      => 'ro',
    isa     => 'Bool',
    lazy => 1,
    default => sub { $_[0]->cascade_model },
);

use Types::Standard qw/ InstanceOf Str HashRef/;

before _process_options => sub ( $meta, $name, $options ) {
    my $type = InstanceOf[ $options->{store_model } ] | Str | HashRef;
    $options->{isa} ||= $type;
};

after install_accessors => sub { 
    my $attr = shift;

    my $reader = $attr->get_read_method;
    # class that has the attribute
    my $main_class = $attr->associated_class;

    $main_class->add_before_method_modifier( delete => sub ( $self, @) {
        my $obj = $self->$reader or return;
        $obj->delete;
    }) if $attr->cascade_delete;

    $main_class->add_before_method_modifier( $attr->get_read_method => sub ( $self, @rest ) {
        return if @rest;

        my $value = $attr->get_value( $self );
        return unless defined $value and not blessed $value;

        if ( ref $value ) { 
            $attr->set_raw_value( $self, 
                $attr->store_model->new($value)
            );
        }
        else {  # it's the store key
            my $class = $attr->store_model;
            $class =~ s/^.*::Model:://;
            $class =~ s/::/_/g;

            $attr->set_raw_value( $self, 
                $self->store_db->get( $class => $value )
            );
        }
    });

    $main_class->add_around_method_modifier( pack => sub($orig,$self) {
            my $packed = $orig->($self);
            my $val = $attr->get_read_method_ref->($self);
            if ( $val ) {
                $packed->{ $attr->name } = $val->store_key;
            }
            return $packed;
    } );

    if( $attr->cascade_save ) {
        $main_class->add_before_method_modifier( 'save' => sub ( $self, $store=undef ) {
                my $value = $self->$reader or return;
                
                if ( $attr->cascade_delete ) {
                    my $prior = eval { $self->store_db->get( $self->store_model, $self->store_key )->$reader };

                    if ( $prior ) { 
                        $log->trace( "deleting prior attribute", {
                            main_object => [ $self->store_model, $self->store_key ],
                            attribute => [ $attr->name, $prior->store_key ],
                        }
                        );
                        $prior->delete;
                    }
                }

                $log->trace(
                    "saving attribute", {
                        main_object => [ $self->store_model, $self->store_key ],
                        attribute => [ $attr->name, $value->store_key ],
                    }
                );


                $store ||= $self->store_db;

                $value->store_db( $store );

                $value->save;
        });
    }
};


1;
