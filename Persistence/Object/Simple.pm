#!/usr/bin/perl -s
##
## Persistence::Object::Simple -- Persistence For Perl5 Objects. 
##
## $Date: 1999/04/04 14:37:07 $
## $Revision: 0.34 $
## $State: Exp $
## $Author: root $
##
## Copyright (c) 1998, Vipul Ved Prakash.  All rights reserved.
## This code is free software; you can redistribute it and/or modify
## it under the same terms as Perl itself.

package Persistence::Object::Simple; 
use Data::Dumper; 
use Carp; 
use Fcntl; 
use vars qw( $VERSION ); 


# -- Module Version. 
( $VERSION )  = '$Revision: 0.34 $' =~ /\s+(\d+\.\d+)\s+/;  

# -- The default Directory Of Persistent Entities. 
my $DOPE      = "/tmp";   
my $MAXTRIES  = 250; 

sub dope { 

    my ( $self, $dope ) = @_; 
    ${ $self->{ __DOPE } } = $dope if $dope; 
    ${ $self->{ __DOPE } };

}

sub new { 
    
    my ( $class, %args ) = @_; 
    my $self = {}; 
    my $fn = $args{ __Fn }; 

    unless ( $fn ) { 
        my $dir = $args{ __Dope } || $DOPE; 
        $fn = $class->uniqfile ( $dir ); 
        return undef unless $fn;
    }

    $self->{ __Fn } = $fn; 
    $self->{ __DOPE } = \$DOPE; 

    my $existing = $class->load ( __Fn => $fn ); 
    $self = $existing if $existing; 

    for ( keys %args ) { $self->{ $_ } = $args{ $_ } } 

    bless $self, $class; 

} 

sub dumper { 

    my $self = shift; 

    $self->{ __Dumper } = new Data::Dumper ( [ $self ] ); 
    return $self->{ __Dumper }; 

}

sub commit { 

    my ( $self, %args ) = @_; 
    my ( $d, $fn );
    $fn = $args{ __Fn }  || $self->{ __Fn }; 

    if ( ref $self ) { 
        $d = $self->{ __Dumper } || $self->dumper () ;
    } else {  # -- Whoa! It's a class method!
        $d = new Data::Dumper ( [ $args{ Data } ] ); 
    } 

    # -- generate a temp filename for the class method call. 
    unless ( ref $self || $fn ) { 
        $args{ __Dope } = $DOPE unless $args{ __Dope };
        $fn = $class->uniqfile ( $args{ __Dope } );
    }

    if ( $args{ __Dope } ) { 
            $fn =~ s:.*/::; 
            $args{ __Dope } =~ s:/$::;
            $fn = $args{ __Dope } . "/$fn"; 
            croak "$fn exists. Can't overwrite." if -e $fn;
    }
    
    my $locked_fh = $self->{ __Lock }; 
    seek $locked_fh, 0, 0 if $locked_fh;
    my $fh; 

    # -- delete extra object data and class data-refs if this looks like 
    # -- an object. 
    if ( ref $self ) { 
        for ( keys %$self ) { delete $self->{ $_ } if /^__(?:Dumper|DOPE|Fn|Lock)/ }; 
    }

    unless ( $locked_fh ) { 
        open C, ">$fn" || croak "Can't open $fn for writing."; 
        flock C, 2; 
        $fh = *C{ IO }; 
    } 

    print { $locked_fh ? $locked_fh : $fh } $d->Dump (); 
    close $fh if $fh; 

    if ( ref $self ) { 
        $self->{ __Fn } = $fn; 
        $self->{ __Lock } = $locked_fh if $locked_fh; 
    #    $self->{ __Dumper } = $d; 
    }

    return $fn; 

} 

sub load { 

    my ( $class, %args ) = @_; 

    return undef unless -e $args{ __Fn };
    
    open C, $args{ __Fn } || croak "Couldn't open $args{ __Fn }."; 
    flock C, 2; 
    my @object = <C>; close C; 
    my $object = eval join '', @object;
    croak "Syntax Error in $args{ __Fn }" if $@; 
    $object->{ __Fn } = $args{ __Fn } if ref $object eq 'HASH';
    return $object; 

}

sub expire { 

    my ( $self ) = @_; 
    my $fn = $self->{ __Fn };

    return 1 if unlink $fn; 

} 

sub move { 

    my ( $self, %args ) = @_; 
    my   $class = ref $self; 

    $self->expire (); 
    my $fn = $self->commit ( %args ); 

    my $moved = $class->new ( __Fn => $fn ); 
    $self = $moved; 

}

sub lock { 

    my ( $self ) = @_; 

    my $fn = $self->{ __Fn }; 
	$self->commit unless -e $fn; 
    open ( F, "+<$fn" ) || croak "Couldn't open $fn for locking. Commit first!"; 
    flock F, 2; 
    $self->{ __Lock } = *F{ IO }; 

}

sub unlock { 

    my ( $self ) = @_; 
    $F = $self->{ __Lock }; 
    close $F; 
    undef $self->{ __Lock };
    
}

sub uniqfile { 

    my ( $class, $dir ) = @_; 
    my $fn; my $counter; 

    do { $fn = "@{[time]}.@{[int rand 2**8]}"; $counter++ }
        until sysopen ( C, "$dir/$fn" , O_RDWR|O_EXCL|O_CREAT ) or $counter > $MAXTRIES;
    close C; 
    
    return undef if $counter > $MAXTRIES;
    return "$dir/$fn";
}

'True Value';
__END__



=head1 NAME

Persistence::Object::Simple - Object Persistence with Data::Dumper. 

