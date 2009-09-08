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
$pagedir = "$ENV{'DOCUMENT_ROOT'}/newpages";

##########################################################################

# Simple interface to existing code: page_text, page_modtime, page_exists
# These all take a CamelCase name and un_Camel_Case it.

# Once I officially deprecate CamelCase (coming soon!) this ugliness can go
# away.

sub page_text {
    my ($name) = @_;
    return cached_page_attrib(uncamelcase($name), 'markup');
}

sub page_modtime {
    my ($name) = @_;
    return int(cached_page_attrib(uncamelcase($name), 'modtime'));
}

sub page_exists {
    my ($name) = @_;
    return page_exists_dir(uncamelcase($name));
}

##########################################################################

# Now the core of the code. Down here page names are always uncamelcased.

# global cached page object
%cached_page = ();

sub cached_page_attrib {
    my ($name, $attrib) = @_;
    if (!defined $cached_page{'name'} || $cached_page{'name'} ne $name) {
        %cached_page = get_page($name);
    }
    return $cached_page{$attrib};
}

sub page_to_dir {
    my ($name) = @_;
    return "$pagedir/$name";
}

# When checking for existence we don't want to load in the page attribs.
# Not only would this take a while, but often we check for the existence of
# _other_ pages than the one we are rendering, in order to choose what kind
# of link to make (ie, show vs edit).

# The question of existence is a subtle one - rather surprisingly. This is
# only because of the remarkable flexibility of page attributes. One
# application I thought of recently was being able to have multiple
# versions of a page, in different formats: HTML, plain text, Markdown,
# Textile, my wiki markup, etc.

# The idea is that an attribute whose _name_ is one of the supported
# formats will contain the text of the page in that format. If there is
# more than one, they aren't guaranteed to have any relationship to each
# other - for instance, to all represent the same text. They are
# independent attributes like any other - but this allows for flexibility.

# I'm going to adopt the following definition:
#     A page is said to exist when its directory exists, and it has a
#     readable non-empty text attribute in one of the supported formats.

# That brings up the question: Which one is the "current" version? I'm
# going to adopt the idea that some formats are more "appealing" than
# others. So I list them in decreasing order of appeal, and the first one
# that exists is it. For existence, we don't care which one - we just want
# to know if the page exists in _any_ format.

# If page exists, returns $dir (which is _true_, according to Larry Wall!)
# Otherwise, returns 0 (which is generally considered false).

# Right now, our list of formats contains just one: "markup" (which is my
# wiki markup).

# This list will change. That is, it will hopefully get _longer_. ;-)

#@fancypants_supported_page_formats = ( "markup", "html", "text" );
@supported_page_formats = ( "markup" );

sub page_exists_dir {
    my ($name) = @_;
    my $dir = page_to_dir($name);
    if (! -d $dir) {
        return 0;
    }
    foreach my $format (@supported_page_formats) {
        my $try = "$dir/$format";
        if (-r $try && -f $try && -s $try) {
            return $dir;
        }
    }
    return 0;
}

# Similarly, a way to make a page no longer exist - delete it! Rather than
# try to delete its attribute files and then its (now empty) directory, we
# simply delete its anything that could contain its text - all formats.

sub delete_page {
    my ($name) = @_;
    my $dir = page_to_dir($name);

    if (-d $dir) {
        foreach my $format (@supported_page_formats) {
            unlink "$dir/$format";
        }
    }
}

sub get_page {
    my ($name) = @_;
    my %page = (
        name    => "$name",
        exists  => 0,
        text    => "",
        modtime => 0,
    );
    my $dir = page_exists_dir($name);
    if ($dir) {
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

# Unlike get_page, if you get_page_attrib() on an attribute that isn't
# defined, you'll get one in the hash, with a value of "". get_page()
# doesn't populate the hash at all unless the attribute exists and is
# non-empty.

sub get_page_attrib {
    my ($name, $attrib) = @_;
    my %page = (
        name    => "$name",
        exists  => 0
    );
    my $dir = page_exists_dir($name);
    $page{'exists'} = 1 if $dir;
    $page{$attrib} = (-r "$dir/$attrib" && -f "$dir/$attrib" && -s "$dir/$attrib")
        ? read_file("$dir/$attrib") : "";
    return %page;
}

# put_page_attribs is used to _replace_ or _add_ page attributes, unlike
# put_page, which deletes from the filesystem any attributes which aren't
# in the hash.

sub put_page_attribs {
    my (%page) = @_;
    my $dir = page_to_dir($page{'name'});

    mkdir "$dir" unless (-d "$dir");
    foreach my $key (keys %page) {
        write_file("$dir/$key", $page{$key}) unless $key =~ m/name|exists/;
    }
}

sub put_page {
    my (%page) = @_;
    my $dir = page_to_dir($page{'name'});

    put_page_attribs(%page);

    # now delete files that don't have corresponding keys in %page
    opendir ATTRIBS, "$dir" or die "can't opendir $dir: $!";
    foreach my $attrib (grep { ! m/^\./ && -r "$dir/$_" && -f "$dir/$_" }
                        readdir ATTRIBS) {
        unlink("$dir/$attrib") unless defined $page{$attrib};
    }
    closedir ATTRIBS;
}

# Record that the "calling" page links to a particular page. It's a no-op
# right now. Put into "called" page's "linkedfrom" metadata.
sub linksto_page {
    my ($name) = @_;
    my %p = get_page_attrib($name, 'linkedfrom');
    #$p{'linkedfrom'} = XXX
    # XXX Turn into a list, add the calling page, turn back into a string
    #my $lf = join "\n", ("$page", (split /\n/, XXXXX
    put_page_attribs(%p);
}

# NOTE: be careful to turn the page (directory) _back_ into CamelCase
# before returning them. Also be careful to use an existence test that
# doesn't expect a CamelCase name (so we call page_exists_dir instead of
# page_exists).

sub filter_pages {
    my ($pred) = @_;
    opendir PAGES, "$pagedir" or die "can't opendir $pagedir: $!";
    my @matches = map camelcase($_), grep { ! m/^\./ && -d "$pagedir/$_"
        && page_exists_dir($_) && &$pred() } readdir PAGES;
    closedir PAGES;
    return @matches;
}

