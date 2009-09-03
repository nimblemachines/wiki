# Moved anything having to do with storing pages here.
#
# I'm ditching Subversion. The pages are simply stored in the filesystem,
# but I'll probably push them into Git every time something changes.
#
# The basic idea is that a page is really a directory. That directory
# contains a file for each _attribute_ of the page. The ones I'm thinking
# of right now (mostly because they map nicely from what I have now in svn)
# are:
#
# * contents (or maybe _text_)
# * modtime
# * editcomment
#
# I'm _not_ going to try to pull all the history out of svn. I don't care.
# I'm going to start with the latest snapshot and only think about the
# future.

### Set defaults ###
$pagedir = "$ENV{'DOCUMENT_ROOT'}/pages";

# Convert a page name (in CamelCase) to a directory name, with underscores
# separating the wiki words - so CamelCase becomes Camel_Case.
sub page_to_dir {
    my ($name) = @_;
    my $dir = fancy_title($name);
    $dir =~ tr/ /_/;   # replace space with _
    return "$pagedir/$dir";
}

# Nice to be able to ask if a page exists - eg when making a link - without
# having to read all its data.
#
# A page is said to exist when its directory exists, and it has a readable
# non-empty text attribute.
#
# Returns a list of (exists, $dir)
sub page_exists {
    my ($name) = @_;
    my $dir = page_to_dir($name);
    return (-d "$dir" && -r "$dir/text" && -f "$dir/text" && -s "$dir/text",
            $dir);
}

# Similarly, a way to make a page no longer exist - delete it!
# Rather than try to delete its attribute files and then its (now empty)
# directory, we simply delete its text, if it exists.
sub delete_page {
    my ($name) = @_;
    my ($exists, $dir) = page_exists($name);
    unlink "$dir/text" if $exists;
}

sub get_page {
    my ($name) = @_;
    my %page = (
        name        => "$name",
        exists      => 0,
        text        => "",
        modtime     => 0,
    );
    my ($exists, $dir) = page_exists($name);
    if ($exists) {
        $page{'exists'} = 1;
        # read each file into an attribute (key)
        opendir ATTRIBS, "$dir" or die "can't opendir $dir: $!";
        foreach my $attrib (grep { ! m/^\./ && -r "$dir/$_" && -f "$dir/$_"
                                            && -s "$dir/$_" }
                            readdir ATTRIBS) {
            $page{$attrib} = read_file("$dir/$attrib");
        }
        closedir ATTRIBS;
    }
    return %page;
}

sub put_page {
    my (%page) = @_;
    my $dir = page_to_dir($page{'name'});
    #print "put_page $dir\n";
    mkdir "$dir" unless (-d "$dir");
    foreach my $key (keys %page) {
        write_file("$dir/$key", $page{$key}) unless $key =~ m/name|exists/;
    }
    # now delete files that don't have corresponding keys in %page
    opendir ATTRIBS, "$dir" or die "can't opendir $dir: $!";
    foreach my $attrib (grep { ! m/^\./ && -r "$dir/$_" && -f "$dir/$_" }
                        readdir ATTRIBS) {
        unlink("$dir/$attrib") unless defined $page{$attrib};
    }
    closedir ATTRIBS;
}

# common to search & diff
sub filter_pages {
    my ($pred) = @_;
    opendir PAGES, "$pagesdir" or die "can't opendir $pagesdir: $!";
    my @matches = grep { ! m/^\./ && -d "$pagesdir/$_" && page_exists($_)[0]
                         && &$pred() } readdir PAGES;
    closedir PAGES;
    return @matches;
}

