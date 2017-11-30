package ardnew::Iterators;

#
# MODULE: Iterators
# AUTHOR: Andrew Shultzabarger
#
# 1. subroutines for basic iterator construction and standard iterators
#
#   - iterator: syntactic sugar for replacing "sub{...}" with "iterator{...}"
#   - step: return the current value of an iterator and increment one time
#   - inc: return the current value of an iterator after calling step N times
#   - up: iterator for all integer values from N to +INF
#   - down: iterator for all integer values from N to -INF
#   - range: iterator for integer values in a given range
#   - cover: iterator for values of a given function for a given domain iterator
#
# 2. subroutines for specialized iterators
#
#   - filehandle: TBD
#   - unglob: generates all possible lists from a given list whose individual
#       elements may be chosen from a sublist of elements (see definition below)
#

use strict;
use warnings;

my (@export_local);

BEGIN
{
  require Exporter;

  our $VERSION   = 0.001;
  our @ISA       = qw| Exporter |;

  @export_local = # ardnew::Iterators
    qw| iterator step inc up down range cover unglob |;

  our @EXPORT_OK   = @export_local;
  our %EXPORT_TAGS =
    (
      all   => \@EXPORT_OK,
      local => \@export_local,
    );
}

use ardnew::Util qw| :all |;

sub iterator(&) { shift }

sub step(@) { @_ = map { $_->() } topic @_ ; wantarray ? @_ : shift }
sub inc($$)
{
  my ($iter, $count) = @_;
  my ($result) = undef;

  while ($count-- > 0 && ($result = step($iter))) {}

  $result
}

sub up($) { my ($n) = shift; iterator { $n++ } }
sub down($) { my ($n) = shift; iterator { $n-- } }
sub range($$) { my ($m, $n) = @_; iterator { $m <= $n ? $m++ : undef } }

sub cover(&$)
{
  my ($func, $iter) = @_;
  my ($x);

  iterator
  {
    ($x = step($iter)) ? $func->($x) : undef
  }
}

sub filehandle($) { my ($handle) = topic @_; iterator { <$handle> } }

sub unglob(@)
{
  # input is a list consisting of elements that are either scalar values or a
  # reference to an array containing scalar values. the array refs represent the
  # "wildcard" or choice-point elements from which each iteration will select
  # its next possible element.
  my @element = map { (arrayref) ? [ 0, @{$_} ] : $_ } @_;
  my $covered = 0;

  iterator
  {
    return if $covered;

    my @current = ();
    my $iterate = 1;

    for my $item (@element)
    {
      unless (arrayref $item)
      {
        push @current, $item;
      }
      else
      {
        my ($position, @choice) = @{$item};
        push @current, $choice[$position];

        if ($iterate)
        {
          ${$item}[0] = 0, next if $position == $#choice;
          ++${$item}[($iterate = 0)]; # just for funzies
        }
      }
    }
    $covered = $iterate;
    @current
  }
}

END
{
  ;
}

1;
