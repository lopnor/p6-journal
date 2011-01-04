use v6;

class Journal {
    use MiniDBI;
    use Formatter;
    use Plackdo::Request;

    has $!dbh;

    method webapp {
        sub (%env) {
            return self.handle_request(%env);
        };
    }

    method handle_request (%env) {
        my $req = Plackdo::Request.new(|%env);
        my $body = '';
        given ($req.uri.path) {
            when m{^\/entry\/$<id>=(\d+)$} {
                $body = self.show($/<id>);
            }
#            when m{^\/writer\/$<id>=(\d+)?$} {
#
#            }
            when m{^\/page\/$<page>=(\d+)$} {
                $body = self.page($/<page>);
            }
            when m{^\/$} {
                $body = self.page(1);
            }
            default {
                return [404, [Content-Type => 'text/plain'], ['404 not found']];
            }
        }

        return [
            200, 
            [
                Content-Type => 'text/html; charset=utf8', 
                Content-Length => $body.bytes
            ], 
            [$body]
        ];

    }

    multi method new ($in) {
        my $dbh = MiniDBI.connect(|$in, :RaseError);
        $dbh.do('set names utf8');
        self.bless(
            *,
            dbh => $dbh
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
        my $body = decode($row<body>);
        my $subject = decode($row<subject>);
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
}

# vim: ft=perl6 :
