#!/usr/bin/env perl6
use v6;
use Plackdo::Test;
use Journal;

sub MAIN ( $uri = '/' ) {
    my $conf = eval slurp 'config.pl';
    my $log = IO.new.open('profile.log', :w);
    my $j = Journal.new(|$conf<database>, log => $log );

#    $Plackdo::Test::Impl = 'Standalone';

    test_p6sgi(
        $j.webapp,
        sub (&cb) {
            my $req = new_request('GET', $uri);
            my $res = &cb($req);
            say $res.content;
        }
    );

    $log.close;
}

# vim: ft=perl6
