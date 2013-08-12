use strict;
package Git::Hook::PostReceive;
#ABSTRACT: Parses git commit information in post-receive hook scripts

use v5.10;
use Cwd;
use File::Basename;

sub new {
    my ($class, %args) = @_;
    my $self = bless { }, $class;
    $self;
}

sub read_stdin {
    my ($self, $line) = @_;

    chomp $line;
    my @args = split /\s+/, $line;
    return $self->run( @args );
}

sub run {
    my ($self, $before, $after, $ref) = @_;

    my ($created,$deleted) = (0,0);

    if ($before ne '0000000000000000000000000000000000000000') {
        $before  = qx(git rev-parse $before);
        chomp $before;
    } else {
        $created = 1;
    }

    if ($after ne '0000000000000000000000000000000000000000') {
        $after  = qx(git rev-parse $after);
        chomp $after;
    } else {
        $deleted = 1;
    }

    my $repo = getcwd;
    return {
        before     => $before,
        after      => $after,
        repository => $repo,
        ref        => $ref,
        created    => $created,
        deleted    => $deleted,
        commits    => [
            $self->get_commits($before,$after)
        ]
        # head_commit => ... # ?
    };
}

sub get_commits {
    my ($self,$before,$after) = @_;

    my $log_string;

    if( $before ne '0000000000000000000000000000000000000000' &&
        $after  ne '0000000000000000000000000000000000000000') {
        $log_string = qx(git rev-list $before...$after);
    }
    elsif( $after ne '0000000000000000000000000000000000000000' ) {
        $log_string = qx(git rev-list $after);
    }

    return ( ) unless $log_string;

    return reverse map { $self->commit_info($_) } split /\n/,$log_string;
}

sub commit_info {
    my ($self, $hash) = @_;

    my $commit = qx{git show --format=fuller --date=iso --name-status $hash};

    my @lines = split /\n/, $commit;

    my $info = {
        added => [],
        removed => [],
        modified => []
    };

    for my $line ( @lines ) {
        given($line) {
            when( m{^commit (.*)$}i ) {
                $info->{id} = $1;
            }
            when( m{^author:\s+(.*?)\s<(.*?)>}i ) {
                $info->{author} = { name  => $1, email => $2 };
            }
            when( m{^commit:\s+(.*?)\s<(.*?)>}i ) {
                $info->{commiter} = { name  => $1, email => $2 };
            }
            when( m{^authordate:\s+(.*)$}i ) {
                $info->{timestamp} = $1;
                $info->{timestamp} =~ s/ /T/;
                $info->{timestamp} =~ s/ ([+-])(\d\d)(\d\d)/$1$2:$3/;
            }
            when( m{^merge: (\w+)\s+(\w+)}i ) {
                $info->{merge} = { parent1 => $1 , parent2 => $2 }
            }
            when( m{^A\t(.+)}) {
                push @{$info->{added}}, $1;
            }
            when( m{^D\t(.+)}) {
                push @{$info->{removed}}, $1;
            }
            when( m{^M\t(.+)} ) {
                push @{$info->{modified}}, $1;
            }
            when( m{^    (.*)} ) {
                $info->{message} .= $1."\n";
            }
        }
    }
    chomp $info->{message};

    return $info;
}

1;
__END__

=head1 SYNOPSIS

    # hooks/post-receive
    use Git::Hook::PostReceive;

    foreach my $line (<STDIN>) {
        my $payload = Git::Hook::PostReceive->new->read_stdin( $line );

        $payload->{new_head};
        $payload->{delete};

        $payload->{before};
        $payload->{after};
        $payload->{ref_type}; # tags or heads

        for my $commit (@{ $payload->{commits} } ) {
            $commit->{id};
            $commit->{author}->{name};
            $commit->{author}->{email};
            $commit->{message};
            $commit->{date};
        }
    }

=head1 DESCRIPTION

Git::Hook::PostReceive parses git commit information in post-receive hook script.

All you need to do is pass each STDIN string to Git::Hook::PostReceive,
then it returns the commit payload for the particular branch.

This module does not use any non-core dependencies, so you can also
copy it to a location of your choice and directly include it.

To run the hook on an arbitrary git repository, set the C<GIT_WORK_TREE>
environment variable.

=head2 payload format

The payload format returned by method C<read_stdin> or C<run> is compatible with
L<https://help.github.com/articles/post-receive-hooks|GitHub Post-Receive Hooks>
with some minor differences:

    {
        before  => $commit_hash_before,
        after   => $commit_hash_after,
        ref     => $ref,
        created => $whether_new_branch,      # 1|0 in contrast to true|false
        deleted => $whether_branch_removed,  # 1|0 in contrast to true|false
        commits => [
            id        => $hash,
            message   => $message,
            timestamp => $date,
            author    => {
                email => $email,
                name  => $name
            },
            commiter  => {
                email => $email,
                name  => $name
            },
            added     => [@added_paths],
            removed   => [@deleted_paths],
            modified  => [@modified_paths],
        ],
        repository => $directory,           # in contrast to detailed object
    }

C<before> is set to <0000000000000000000000000000000000000000> and C<created>
is set to C<1> (C<0> otherwise) when a new branch has been pushed. C<after> is
set to <0000000000000000000000000000000000000000> and C<deleted> is set to C<1>
(C<0> otherwise) when a branch has been deleted.

=head2 SEE ALSO

L<Git::Repository>, L<Plack::App::GitHub::WebHook>

