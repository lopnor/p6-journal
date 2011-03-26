use v6;

class Journal::Util {
    method decode ($str, $encoding = 'utf8') {
        my $ret = ~Q:PIR {
            .local pmc bb
            .local string s

            $P0 = find_lex '$str'
            $S0 = $P0
            bb = new ['ByteBuffer']
            bb = $S0

            $P1 = find_lex '$encoding'
            $S1 = $P1
            s = bb.'get_string'($S1)
            %r = box s
        };
        return $ret;
    }
}

# vim: ft=perl6 :
