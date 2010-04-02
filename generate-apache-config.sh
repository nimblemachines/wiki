#!/bin/sh

# automagically make vhosting config files for Apache

### When moved to a new machine, $www_root is the only setting that should
### need to change, assuming that everything hangs off this root.

# Apache vhost domains root
# Change this if necessary!
www_root=$(pwd)/www

# main server config to make this all work
conf=${www_root}/wiki.conf

# Apache vhosts directory
vhosts=${www_root}/vhosts

# common wiki code
wiki=$(pwd)/wiki

# name of pages/ directory?
pages=${www_root}/data/\*/pages

gen_server_config () {
    cat <<EOT > ${conf}
# This file is automagically generated. DO NOT EDIT!!

# Restrict access to everything by default!
<Directory ${www_root}>
    Options FollowSymLinks
    AllowOverride None
    Order deny,allow
    Deny from all
</Directory>

# Allow access to actions/ files/ images/ styles/
# robots.txt.* are now in files/

<DirectoryMatch ^${wiki}/(actions|files|images|styles)>
    Options MultiViews
    Order allow,deny
    Allow from all
</DirectoryMatch>

# Use name-based virtual hosting.
NameVirtualHost *

# We need a fake first VHost so that requests for bare IP or Host: headers
# that don't match, get nothing, rather than the first in the list - a
# rather _stupid_ heuristic for the Apache developers to have used.

<VirtualHost *>
# This is a holding space for requests with unknown or unspecified Hosts.
# Point to DocRoot, which has no access by default.
  DocumentRoot ${www_root}
</VirtualHost>

Include ${vhosts}
EOT
}

gen_domain_vhost () {
    logroot=${www_root}/logs/$sub.$dom
    mkdir -p ${logroot}
    admin="webhamster@$dom"
    [ -f $dir/../admin ] && admin=$(eval echo $(cat $dir/../admin))

    # Set up whether site is readonly or readwrite. This affects which
    # robots.txt file is served, and also how an EnvVar (that the action
    # scripts read) gets set.
    sitemode="readwrite"
    [ -f $dir/readonly ] && sitemode="readonly"

    (
    cat <<EOT
# This file is automagically generated. DO NOT EDIT!!
<VirtualHost *>
  DocumentRoot ${docroot}
  CustomLog    ${logroot}/access_log combined
  ErrorLog     ${logroot}/error_log
  UseCanonicalName On
  ServerName   $sub.$dom
  ServerAdmin  ${admin}
EOT

    # Generate server aliases
    if [ -f $dir/serveraliases ]; then
        for alias in $(eval echo $(cat $dir/serveraliases)); do
    cat <<EOT
  ServerAlias  $alias
EOT
        done
    fi

    # This is where I need Perl: to concatenate several strings with "|"
    # between them.

    cat_subdirs=
    if [ -f $dir/subdirs ]; then
        for s in $(cat $dir/subdirs); do
            [ "$cat_subdirs" ] && s="|$s"
            cat_subdirs="$cat_subdirs$s" 
        done

    # Lump the user's specified subdirs in with files|images|styles when
    # doing the DirectoryMatch to set permissions, but do the AliasMatch
    # separately for files|images|styles since we link from singular to
    # plural.

    # Allow access to files, styles, and images; also, set up
    # content-negotiation (MultiViews) so we can name things without using
    # .html, .jpg, .png And set up the possibility of turning on Indexing
    # with a .htaccess file (yuck!).

        # Output this AliasMatch only if subdirs were specified...
        cat <<EOT

  AliasMatch	^/($cat_subdirs)/(.*)	${docroot}/\$1/\$2
EOT
        # Prepend list with a "|" only if subdirs were specified...
        cat_subdirs="|$cat_subdirs"
    fi

    # ...but output this DirectoryMatch _always_, since it includes
    # files|images|styles

    cat <<EOT

  <DirectoryMatch ^${docroot}/(files|images|styles$cat_subdirs)>
    Options MultiViews FollowSymLinks
    AllowOverride Indexes
    Order Allow,Deny
    Allow from all
  </DirectoryMatch>

EOT
    # In case order could affect things, let's put the site-specific
    # httpconf bits here. I think putting them before that catch-all
    # ScriptAlias is probably a good idea!

    if [ -f $dir/httpconf ]; then
        . $dir/httpconf
    fi
    cat <<EOT
  RedirectMatch	^/$		http://$sub.$dom/show
  RedirectMatch	^/out/(.*)	\$1

  Alias		/robots.txt	${wiki}/files/robots.txt.${sitemode}
  AliasMatch	^/(file|image|style)/(.*)	${docroot}/\$1s/\$2
  AliasMatch	^/_(image|style)/(.*)		${wiki}/\$1s/\$2
  ScriptAlias	/		${wiki}/actions/
  SetEnv	SITEMODE	${sitemode}
</VirtualHost>
EOT
    ) > ${vhosts}/$sub.$dom
}

