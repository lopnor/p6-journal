use v6;
use Test;
use Formatter;

ok 1;

{
    is div({'class' => 'hoge'}, 'hogehgoe'), '<div class="hoge">hogehgoe</div>';
}
{
    is div({'class' => 'hoge', id => 'fuga'}, DateTime.new(1234567890).Str), 
        '<div class="hoge" id="fuga">2009-02-13T23:31:30Z</div>';
}
{
    is h1({'class' => 'hoge', id => 'fuga'}, 'hoge'), 
        '<h1 class="hoge" id="fuga">hoge</h1>';
}

done;

# vim: ft=perl6 :

