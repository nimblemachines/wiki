#
# $Id$
#
# This file is for local (site) configuration of the wiki script.
# PLEASE change these values from their defaults!
#

### Set up the config variables ###
$webhamster = 'webhamster@example.com';
$wikiname = "My Wiki";
$defaultpage = "WelcomePage";
$editscript = "wiki";
$iconimgsrc = "_images/lambda";
$iconimgalt = "lambda the ultimate!";
$style = "style/screen";

## typographic style
$convert_endash = 1;
$convert_emdash = 0;
$convert_quotes = 1;

# change this to be *you*!! and make sure to escape the '@' into '%40'
# as below.
$flickr_user = "52541558%40N00";
$flickr_name = "nimblemachines";

%metas = (
#    keywords => "wiki",
#    description => "A wiki for discussing the things that I care about.",
    copyright => "All content on example.com is copyrighted. All rights are reserved."
    );

# where pages and page archive are located
# NOTE: you should copy _pages/ to pages/ (or something) and put your
# pages/ under subversion!
$pagedir = "pages";
$archivedir = "$pagedir/archive";

# really run subversion commands; default to no
$subversion = "no";
$svn = "/usr/local/bin/svn";
