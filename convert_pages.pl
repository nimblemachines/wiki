# a script to convert existing pages to a new format, where each page is a
# directory, and each file under that directory is an attribute.

do 'common.pl';
do 'pages.pl';

# override env var, just to make things easier
# this is the _dest_ directory; we'll be using put_page to write the new
# pages.
$pagedir = "newpages";
$oldpagedir = "oldpages";

sub run_svn {
    my @svn = ("$svn", @_);
    system(@svn) == 0 or die "can't run @svn: $!";
}

sub get_old_page {
    my ($pagename) = @_;
    my %page = (
        name        => "$pagename",
        exists      => 0,
        text        => "",
        modtime     => 0,
        editcomment => ""
    );
    my $f = "$oldpagedir/$pagename";
    if (-r "$f" && -f "$f") {
        $page{'exists'} = 1;
        $page{'text'} = read_file("$f");
        $page{'modtime'} = int(`svn pg modtime $f`);
        chomp($page{'editcomment'} = `svn pg editcomment $f`);
    }
    return %page;
}


sub doit {
    opendir PAGES, "$oldpagedir" or die "can't opendir $oldpagedir: $!";
    foreach my $pagename (grep { ! m/^\./ } readdir PAGES) {
        my %p = get_old_page($pagename);
        print "$p{'modtime'} $p{'name'} $p{'editcomment'}\n";
        put_page(%p) if $p{'exists'} = 1;
    }
    closedir PAGES;
    return @matches;
}

doit();

