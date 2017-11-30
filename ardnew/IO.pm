package ardnew::IO;

#
# MODULE: IO
# AUTHOR: Andrew Shultzabarger
#
# 1. subroutines for displaying information to the user
#
#   - pout: print raw data to file handle (or STDOUT if unspecified)
#   - perr: print raw data to file handle (or STDERR if unspecified)
#   - sinfo: print normal info to file handle (or STDOUT if unspecified)
#   - swarn: print warning info to file handle (or STDERR if unspecified)
#   - serror: print fatal info to file handle (or STDERR if unspecified)
#   - ohno: same as die but uses serror for output
#   - final: same as die but uses perr for output (no status prefix symbol)
#   - qclr: constructs a colored string using ANSI escape sequences
#   - clr: same as qclr but auto-wraps the string in ANSI reset sequences
#
#   - poutf, perrf, sinfof, swarnf, serrorf, ohnof, finalf: same as the parent
#     routine but with an additional leading format argument which will be used
#     with sprintf on each argument before calling the parent routine
#
#   the functions above for printing data all append a trailing line ending
#   automatically to each line. each argument given to the functions are printed
#   on their own line.
#
# 2. subroutines for retrieving information from the user
#
#   - readkey: reads a single keystroke without waiting for RETURN (STDIN ONLY)
#   - readln: reads a single line of input from file handle (or STDIN)
#   - confirm: executes a sub, reads a single keystroke, passes into other sub
#

use strict;
use warnings;

my (@export_local);

BEGIN
{
  require Exporter;

  our $VERSION   = 0.001;
  our @ISA       = qw| Exporter |;

  @export_local = # ardnew::IO
    qw| pout perr sinfo swarn serror ohno final qclr clr readkey readln confirm poutf perrf sinfof swarnf serrorf ohnof finalf |;

  our @EXPORT_OK   = (@export_local);
  our %EXPORT_TAGS =
    (
      all   => \@EXPORT_OK,
      local => \@export_local,
    );
}

use ardnew::Util qw| :all |;

use Scalar::Util qw| openhandle |;
use POSIX qw| :termios_h |;

use constant
  {
    _OUT_INFO  => 0,
    _OUT_WARN  => 1,
    _OUT_ERROR => 2,
  };

my @_OUTSYM =
  (
    '[-]', # _OUT_INFO
    '[+]', # _OUT_WARN
    '[*]', # _OUT_ERROR
  );

use constant _ANSI_RESET =>
  sub { local @_ = @_; @_ = map { $_."\e[0m" } @_; (@_ > 0) ? @_ : shift };

use constant _ANSI_SEQ =>
  sub { local @_ = @_; my $c = shift; @_ = map { $c.$_ } @_; (@_ > 0) ? @_ : shift };

