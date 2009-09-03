# We need to test our newfangled "page repo" code.

do 'common.pl';
do 'pages.pl';

# override env var, just to make things easier
$pagedir = "newpages";

$name = "Arm_Development_Board";
my %p;

# get and show a page
sub show {
    %p = get_page($name);
    print "$p{'exists'} $p{'modtime'} $p{'name'}\n";
    my $len = length $p{'text'};
    my $snippet = substr($p{'text'}, 0, 32);
    print "   $len $snippet\n";
    foreach my $key (sort keys %p) {
        print "   $key=$p{$key}\n" unless $key =~ m/name|text|modtime|exists/;
    }
}

show();
$p{'tags'} = "microcontrollers ARM hardware development";
$p{'editcomment'} = "testing the page code";
put_page(%p);

%p = get_page($name);
show();
$p{'editcomment'} = "";
put_page(%p);
show();
delete $p{'editcomment'};
put_page(%p);
show();

# should be a page we just created
#delete_page();

