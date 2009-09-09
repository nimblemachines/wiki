#use strict;

$| = 1;   # flush after each print

# get the version
do "../version.perl";

# get the "pages" abstraction code
do "../pages.perl";

$wikiword = "I|A|[A-Z][a-z]+";
$wikilink = "(?:$wikiword){2,}";
$interprefix = "[A-Za-z.]+";
$interquery = "[A-Za-z0-9+_()]+";

# HTTP scheme pattern; promise to Perl that we won't change this, so it can
# be compiled once (the 'o' modifier). And, by the way, those + characters
# do two different things: one is inside a character class (alpha or +);
# the other says "we want one or more". So $http_scheme can match "http://"
# but also "svn+ssh://" (for those of you unlucky enough to still be using
# Subversion ;-).
$http_scheme = qr#^[[:alpha:]+]+://#o;

### Set defaults ###
$webhamster = "$ENV{'SERVER_ADMIN'}";
$defaultpage = "WelcomePage" unless $defaultpage;   # in case no config.perl

### Read in per-domain configuration variables ###
do "$ENV{'DOCUMENT_ROOT'}/config.perl";

if ($ENV{'SITEMODE'} eq "readwrite") {
    $editable = 1;
    $wikiname = "Edit $wikiname";      # remind us
} else {
    $editable = 0;
}

$content = "";
%http_response_headers = (
    "Content-Type" => "text/html",
    "Status"       => "200 Groovy"        # default is everything Ok
);
@footerlines = ();

# URIs have following form:
# /action/page
# /query?string
# actions: show, edit, diff, save, maybe linksto
# queries: search

# SCRIPT_NAME starts with a /
# last part of path is script we are running
my @scriptpath = split '/', $ENV{'SCRIPT_NAME'};
my $script = pop @scriptpath;

# With "UseCanonicalName On" in the server config, SERVER_NAME gets set to
# ServerName in VHost configuration, regardless of the Host header
# specified in the HTTP request. If the user request refers to a
# ServerAlias, HTTP_HOST will differ from SERVER_NAME. If that's true, make
# a pathprefix that "canonicalises" all script_hrefs by making them
# absolute URIs referring to the SERVER_NAME, so the first link that the
# user follows will be to the canonical name.
#
# If HTTP_HOST and SERVER_NAME are the same, just use "root local"
# script_hrefs, like "/show/PageName".

$canonicalise = ($ENV{'HTTP_HOST'} ne $ENV{'SERVER_NAME'})
    ? "http://$ENV{'SERVER_NAME'}"
    : "";

$pathprefix = $canonicalise . join '/', @scriptpath;

# PATH_INFO starts with a / followed by pagename. If there is another /
# then $pathjunk will get defined, and we'll redirect; see below.

my (undef, $reqpage, $pathjunk) = split '/', $ENV{'PATH_INFO'};

# if no page specified, default its value
$page = $reqpage || $defaultpage;

# If we didn't request a valid page OR if there was junk *after* the page name,
# redirect to the canonical URI. But don't do this automatically - it breaks
# search, for instance. Only /show will call this. redirect is wired to doing
# a "show" anyway, so if /edit called it, it would be redirected oddly...

sub redirect_to_canonical_uri {
    if (not $reqpage or defined($pathjunk)) {
        redirect("temporary");
        exit();
    }
}

sub choke {
    my ($errortext) = @_;
    my $subject = escape_uri($errortext);
    $http_response_headers{'Status'} = "500 Bad news";
    $content = <<"";
    <p>An error occurred processing your last request.</p>
    <p>The error message was <em>$errortext</em>.</p>
    <p>Please <a href="mailto:$webhamster?subject=$subject">contact</a> the
       ding-dong responsible for this site with details about what you
       were doing when this happened.</p>
    <p>Thank you.</p>

    generate_xhtml("An error occurred", "Something went terribly wrong", "no");
    exit;
}

