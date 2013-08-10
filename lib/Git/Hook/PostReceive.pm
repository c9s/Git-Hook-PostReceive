use strict;
package Git::Hook::PostReceive;
#ABSTRACT: Parses git commit information in post-receive hook scripts

use v5.10;
use DateTime::Format::DateParse;
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

    my $is_new_head = $before =~ /^0{40}/;
    my $is_delete = $after =~ /^0{40}/;

    $before  = $before ne '0000000000000000000000000000000000000000'
                ? qx(git rev-parse $before)
                : undef;

    $after   = $after ne '0000000000000000000000000000000000000000'
                ? qx(git rev-parse $after)
                : undef;

    chomp($before) if $before;
    chomp($after) if $after;

    my ($ref_type,$ref_name) = ( $ref =~ m{refs/([^/]+)/([^/]+)} );
    my $repo = getcwd;
    my @commits = $self->get_commits($before,$after);
    return {
        before     => $before,
        after      => $after,
        repository => $repo,
        ref        => $ref_name,
        ref_type   => $ref_type,
        ( $is_new_head
            ? (new_head => $is_new_head)
            : () ),
        ( $is_delete
            ? (delete => $is_delete)
            : () ),
        commits    => \@commits,
    };
}

sub get_commits {
    my ($self,$before,$after) = @_;

    my $log_string;

    if( $before && $after ) {
        $log_string = qx(git rev-list --date=iso --pretty $before...$after);
    }
    elsif( $after ) {
        $log_string = qx(git rev-list --date=iso --pretty $after);
    }

    return ( ) unless $log_string;

    my @lines = split /\n/,$log_string;
    my @commits = ();
    my $buffer = '';
    for( @lines ) {
        if(/^commit\s/ && $buffer ) {
            push @commits,$buffer;
            $buffer = '';
        }
        $buffer .= $_ . "\n";
    }
    push @commits, $buffer;
    return reverse map {
                my @lines = split /\n/,$_;
                my $info = {  };
                for my $line ( @lines ) {
                    given($line) {
                        when( m{^commit (.*)$}i ) { $info->{id} = $1; }
                        when( m{^author:\s+(.*?)\s<(.*?)>}i ) {
                                $info->{author} = {
                                    name => $1,
                                    email => $2
                                };
                            }
                        when( m{^date:\s+(.*)$}i ) {
                            $info->{timestamp} = $1;
                            $info->{timestamp} =~ s/ /T/;
                            $info->{timestamp} =~ s/ ([+-])(\d\d)(\d\d)/$1$2:$3/;
                        }
                        when( m{^merge: (\w+)\s+(\w+)} ) { $info->{merge} = { parent1 => $1 , parent2 => $2 } }
                        default {
                            $info->{message} .= $line . "\n";
                        }
                    }
                }
                $info;
            } @commits;
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

all you need to do is pass each STDIN string to Git::Hook::PostReceive,
then it returns the commit payload for the particular branch.

