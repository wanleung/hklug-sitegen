#!/usr/bin/perl

use Template;

my $tt = Template->new({
    INCLUDE_PATH => '../template',
    INTERPOLATE  => 1,
}) || die "$Template::ERROR\n";

my $vars = {
    title     => 'Count Edward van Halen',
    debt     => '3 riffs and a solo',
    deadline => 'the next chorus',
    news => [{"title" => "aaa", content=>"ldsuifsd", "author" =>"bbb"} , {"title" =>"1111", content=>"87sdfsdfs", "author" =>"222"} ,

    ],
    post => {title=>'aaa', author=>'bbb'
    },
};

$tt->process('news_section.html', $vars)
    || die $tt->error(), "\n";
