
BEGIN { $diagnostics::PRETTY = 1 }

package Pat::Logger;
our $VERSION = '1.3';

use strict;
use diagnostics;
use Fcntl ':flock';

use fields qw ( Debug_Log First_Message Separator );


# ------------------------
# subroutine declorations:
#-------------------------
sub new($);
sub new_stdout();
sub debug_message($);
sub separate();


sub _get_header();
sub _format_to_str($$$$);
sub _print_to_file($);
sub _get_debug_params();


# Global variables:
our $separator = "\n\n" . scalar ('-' x 152) . "\n\n";


# -----------------------------------------------------------------
# Name         : new() (constructor).
# Description  : Simple constructor that sets the unique_id value
# Recives      : File to hold all debugging messages.
# Returns      : FALSE/TRUE
# Algorithm    : Trivial.
# Dependencies : None.
# -----------------------------------------------------------------
sub new($)
{
    my ( $class, $debug_file ) = @_;
    my $self;

    # Validate  call to c'tor:
    die 'Bad call to constructor - check argument' unless defined $debug_file;
    

   
    # Bless object:    
    $self = fields::new $class;
    die "Can't create Logger object" unless defined $self;

    $self->{Debug_Log}	    = $debug_file;
    $self->{First_Message}  = 1;
    $self->{Separator}	    = $separator;



    return $self;
}



# -----------------------------------------------------------------
# Name         : new_stdout() (constructor).
# Description  : Simple constructor that sets the unique_id value
#		 that prints only to STDOUT.
# Recives      : Unique_id.
# Returns      : FALSE/TRUE
# Algorithm    : Trivial.
# Dependencies : None.
# -----------------------------------------------------------------
sub new_stdout()
{
    my $class = shift;
    my $self;

  
    # Bless object:    
    $self = fields::new $class; 
    die "Can't create Logger object" unless defined $self;

    $self->{First_Message} = 1;
    $self->{Separator}	   = $separator;

    return $self;    
}


# -----------------------------------------------------------------
# Name         : debug_message().
# Description  : Simple Debugging method, using Format.
# Recives      : 1st - Subroutine in which the message originated.
#                2nd - Body of debugging message.
# Returns      : Void.
# Algorithm    : Trivial.
# Dependencies : None.
# -----------------------------------------------------------------
sub debug_message($)
{
    
    my ($self, $message) = @_;
    my ($package, $sub, $line) ;
    my $debug_message = '';
    my $rc;

    
    # Bad call to method?
    unless ( defined $message )
    {
	return warn "No debug message defined";
    }

    chomp $message; #Just in case;        

    # In this part we gather all the information relevant for this debug message:
    ($package, $sub, $line) = $self->_get_debug_params();  


    # It's the first time we print a message, so let's create the headers:
    $debug_message  = $self->_get_header() if $self->{First_Message};

    
    $debug_message .= $self->_format_to_str( $package, $sub, $line, $message );
    
    
    $self->_print_to_file( $debug_message ) if defined $self->{Debug_Log};
    print $debug_message;
    

    return 1;    
}




sub _print_to_file($)
{
    my $self = shift;
    my $message = shift;
    
    # we are using a log file, so let's create a file handle to it:
    if (  defined $self->{Debug_Log} )
    {
	# Create File handle to log file:   
	if (! open (LOG, ">> $self->{Debug_Log}") )
	{
	    print "Can't open $self->{Debug_Log}: $!\n";
	    return 0;
	}
	else
	{
	    # We lock the file for security reasons:
	    flock LOG, LOCK_EX;
	    print LOG $message;
	    close LOG;
	}
	    
    }
    return 1; 
}



sub _get_header()
{
    my $self = shift;

    $self->{First_Message} = 0;
    
    my $headers = "
--------------------------------------------------------------------------------------------------------------------------------------------------------
 PACKAGE	METHOD		    	     LINE      MESSAGE
--------------------------------------------------------------------------------------------------------------------------------------------------------\n\n";

    return $headers;
}
     


sub separate()
{
    my $self = shift;

    $self->_print_to_file( $self->{Separator} ) if defined $self->{Debug_Log};
    print $self->{Separator};
    
    return 1; 
}   