my %ANSI_SEQ =
  (
    RESET       => _ANSI_RESET,
    # regular
    BLACK       => sub { _ANSI_SEQ->("\e[0;30m", @_) }, # black
    RED         => sub { _ANSI_SEQ->("\e[0;31m", @_) }, # red
    GREEN       => sub { _ANSI_SEQ->("\e[0;32m", @_) }, # green
    YELLOW      => sub { _ANSI_SEQ->("\e[0;33m", @_) }, # yellow
    BLUE        => sub { _ANSI_SEQ->("\e[0;34m", @_) }, # blue
    PURPLE      => sub { _ANSI_SEQ->("\e[0;35m", @_) }, # purple
    CYAN        => sub { _ANSI_SEQ->("\e[0;36m", @_) }, # cyan
    WHITE       => sub { _ANSI_SEQ->("\e[0;37m", @_) }, # white
    # bold
    BBLACK      => sub { _ANSI_SEQ->("\e[1;30m", @_) }, # black
    BRED        => sub { _ANSI_SEQ->("\e[1;31m", @_) }, # red
    BGREEN      => sub { _ANSI_SEQ->("\e[1;32m", @_) }, # green
    BYELLOW     => sub { _ANSI_SEQ->("\e[1;33m", @_) }, # yellow
    BBLUE       => sub { _ANSI_SEQ->("\e[1;34m", @_) }, # blue
    BPURPLE     => sub { _ANSI_SEQ->("\e[1;35m", @_) }, # purple
    BCYAN       => sub { _ANSI_SEQ->("\e[1;36m", @_) }, # cyan
    BWHITE      => sub { _ANSI_SEQ->("\e[1;37m", @_) }, # white
    # underline
    UBLACK      => sub { _ANSI_SEQ->("\e[4;30m", @_) }, # black
    URED        => sub { _ANSI_SEQ->("\e[4;31m", @_) }, # red
    UGREEN      => sub { _ANSI_SEQ->("\e[4;32m", @_) }, # green
    UYELLOW     => sub { _ANSI_SEQ->("\e[4;33m", @_) }, # yellow
    UBLUE       => sub { _ANSI_SEQ->("\e[4;34m", @_) }, # blue
    UPURPLE     => sub { _ANSI_SEQ->("\e[4;35m", @_) }, # purple
    UCYAN       => sub { _ANSI_SEQ->("\e[4;36m", @_) }, # cyan
    UWHITE      => sub { _ANSI_SEQ->("\e[4;37m", @_) }, # white
    # background
    ON_BLACK    => sub { _ANSI_SEQ->("\e[40m", @_) }, # black
    ON_RED      => sub { _ANSI_SEQ->("\e[41m", @_) }, # red
    ON_GREEN    => sub { _ANSI_SEQ->("\e[42m", @_) }, # green
    ON_YELLOW   => sub { _ANSI_SEQ->("\e[43m", @_) }, # yellow
    ON_BLUE     => sub { _ANSI_SEQ->("\e[44m", @_) }, # blue
    ON_PURPLE   => sub { _ANSI_SEQ->("\e[45m", @_) }, # purple
    ON_CYAN     => sub { _ANSI_SEQ->("\e[46m", @_) }, # cyan
    ON_WHITE    => sub { _ANSI_SEQ->("\e[47m", @_) }, # white
    # high-intensity
    IBLACK      => sub { _ANSI_SEQ->("\e[0;90m", @_) }, # black
    IRED        => sub { _ANSI_SEQ->("\e[0;91m", @_) }, # red
    IGREEN      => sub { _ANSI_SEQ->("\e[0;92m", @_) }, # green
    IYELLOW     => sub { _ANSI_SEQ->("\e[0;93m", @_) }, # yellow
    IBLUE       => sub { _ANSI_SEQ->("\e[0;94m", @_) }, # blue
    IPURPLE     => sub { _ANSI_SEQ->("\e[0;95m", @_) }, # purple
    ICYAN       => sub { _ANSI_SEQ->("\e[0;96m", @_) }, # cyan
    IWHITE      => sub { _ANSI_SEQ->("\e[0;97m", @_) }, # white
    # bold high-intensity
    BIBLACK     => sub { _ANSI_SEQ->("\e[1;90m", @_) }, # black
    BIRED       => sub { _ANSI_SEQ->("\e[1;91m", @_) }, # red
    BIGREEN     => sub { _ANSI_SEQ->("\e[1;92m", @_) }, # green
    BIYELLOW    => sub { _ANSI_SEQ->("\e[1;93m", @_) }, # yellow
    BIBLUE      => sub { _ANSI_SEQ->("\e[1;94m", @_) }, # blue
    BIPURPLE    => sub { _ANSI_SEQ->("\e[1;95m", @_) }, # purple
    BICYAN      => sub { _ANSI_SEQ->("\e[1;96m", @_) }, # cyan
    BIWHITE     => sub { _ANSI_SEQ->("\e[1;97m", @_) }, # white
    # high-intensity background
    ON_IBLACK   => sub { _ANSI_SEQ->("\e[0;100m", @_) }, # black
    ON_IRED     => sub { _ANSI_SEQ->("\e[0;101m", @_) }, # red
    ON_IGREEN   => sub { _ANSI_SEQ->("\e[0;102m", @_) }, # green
    ON_IYELLOW  => sub { _ANSI_SEQ->("\e[0;103m", @_) }, # yellow
    ON_IBLUE    => sub { _ANSI_SEQ->("\e[0;104m", @_) }, # blue
    ON_IPURPLE  => sub { _ANSI_SEQ->("\e[10;95m", @_) }, # purple
    ON_ICYAN    => sub { _ANSI_SEQ->("\e[0;106m", @_) }, # cyan
    ON_IWHITE   => sub { _ANSI_SEQ->("\e[0;107m", @_) }, # white
  );

