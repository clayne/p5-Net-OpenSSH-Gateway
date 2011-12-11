package Net::OpenSSH::Gateway::Backend::perl;

use strict;
use warnings;

require Net::OpenSSH::Gateway::Backend;
our @ISA = qw(Net::OpenSSH::Gateway::Backend);

sub _command { 'perl' }

my @data = <DATA>;
my $data = join('', @data);

sub check_args {
    my $self = shift;
    my $proxies = $self->{proxies};
    if (@$proxies) {
        $self->_push_error("pnc does not support proxies");
        return;
    }
    1;
}

my %modules = ( 'IO::Socket::INET' => [] );
#Fcntl  => [qw(F_SETFL F_GETFL O_NONBLOCK)] );

sub _command_args {
    my ($self, %opts) = @_;

    my $code = $self->_slave_quote($self->_minify_code($data));

    my $host = $self->_slave_quote_opt(host => %opts);
    my $port = $self->_slave_quote_opt(port => %opts);
    $code =~ s/\bPORT\b/$port/g;
    $code =~ s/\bSERVER\b/$host/g;

    my @modules;
    for my $k (keys %modules) {
        push @modules, "-M$k" . (@{$modules{$k}} ? '=' . join(',', @{$modules{$k}}) : '')
    }

    return (@modules, "-e$code");
}

sub _minify_code {
    my ($self, $code) = @_;
    if (1) {
        $code =~ s/^#.*$//m;
        $code =~ s/\s+/ /g;
        $code =~ s/\s(?!\w)//g; # that breaks "use foo 'doz'" so don't use that!!!
        $code =~ s/(?<!\w)\s//g;
        $code =~ s/;}/}/g;

        my $next = 'c';
        my %vars;
        $code =~ s/([\$\@%])([a-z]\w*)/$1 . ($vars{$2} ||= $next++)/ge;
    }
    $code;
}

sub one_liner {
    my $self = shift;
    my @out = 'perl';
    for my $k (keys %modules) {
        push @out, "-M$k" . (@{$modules{$k}} ? '=' . join(',', @{$modules{$k}}) : '')
    }
    my $code = $data;
    $code =~ s/\bPORT\b/\$ARGV[1]/g;
    $code =~ s/\bSERVER\b/\$ARGV[0]/g;
    push @out, '-e' . $self->_minify_code($code);

    require Net::OpenSSH;
    scalar Net::OpenSSH->shell_quote(@out);
}

1;

__DATA__
#$0=perl;
$socket = new IO::Socket::INET "SERVER:PORT";
blocking $_ 0 for @in = (*STDIN, $socket), @out = ($socket, *STDOUT);

L:
for (0, 1) {
    sysread ($in[$_], $buffer, 8**5) || exit and $buffer[$_] .= $buffer
        if vec $iv, $_ * ($socket_fileno = fileno $socket), 1;
    substr $buffer[$_], 0, syswrite($out[$_], $buffer[$_], 8**5), "";
    vec($iv, $_ * $socket_fileno, 1) = ($l = length $buffer[$_] < 8**5);
    vec($ov, $_ || $socket_fileno, 1) = !!$l;
}
select $iv, $ov, $u, 5;
goto L

