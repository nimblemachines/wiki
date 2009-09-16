# Moved anything having to do with storing pages here.
#
# I'm ditching Subversion. The pages are simply stored in the filesystem,
# but I'll probably push them into Git every time something changes.
#
# The basic idea is that a page is really a directory. That directory
# contains a file for each _property_ of the page. The ones I'm thinking
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
$docroot = $ENV{'DOCUMENT_ROOT'};
#$docroot = "/Users/david/nimblemachines_newpages";

# Using Git via GIT_DIR and GIT_WORK_TREE is a bit subtle. It turns that
# "git add" and "git rm" work best with paths _relative to the
# GIT_WORK_TREE (which is our $docroot). So we need two ways to get to the
# pages: absolute (for normal file operations) and relative (for Git). So
# we define relative and absolute paths to pages:
$relpages = "pages";
$abspages = "$docroot/$relpages";

# In the bulk of the code below, I try to be careful about distinguishing
# absolute and relative paths. When I'm calculating a path to use several
# times, I'll usually call it $abs.

### Set envvars so Git can find its way around.
$ENV{'GIT_DIR'} = "$docroot/.git";
$ENV{'GIT_WORK_TREE'} = "$docroot";

# set a umask so that we have a hope of sharing with a command line user,
# using group-writable bits.
umask 0002;

##########################################################################

# Simple interface to existing code: page_text, page_modtime, page_exists
# These all take a CamelCase name and un_Camel_Case it.

# Once I officially deprecate CamelCase (coming soon!) this ugliness can go
# away.

sub page_property {
    my ($name, $property) = @_;
    return cached_page_property(uncamelcase($name), $property);
}

sub page_exists {
    my ($name) = @_;
    return page_exists_abs(uncamelcase($name));
}

##########################################################################

# Now the core of the code. Down here page names are always uncamelcased.

# global cached page object
%cached_page = ();

sub cached_page_property {
    my ($name, $property) = @_;
    if (!defined $cached_page{'name'} || $cached_page{'name'} ne $name) {
        %cached_page = get_page($name);
    }
    return $cached_page{$property};
}

# Returns an absolute path to a particular page's directory.
sub page_to_abs {
    my ($name) = @_;
    return "$abspages/$name";
}

# When checking for existence we don't want to load in the page properties.
# Not only would this take a while, but often we check for the existence of
# _other_ pages than the one we are rendering, in order to choose what kind
# of link to make (ie, show vs edit).

# The question of existence is a subtle one - rather surprisingly. This is
# only because of the remarkable flexibility of page properties. One
# application I thought of recently was being able to have multiple
# versions of a page, in different formats: HTML, plain text, Markdown,
# Textile, my wiki markup, etc.

# The idea is that a property whose _name_ is one of the supported
# formats will contain the text of the page in that format. If there is
# more than one, they aren't guaranteed to have any relationship to each
# other - for instance, to all represent the same text. They are
# independent properties like any other - but this allows for flexibility.

# I'm going to adopt the following definition:
#     A page is said to exist when its directory exists, and it has a
#     readable non-empty text property in one of the supported formats.

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

sub page_exists_abs {
    my ($name) = @_;
    my $abs = page_to_abs($name);
    if (! -d $abs) {
        return 0;
    }
    foreach my $format (@supported_page_formats) {
        my $try = "$abs/$format";
        if (-r $try && -f $try && -s $try) {
            return $abs;
        }
    }
    return 0;
}

# Similarly, a way to make a page no longer exist - delete it! Rather than
# try to delete its property files and then its (now empty) directory, we
# simply delete anything that could contain its text - all formats.

