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
};

$tt->process('main.html', $vars)
    || die $tt->error(), "\n";