my $fileno_stdin = fileno(STDIN);
my $posix_termio = POSIX::Termios->new;
$posix_termio->getattr($fileno_stdin);

my $FLAGS_TERM   = $posix_termio->getlflag;
my $FLAGS_ECHO   = ECHO | ECHOK | ICANON;
my $NO_ECHO      = $FLAGS_TERM & ~$FLAGS_ECHO;

sub _pout($$)
{
  my ($fh, $data) = @_;

  printf $fh "%s%s", $_, $/ || "" for @{$data};
}

sub _shift_filehandle($$)
{
  # $_[0]: default value
  # $_[1]: array reference
  my ($default, $data) = @_;

  my ($handle) = @{$data};

  # prepend the default value onto the array if it's first element is not a
  # file handle
  unshift @{$data}, $default
    unless defined $handle and defined openhandle $handle;

  # remove and return the first element of the array
  shift @{$data};
}

sub   pout(@) { _pout _shift_filehandle(*STDOUT, \@_), [ map { sprintf "%s",                          $_ } @_ ] }
sub   perr(@) { _pout _shift_filehandle(*STDERR, \@_), [ map { sprintf "%s",                          $_ } @_ ] }
sub  sinfo(@) { _pout _shift_filehandle(*STDOUT, \@_), [ map { sprintf "%s %s", $_OUTSYM[_OUT_INFO],  $_ } @_ ] }
sub  swarn(@) { _pout _shift_filehandle(*STDERR, \@_), [ map { sprintf "%s %s", $_OUTSYM[_OUT_WARN],  $_ } @_ ] }
sub serror(@) { _pout _shift_filehandle(*STDERR, \@_), [ map { sprintf "%s %s", $_OUTSYM[_OUT_ERROR], $_ } @_ ] }
sub   ohno(@) { serror @_; quit 1 }
sub  final(@) { perr @_; quit }

sub _convert_args(@)
{
  # the first argument must be a format string
  my ($format) = shift;

  # if the following arguments are array references, then process them through
  # sprintf individually (this is for multi-line output messages)
  if (0 < @_ and arrayref $_[0])
  {
    map { sprintf $format, grep { not coderef } @{$_} } @_;
  }
  # otherwise, the remaining arguments are simply the arguments to sprintf
  else
  {
    sprintf $format, grep { not coderef } @_;
  }
}

sub   poutf(@) {   pout _convert_args @_ }
sub   perrf(@) {   perr _convert_args @_ }
sub  sinfof(@) {  sinfo _convert_args @_ }
sub  swarnf(@) {  swarn _convert_args @_ }
sub serrorf(@) { serror _convert_args @_ }
sub   ohnof(@) {   ohno _convert_args @_ }
sub  finalf(@) {  final _convert_args @_ }

sub qclr($@)
{
  # first arg is arrayref of sequence names to apply in-order:
  #   clr(["on_green", "red"], "...") will place red text on green background
  my ($sref, @text) = @_;

  my @seq = grep { exists $ANSI_SEQ{$_} } map { uc } @{$sref};

  @text = $ANSI_SEQ{$_}->(@text) for @seq;

  (@text > 1) ? @text : shift @text
}

sub clr($@)
{
  #my ($sref) = shift;
  qclr([@{(shift)}, "reset"], @_);
}

sub _cbreak
{
  $posix_termio->setlflag($NO_ECHO);
  $posix_termio->setcc(VTIME, 1);
  $posix_termio->setattr($fileno_stdin, TCSANOW);
}

sub _cooked
{
  $posix_termio->setlflag($FLAGS_TERM);
  $posix_termio->setcc(VTIME, 0);
  $posix_termio->setattr($fileno_stdin, TCSANOW);
}

sub readkey
{
  my $key = "";
  _cbreak;
  sysread(STDIN, $key, 1);
  _cooked;
  $key
}

sub readln(@)
{
  my ($handle) = _shift_filehandle *STDIN, \@_;
  my ($in) = <$handle>;

  chomp $in;

  $in
}

sub confirm(&&)
{
  my ($prompt, $handle) = @_;

  # readkey does some funky things with the terminal, so be sure
  # to flush it immediately on every write
  local $| = 1;
  $prompt->();
  $handle->(readkey);
}

END
{
  _cooked
}

1;