sub delete_page {
    my ($name) = @_;

    if (-d page_to_abs($name)) {
        foreach my $format (@supported_page_formats) {
            git_unlink ("$name/$format");
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
    my $abs = page_exists_abs($name);
    if ($abs) {
        $page{'exists'} = 1;
        # read each file into a property (key)
        opendir PROPS, "$abs" or die "can't opendir $abs: $!";
        foreach my $property (grep { ! m/^\./ && -r "$abs/$_" && -f "$abs/$_"
                                            && -s "$abs/$_" }
                            readdir PROPS) {
            $page{$property} = read_file("$abs/$property");
        }
        closedir PROPS;
    }
    return %page;
}

# Unlike get_page, if you get_page_property() on a property that isn't
# defined, you'll get one in the hash, with a value of "". get_page()
# doesn't populate the hash at all unless the property exists and is
# non-empty.

# Also note: this returns a hash (a new page), rather than the property.

sub get_page_property {
    my ($name, $property) = @_;
    my %page = (
        name    => "$name",
        exists  => 0
    );
    my $abs = page_exists_abs($name);
    $page{'exists'} = 1 if $abs;
    $page{$property} = (-r "$abs/$property" && -f "$abs/$property"
            && -s "$abs/$property")
        ? read_file("$abs/$property") : "";
    return %page;
}

# put_page_properties is used to _replace_ or _add_ page properties, unlike
# put_page, which deletes from the filesystem any properties which aren't
# in the hash. However, put_page_properties _does_ delete files for properties
# that have keys but no value, or that are the empty string.

sub put_page_properties {
    my (%page) = @_;
    my $name = $page{'name'};
    my $abs = page_to_abs($name);

    mkdir "$abs" unless (-d "$abs");
    foreach my $key (grep { ! m/name|exists/ } (keys %page)) {
        if (!defined $page{$key} || $page{$key} eq "") {
            git_unlink("$name/$key");
        } else {
            git_write_file("$name/$key", $page{$key});
        }
    }
}

sub put_page {
    my (%page) = @_;
    my $name = $page{'name'};
    my $abs = page_to_abs($name);

    put_page_properties(%page);

    # now delete files that don't have corresponding keys in %page
    opendir PROPS, "$abs" or die "can't opendir $abs: $!";
    foreach my $property (grep { ! m/^\./ && -r "$abs/$_" && -f "$abs/$_" }
                        readdir PROPS) {
        git_unlink("$name/$property") unless defined $page{$property};
    }
    closedir PROPS;
}

# Record that the "calling" page links to a particular page. It's a no-op
# right now. Put into "called" page's "linkedfrom" metadata.
sub linksto_page {
    my ($name) = @_;
    my %p = get_page_property($name, 'linkedfrom');
    #$p{'linkedfrom'} = XXX
    # XXX Turn into a list, add the calling page, turn back into a string
    #my $lf = join "\n", ("$page", (split /\n/, XXXXX
    put_page_properties(%p);
}

# NOTE: be careful to turn the page (directory) _back_ into CamelCase
# before returning them. Also be careful to use an existence test that
# doesn't expect a CamelCase name (so we call page_exists_abs instead of
# page_exists).

sub filter_pages {
    my ($pred) = @_;
    opendir PAGES, "$abspages" or die "can't opendir $abspages: $!";
    my @matches = map camelcase($_), grep { ! m/^\./ && -d "$abspages/$_"
        && page_exists_abs($_) && &$pred() } readdir PAGES;
    closedir PAGES;
    return @matches;
}

# Git utility functions. These must be passed a _relative path_ (w.r.t.
# $docroot) to the file in question. For some reason absolute paths fail.
# So $path_to_property will have the form Page_Name/property. We form the
# relpath by prepending $relpages.

sub git_unlink {
    my ($path_to_property) = @_;
    my $abs = "$abspages/$path_to_property";
    if (-f $abs) {
        unlink($abs);
        git('rm', "$relpages/$path_to_property");
    }
}

sub git_write_file {
    my ($path_to_property, $contents) = @_;
    # More permissions stuff. Sharing this way is hard! When we add a page,
    # say via Git (by merging changes from the "live" site into our
    # conversion repo) the pagename directory (ie, that contains the
    # properties) is owned by me. But it's sitting in a directory that the
    # web server has write permission to. So, just as we unlink before
    # writing a _file_, how about we try to _chown_ before writing to a
    # directory?
    #chown();

    # To avoid permissions/ownership problems, unlink before writing new
    # file. Whether we own the file or not, we should have write permission
    # on the enclosing directory ($abspages).
    unlink("$abspages/$path_to_property");
    write_file("$abspages/$path_to_property", $contents);
    git('add', "$relpages/$path_to_property");
}

sub git {
    my $gitoutput = `$git @_`;
    #append_file("somewhere/git.log", $gitoutput);
}

