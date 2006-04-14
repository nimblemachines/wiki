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
$iconimgsrc = "images/lambda";
$iconimgalt = "lambda the ultimate!";
$style = "style/screen";

# change this to be *you*!! and make sure to escape the '@' into '%40'
# as below.
$flickr_user = "52541558%40N00";

%metas = (
    keywords => "wiki",
    description => "A wiki for discussing the things that I care about.",
    copyright => "All content on example.com is copyrighted. All rights are reserved."
    );
$heading_template = "<home />\n<h1>. <heading /></h1>";

# where pages and page archive are located
$pagedir = "pages";
$archivedir = "$pagedir/archive";

# really run subversion commands; default to no
$subversion = "no";

