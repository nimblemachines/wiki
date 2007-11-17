#!/usr/bin/perl -w

# $Id$

sub escape_html {
    s/&/&amp;/g;
    s/</&lt;/g;
}

sub init_interwiki {
    my $file = "intermap";
    %intermap = (-r "$file" && -f "$file") ? split /\s+/, read_file($file) : ();
}

sub do_init {
    my $search_href = script_href("search");

    $textsearchform = <<"";
<form action="$search_href" method="get" enctype="application/x-www-form-urlencoded">
  <p><input type="text" name="text" size="30" /></p>
</form>

    $namesearchform = <<"";
<form action="$search_href" method="get" enctype="application/x-www-form-urlencoded">
  <p><input type="text" name="name" size="30" /></p>
</form>

    init_interwiki();
}

sub iso_timestamp {
    my ($time) = @_;
    my ($year, $mon, $month, $mday, $hour, $min, $sec) = pretty_time($time);
    "$year-$mon-$mday" . "T" . "$hour:$min:$sec";
}

sub editfooter {
    my $edittext = hyper("Edit", script_href("edit", $page)) . " this page";
    my $modtime = page_modtime("$page");
    my $modtext  = ($modtime != 0)
        ? " (last edited "
          .  hyper(stamp($modtime), script_href("diff", $page)) . ")"
        : "";

    push @footerlines, "$edittext$modtext";
}
 
sub commentfooter {
    push @footerlines, obfuscate_mailto("$webhamster", "Comment")
        . " on this page";
}

sub make_interwiki_link {
    my ($prefix, $query) = @_;
    my $interlink = $intermap{$prefix};

    # the human-readable version of query
    (my $link_text = $query) =~ tr/_+/  /;

    defined $interlink
        ? "<a href=\"$pathprefix/out/$interlink$query\">$link_text</a>"
        : "$prefix:$query";
}

sub hide {
    my ($link) = @_;

    # use "" to hide links
    $link =~ s/($wikiword)/$1\"\"/go;
    $link;
}

sub convert_wiki_links {
    s/\b($wikilink)\b/make_wiki_link($1)/geo;
}

sub convert_interwiki_links {
    s/($interprefix):($interquery)/hide(make_interwiki_link($1, $2))/geo;
}

sub wrap {
    my ($elem, $contents) = @_;
    "<$elem>$contents</$elem>";
}

# For every voice except the first (">") there is an open div.
$current_voice = "1";

sub end_voice {
    ($current_voice ne "1") ? "</div>\n" : "";
}

sub start_voice {
    my ($v) = @_;
    if ($v ne $current_voice) {
        my $old = end_voice();
        my $new = ($v ne "1") ? "<div class=\"voice" . $v . "\">" : "";
        $current_voice = $v;
        "$old$new";
    }
    else { "" }
}

# This implementation (by mip) has a built-in "protection" for the user.
# Only the first item's kind (* or #) is used to determine the kind of the
# list. After that, items are added whether their kind matches the current
# open list.
#
# This has the benefits of simplicity and resiliency; OTOH, it prevents you
# from doing things you might want to do. mip will dispute this, of course.
# ;-)

$curlist = "";

sub listitem {
    my ($kind, $item, $class) = @_;
    my $result = "";
    
    unless ($curlist) {
        $kind = $kind eq '#' ? 'ol' : 'ul';
        $curlist = "</$kind>\n";
        $result .= "<$kind>\n";
    }
    $result . "<li$class>$item</li>";
}

sub listend {
    if ($curlist) {
        my $result = $curlist;
        $curlist = "";
        $result;
    }
    else { "" }
}

# Support for flickr badges.
#
# Markup is
# "[flickr" [<num>] [ ":all" ] [ ":latest" ] [ <tags> ] "]"
#
# The flickr script generate images each inside a div with class
# "flickr_badge_image".
#
# Notes on usage of Flickr badge query API:
#   size=s gives small square pix;
#   size=t gives small thumbnails;
#   size=m gives rather large pix (4 across)
#   display=random
#   display=latest
#   layout=h  (tables - ugh!)
#   layout=v  (ditto!)
#   layout=x  (wraps each pic in a div)
#   source=all
#   source=user
#     user=<id>
#   source=user_tag
#     user=<id>
#     tag=<tag>
#   source=all_tag
#     tag=<tag>

