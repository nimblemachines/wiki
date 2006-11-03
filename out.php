<?php

// $Id$

// Make a record of when someone *leaves* the site. All off-site links go
// thru this script. All it does is redirects to the URI in the query
// string.

$uri =  $_SERVER['QUERY_STRING'];
header("Location: $uri");

// header("Location: {$_SERVER['QUERY_STRING']}");
// also works, but it's hard to read & parse. You need the extra { } to
// parse the more complicated array reference.
?>
