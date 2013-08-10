package Git::Hook::PostReceive;
use v5.10;
use DateTime::Format::DateParse;
use Cwd;
use File::Basename;

our $VERSION = '0.01';

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
        $log_string = qx(git rev-list --pretty $before...$after);
    }
    elsif( $after ) {
        $log_string = qx(git rev-list --pretty $after);
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
                        when( m{^date:\s+(.*)$}i ) {  $info->{date} = DateTime::Format::DateParse->parse_datetime( $1 ); }
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
=head1 NAME

Git::Hook::PostReceive - 

=head1 SYNOPSIS

    # hooks/post-receive
    use Git::Hook::PostReceive;
    my $payload = Git::Hook::PostReceive->new->read_stdin( <STDIN> );

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

=head1 DESCRIPTION

Git::Hook::PostReceive parses git commit information in post-receive hook script.

all you need to do is pass the stdin string to Git::Hook::PostReceive, 
then it returns the commit payload .

=head1 INSTALLATION

Git::Hook::PostReceive installation is straightforward. If your CPAN shell is set up,
you should just be able to do

    % cpan Git::Hook::PostReceive

Download it, unpack it, then build it as per the usual:

    % perl Makefile.PL
    % make && make test

Then install it:

    % make install

=head1 DOCUMENTATION

Git::Hook::PostReceive documentation is available as in POD. So you can do:

    % perldoc Git::Hook::PostReceive

to read the documentation online with your favorite pager.

=head1 AUTHOR

Yo-An Lin E<lt>cornelius.howl {at} gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
