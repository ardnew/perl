package ardnew::Lists;

#
# MODULE: Lists
# AUTHOR: Andrew Shultzabarger
#
# 1. subroutines for operating on a discrete set or list of elements:
#
#   - unique: remove duplicate items from a list (preserves ordering)
#   - permute: permutations enumerator
#   - combine: combinations enumerator
#
#   the enumerator functions are called with a coderef used to handle each
#   element generated (*as it is generated*) followed by the list of elements.
#   the coderef will receive a list of elements in @_ containing the current
#   permutation.
#

use strict;
use warnings;

my (@export_local, @export_list_util);

BEGIN
{
  require Exporter;

  our $VERSION   = 0.001;
  our @ISA       = qw| Exporter |;

  @export_local = # ardnew::Lists
    qw| unique permute combine |; 

  @export_list_util = # List::Util
    qw| reduce first max maxstr min minstr sum shuffle |;

  { # the following subs are not implemented in older perls and are instead
    # implemented in this module if they aren't already defined in List::Utils
    require List::Util; 
    no strict 'refs';
    no warnings 'once';
    for (qw| any all none notall product sum0 |)
    {
      # symbol table hackery
      if (defined *{"List::Util::$_"}{CODE}) { push @export_list_util, $_ } 
      else { push @export_local, $_ ; *{"$_"} = \&{"_$_"} }
    }
  }

  our @EXPORT_OK   = (@export_local, @export_list_util);
  our %EXPORT_TAGS =
    (
      all       => \@EXPORT_OK,
      local     => \@export_local,
      list_util => \@export_list_util,
    );
}

use List::Util @export_list_util;

sub _permute_iterative
{
  my ($handler) = shift;
  my (@pattern) = 0 .. $#_;
  my ($p, $q);

  return unless 0 < @_;

  {
    $handler->(@_[@pattern]);

    $p = $#pattern;

    --$p while $pattern[$p - 1] > $pattern[$p];

    $q = $p or return;

    push @pattern, reverse splice @pattern, $p;

    ++$q while $pattern[$p - 1] > $pattern[$q];

    @pattern[$p - 1, $q] = @pattern[$q, $p - 1];

    redo;
  }
}

sub _permute_recursive
{
  my ($handler) = shift;
  my (@current) = @{(shift)};
  my (@residue) = @{(shift)};

  if (0 == @residue and 0 < @current)
  {
    $handler->(@current);
  }
  else
  {
    my (@stack) = ();
    
    while (my $element = shift @residue)
    {
      _permute_recursive($handler, [@current, $element], [@stack, @residue]);

      push @stack, $element;
    }
  }
}

sub _combine_complete
{
  my ($handler) = shift;
  my ($k)       = shift;

  return unless 0 < $k;
  return unless 0 < @_;

  my ($n) = scalar @_;

  return if $k > $n;

  for (my (@c, $i) = 0 .. $k - 1;;)
  {
    $handler->(map { $_[$_] } @c), $i = $k - 2;

    next if $c[$k - 1]++ < $n - 1;

    --$i while $i >= 0 && $c[$i] >= $n - ($k - $i);

    last if $i < 0;

    ++$c[$i];
    $c[$i] = $c[$i - 1] + 1 while ++$i < $k; 
  }
}

sub _combine_unique
{
  _combine_complete(unique(@_));
}

sub unique(@)
{
  my (%seen) = ();

  grep { not $seen{$_}++ } @_;
}

sub permute(&@)
{
  my ($handler) = shift;

  _permute_iterative($handler, @_);
  #_permute_recursive($handler, [], \@_);
}

sub combine(&$@)
{
  my ($handler) = shift;
  my ($k)       = shift;

  _combine_complete($handler, $k, @_);
  #_combine_unique($handler, $k, @_);
}

sub     _any(&@) { my $code = shift; reduce { $a ||   $code->(local $_ = $b) } 0, @_ }
sub     _all(&@) { my $code = shift; reduce { $a &&   $code->(local $_ = $b) } 1, @_ }
sub    _none(&@) { my $code = shift; reduce { $a && ! $code->(local $_ = $b) } 1, @_ }
sub  _notall(&@) { my $code = shift; reduce { $a || ! $code->(local $_ = $b) } 0, @_ }
sub _product     { reduce { $a * $b } @_ }
sub    _sum0     { reduce { $a + $b } 0, @_ }

END
{
  ;
}

1;
