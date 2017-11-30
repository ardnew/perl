package ardnew::Files;

#
# MODULE: Files
# AUTHOR: Andrew Shultzabarger
#
# 1. subroutines for manipulating file paths and file names
#
#   - separator: returns the current system file path separator
#   - abspath: returns the absolute path of file(s)
#   - realpath: like abspath, but returns the physical path (collapse symlinks)
#   - catpath: joins strings using the system path separator
#   - dirname: extracts the directory portion from file path(s)
#   - basename: extracts the file name portion from file path(s)
#   - fileext: extracts the right-most file extension from file path(s)
#   - rmfileext: removes the right-most file extension from file path(s)
#   - splitpath: separates components of path(s) into array elements
#
# 2. subroutines for manipulating files and filesystems
#
#   - slurp: stuffs the contents of an entire file into scalar variable
#   - memfh: creates a read-write handle (clobbered) for an "in-memory file"
#   - tmpdir: creates a temp directory that will be deleted on scope exit
#   - tmpfh: creates a temp file that will be deleted on program exit
#   - rmr: deletes a directory and its contents recursively, like unix "rm -rf"
#   - mv: moves file from location to another, like unix "mv"
#   - forcedir: creates a hierarchy of directories, like unix "mkdir -p"
#
# 3. subroutines for traversing a filesystem
#
#   - walk: walks directory trees performing some operation on each file
#   - sift: walks directory trees locating files whose names match a pattern
#   - bury: inversion of sift (file names that do NOT match a pattern)
#   - sifti: case-insensitive variation of sift
#   - buryi: case-insensitive variation of bury
#
#   the primary traversal routine walk is called with a coderef and list of
#   paths to traverse. the coderef is called for each file encountered (*as it
#   is encountered*), and the body of the sub should use $_ to refer to the file
#   encountered.
#
#   the search routines are called with only a regex pattern and a list of
#   paths to traverse. these call walk with a coderef that merely prints the
#   appropriate file names when encountered.
#

use strict;
use warnings;

my (@export_local);

BEGIN
{
  require Exporter;

  our $VERSION   = 0.001;
  our @ISA       = qw| Exporter |;

  @export_local = # ardnew::Files
    qw| separator abspath realpath catpath dirname basename fileext rmfileext splitpath slurp memfh tmpfh tmpdir rmr forcedir walk sift bury sifti buryi |;

  our @EXPORT_OK   = (@export_local);
  our %EXPORT_TAGS =
    (
      all   => \@EXPORT_OK,
      local => \@export_local,
    );
}

use ardnew::IO qw| :all |;
use ardnew::Util qw| :all |;

use File::Spec;
use File::Find;
use File::Temp;
use File::Copy qw| move |;
use File::Path qw| make_path rmtree |;
use Cwd;

sub separator() { File::Spec->catfile(q||, q||) }

sub abspath(@) { File::Spec->rel2abs((topic @_), q||) }

sub realpath(@) { Cwd::realpath(topic @_) }

sub catpath(@)
{
  return unless scalar @_ > 0;

  my $path = shift;

  $path = File::Spec->catfile($path, $_) while $_ = shift @_;

  File::Spec->canonpath($path)
}

sub dirname(@)
{
  my ($dir) = File::Spec->canonpath(topic @_);
  (undef, $dir, undef) = File::Spec->splitpath($dir);

  File::Spec->canonpath($dir)
}

sub basename(@)
{
  my ($file) = File::Spec->canonpath(topic @_);
  (undef, undef, $file) = File::Spec->splitpath($file);

  File::Spec->canonpath($file)
}

sub fileext(@)
{
  my ($ext) = File::Spec->canonpath(topic @_);
  (undef, undef, $ext) = File::Spec->splitpath($ext);

  # don't continue if the name contains no periods or if only one period exists
  # and its the first symbol (hidden files)
  return "" if $ext =~ /^\.?[^.]+$/;

  $ext =~ s/^.*(\.[^.]*)$/$1/;
  $ext
}

sub rmfileext(@)
{
  my ($file) = File::Spec->canonpath(topic @_);
  my ($ext)  = quotemeta fileext $file;

  $file =~ s/$ext$//;
  $file
}

sub splitpath(@)
{
  my ($volume, $directories, $name) = File::Spec->splitpath(topic @_);

  grep { (length) } ($volume, File::Spec->splitdir($directories), $name)
}

sub slurp(@)
{
  my ($filepath) = topic @_;
  my ($fh);

  unless (open $fh, "<", $filepath)
  {
    serror "cannot open file '$filepath': $!";
    return;
  }

  do { local $/; <$fh> }
}

sub memfh(@)
{
  my ($reference) = topic @_;
  my ($fh);

  unless (0 < length ref $reference)
  {
    serror "argument value is not a reference";
    return;
  }

  unless (open $fh, "+>", $reference)
  {
    serror "cannot create in-memory file: $!";
    return;
  }

  $fh
}

sub tmpdir
{
  File::Temp->newdir
}

sub tmpfh
{
  my (undef, $template) = map { basename } @{frame(1)};
  $template =~ s/[^A-Z0-9_]+/-/ig;
  $template .= '-XXXX';

  my ($fh) = File::Temp->new(
    TEMPLATE => $template,
    DIR      => tmpdir,
    UNLINK   => 1,
    SUFFIX   => '.tmp');
  $fh->unlink_on_destroy(1);

  ($fh, $fh->filename)
}

sub rmr(@)
{
  for (@_)
  {
    rmtree($_) if not -l and -d _
  }
}

sub mv($$)
{
  my ($src, $dst) = @_;

  unless (-e $src)
  {
    serror "source file does not exist: $src";
    return;
  }

  move($src, $dst);
}

sub forcedir(@)
{
  for (@_)
  {
    make_path($_, { chmod => 0755, })
  }
}

sub walk(&@)
{
  my ($proc) = shift;

  # use PWD if no path specified
  push @_, abspath q|.| unless @_ > 0;

  # see File::Find docs for an overview of each of these options
  my %options =
  (
    wanted            => $proc, # takes no arguments, file to be inspected is $_
    bydepth           => 0,
    preprocess        => undef,
    postprocess       => undef,
    follow            => 0,
    follow_fast       => 0,
    follow_skip       => 1,
    dangling_symlinks => 0,
    no_chdir          => 1,
    untaint           => 0,
    #untaint_pattern   => # do not override, use default
    #untaint_skip      => # do not override, use default
  );

  find(\%options, @_);
}

sub _walk_find($$$@)
{
  my ($pattern, $caseinsensitive, $positive, @path) = @_;

  return unless
    defined $pattern and
    defined $caseinsensitive and
    defined $positive;

  our $_pattern = $caseinsensitive ? qr|$pattern|i : qr|$pattern|;

  if ($positive) { walk sub { $_ =~ $_pattern and print }, @path }
            else { walk sub { $_ !~ $_pattern and print }, @path }
}

sub sift($@)  { _walk_find shift, 0, 1, @_ }
sub bury($@)  { _walk_find shift, 0, 0, @_ }
sub sifti($@) { _walk_find shift, 1, 1, @_ }
sub buryi($@) { _walk_find shift, 1, 0, @_ }

END
{
  ;
}

1;