sub escape_uri {
    my ($uri) = @_;

    # XXX is this actually kosher?
    # escape a minimal set - probably more chars are needed here
    $uri =~ s/([&=+?'"\000-\037\177])/"%" . unpack("H2", $1)/ge;
    $uri =~ tr/ /+/;    # may have to be %20
    $uri;
}

sub unescape_uri {
    my ($uri) = @_;
    return undef unless defined $uri;
    $uri =~ tr/+/ /;
    $uri =~ s/%([0-9a-fA-F]{2})/pack("C",hex($1))/ge;
    $uri;
}

sub parse_http_data {
    my ($data) = @_;
    return map unescape_uri($_), (map split(/=/, $_, 2), split(/&/, $data));
}

sub read_file {
    my ($filename) = @_;
    my $contents = "";

    open F, "< $filename" or choke("open $filename (for reading) failed: $!");
    local $/;  # slurp mode
    $contents = <F>;
    close F;
#    print STDERR "reading file $filename = $contents\n";
    $contents;
}

sub write_file {
    my ($filename, $contents) = @_;

#    print STDERR "writing file $filename = $contents\n";
    open F, "> $filename" or choke("open $filename (for writing) failed: $!");
    print F $contents;
    close F;
}

# This bit of code is ugly because it is being passed an array of references
# to scalars that are to be modified. Hence the $$n everywhere.
sub leading_zero {
    my @nums = @_;
    foreach my $n (@nums) {
        $$n = "0$$n" if ($$n < 10);
    }
}

sub pretty_time {
    my ($time) = @_;
    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday) = localtime($time);
    $year += 1900;
    my $month = (qw(January February March April May June July
                    August September October November December))[$mon];
    $mon = $mon + 1;    # was indexed from 0
    leading_zero \($mon, $mday, $hour, $min, $sec);
    ($year, $mon, $month, $mday, $hour, $min, $sec);
}

sub stamp {
    my ($time) = @_;
    my ($year, $mon, $month, $mday, $hour, $min, $sec) = pretty_time($time);
    "$year $month $mday $hour:$min";
}

# We want the hrefs we generate - in links and such - to be "rooted" rather
# than relative. This doesn't mean that we have put a full scheme,
# hostname, and path in there, though. But for local - or what I like to
# call "root relative" URIs - those that refer back to resources on the
# same host - we prepend a path prefix, that, in the common case, is simply
# a slash.
#
# If the URI is already an absolute URI, we leave it alone. It's already
# rooted.

sub rooted_href {
    my ($uri) = @_;
    $uri = "$pathprefix/$uri" unless ($uri =~ $http_scheme);
    return "$uri";
}

# XXX should this be called make_path or abs_path or something? Now that's
# all it does!
sub script_href {
    return join "/", ${pathprefix}, @_;
}

# make a hyperlink
# called with linktext, href, optional class
sub hyper {
    my ($linktext, $href, $class) = @_;
    $class = $class ? " class=\"$class\"" : "";
    "<a href=\"$href\"$class>$linktext</a>";
}

sub make_wiki_link {
    my ($page) = @_;
    #page_linkedfrom($page);     # record that we link to this page
    page_exists($page)
        ?              hyper($page, script_href("show", $page))
        : ($editable ? hyper($page, script_href("edit", $page), "missing")
                     : "$page");
}

# Convert "CamelCase" to "Camel Case", to make nice page titles. We first
# convert to our new-style page name (Camel_Case); and then, by replacing
# underscores with spaces, to a nice page title.

sub fancy_title {
    my ($name) = @_;
    $name = uncamelcase($name);
    $name =~ tr/_/ /;
    $name
}

# Convert a page name (in CamelCase) to a new-style name, with underscores
# separating the wiki words - so CamelCase becomes Camel_Case.

sub uncamelcase {
    my ($name) = @_;
    # Separate wikiwords with spaces. I split this into *two* expressions
    # because it wasn't working when I folded them together. My conjecture
    # is that the one-letter REs (I and A) need to match both at the
    # beginning and the end of a wikiword (since they are only one letter
    # long); but the RE matching rules only lets them match once.
    $name =~ s/([a-z])([A-Z])/$1_$2/g;    # end of one, start of another
    $name =~ s/([IA])([A-Z])/$1_$2/g;     # special wikiwords I and A
    return "$name";
}

# going the other way is easy...
sub camelcase {
    my ($name) = @_;
    $name =~ s/_//g;
    return "$name";
}

# Since we use HERE documents in the following code to quote chunks of HTML
# - esp chunks that contain lots of interpolated variables AND double
# quotes - and since here docs have squirrelly annoying trailing newlines,
# here is a bit of code to neatly slice off those newlines.
sub clean {
    my ($str) = @_;
    return substr($str, 0, -1);
}

sub generate_xhtml {
    my ($title, $heading, $robots) = @_;

    # Mostly we want the title and heading to be the same text. $heading is
    # usually a link to a search page, but the link text is the same as
    # $title. To get this behavior, pass "" for $heading. Sometimes,
    # though, they need to be different: if, for instance, we want inline
    # markup in the heading but not in the title (where it violates the
    # html spec). Or if we _don't_ want $heading to be a link (like on edit
    # pages).
    #
    # There is another wrinkle to this. We don't want web spiders to follow
    # links to edit or search pages and follow the links because they might
    # get stuck in circles or do damage to the wiki. Only "normal"
    # (do_show) pages should be indexed.

    $heading = hyper("$title", script_href("search?text=$page"))
        unless $heading;

    # push default style onto front of @styles
    unshift @styles, "_style/screen";

    # prefix with $pathprefix unless already an absolute URI
    $iconsrc = rooted_href($iconsrc);

    # Only display icon if we're *not* editing. There is a subtlety:
    # since a save may fail (due to collision) we could be editing even
    # though our URI says "save".
    my $home_link = ($script =~ m/edit|save/)
        ? ""
        : hyper(clean(<<"IMG"), script_href("show", $defaultpage));
<img id="icon" src="$iconsrc" alt="$iconalt" />
IMG

    $robots = "no" if $editable;
    $metas{'robots'} = "${robots}index,${robots}follow";

    my $meta_elements = join "\n", (map clean(<<"META"), keys %metas);
<meta name="$_" content="$metas{$_}" />
META

    # combine into html link elems
    my $stylesheets = join "\n", (map clean(<<"LINK"), (map rooted_href($_), @styles));
<link rel="stylesheet" href="$_" type="text/css" />
LINK

    # string together footer lines, separated by <br />
    my $footer = join "<br />\n", @footerlines;

    my $http_response_headers = join "\n",
        (map "$_: $http_response_headers{$_}", keys %http_response_headers);

    print <<EOT;
$http_response_headers

<?xml version="1.0" encoding="iso-8859-1"?>
<!DOCTYPE html 
  PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
         "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
$meta_elements
$stylesheets
<title>$wikiname :: $title</title>
</head>
<body>

<div id="header">
$home_link
<h1>$heading</h1>
<hr />
</div>

<div id="content">
$content
</div>

<div id="footer">
<hr />
$footer
</div>

</body>
</html>
EOT
}

sub findfooter {
    push @footerlines, hyper("Search", script_href("show", "SearchPage"))
        . " for page titles or text, browse "
        . hyper("RecentChanges", script_href("show", "RecentChanges"))
        . ", or return to "
        . hyper($defaultpage, script_href("show", $defaultpage));
}

sub validator {
    return unless $editable;
    push @footerlines, clean(<<"VALID");
<p>
wiki commit $current_version_sha1
</p>
<p>
  <a href="http://validator.w3.org/check/referer">
    <img src="${pathprefix}/_image/valid-xhtml10-blue" alt="Valid XHTML 1.0 Strict!" />
  </a>
  <a href="http://jigsaw.w3.org/css-validator/check/referer">
    <img src="${pathprefix}/_image/valid-css-blue" alt="Valid CSS!" />
  </a>
</p>
VALID
}

# Wired in that we redirect to rendering $page ("show").
sub redirect {
    my %redirections = (
	permanent => "301 Permanent",
	temporary => "302 Found",
	post      => "303 See other"
    );
    my $href = script_href("show", $page);
    $content = hyper($page, $href);
    $http_response_headers{'Status'} = $redirections{$_[0]};
    $http_response_headers{'Location'} = $href;
    generate_xhtml("Redirect", "Redirect", "no");
}
