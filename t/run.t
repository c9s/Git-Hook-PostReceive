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
my $after = `git log --format='%H' -1`;
chomp $after;

my $hook = Git::Hook::PostReceive->new;

my $payload = $hook->run('0' x 40, $after, 'master');

is $payload->{after}, $after, 'after';
is scalar @{$payload->{commits}}, 2, 'number of commits';

#use Data::Dumper; say Dumper($payload);

done_testing;

__DATA__
git init --quiet
echo 1 > foo
echo 2 > bar
echo 3 > doz
git add --all
git commit --author "Alice <a@li.ce>" -m "first" --quiet
git rm foo --quiet
echo 4 > bar
echo 5 > baz
git add bar baz
git commit --author "Alice <a@li.ce>" -m "second" --quiet