sub _format_to_str( $$$$ )
{
    my $self = shift;
    my ( $package, $sub, $line, $message ) = @_;
    my $pid;
    my $result = '';
    my $separator = "\n\n" . scalar ('-' x 152) . "\n\n";

   

    $pid = open ( FILTER, '-|' );
    die "Can't fork $!" unless defined $pid;


    # father executes here:
    if ( $pid )
    {
	my $line_from_son = '';
	while ( defined ( $line_from_son = <FILTER> ) ) {
	    
	    $result .= $line_from_son;
	}
	waitpid( $pid, 0 );
	close FILTER;
    }


    else
    {
	

    # From here on it's the son, writing to filter:    

    
        my $str = '
    
	format STDOUT =
@<<<<<<<<<<<<<<<@<<<<<<<<<<<<<<<<<<<<<<<<<<<<@<<<<<<<<<@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
" $package",	$sub,  			     $line,    $message
.   
    write STDOUT;';

	#no warnings;
        eval $str;
	print STDOUT "$@\n" if $@;
	#print STDERR "Son $pid exiting\n";
	close STDOUT;
	exit;
    }

    return $result;    
}




sub _get_debug_params()
{
    my $self = shift;
    my ($package, $sub, $line);
    my @caller_param_1 = caller(1);
    my @caller_param_2 = caller(2);

    $package = $caller_param_1[0];
    $line    = $caller_param_1[2];

    my @package = ( split '::', $package );
    $package = $package[ $#package ];

    # Sub may be the main of a package (which will not show up in caller).
    if ( defined $caller_param_2[3] )
    {
	# if it's an eval, we have to see who called it.
	( $caller_param_2[3] =~ /eval/ ) ?  ( $sub = (caller(3))[3] ) : ( $sub = $caller_param_2[3] );
	
	$sub =~ s/^.*?::(.*)$/$1/;
    } else {
	 $sub = 'main';
    }

    my @subroutine = ( split '::', $sub );
    $sub = $subroutine[ $#subroutine ];


    return ($package, $sub, $line);
}


return 1;





__END__

=head1 NAME

 Pat::Logger - OO debugging tool which outputs logging messages in a nifty format.
               (Pat stands for Parogrammer Assisting Tools).

=head1 SYNOPSIS

=over

=item * Print messages to both STDOUT and a file:

=back
    
=head1

    use Pat::Logger;
    $debug_file = '/tmp/foo.log';
    eval { $logger = new Pat::Logger ( $debug_file ) };
    die $@ if $@;

    $logger->debug_message ( "Logger will tell you the package, subroutine and line number" );
    $logger->debug_message ( 'your debug message originated from' );

=over

=item * Print to STDOUT only:

=back

=head1

    use Pat::Logger;
    eval { $logger = new_stdout Pat::Logger() };
    die $@ if $@;

    $logger->debug_message ( "This line will go to STDOUT only" );
    $logger->separate;
    $logger->debug_message ( "This line is separated from the previous one" );

    
   

=head1 DESCRIPTION

    The Logger module is a nifty tool to organaize your debug messages.

    While writing your code you need a tool to output your debug messages.
    You want to see where the message originated from (which module, which subroutine and line number),
    so you can proceed directly to solving the matter, rather than search for it's location.
    Logger does just that.

    There are two working modes for Logger, each one has it's own constructor:

    (1) Debugging to STDOUT+file.
    (2) Debugging to STDOUT only.

=over

=item  * new($)

    This constructor expects a file name to output all message to.
    Upon success, a blessed hash reference will be returned.
    Upon failure the method dies, and $@ will hold the error message.


=item * new_stdout()

    All debug messages will be sent to STDOUT solemly.
    Upon success, a blessed hash reference will be returned.
    Upon failure the method dies, and $@ will hold the error message.
    

=item * debug_message($)

    This method takes one argument - the debug message you wish to log.
    Upon success - the method returns 1.
    Upon failre  - the method returns 0.
    
    The Logger object does all the work behind the scenes:
    (1) Grab the package, subroutine name and line number which the message originated from.
    (2) Create a nice format with the parameters aforementioned.
    (3) Output it according to object type.

=item * separate()

    You may wish to create visual separation between messages.
    When you invoke separate(), a line consistant of 152 x '-' will be outputed.

    This length is coherent with the length of the format.
 

=head1 BUGS

    None at the moment. 
    If you have any question or comment - pengas@cpan.org


=head1 COPYRIGHT

    Copyright 2001-2002, Pengas Nir

    This library is free software - you can redistribute 
    it and/or modify it under the same terms as Perl itself.


=cut
