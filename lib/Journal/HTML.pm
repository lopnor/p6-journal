use v6;

class Journal::HTML {
    use XML::Writer;
    use Journal::Util;

    method show_entry($row) {
        return self.enclose(self.format_entry($row));
    }

    method format_entry ($row) {
        my $body = Journal::Util.decode($row<body>);
        my $subject = Journal::Util.decode($row<subject>);
        my $d = DateTime.new($row<posted_at>.Int);
        my $entry = div => [ 
            :class('entry hentry'),
            h2 => [
                :class('subject entry-title'),
                a => [
                    :rel('bookmark'), :href('/entry/' ~ $row<id>),
                    $subject
                ],
            ],
            div => [
                :class('updated'),
                $d.Str,
            ],
            div => [
                :class('entry-content markdown'),
                self.format_body($body, $row<format>)
            ]
        ];
        return $entry;
    }

    method show_form ($subject, $body) {
        my $form = div => [
            form => [ :method('POST'),
                input => [
                    :id('form_subject'), :type('text'), :name('subject'),
                    :value($subject)
                ],
                textarea => [
                    :id('form_body'), :name('body'),
                    $body
                ],
                input => [:type('submit'), :value('post this entry')],
                input => [:type('submit'), :name('delete'), :value('delete')],
            ]
        ];
        return self.enclose($form);
    }

    method enclose ( *@body ) {
        my $enclosed = html => [
            head => [
                title => ['soffritto::journal'],
                meta => [
                    :http-equiv('Content-Type'), :value('text/html; charset=utf8'),
                ],
                link => [
                    :rel('shortcut icon'), :href('/static/favicon.ico'),
                ],
                link => [
                    :rel('alternate'),
                    :type('application/rss+xml'),
                    :title('RSS'),
                    :href('/feed'),
                ],
                link => [
                    :rel('stylesheet'),
                    :media('screen'),
                    :type('text/css'),
                    :href('/static/style.css'),
                ],
            ],
            body => [
                div => [
                    :id('header'),
                    h1 => [
                        :class('title'),
                        a => [
                            :href('/'),
                            'soffritto::journal',
                        ],
                    ],
                ],
                div => [
                    :id('main'), :class('autopagerize_page_element'),
                    @body,
                ],
                div => [
                    :id('footer'), :class('autopagerize_insert_before'),
                    '',
                ]
            ]
        ];
        return XML::Writer.serialize($enclosed);
    }

    method format_body ($body is copy, $formatter) {
        $body ~~ s:g[\&] = '&amp;';
        $body ~~ s:g[\"] = '&quot;';
        $body ~~ s:g[\>] = '&gt;';
        $body ~~ s:g[\<] = '&lt;';
        my @lines = $body.split("\n");
        my $br = br => [];
        my @arr;
        for @lines -> $line {
            @arr.push($line, $br);
        }
        return @arr;
    }
}

# vim: ft=perl6 :
