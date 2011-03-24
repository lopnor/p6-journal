use v6;

class Journal::RSS::Entry {
    use Plackdo::HTTP::Date;
    has $.title;
    has $.issued;
    has $.link;
    has $.content;

    method get_obj {
        my $date = time2str($.issued);
        my $item = item => [
            title => [$.title],
            link => [$.link],
            guid => [:isPermaLink('true'), $.link],
            pudDate => [$date],
            'content:encoded' => [$.content],
        ];
        return $item;
    }
}

class Journal::RSS {
    use XML::Writer;
    has $.channel;
    has $.link;
    has $.description;
    has @.entries;

    method add_entry (Journal::RSS::Entry $entry) {
        @.entries.push($entry);
    }

    method as_xml {
        my @items = map { $_.get_obj }, @.entries;
        my $obj = rss => [
            'version' => '2.0',
            'xmlns:blogChannel' => 'http://backend.userland.com/blogChannelModule',
            'xmlns:geo' => 'http://www.w3.org/2003/01/geo/wgs84_pos#',
            'xmlns:content' => 'http://purl.org/rss/1.0/modules/content/',
            'xmlns:atom' => 'http://www.w3.org/2005/Atom',
            'xmlns:dcterms' => 'http://purl.org/dc/terms/',
            channel => [
                title => [$.channel],
                link => [$.link],
                description => [$.description],
                @items
            ]
        ];
        return '<?xml version="1.0" encoding="UTF-8"?>' ~ "\n"
            ~ XML::Writer.serialize($obj);
    }
}

# vim: ft=perl6 :
