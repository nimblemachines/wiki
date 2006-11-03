<?php

// $Id$

// Make a record of when someone *leaves* the site. All off-site links go
// thru this script. All it does is redirects to the URI in the query
// string.

$uri =  $_SERVER['QUERY_STRING'];
header("Location: $uri");
?>
