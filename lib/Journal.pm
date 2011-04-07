use v6;

class Journal {
    use MiniDBI;
    use Plackdo::Request;
    use Journal::HTML;
    use Journal::RSS;

    has $!dbh;
    has $!log;

    method !log (Str $str?) {
        defined $!log or return;
        $!log.say(now.x ~ "\t$str");
    }

    method webapp {
        sub (%env) {
            return self.handle_request(%env);
        };
    }

    method handle_request (%env) {
        self!log("handle_request");
        my $req = Plackdo::Request.new(|%env);
        my $ret;
        given ($req.uri.path) {
            when m{^ '/entry/' $<id>=(\d+) $} {
                $ret = self.show($/<id>);
            }
            when m{^ '/writer' [ '/' $<id>=(\d+) ]? $} {
                my $method = "writer_" ~ $req.request_method.lc;
                $ret = self."$method"($/<id>, $req);
            }
            when m{^ '/page/' $<page>=(\d+) $} {
                $ret = self.page($/<page>);
            }
            when m{^ '/' $} {
                $ret = self.page(1);
            }
            when m{^ '/feed' $} {
                $ret = self.feed;
            }
            default {
                $ret = self.not_found;
            }
        }
        $ret //= [400, [Content-Type => 'text/plain'], ['bad request']];

        self!log("handle_request end");
        return $ret;
    }

    multi method new (*@in, :$log? ) {
        my $dbh = MiniDBI.connect(|@in, :RaiseError)
            or die "dbh not available";
        $dbh.do('set names utf8');
        self.bless(
            *,
            dbh => $dbh,
            log => $log,
        );
    }

    method not_found {
        [404, [Content-Type => 'text/plain'], ['404 not found']];
    }
    method redirect ($uri) {
        [302, [Location => $uri], []];
    }

    method make_response ($str, $type = 'text/html; charset=utf-8') {
        return [
            200, 
            [
                Content-Type => $type, 
                Content-Length => $str.bytes
            ], 
            [$str]
        ];
    }

    method show ($id) {
        my $sth = $!dbh.prepare('select * from entry where id <= ? order by id desc limit ?');
        $sth.execute($id, 2);
        my $row = $sth.fetchrow_hashref();
        unless $row { return self.not_found; }
        my $pager;
        try {
            if my $row = $sth.fetchrow_hashref() {
                $pager = Journal::HTML.pager('/entry/' ~ $row<id> );
            }
        }
        return self.make_response(
            Journal::HTML.enclose(
                Journal::HTML.format_entry($row),
                $pager
            )
        );
    }
    
    method page ($page) {
        my $per_page = 5;
        my $sth = $!dbh.prepare('select * from entry order by id desc limit ?,?');
        $sth.execute(($per_page + 1) * ($page - 1), ($per_page + 1));
        my @entries;
        for (1 .. $per_page) {
            my $row = $sth.fetchrow_hashref() or last;
            @entries.push( Journal::HTML.format_entry($row) );
        }
        try {
            if $sth.fetchrow_hashref() {
                @entries.push( Journal::HTML.pager('/page/' ~ $page + 1) );
            }
        }
        unless @entries { return self.not_found; } 
        return self.make_response(
            Journal::HTML.enclose(@entries)
        ); 
    }

    method writer_get ($id, $req) {
        my $subject = '';
        my $body = '';
        if $id {
            my $sth = $!dbh.prepare('select * from entry where id = ?');
            $sth.execute($id);
            my $row = $sth.fetchrow_hashref;
            $row or return self.redirect('/writer');
            $body = $row<body>;
            $subject = $row<subject>;
        }
        return self.make_response(
            Journal::HTML.show_form($subject, $body)
        );
    }

    method writer_post ($id is copy, $req) {
        if $req.param('delete') {
            my $sth = $!dbh.prepare('delete from entry where id = ?');
            $sth.execute($id);
            return self.redirect('/');
        } else {
            if $id {
                my $sth = $!dbh.prepare('update entry set subject = ?, body = ? where id = ?');
                $sth.execute($req.param('subject'), $req.param('body'), $id);
            } else {
                my $sth = $!dbh.prepare('insert into entry (subject, body, posted_at) values (?, ?, ?)');
                $sth.execute($req.param('subject'), $req.param('body'), time);
                $id = $sth.mysql_insertid;
            }
            return self.redirect('/entry/' ~ $id);
        }
    }

    method feed {
        self!log('here');
        my $sth = $!dbh.prepare(
            'select * from entry order by id desc limit ?,?'
        );
        $sth.execute(0, 5);
        my $rss = Journal::RSS.new(
            channel => 'soffritto::journal',
            link => 'http://journal.soffritto.org/',
            description => 'soffritto::journal by Nobuo Danjou',
        );

        while $sth.fetchrow_hashref -> $row {
            my $entry = Journal::RSS::Entry.new(
                title => $row<subject>,
                issued => $row<posted_at>.Int,
                link => 'http://journal.soffritto.org/entry/' ~ $row<id>,
                content => Journal::HTML.format_body(
                    $row<body>, 
                    $row<format>
                )
            );
            $rss.add_entry($entry);
        }
        my $str = $rss.as_xml;
        return self.make_response($str, 'application/rss+xml; charset=utf-8');
    }

}

# vim: ft=perl6 :
