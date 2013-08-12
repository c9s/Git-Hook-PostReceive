use strict;
use v5.10;
use Test::More;
use File::Temp qw(tempdir);
use Git::Hook::PostReceive;
use Cwd;

my $gitv = `git --version`; # e.g. "git version 1.8.1.2"
if ($?) {
    plan skip_all => 'git not installed';
    exit;
} else {
    diag $gitv;
}

my $cwd = cwd;

my $repo = tempdir();
chdir $repo;

my $null = '0000000000000000000000000000000000000000';
my @commands = <DATA>;
foreach (@commands) {
    system($_) && last;
}

my ($second,$first) = split "\n", `git log --format='%H'`;

my $expect = {
    before  => $null,
    after   => $second,
    created => 1,
    deleted => 0,
    ref => 'master',
    repository => $repo,
    commits => [
        {
            timestamp => '2013-07-30T08:20:24+02:00',
            author => {
                email => 'a@li.ce',
                name => 'Alice'
            },
            commiter => {
                email => 'a@li.ce',
                name => 'Alice'
            },
            id => $first,
            message => 'first',
            added => [sort qw(foo bar doz)],
            removed => [],
            modified => [],
#           distinct => true,
        },
        {
            id => $second,
            timestamp => '2013-08-10T14:36:06-01:00',
            author => {
                email => 'a@li.ce',
                name => 'Alice'
            },
            commiter => {
                email => 'a@li.ce',
                name => 'Alice'
            },
            message => 'second',
            added   => ['baz'],
            removed => ['foo'],
            modified => ['bar']
        }
    ],
};

my $hook = Git::Hook::PostReceive->new;

my $payload = $hook->read_stdin("$null $second master\n");

is_deeply $payload, $expect;

use Data::Dumper; say Dumper($payload);

# TODO: test merge, test multiline message

done_testing;

__DATA__
git init --quiet
git config user.name "Alice"
git config user.email "a@li.ce"
echo 1 > foo
echo 2 > bar
echo 3 > doz
git add --all
git commit -m "first" --date "Tue, 30 Jul 2013 08:20:24 +0200" --quiet
git rm foo --quiet
echo 4 > bar
echo 5 > baz
git add bar baz
git commit -m "second" --date "1376148966 -01:00" --quiet
