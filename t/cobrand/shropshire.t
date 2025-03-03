use CGI::Simple;
use Test::MockModule;
use Test::MockTime qw(:all);
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
use Catalyst::Test 'FixMyStreet::App';

use Open311::PopulateServiceList;

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(2238, 'Shropshire Council');
$mech->create_contact_ok(body_id => $body->id, category => 'Bridges', email => 'bridges@example.org');

my ($report) = $mech->create_problems_for_body(1, $body->id, 'Test Report', {
    category => 'Bridges', cobrand => 'shropshire',
    latitude => 52.859331, longitude => -3.054912, areas => ',11809,129425,144013,144260,148857,2238,39904,47098,66017,95047,',
    external_id => '1309813', whensent => \'current_timestamp',
});

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'shropshire' ],
    MAPIT_URL => 'http://mapit.uk/',
    STAGING_FLAGS => { send_reports => 1, skip_checks => 0 },
}, sub {

    subtest 'cobrand displays council name' => sub {
        ok $mech->host("shropshire.fixmystreet.com"), "change host to shropshire";
        $mech->get_ok('/');
        $mech->content_contains('Shropshire Council');
    };

    subtest 'cobrand displays council name' => sub {
        $mech->get_ok('/reports/Shropshire');
        $mech->content_contains('Shropshire Council');
    };

    subtest 'External ID is shown on report page' => sub {
        $mech->get_ok('/report/' . $report->id);
        $mech->content_contains("Council ref:&nbsp;" . $report->external_id);
    };

};

subtest 'check open311_contact_meta_override' => sub {

    my $processor = Open311::PopulateServiceList->new();

    my $meta_xml = '<?xml version="1.0" encoding="utf-8"?>
<service_definition>
    <service_code>100</service_code>
    <attributes>
        <attribute>
            <automated>server_set</automated>
            <code>hint</code>
            <datatype>string</datatype>
            <datatype_description></datatype_description>
            <description>Abandoned since</description>
            <order>1</order>
            <required>false</required>
            <variable>false</variable>
        </attribute>
        <attribute>
            <automated>server_set</automated>
            <code>group_hint</code>
            <datatype>string</datatype>
            <datatype_description></datatype_description>
            <description>Registration Mark</description>
            <order>2</order>
            <required>false</required>
            <variable>false</variable>
        </attribute>
    </attributes>
</service_definition>
    ';

    my $contact = FixMyStreet::DB->resultset('Contact')->create({
        body_id => $body->id,
        email => '100',
        category => 'Abandoned vehicle',
        state => 'confirmed',
        editor => $0,
        whenedited => \'current_timestamp',
        note => 'test contact',
    });

    my $o = Open311->new(
        jurisdiction => 'mysociety',
        endpoint => 'http://example.com',
    );
    Open311->_inject_response('/services/100.xml', $meta_xml);

    $processor->_current_open311( $o );
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'shropshire' ],
    }, sub {
        $processor->_current_body( $body );
    };
    $processor->_current_service( { service_code => 100, service_name => 'Abandoned vehicle' } );
    $processor->_add_meta_to_contact( $contact );
    $contact->discard_changes;
    my @extra_fields = $contact->get_extra_fields;

    is $extra_fields[0][0]->{fieldtype}, 'date', "added fieldtype 'date' to 'Abandoned since'";
    is $extra_fields[0][0]->{required}, 'true', "set required to true";
    is $extra_fields[0][1]->{fieldtype}, undef, "not added fieldtype 'date' to 'Registration Mark'";
};

done_testing();
