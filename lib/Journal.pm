use v6;

class Journal {
    use MiniDBI;
    use Formatter;
    use Plackdo::Request;

    has $!dbh;
    has $!log;

    method !log (Str $str?) {
        $!log or return;
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
        my $body = '';
        given ($req.uri.path) {
            when m{^ '/entry/' $<id>=(\d+) $} {
                $body = self.show($/<id>);
            }
#            when m{^ '/writer/' $<id>=(\d+)? $} {
#
#            }
            when m{^ '/page/' $<page>=(\d+) $} {
                $body = self.page($/<page>);
            }
            when m{^ '/' $} {
                $body = self.page(1);
            }
            default {
                return [404, [Content-Type => 'text/plain'], ['404 not found']];
            }
        }

        my $ret = [
            200, 
            [
                Content-Type => 'text/html; charset=utf-8', 
                Content-Length => $body.bytes
            ], 
            [$body]
        ];
        self!log("handle_request end");
        return $ret;
    }

    multi method new (*@in, :$log? ) {
        my $dbh = MiniDBI.connect(|@in, :RaseError);
        $dbh.do('set names utf8');
        self.bless(
            *,
            dbh => $dbh,
            log => $log,
        );
    }

    method show ($id) {
        my $sth = $!dbh.prepare('select * from entry where id = ?');
        $sth.execute($id);
        my $row = $sth.fetchrow_hashref();
        $sth.finish;
        return self.enclose( self.format_entry($row) );
    }
    
    method page ($page) {
        my $per_page = 2;
        my $body = '';
        my $sth = $!dbh.prepare('select * from entry order by id desc limit ?,?');
        $sth.execute($per_page * ($page - 1), $per_page);
        while $sth.fetchrow_hashref() -> $row {
            $body ~= self.format_entry($row);
        }
        return self.enclose($body);
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
        return html(
            head(
                title('soffritto::journal'),
                meta({http-equiv => 'Content-Type', value => 'text/html; charset=utf8'}),
                Formatter::link({
                    rel => 'shortcut icon', 
                    href => 'http://soffritto.org/images/favicon.ico'
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
    }

    method format_body ($body, $formatter) {
        return $body.subst(/\n/, '<br />');
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
