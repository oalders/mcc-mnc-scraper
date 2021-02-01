#!/usr/bin/env perl

use strict;
use warnings;
use feature qw( say );

use CHI                ();
use Cpanel::JSON::XS   ();
use Locale::SubCountry ();
use Mojo::DOM          ();
use Path::Tiny qw( path );
use Mojo::Util qw( trim );
use Try::Tiny::Warnings qw( catch try_warnings );
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
cellidfinder();

sub cellidfinder {
    my $url        = 'https://cellidfinder.com/mcc-mnc';
    my $dom        = Mojo::DOM->new( $ua->get($url)->content );
    my @by_country = $dom->find('table')->each;

    my %country2code = (
        UK => 'GB',
    );

    my @to_json;
    for my $batch (@by_country) {
        my $country_name = $batch->preceding->last->all_text;
        my $code;
        try_warnings {
            if ( exists $country2code{$country_name} ) {
                $code = $country2code{$country_name};
                return;
            }
            my $lc = Locale::SubCountry->new($country_name);
            $code = $lc->country_code;
        }
        catch {
            $code = 'UNKNOWN';
        };

        my @rows = $batch->find('tr')->each;
        shift @rows;    # Ignore header
        my @networks = map {
            [ map { trim($_) } $_->find('td')->map('all_text')->each ]
        } @rows;

        for my $net (@networks) {
            push @to_json, {
                mcc                    => $net->[0],
                mnc                    => $net->[1],
                network_name           => $net->[2],
                operator_or_brand_name => $net->[3],
                iso                    => $code,
                country                => $country_name,
                status                 => $net->[4],
            };
        }
    }

    path('cellidfinder.json')->spew( $json->encode( [@to_json] ) );
}

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
