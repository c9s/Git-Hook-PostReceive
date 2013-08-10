use strict;
use v5.10;
use Test::More;
use File::Temp qw(tempdir);
use Git::Hook::PostReceive;

my $gitv = `git --version`; # e.g. "git version 1.8.1.2"
if ($? != 0) {
    plan skip_all => 'git not installed';
    exit;
}

my $repo = tempdir();
chdir $repo;

my @commands = <DATA>;
foreach (@commands) {
    system($_) && break;
}

my ($second,$first) = split "\n", `git log --format='%H'`;

my $hook = Git::Hook::PostReceive->new;

my $payload = $hook->run('0' x 40, $second, 'master');

is $payload->{after}, $second, 'after';
is scalar @{$payload->{commits}}, 2, 'number of commits';

is_deeply $payload->{commits}->[0],
    {
        timestamp => '2013-07-30T08:20:24+02:00',
        author => { email => 'a@li.ce', name => 'Alice' },
        id      => $first,
        message => 'first'
    }, 'commit';

#use Data::Dumper; say Dumper($payload);

done_testing;

__DATA__
git init --quiet
echo 1 > foo
echo 2 > bar
echo 3 > doz
git add --all
git commit --author "Alice <a@li.ce>" -m "first" --date "Tue, 30 Jul 2013 08:20:24 +0200" --quiet
git rm foo --quiet
echo 4 > bar
echo 5 > baz
git add bar baz
git commit --author "Alice <a@li.ce>" -m "second" --quiet
