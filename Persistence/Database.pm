#!/usr/bin/perl -I..
##
## Persistence::Database -- Persistent Database. 
##
## $Date: 1999/01/16 23:19:01 $
## $Revision: 0.11 $
## $State: Exp $
## $Author: root $
##
## Copyright (c) 1998, Vipul Ved Prakash.  All rights reserved.
## This code is free software; you can redistribute it and/or modify
## it under the same terms as Perl itself.

package Persistence::Database; 
use Persistence::Object::Simple; 
use Data::Dumper; 
use Carp; 

@ISA = qw( Persistence::Object::Simple ); 
( $VERSION )  = '$Revision: 0.11 $' =~ /\s(\d+\.\d+)\s/;  

sub new { 

	my ( $class, %args ) = @_;
	my ( $id ); 
	my $table = $args{ Table };
	my $self = {}; 

	croak "Table $table doesn't exist." unless -d $table; 

	if ( $args{ Id } ) { 
		$id = $args{ Id };  
		$self = $class->SUPER::new ( __Fn => "$table/$id" ); 
		$self->{ Id  } =  $id;
		return $self; 
	}

	$self->{ Table } = $table; 
	return bless $self, $class; 

} 

sub search { 

	my ( $self, $key, $regex ) = @_; 
	my $class = ref $self;
	my $table = $self->{ Table }; 
	my @found; 
	$key =~ s/^(.)/uc $1/e; 

	croak "Unidentified Id." unless $table; 

	opendir( GROUP, $table ) || croak "Unidentified Table: $table.";
    my @users = grep { !(-d "$table/$_") }  readdir( GROUP );
	closedir GROUP; 

	for ( @users ) { 
		my $user = $class->new ( Id => $_ , Table => $table ); 
		my $data = $user->{ $key }; 
		push @found, $user if $data =~ /$regex/;
	}

	return \@found; 

}

sub commit { 

	my ( $self ) = @_; 
	return $self->SUPER::commit (); 

} 

sub load  { 

	my ( $class, %args ) = @_; 
	my $object = $class->SUPER::load ( %args );
	return $object; 

}


sub AUTOLOAD { 

	my ( $self, $value ) = @_; 

 	my $key = $AUTOLOAD;  $key =~ s/.*://;
	$key =~ s/^(.)/uc $1/e; 

	if ( $value ) { 
		$self->{ $key } = $value; 
		$self->commit ();
	}

	return $self->{ $key }; 

}


'True Value'


