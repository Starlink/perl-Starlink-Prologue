package Starlink::Prologue::Parser::ADAMSSE;

=head1 NAME

Starlink::Prologue::Parser::ADAMSSE - Standard Starlink prologue parser

=head1 SYNOPSIS

  use Starlink::Prologue::Parser::ADAMSSE;

  $p = new Starlink::Prologue::Parser::ADAMSSE();

  for my $l (@lines) {
    my $status = $p->push_line( $l );
  }

=head1 DESCRIPTION

This class is responsible for parsing source code and creating
C<Starlink::Prologue> objects.  It only knows how to parse old-style
ADAM/SSE prologues.

=cut

use 5.006;
use strict;
use warnings;
use Carp;

use Starlink::Prologue;
use base qw/ Starlink::Prologue::Parser::Base /;

=head1 METHODS

=head2 Constructor

=over 4

=item B<new>

Create a new ADAM/SSE parser

  $p = new Starlink::Prologue::Parser::ADAMSSE();

=back

=head2 Accessors

For a list of generic accessors see C<Starlink::Prologue::Parser::Base>.

=head2 General

Also see C<Starlink::Prologue::Parser::Base>.

=over 4

=item B<push_line>

Add a new line of content to the parser. Since some prologues are only
terminated when the first line of code is discovered, it is sometimes
necessary to return both a line of code and the relevant
C<Starlink::Prologue> prologue object. The C<push_line> method returns
the line itself if the line is not part of a prologue, and/or a
prologue object if the prologue is terminated by this line.

  ($line, $prologue) = $parser->push_line;

=cut

sub push_line {
  my $self = shift;
  my $line = shift;

  my $prl = $self->prologue;
  if (defined $prl) {
    # currently active prologue
    my $cchar = $prl->comment_char;
    my $r = quotemeta( $cchar );

    # now need to parse the line. We have the following cases:
    # - start of section (* Section :)
    # - content (*  XXXX)
    # - blank line (*   )
    # - blank line (    )
    # - Terminator section, eg. Type Definitions :
    # - terminator (*-) if we are too late

    # The complication is that the *- completes the
    # variable definition section but the prologue that
    # interests Starlink::Prologue does not include variable
    # definitions.

    # Real code can not be a terminator s
    
    #
    # blank lines are treated as content unless they are
    #   before a section.
    # programmatic content in a modern prologue indicates
    #   that the prologue finished prematurely.

    chomp($line);
    if ( $line =~ /^\s*[$r]\s+Type Definitions\s*:$/i
	 || $line =~ /^\s*[$r]\s+Global constants\s*:$/i
	 || $line =~ /^\s*[$r]\s+Import\s*:$/i
	 || $line =~ /^\s*[$r]\s+Export\s*:$/i
	 || $line =~ /^\s*[$r]\s+Status\s*:$/i
	 || $line =~ /^\s*[$r]\-\s*$/  #   *- but usually too late
       ) {
      print "End of prologue detected\n";
      # end of prologue so flush the current section
      $self->flush_section();

      # undefine the internal copy
      $self->prologue( undef );

      # we must return the line unless it was the *-
      my $retval;
      $retval = $line unless $line =~ /^\s*[$r]\-\s*$/;

      # return the newly minted version
      return ($retval, $prl);

    } elsif ( $line =~ /^\s*[$r]\s+([A-Za-z\s]*)\s*:\s*$/ ) {
      # section start
      $self->flush_section();

      my $section = $1;
      $section =~ s/\s+$//;

      # need to rename some sections
      if ($section =~ /^Parameters$/i) {
	$section = 'Arguments';
      }
      $self->section( $section );
    } elsif ( $line =~ /^\s*[$r](\s+.*)\s*$/ ) {
      # prologue content (or *- but that is dealt with above)
      # Include leading spaces since we want to retain indenting
      # strip off the first 5 spaces (standard formatting)
      my $content = $1;
      $content =~ s/^\s{2,5}//;

      # special case endhistory
      if ($self->section() eq 'History' &&
	  $content =~ /^\s*endhistory\s*$/i) {
	$self->flush_section();
      }

      push(@{$self->content()}, $content);
    } else {
      # if nothing matches we have a blank line
      # we should store it in case it is within a section
      my $content = $line;
      $content =~ s/^\s+//;
      $content =~ s/\s+$//;
      $content = '' if $content =~ /^$r$/;
      push(@{$self->content()}, $content);

    }

  } else {
    # looking for one to start
    my ($cchar, $title, $purpose) = $self->prolog_start( $line );
    if (defined $cchar) {
      chomp($line);
      print "Starting prologue with comment char $cchar ($line)\n";
      # a new prologue is starting
      $prl = new Starlink::Prologue();
      $self->prologue( $prl );
      $prl->comment_char( $cchar );
      $prl->start_c_comment( 0 );

      # we should always have this
      if (defined $title) {
	$prl->name( $title );
      }

      if (defined $purpose) {
	$prl->purpose( $purpose );
      }


      # inside a prolog so return nothing
      return ();

    } else {
      # not interested
      return ($line, undef);
    }

  }

}

=head2 Class Methods

=over 4

=item B<prolog_start>

Returns true if the line supplied could be interpreted as a
start of a prolog. Otherwise returns false.

 $is_start = $p->prolog_start( $line );

In list context returns the comment character (usually a '*'),
the name of the routine and the purpose (which should all be on a
single line).

 ($cchar, $title, $purpose) = $p->prolog_start( $line );

=cut

sub prolog_start {
  my $self = shift;
  my $line = shift;
  my $cchar;
  my $title;
  my $purpose;
  if ($line =~ /^\s*([\*\#])\+\s*([\w_\d]+)\s*-\s*(.*)\s*$/) {
     # Normal prologue start :  *+ title - purpose
     $cchar = $1;
     $title = $2;
     $purpose = $3;
  }

  # title is mandatory
  if (defined $cchar && defined $title ) {
    if (wantarray) {
      return ($cchar, $title, $purpose);
    } else {
      return 1;
    }
  }
  return ();
}

=back

=head1 NOTES

This class is a subclass of C<Starlink::Prologue::Parser::Base>

=head1 SEE ALSO

C<Starlink::Prologue::Parser::Base>

=head1 AUTHOR

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

Copyright 2006 Particle Physics and Astronomy Research Council.
All Rights Reserved.

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful,but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 59 Temple
Place,Suite 330, Boston, MA  02111-1307, USA

=cut

1;
