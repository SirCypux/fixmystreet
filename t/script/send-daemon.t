#!/usr/bin/env perl
#
# send-daemon.t
# FixMyStreet test for reports- and updates-sending daemon.

use strict;
use warnings;
use v5.14;

use FixMyStreet;
use FixMyStreet::DB;
use FixMyStreet::Cobrand::UK;
use FixMyStreet::Script::Reports;
use FixMyStreet::Queue::Item::Report;

use Test::Most;
use Test::MockObject::Extends;

$|++;

# add new problem to DB

my $u = FixMyStreet::DB->resultset('User')->new( { email => 'test@example.test', name => 'A User' } );
my $p = FixMyStreet::DB->resultset('Problem')->new( {
    latitude => 51.387339,
    longitude => -2.360113,
    title => 'Burnt out Transit Van',
    detail => 'Making Bath look very untidy',
    user => $u,
    name => 'A User',
    cobrand => 'fixmystreet',
    send_fail_count => 0,
} );

# mock 500 error in Cobrand::UK
my $cob_uk = FixMyStreet::Cobrand::UK->new;
my $mock_cob_uk = Test::MockObject::Extends->new($cob_uk);
$mock_cob_uk->mock('find_closest', sub {
    die q[Can't use string ("<h1>Server Error (500)</h1>")]
    . q[ as a HASH ref while "strict refs" in use at ]
    . q[/Users/username/git/fixmystreet/perllib/]
    . q[FixMyStreet/Cobrand/UK.pm line 148.]);
});

# run bin/send-daemon (or check already running??)

# check that problem has send fail count > 0 etc.

# un-mock 500 error in Cobrand::UK

# wait for send-daemon to loop round again – or restart?

# check whensent is now filled in