sub flickr_badge {
    my ($opts) = @_;

    my ($count, $opt, $tags) = $opts =~ m/(\d*)([:\w]*)\s*([ \w'"]*)/; # '
    $count = 5 if not $count;
    $which = ($opt =~ m/:latest/) ? "latest" : "random";
    $whose = ($opt =~ m/:all/)    ? "all"    : "user";

    # init hash for query string
    my %q = (
             count => $count,
             size  => "t",          # "s" for small squares; "m" for biggies
             display => $which,
             layout => "x"          # this gives us div's rather than td's
             );

    if ($whose eq "user") {
        $q{'user'} = "$flickr_user";
    }

    # Separate tags into an array...
    my @tags = split / +/, $tags;

    # ...then escape the rest for query string
    foreach (@tags) { $_ = escape_uri($_) }

    if (@tags) {
        $q{'tag'} = join "+", @tags;
        $whose .= "_tag";
    }

    $q{'source'} = $whose;

    # Finally!
    my $query = join "&amp;", (map "$_=$q{$_}", (sort keys %q));

    return <<"";
<div class="flickr_badge">
  <script type="text/javascript" src="http://www.flickr.com/badge_code_v2.gne?$query">
  </script>
</div>

}

sub block_markup {
    my $class = "";
    $class = " class=\"changed\"" if s#^\a##;
    
    if (m/^([*#])\s*(.*)/) {
        $_ = listitem($1, $2, $class);
    } else {
        s#^(\s+.*)#<pre$class>\n$1\n</pre>#s ||
        s#^"{2}(.*)#<blockquote$class><p>$1</p></blockquote>#s ||

        # hrules and headings return to voice 1
        s#^-{4,}#start_voice(1) . "<hr />"#e ||
        s/^(={1,4})\s*(.*)/start_voice(1) . wrap("h".((length $1)+1), $2)/e ||

        # special "forth" voice
        s/^(>>forth)/start_voice("forth")/e ||
        
        # multiple "voices"
        s/^(>{1,8})/start_voice(length($1))/e ||

        # special links - these generate form elements, which are considered to
        # be block-level markup. In order to validate, these cannot be enclosed
        # in p elems.
        s/^\[namesearch\]/$namesearchform/ ||
        s/^\[textsearch\]/$textsearchform/ ||

        # comments, using Haskell notation: --
        # daf: mip pointed out that this breaks signatures (--DavidFrech)
        # at the starts of lines, so we need different markup.
        # using ++ instead!
        s/^\+\+.*//s ||

        # generate a flickr badge, with user or public content
        s/^\[flickr(.*)\]/flickr_badge($1)/e ||

        # nothing else matches, make it a p
        s#^(.*)#<p$class>$1</p>#s;
        $_ = listend() . $_;
    }
}

sub show_uris {
    # remove double quotes everywhere except at the start of a line (where
    # it denotes a blockquote) - can be used to foil wikilinks, and to add
    # plurals to singularly-linked pages
    s/(.)""/$1/g;
}

sub obfuscate_mailto {
    my ($email, $link) = @_;
    $email =~ s/(.)/"%" . unpack("H2", $1)/ge;
    "<a href=\"mailto:$email?subject=$page\">$link</a>";
}

sub img_link {
    my ($uri, $text) = @_;
    $uri = "$pathprefix/static/$uri" if ($uri !~ m/^https?:/);
    "<img src=\"$uri\" alt=\"$text\" />";
}

sub href_link {
    my ($uri, $text) = @_;
    if ($uri =~ m/^https?:/) {
        $uri = "$pathprefix/out/$uri";
    } else {
        $uri = "$pathprefix/static/$uri";
    }
    "<a href=\"$uri\">$text</a>";
}

sub manpage {
    my ($man, $section) = @_;
    return href_link("http://www.freebsd.org/cgi/man.cgi?query=$man&sektion=$section", "<code class=\"man\">$man($section)</code>");
}

sub inline_markup {
    # obscure something so Google won't properly index it - like "Eric Raymond"
    # should this be "bracketing" markup instead? Matches only between "word"
    # characters (\w).
    s#(\w)\.\.(\w)#$1<span class="empty"></span>$2#gs;

    s#'{3}(.+?)'{3}#<strong>$1</strong>#gs;
    s#'{2}(.+?)'{2}#<em>$1</em>#gs;
    # XXX: code, cite, kbd, ???

    # forth word
    s#fw\(\(\s*(.+?)\s*\)\)#<code class="forth">$1</code>#gs;

    # Quote character entities so that the browser doesn't "helpfully"
    # convert them. Use !!name!! or ??name??.
    s#[!\?]{2}(.+?)[!\?]{2}#&$1;#gs;

    if ($convert_endash) {
        # convert ' - ' to an en-dash
        s/ - / &ndash; /g;
    }

    if ($convert_emdash) {
        # convert ' -- ' to an em-dash, eliding the surrounding spaces
        s/ -- /&mdash;/g;

        # convert '--' to an em-dash, if surrounded by reasonable text
        s/([a-zA-Z!)"'])--([a-zA-Z("'])/$1&mdash;$2/g;
    }

    if ($convert_quotes) {
        # convert " to ldquo or rdquo, ' to lsquo or rsquo

        # special case: for prefix number abbrevs, like '76
        s/(^|\s+|[[({])'([0-9]+s?|t|tis|ere($|\s+|[])},.?;:-]))/$1&rsquo;$2/gi;

        s/(^|\s+|[[({]|<[a-z]+>)"([a-zA-Z0-9])/$1&ldquo;$2/g;
        s/(^|\s+|[[({]|<[a-z]+>)'([a-zA-Z0-9])/$1&lsquo;$2/g;

        s#([a-zA-Z0-9.?!,;:_])"($|\s+|[])},.?!;:-]|</[a-z]+>)#$1&rdquo;$2#g;
        s#([a-zA-Z0-9.?!,;:_])'($|\s+|[])},.?!;:-]|</[a-z]+>)#$1&rsquo;$2#g;

        s/([]a-zA-Z0-9])'([a-zA-Z0-9])/$1&rsquo;$2/g;  # ' acting as an apostrophe
    }

    # obfuscated mailto links: [[mailto:email link text]]
    # link text is required, since what would we put there other than the
    # unescaped mailto address, thereby making the whole thing moot?
    s#\[\[mailto:(\S+)\s+(.+)\]\]#hide(obfuscate_mailto($1, $2))#ge;

    # Since Flickr claims that we're in violation of their Terms of Service
    # unless we link images to their flickr page, I've made some special
    # case matching to create markup that uses the image given as a
    # "thumbnail" and makes it a link to the picture's "home page" on
    # Flickr. Sigh.

    # flickr img link: [[uri.ext alt text]] where ext is img type
    s#\[\[img (http://static.flickr.com/([0-9]+)/([0-9]+)_([0-9a-f]+).jpg)\s+(.+?)\]\]#hide(
        "<a href=\"$pathprefix/out/http://www.flickr.com/photos/$flickr_name/$3/\">
  <img src=\"$1\" alt=\"$5\" /></a>")#ge;

    # link to man page - this can't be done with intermap because it needs
    # to pull the section number out of parens and substitute it into the
    # URI.
    s{\bman:([\w-]+)\((\d+)\)}{hide(manpage($1, $2))}ge;

    # inline img link: [[uri.ext alt text]] where ext is img type
    s#\[\[img (\S+\.(?:jpg|jpeg|gif|png))\s+(.+?)\]\]#hide(img_link($1,$2))#ge;

    # unnamed href link: [[uri]]
    s#\[\[(\S+?)\]\]#hide(href_link($1,$1))#ge;

    # generic href link: [[url lots of link text]]
    s#\[\[(\S+?)\s+(.+?)\]\]#hide(href_link($1,$2))#ge;

    # ISBN ...
    # RFC ...

    convert_interwiki_links();
    convert_wiki_links();
    show_uris();
}

sub render_body {
    escape_html();

    # XXX if we do inline on a per-para basis, we can "catch" dangling
    # markup that spans para boundaries. I wonder if everything shouldn't
    # be wrapped in the foreach by para.

    # we're going to do "paragraph" markup delimited with multiple newlines
    foreach (split /\n{2,}/, $_) {
        inline_markup() unless m/^\a?\s+/;  # leave pre alone
        block_markup();
        $content .= "$_\n";
    }

    # close any open list
    $content .= listend();
    
    # close our last "voice" div
    $content .= start_voice(1);
}

sub render_page {
    my ($robots) = @_;
    render_body();
    editfooter() if $editable;
    commentfooter() unless $editable;
    findfooter();
    validator();
    generate_xhtml(fancy_title($page), "", $robots);
}

do_init();
