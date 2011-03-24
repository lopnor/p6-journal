use v6;

class Journal {
    use MiniDBI;
    use Formatter;
    use Plackdo::Request;
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

    method make_response ($str) {
        return [
            200, 
            [
                Content-Type => 'text/html; charset=utf-8', 
                Content-Length => $str.bytes
            ], 
            [$str]
        ];
    }

    method show ($id) {
        my $sth = $!dbh.prepare('select * from entry where id = ?');
        $sth.execute($id);
        my $row = $sth.fetchrow_hashref();
        $sth.finish;
        unless $row { return self.not_found; }
        return self.enclose( self.format_entry($row) );
    }
    
    method page ($page) {
        my $per_page = 5;
        my $body = '';
        my $sth = $!dbh.prepare('select * from entry order by id desc limit ?,?');
        $sth.execute($per_page * ($page - 1), $per_page);
        while $sth.fetchrow_hashref() -> $row {
            $body ~= self.format_entry($row);
        }
        unless $body { return self.not_found; } 
        return self.enclose($body);
    }

    method writer_get ($id, $req) {
        my $subject = '';
        my $body = '';
        if $id {
            my $sth = $!dbh.prepare('select * from entry where id = ?');
            $sth.execute($id);
            my $row = $sth.fetchrow_hashref;
            $sth.finish;
            $row or return self.redirect('/writer');
            $body = self.decode($row<body>);
            $subject = self.decode($row<subject>);
        }
        my $form = div( {},
                form({'method' => 'POST'},
                input({id => 'form_subject', type => 'text', name => 'subject', value => $subject}),
                Formatter::textarea({id => 'form_body', name => 'body'}, $body),
                input({type => 'submit', value => 'post this entry'}),
                input({type => 'submit', name => 'delete', value => 'delete'}),
            )
        );
        return self.enclose($form);
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
            :channel('soffritto::journal'),
            :link(''),
            :description('soffritto::journal by Nobuo Danjou')
        );

        while $sth.fetchrow_hashref() -> $row {
            my $entry = Journal::RSS::Entry.new(
                title => self.decode($row<subject>),
                issued => $row<posted_at>.Int,
                link => 'http://journal.soffritto.org/entry/' ~ $row<id>,
                content => self.format_body(self.decode($row<body>), $row<format>)
            );
            $rss.add_entry($entry);
        }
        my $str = $rss.as_xml;
        return [
            200,
            [
                Content-Type => 'application/rss+xml; charset=utf-8',
                Content-Length => $str.bytes,
            ],
            [$str]
        ];
    }

    method format_entry ($row) {
        self!log('before decode');
        my $body = self.decode($row<body>);
        my $subject = self.decode($row<subject>);
        self!log('after decode');
        my $d = DateTime.new($row<posted_at>.Int);

        return div({'class' => 'entry hentry'},
            h2({'class' => 'subject entry-title'}, 
                a({rel => 'bookmark', href => '/entry/'~ $row<id>}, $subject )
            ),
            div({'class' => 'updated'}, $d.Str),
            div({'class' => 'entry-content markdown'}, self.format_body($body, $row<format>) )
        );
    }

    method enclose ($body) {
        my $enclosed = html(
            head(
                title('soffritto::journal'),
                meta({http-equiv => 'Content-Type', value => 'text/html; charset=utf8'}),
                Formatter::link({
                    rel => 'shortcut icon', 
                    href => '/static/favicon.ico',
                }),
                Formatter::link({
                    rel => 'alternate',
                    type => 'application/rss+xml',
                    title => 'RSS',
                    href => '/feed',
                }),
                Formatter::link({
                    rel => 'stylesheet', 
                    media => 'screen',
                    type => 'text/css',
                    href => '/static/style.css'
                }),
            ),
            Formatter::body(
                div({id => 'header'},
                    h1({'class' => 'title'}, 
                        a({href => '/'}, 'soffritto::journal')
                    )
                ),
                div({id => 'main', 'class' => 'autopagerize_page_element'}, $body),
                div({id => 'footer', 'class' => 'autopagerize_insert_before'}, '')
            )
        );
        return self.make_response($enclosed);
    }

    method format_body ($body is copy, $formatter) {
        $body ~~ s:g[\&] = '&amp;';
        $body ~~ s:g[\"] = '&quot;';
        $body ~~ s:g[\>] = '&gt;';
        $body ~~ s:g[\<] = '&lt;';
        $body ~~ s:g[\n] = '<br />';
        return $body;
    }

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
