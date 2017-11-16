use strict;
use warnings;

use lib 't/lib';

use Test::More tests => 2;
use Test::Deep;

use Blog;

my $store = Blog->connect(':memory:');

my $author = Blog::Model::Author->new( name => 'yanick', bio => 'necrohacker' );
$author->save($store);

my $entry = $store->create( 'Entry', url => '/first', author => $author );

cmp_deeply $entry->pack => superhashof({
    __CLASS__ => 'Blog::Model::Entry',
    url       => '/first',
    author    => 'yanick',
});

is $store->create( 'Entry', url => '/first', author => 'yanick' )->author->bio
    => 'necrohacker', 'expansion happens';


subtest 'cascade_save' => sub {
    $store->create( Entry => (
        url => '/second', author => Blog::Model::Author->new(
            name => 'bob',
        ),
    ));

    ok !$store->get( 'Author' => 'bob' ), "author is not auto-saved";
    
    $store->create( Entry2 => (
        url => '/second', author => Blog::Model::Author->new(
            name => 'bob',
        ),
    ));

    ok $store->get( 'Author' => 'bob' ), "author is auto-saved";

};


