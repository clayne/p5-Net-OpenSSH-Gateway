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

my %modules = ( Socket => [],
                Fcntl  => [qw(F_SETFL F_GETFL O_NONBLOCK)] );

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

sub _generate_pnc {
    my $self = shift;

    open (my $out, ">/tmp/pnc") or die $!;

    print $out "#!/usr/bin/perl\n";
    print $out "use $_" . (@{$modules{$_}} ? " qw(@{$modules{$_}})" : '') .";\n" for keys %modules;
    my $code = $self->_minify_code($data);
    $code =~ s/\bSERVER\b/\$ARGV[0]/;
    $code =~ s/\bPORT\b/\$ARGV[1]/;
    print $out "$code\n";
    close $out;
}

__DATA__
$0=perl;
socket($socket, AF_INET, SOCK_STREAM, 0) &&
connect($socket,  sockaddr_in PORT, inet_aton "SERVER") || die $!;
fcntl $_, F_SETFL, O_NONBLOCK|fcntl $_, F_GETFL, 0 for @in = (*STDIN, $socket), @out = ($socket, *STDOUT);

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
