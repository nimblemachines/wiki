# $Id$

$| = 1;         # flush after each print

### Read in configuration variables ###
do "config.pl";

$content = "";
$http_status = "200 Groovy";        # default is everything Ok
@footerlines = ();

# everything but the script name
my @scriptpath = split '/', $ENV{'SCRIPT_NAME'};
$scriptpath[-1] = "";    # null the last element
$pathprefix = join '/', @scriptpath;

sub choke {
    my ($errortext) = @_;
    my $subject = escape_uri($errortext);
    print <<EOT;
Content-type: text/html

<html>
  <head>
    <title>$wikiname :: An error occurred</title>
  </head>
  <body>
    <h1>Something went terribly wrong</h1>
    <p>An error occurred processing your last request.</p>
    <p>The error message was <em>$errortext</em>.</p>
    <p>Please <a href="mailto:$webhamster?subject=$subject">contact</a> the
       ding-dong responsible for this site with details about what you
       were doing when this happened.</p>
    <p>Thank you.</p>
  </body>
</html>
EOT
    exit;
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
    my @pairs;
    foreach (split( /&/, $data)) {
	my ($key, $value) = split(/=/, $_, 2);
	push @pairs, unescape_uri($key), unescape_uri($value);
#	push @pairs, unescape_uri($key), $value;
    }
    @pairs;
}

sub read_file {
    my ($filename) = @_;
    my $contents = "";

    open F, "< $filename" or choke "open $filename (for reading) failed: $!";
    local $/;  # slurp mode
    $contents = <F>;
    close F;
#    print STDERR "reading file $filename = $contents\n";
    $contents;
}

sub page_text {
    my ($page) = @_;
    my $file  = "$pagedir/$page";
    (-r "$file" && -f "$file") ? read_file($file) : "";
}

# XXX: do we still need to ever call this with action empty?
sub script_href {
    my ($action, $page) = @_;
    my $href = "";
    $page = "/$page" if $page;
    $href = "$action$page" if $action;  # and nothing otherwise!
    "${pathprefix}${href}";
}

sub scriptlink {
    my ($action, $page, $linktext) = @_;
    my $href = script_href($action, $page);
    "<a href=\"$href\">$linktext</a>";
}

sub scriptlinkclass {
    my ($action, $page, $linktext, $class) = @_;
    my $href = script_href($action, $page);
    "<a class=\"$class\" href=\"$href\">$linktext</a>";
}

sub make_wiki_link {
    my ($page) = @_;
    (-r "$pagedir/$page" && -f "$pagedir/$page")
        ? scriptlink("page", $page, $page)
        : ($editable ? scriptlinkclass("edit", $page, $page, "missing")
                     : "$page");
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

    $heading = scriptlink("search", $page, "$title") unless $heading;

    my $home_link = "";
    # only display icon if we're *not* editing
    if ($action ne "edit") {
        $home_link = scriptlink("page", $defaultpage,
            "<img id=\"icon\" src=\"$pathprefix$iconimgsrc\" alt=\"$iconimgalt\" />");
    }

    $metas{'robots'} = "${robots}index,${robots}follow";

    my $meta_elements = join "\n",
        map "<meta name=\"$_\" content=\"$metas{$_}\" />", keys %metas;

    # string together footer lines, separated by <br />
    my $footer = join "<br />\n", @footerlines;

    print <<EOT;
Content-type: text/html
Status: $http_status

<?xml version="1.0" encoding="iso-8859-1"?>
<!DOCTYPE html 
          PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
          "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
$meta_elements
<link rel="stylesheet" href="$pathprefix$style" type="text/css" />
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
    push @footerlines, scriptlink("page", "SearchPage", "Search")
        . " for page titles or text, browse "
        . scriptlink("page", "RecentChanges", "RecentChanges")
        . ", or return to " . scriptlink("page", $defaultpage, $defaultpage);

}

sub validator {
    push @footerlines, << "";
<p>
  <a href="http://validator.w3.org/check/referer">
    <img src="${pathprefix}_images/valid-xhtml10-blue" alt="Valid XHTML 1.0 Strict!" />
  </a>
  <a href="http://jigsaw.w3.org/css-validator/check/referer">
    <img src="${pathprefix}_images/valid-css-blue" alt="Valid CSS!" />
  </a>
</p>

}