=head1 SYNOPSIS

  use Persistence::Object::Simple; 
  my $perobj = new Persistence::Object::Simple ( __Fn   => $path ); 
  my $perobj = new Persistence::Object::Simple ( __Dope => $directory ); 
  my $perobj = new Persistence::Object; 
  my $perobj->commit (); 


=head1 DESCRIPTION

P::O::S provides persistence functionality to its objects.  Object definitions
are stored as stringified perl data structures, generated with Data::Dumper,
that are amenable to manual editing and external processing from outside the
class interface.

Persistence is achieved with a blessed hash container that holds the object
data. The container can store objects that employ non-hash structures as
well. See L<"Inheriting Persistence::Object::Simple">, L<"Non-OO Usage"> and
the persistent list class example (examples/Plist.pm).

=head1 CONSTRUCTOR 

=over 4

=item B<new()>

Creates a new Persistent Object or retrieves an existing object definition.
Takes a hash argument with following possible keys:

=over 8

=item B<__Fn> 

Pathname of the file that contains the persistent object definition. __Fn is
treated as the object identifier and required at object retrieval.

=item B<__Dope> 

The Directory of Persistent Entities.  P::O::S generates a unique filename 
to store object data in the specified directory.  The object identifier is 
the complete pathname of the object's persistent image and is placed in the 
__Fn instance variable.  This argument is ignored when __Fn is provided.

=back 

=back 

=over 4

=item 

When new() is called without any arguments it uses a unique file in the 
default DOPE, "/tmp", to store the object definition. The default DOPE
can be altered with the dope() method. 

 $po = new Persistence::Object::Simple 
       ( __Fn => "/tmp/codd/suse5.2.codd" ); 

 # -- generates a unique filename  in /tmp/codd
 $po  = new Persistence::Object::Simple
       ( __Dope => "/tmp/codd" );     
 print $po->{ __Fn }; 

 # -- generates a unique filename in defalt dope (/tmp)
 $po  = new Persistence::Object::Simple; 
 print $po->{ __Fn }; 
       

=head1 METHODS

=over 4

=item B<commit()> 

Commits the object to disk.  Like new() it takes __Fn and __Dope arguments, 
but __Dope takes precedence.  When a __Dope is provided, the directory
portion of the object filename is ignored and the object is stored in the 
specified directory. 

    $perobj->commit (); 
    $perobj->commit (  __Fn   => $foo ); 
    $perobj->commit (  __Dope => $bar ); 



Commit() can also store non-object data refs. See L<"Non-OO Usage">. 

=item B<expire()> 

Irrevocably destructs the object.  Removes the persistent entry from the DOPE. 

    $perobj->expire (); 

If you want to keep a backup of the object before destroying it, 
use commit() to store in a different location. Undefing $obj->{ __Fn } 
before writing to the disk will force commit() to store the object in a 
unique file in the specified DOPE. 

    $perobj->{ __Fn } = undef; 
    $perobj->commit ( __Dope => "/tmp/dead" ); 
    $perobj->expire (); 

=item B<move()> 

Moves the object to a different DOPE. 

    $perobj->move ( __Dope => "/some/place/else" ); 

=item B<lock()> 

Gets an exclusive lock.  The owner of the lock can commit() without 
unlocking.  

    $perobj->lock (); 

=item  B<unlock()>

Releases the lock. 

    $perobj->unlock ();

=item B<dumper()> 

Returns the Data::Dumper instance bound to the object.  Should be called before
commit() to change Data::Dumper behavior.

    my $dd = $perobj->dumper (); 
    $dd->purity (1); 
    $dd->terse  (1);  # -- smaller dumps. 
    $perobj->commit (); 

See L<Data::Dumper>. 

=item B<load()> 

Class method that retrieves and builds the object.  Takes a filename argument. 
Don't call this directly, use new () for object retrieval. 
 
    Persistence::Object::Simple->load ( 
        __Fn => '/tmp/dope/myobject' 
    ); 


=back

=head1 Inheriting Persistence::Object::Simple

In most cases you would want to inherit this module.  It does not provide 
instance data methods so the object data functionality must be entirely 
provided by the inheriting module. Moreover, if you use your objects to 
store refs to class data, you'd need to bind and detach these refs at load() 
and commit().  Otherwise, you'll end up with a separate copy of class data 
with every object which will eventually break your code.  See L<perlobj>, 
L<perlbot>, and L<perltoot>, on why you should use objects to access class data. 

Persistence::Database inherits this module to provide a transparently persistent 
database class.  It overrides new(), load() and commit() methods.  There is no class data 
to bind/detach, but load() and commit() are overridden to serve as examples/templates
for derived classes.  Data instance methods, AUTOLOADed at runtime, automatically commit() 
when data is stored in Instance Variables.  For more details, Read The Fine Sources.  

=head1 Non-OO Usage

load() and commit() can be used for storing non-object references.  Here's 
a section from examples/pdataref: 

 @list = 0..100; 
 Persistence::Object::Simple::commit 
  ( undef, __Fn => '/tmp/datarefs/numbers', 
    Data => \@list; 
  ); 

 $list = Persistence::Object::Simple::load 
  ( undef, __Fn => '/tmp/datarefs/numbers' ); 

 $" = "\n"; print "@$list"; 

=head1 SEE ALSO 

Data::Dumper(3), 
Persistence::User(3), 
perl(1).

=head1 AUTHOR

Vipul Ved Prakash, mail@vipul.net

=head1 COPYRIGHT 

Copyright (c) 1998, Vipul Ved Prakash.  All rights reserved.
This code is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
 
