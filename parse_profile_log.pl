#!/usr/bin/env perl6
use v6;

sub MAIN ($filename = 'profile.log') {
    my $fh = IO.new.open($filename, :r);
    my $t0;
    my $t1;
    while $fh.get -> $line {
        my ($time, $msg) = $line.split(/\t/);
        $t0 //= $time;
        printf("%20s\t%10.8f\t%10.8f\n", $msg, $time - $t0, $t1 ?? $time - $t1 !! '');
        $t1 = $time;
    } 
}

# vim: ft=perl6
