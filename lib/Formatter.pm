use v6;

module Formatter {
    sub div(%attr?, *@str) is export { tag('div', %attr, @str) }
    sub a(%attr, *@str) is export { tag('a', %attr, @str) }
    sub h1(%attr?, *@str) is export { tag('h1', %attr, @str) }
    sub h2(%attr?, *@str) is export { tag('h2', %attr, @str) }
    sub html(*@str) is export  { tag('html', {}, @str) }
    sub head(*@str) is export  { tag('head', {}, @str) }
    our sub body(*@str) is export  { tag('body', {}, @str) }
    our sub link(%attr) is export  { tag('link', %attr) }
    sub title(*@str) is export  { tag('title', {}, @str) }
    sub meta(%attr) is export  { tag('meta', %attr) }

    sub tag($tagname, %attr?, *@str) {
        my $ret = "<$tagname";
        for %attr.pairs -> $p {
            $ret ~= ' ' ~ $p.key ~ '="' ~ $p.value ~ '"';
        }
        if (+@str) {
            $ret ~= '>' ~ [~]@str ~ "</$tagname>\n";
        } else {
            $ret ~= " />\n";
        }
        return $ret;
    }
}

# vim: ft=perl6 :