populate_docroot () {
    mkdir -p ${docroot}

    # Initialise a Git repo for docroot
    [ ! -d ${docroot}/.git ] && GIT_DIR=${docroot}/.git GIT_WORK_TREE=${docroot} git init

    pagesdir="pages"
    for d in files images styles $pagesdir ; do
        mkdir -p ${docroot}/$d
    done
    # copy "seed" pages over, expanding shell vars in markup
    if [ -d ${wiki}/pages ]; then
        echo "Copying seed pages to ${docroot}"
        now=$(date +%s)
        for page in ${wiki}/pages/*; do
            name=$(basename $page)
            newpage=${docroot}/$pagesdir/$name
            mkdir -p $newpage
            if [ ! -f $newpage/markup ]; then
                sed -e "s#\${docroot_full}#$docroot#g" \
                    -e "s#\${docroot}#$dom#g" \
                    < $page/markup > $newpage/markup
                echo "$now" > $newpage/modtime
            fi
        done
    else
        echo "Can't copy seed pages. ${wiki} not found."
    fi

    # generate a config.perl if there isn't already one
    conffile=${docroot}/config.perl
    [ ! -f ${conffile} ] && cat <<EOT > ${conffile}
# This file is for local (site) configuration of the wiki script.
# PLEASE change these values from their defaults!

## The basics
\$wikiname = "My wiki";
\$defaultpage = "InstalledSuccessfully";
\$iconsrc = "_image/lambda";
\$iconalt = "We love functional programming!";

## Fill these in; feel free to add others. These turn into <meta />
## elements.
%metas = (
#    keywords    => "",
#    description => "",
    copyright   => "All content on $dom is copyrighted. All rights are reserved."
);

## Where is Git?
\$git = "/usr/local/bin/git";

## typographic style
\$convert_endash = 1;
\$convert_emdash = 0;        # I think it's ugly; you're free to disagree. ;-)
\$convert_quotes = 1;

## Fill these out if you want flickr badges of your pix; badges of public
## pix will work even if these are left empty.
\$flickr_user = "";
\$flickr_name = "";
EOT
}

subdomain () {
    dir=$1
    echo Generating $sub.$dom from $dir
    gen_domain_vhost
}

gen_domain () {
    docroot=${www_root}/data/$dom
    populate_docroot
    cd $dom
    for sub in *; do
        [ -d $sub ] && (cd .. && subdomain $dom/$sub)
    done
    cd ..
}

gen_domains () {
    for dom in *; do
        if [ ! -f $dom/disabled ]; then gen_domain; fi
    done
}

welcome_msg () {
    cat <<EOT

There are three things to do to make your new sites live:

(1) Copy this line into the end of your main Apache httpd.conf:

  Include ${conf}

(2) Set the ownership and permissions on each site's pages directory, so
the web server can write to them. Assuming that Apache is running as
www:www, do this:

  # chgrp -R www ${pages}
  # chmod -R g+w ${pages}

(3) Restart Apache. You should be good to go!

EOT
}

mkdir -p ${vhosts}
rm -f ${vhosts}/*

gen_server_config
(cd domains; gen_domains)
welcome_msg

