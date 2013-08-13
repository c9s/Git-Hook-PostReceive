use strict;
use v5.10;
use Test::More;
use File::Temp qw(tempdir);
use Git::Hook::PostReceive;
use Cwd;
use Text::ParseWords;

my $gitv = `git --version`; # e.g. "git version 1.8.1.2"
if ($?) {
    plan skip_all => 'git not installed';
    exit;
} else {
    diag $gitv;
}

my $hook = Git::Hook::PostReceive->new;
my $payload = $hook->read_stdin("\n");
is $payload, undef, "ignore empty lines";

my $cwd = cwd;

my $repo = tempdir();
chdir $repo;

my $null = '0000000000000000000000000000000000000000';

my @commands = <DATA>;
foreach (@commands) {
    chomp; # don't use shell to avoid encoding issues, unless piped command
    my @args = $_ =~ />/ ? $_ : quotewords('\s+', 0, $_);
    @args = map { $_=~s/\{([0-9A-Z]+)\}/pack('U',hex($1))/ge; $_ }  @args;
    system(@args) && last;
}

my ($second,$first) = split "\n", `git log --format='%H'`;

my @commits = ({
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
# distinct => true,
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
    message => "second\n\n\xE2\x98\x83",
    added   => ['baz'],
    removed => ['foo'],
    modified => ['bar']
});

my $expect = {
    before  => $null,
    after   => $second,
    created => 1,
    deleted => 0,
    ref => 'master',
    repository => $repo,
    commits => [ @commits ],
};

$hook = Git::Hook::PostReceive->new;
$payload = $hook->read_stdin("$null $second master\n");
is_deeply $payload, $expect, 'sample payload';

my @branches = $hook->read_stdin("$null $second master\n","$first mytag mybranch");
is_deeply @branches[1], { 
    repository => $repo, ref => 'mybranch',
    before => $first, after => $second, created => 0, deleted => 0,
    commits => [$commits[1]]
}, 'multiple branches';

$hook = Git::Hook::PostReceive->new( utf8 => 1 );
$payload = $hook->read_stdin("$null mytag master");
$expect->{commits}->[1]->{message} = "second\n\n\x{2603}";
is_deeply $payload, $expect, 'sample payload in UTF8';

# use Data::Dumper; say Dumper(\@branches);
# TODO: test merge

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
git commit -m "second{A}{A}{2603}" --date "1376148966 -01:00" --quiet
git tag mytag
git checkout -b mybranch --quiet
