#!/usr/bin/env perl

use strict;
use warnings;
use feature qw( say );

use CHI              ();
use Cpanel::JSON::XS ();
use Mojo::DOM        ();
use Path::Tiny qw( path );
use Mojo::Util qw( trim );
use WWW::Mechanize::Cached ();

my $cache = CHI->new(
    driver   => 'File',
    root_dir => '/tmp/mcc-mnc'
);

my $ua   = WWW::Mechanize::Cached->new( cache => $cache );
my $json = Cpanel::JSON::XS->new;
$json->canonical(1);
$json->pretty(1);

mcc_mnc_com();

sub mcc_mnc_com {
    my $url = 'https://www.mcc-mnc.com/';
    my $dom = Mojo::DOM->new( $ua->get($url)->content );

    my @rows = $dom->find('#mncmccTable tr')->each;
    shift @rows;    # ignore header row

    my @networks = map {
        [ map { trim($_) } $_->find('td')->map('all_text')->each ]
    } @rows;

    my @to_json;
    for my $net (@networks) {
        push @to_json,
            {
            mcc          => $net->[0],
            mnc          => $net->[1],
            iso          => uc( $net->[2] ),
            country      => $net->[3],
            country_code => $net->[4],
            network_name => $net->[5]
            };
    }

    path('mcc-mnc.json')->spew( $json->encode( [@to_json] ) );
}
