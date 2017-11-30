package ardnew::Util;

#
# MODULE: Util
# AUTHOR: Andrew Shultzabarger
#
# 1. subroutines for debugging
#
#   - frame: returns array ref containing info of specified frame in callstack
#   - callstack: returns an array representing the current callstack
#   - bt: prints the callstack in a nice graphical format
#
# 2. misc. utility subroutines
#
#   - quit: quietly terminate with non-error-default return value
#   - topic: return actual args if provided, otherwise return $_
#   - trim: remove surrounding whitespace from scalar variables
#   - scalarref, arrayref, hashref, coderef, regexref: true if arg is ref type
#   - looksint: returns a truth value if the SV looks like an integer
#   - isint: returns a truth value if the SV is an integer
#   - isfloat: returns a truth value if the SV is a real number
#   - stringof: uses Data::Dumper to return a string representing the internal
#       structure of a variable
#   - now: returns the current datetime in format YYYY-MM-DD HH:MM:SS
#   - nowfs: returns the current datetime in format YYYY-MM-DD__HH-MM-SS, safe
#       for most filesystems
#

use strict;
use warnings;

my (@export_local, @export_memoize, @export_data_dumper);

BEGIN
{
  require Exporter;

  our $VERSION   = 0.001;
  our @ISA       = qw| Exporter |;

  @export_local = # ardnew::Util
    qw| frame callstack bt quit topic trim scalarref arrayref hashref coderef regexref looksint isint isfloat stringof now nowfs |;

  @export_memoize = # Memoize
    qw| memoize |;

  @export_data_dumper = # Data::Dumper
    qw| Dumper |;

  our @EXPORT_OK   = (@export_local, @export_memoize);
  our %EXPORT_TAGS =
    (
      all     => \@EXPORT_OK,
      local   => \@export_local,
      memoize => \@export_memoize,
    );
}

use ardnew::IO qw| :all |;
use ardnew::Lists qw| :all |;

use Memoize @export_memoize;
use Data::Dumper @export_data_dumper;

use Scalar::Util qw| looks_like_number |;
use POSIX;

use constant
  {
    _EXIT_OK    => 0,
    _EXIT_ERROR => 1,
  };

sub quit(@) { exit (@_ > 0 and looks_like_number($_ = shift) ? $_ : _EXIT_OK) }

sub topic(@) { 0 < scalar @_ ? ( wantarray ? @_ : shift ) : $_ }

sub trim(@) { local @_ = @_; for (@_) { s/^\s+//; s/\s+$//; } (0 < scalar @_) ? @_ : shift }

sub _null { }

sub _format_frame($) { sprintf "%s @ %s:%d", @{$_} }

sub frame($)
{
  if (any { (defined) } (@_ = caller(shift)))
  {
    my ($pack, $file, $line, $subr, $args, $arry,
        $eval, $ireq, $hint, $mask, $hash) = @_;

    # returns array ref [ "pkg::subroutine", "file name", "line number" ]
    [ $subr, $file, $line ];
  }
}

sub callstack()
{
  my @trace = ();

  unshift @trace, $_ while $_ = frame(scalar @trace);

  @trace;
}

sub bt()
{
  use constant { _INDENT => "  " };

  @_ = map { _format_frame $_ } callstack;

  # for the graphical output, don't display the calls we make in order to
  # generate the callstack (since they are just incidental to the actual intent
  # of this subroutine).
  # that means i'm removing the last 2 elements from the following chain:
  #   ... -> bt() -> callstack() -> frame()
  splice(@_, -2);

  # filthy hack note: the postfix "++" affects $depth from within the context of
  # printf, but its value as argument to "x" is pre-increment. so the values
  # of $depth here might be counter-intuitive to what you'd initially expect.
  my ($depth) = 0;
  perrf "[%d] %s%s", map {[ $depth, _INDENT x $depth++, $_ ]} @_;
}

sub scalarref(@) { all { (ref($_)) eq "SCALAR" } topic @_ }
sub  arrayref(@) { all { (ref($_)) eq "ARRAY"  } topic @_ }
sub   hashref(@) { all { (ref($_)) eq "HASH"   } topic @_ }
sub   coderef(@) { all { (ref($_)) eq "CODE"   } topic @_ }
sub  regexref(@) { all { (ref($_)) eq "Regexp" } topic @_ }

sub looksint(@)
{
  my ($value) = topic @_;

  # excludes ANY value with a decimal point (e.g. "1.", "1.0", ...)
  0 > index $value, '.' and isint $value
}

sub isint(@)
{
  my ($value) = topic @_;

  # includes integers that contain a decimal point (e.g. "1.", "1.0", ...)
  looks_like_number $value and int($value) == $value
}

sub isfloat(@)
{
  my $value = topic @_;

  looks_like_number $value
}

sub _datadumper_context(&)
{
  # localizes a set of options for Data::Dumper before returning the evaluated
  # code ref passed in as argument

  local $Data::Dumper::Indent        = 2; # use 3 to include array indices
  local $Data::Dumper::Trailingcomma = 1;
  local $Data::Dumper::Purity        = 1; # emits additional info about assumed behavior
  local $Data::Dumper::Pad           = "";
  local $Data::Dumper::Varname       = " --- ";
  local $Data::Dumper::Useqq         = 1;
  local $Data::Dumper::Terse         = 1;
  local $Data::Dumper::Quotekeys     = 1;
  local $Data::Dumper::Pair          = "=> "; # hash key-value separator
  local $Data::Dumper::Maxdepth      = 0; # unlimited
  local $Data::Dumper::Maxrecurse    = 0; # unlimited
  local $Data::Dumper::Useperl       = 0; # use XS (C implementation) if possible
  local $Data::Dumper::Sortkeys      = 1; # see perldoc, can also be a sub to filter hashes
  local $Data::Dumper::Deparse       = 1; # use B::Deparse to turn sub refs into source code
  local $Data::Dumper::Sparseseen    = 0;

  (shift)->()
}

sub stringof(@)
{
  my (@object) = topic @_;

  return unless scalar @object > 0;

  _datadumper_context { Dumper(\@object) }
}

sub now
{
  strftime "%F %T", localtime $^T
}

sub nowfs
{
  $_ = strftime "%F__%T", localtime $^T;
  s/[^\d_]/-/g; $_
}

END
{
  ;
}

1;
