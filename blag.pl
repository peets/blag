#!/usr/bin/env perl
use strict;
use warnings;

use DateTime;
use DateTime::Format::Atom;
use Text::Caml;
use URI::Escape;

my $NOW = DateTime::Format::Atom->new->format_datetime(DateTime->now);

# config
my $N_FRONTPAGE_ENTRIES = 5;
my $N_FEED_ENTRIES = 10;
my $BLAG_URL = 'http://ppplog.net';
my $SRCDIR = '/home/peets/blags';
my $DESTDIR = '/home/peets/proj/ppplog.net';
my $BLAGREL = 'blag';
my $AUTHOR = 'Pierre-Paul Paquin';

# templates
# Text::Caml's documentation says nothing about partials that aren't in separate files,
# but using perl's string interpolation is exactly the same as inserting a partial.
# So instead of `register_partial('links', $partial)`, I do `$LINKS = $partial`.
my $LINKS = qq{
	<div class="row">
		<span class="span4" style="text-align: left"><a href="$BLAG_URL/">Home</a> - <a href="$BLAG_URL/about.html">About</a> - <a href="$BLAG_URL/archive.html">Archive</a></span>
		<span class="span4" style="text-align: center"><img class="my-icon" src="$BLAG_URL/ppplog/feed.png" alt=""> feeds: <a href="$BLAG_URL/logs.xml">Logs</a> - <a href="$BLAG_URL/ramblings.xml">Ramblings</a> - <a href="$BLAG_URL/combined.xml">Combined</a></span>
		<span class="span4" style="text-align: right"><i class="icon-globe"></i> elsewhere: <a href="http://www.rundjet.com">Djet</a> - <a href="http://twitter.com/derpeets">Twitter</a> - <a href="http://github.com/peets">Github</a></span>
	</div>
};
my $HEAD =  qq|<!DOCTYPE html>
<html>
<head>
	<title>{{title}}</title>
	<meta name="description" content="Blag of Pierre-Paul Paquin, a web developer currently building Djet, a logic-less web framework">

	<link href="$BLAG_URL/combined.xml"  type="application/atom+xml" rel="alternate" title="ATOM Feed (ramblings and logs)">
	<link href="$BLAG_URL/ramblings.xml" type="application/atom+xml" rel="alternate" title="ATOM Feed (ramblings only)">
	<link href="$BLAG_URL/logs.xml"      type="application/atom+xml" rel="alternate" title="ATOM Feed (logs only)">

	<link rel="stylesheet" href="$BLAG_URL/bootstrap/css/bootstrap.min.css">
	<link rel="stylesheet" href="$BLAG_URL/ppplog/style.css">

	<script type="text/javascript" src="$BLAG_URL/jquery/jquery.js"></script>
	<script type="text/javascript" src="$BLAG_URL/bootstrap/js/bootstrap.min.js"></script>
</head>

<body>
<div class="header container">
	<h1><a href="$BLAG_URL/">ppplog.net</a></h1>
	$LINKS
</div>
<div class="container">
|;
my $TAIL = qq|
</div>
<div class="footer container">
	<p class="row"><i class="span6"><small>That's all folks!</small></i><span class="span6" style="text-align: right">Write me: <img title="gee I hope spahmbots aren't smart enough to ocr this" src="ppplog/plznocr.png"></span></p>
	$LINKS
	<p class="muted" style="margin-top: 1.5em; text-align: center;"><small class="muted"><a href="$BLAG_URL/$BLAGREL/r2013-01-14a%20So%20I%20Wrote%20a%20Throwaway%20Blag%20Engine.html">Hand powered</a> - <a href="http://www.kontego.net">Kindly hosted by Kontego Networks</a></small></p>
</div>
</body>
|;
my $BLAG = qq|<h2><a href="$BLAG_URL/{{escaped}}">{{title}}</a></h2>\n<div class=\"blagdate\">{{type}} from {{date}}</div>\n{{&content}}
<p style="text-align: right; font-size: 60px; line-height: 80px; color: rgba(0, 0, 0, 0.15);">.</p>\n|;
my $LINK = qq|<a href="$BLAG_URL/{{escaped}}">{{date}} - {{title}}</a>|;

my %TEMPLATES = (
	'blag' => qq|$HEAD
$BLAG
<div class="row">
<div class="span6">
{{#prev}}
	<a rel="prev" href="$BLAG_URL/{{escaped}}">later post: {{title}}</a>
{{/prev}}
</div>
<div class="span6" style="text-align: right">
{{#next}}
	<a rel="next" href="$BLAG_URL/{{escaped}}">earlier post: {{title}}</a>
{{/next}}
</div>
</div>
$TAIL
|,

	'home' => qq|$HEAD
{{#blags}}
	$BLAG
{{/blags}}
$TAIL
|,

	'about' => qq|$HEAD
<h2>About</h2>
<p>Allo, I'm Pierre-Paul. I like to think about problems. This blag aims to chronicle my attempt at <em>solving</em> one problem: making good web apps is still
too hard.</p>
<p>There are two kinds of posts here. <em>Logs</em> are brief progress updates about my main project. <em>Ramblings</em> are longer format essays
that I hope are entertaining or useful to you.</p>
<p>gl hf</p>
$TAIL
|,

	'archive' => qq|$HEAD
<h2>Archive</h2>
<h3>Ramblings</h3>
{{#ramblings}}
	$LINK
{{/ramblings}}
<h3>Logs</h3>
{{#logs}}
	$LINK
{{/logs}}
$TAIL
|,

	'feed' => qq|<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
<title>ppplog.net {{feed}}</title>
<link rel="self" href="{{file}}"/>
<link rel="alternate" href="$BLAG_URL/"/>
<updated>$NOW</updated>
<author><name>$AUTHOR</name></author>
<id>$BLAG_URL/</id>

{{#blags}}
<entry>
	<title>{{title}}</title>
	<link href="$BLAG_URL/{{escaped}}"/>
	<id>$BLAG_URL/{{escaped}}</id>
	<updated>{{mtime}}</updated>
	<content type="html">
	{{content}}
	</content>
</entry>
{{/blags}}

</feed>
|,
);


# get blag data
my %blags = ();
opendir(my $dh, $SRCDIR) or die "failed to open dir $SRCDIR: $!";
while(readdir $dh) {
	my $file = $_;
	if(-f "$SRCDIR/$file") {
		$file =~ /^(r?)(\d\d\d\d-\d\d-\d\d)(\S*)\s+(.*)/ or die "couldn't understand filename $SRCDIR/$file";
		my($is_rambling, $date, $suffix, $title) = ($1, $2, $3, $4);

		my $id = "$date$suffix";
		exists $blags{$id} and die "non-unique id '$id' (file $file)";

		my $type = ($is_rambling ? 'rambling' : 'log');

		my $content = do {
			local $/ = undef;
			open(my $fh, "-|", "markdown", "$SRCDIR/$file") or die "failed markdown pipe: $!";
			<$fh>;
		};

		my $mtime = DateTime::Format::Atom->new->format_datetime(DateTime->from_epoch( epoch => (stat("$SRCDIR/$file"))[9] ));

		$blags{$id} = {
			'date' => $date,
			'title' => $title,
			'content' => $content,
			'type' => $type,
			'filename' => "$file.html",
			'escaped' => "$BLAGREL/" . uri_escape("$file.html"),
			'mtime' => $mtime,
		}
	}
}

# sort blags
my(@frontpage, @combined_feed, @log_feed, @rambling_feed, @logs, @ramblings, $prev);
foreach my $k (reverse sort keys %blags) {
	my $blag = $blags{$k};
	if($prev) {
		$blag->{'prev'} = $prev;
		$prev->{'next'} = $blag;
	}
	$prev = $blag;

	# add to frontpage if applicable
	@frontpage < $N_FRONTPAGE_ENTRIES and push(@frontpage, $blag);

	# add to feeds if applicable
	@combined_feed < $N_FEED_ENTRIES and push(@combined_feed, $blag);
	@log_feed < $N_FEED_ENTRIES and $blag->{'type'} eq 'log' and push(@log_feed, $blag);
	@rambling_feed < $N_FEED_ENTRIES and $blag->{'type'} eq 'rambling' and push(@rambling_feed, $blag);

	# add to archive
	$blag->{'type'} eq 'log' and push(@logs, $blag);
	$blag->{'type'} eq 'rambling' and push(@ramblings, $blag);
}

# setup print job
my %print_job = (
	'home' => { 'index.html' => { 'title' => 'ppplog.net, the homepage of Pierre-Paul Paquin', 'blags' => \@frontpage } },
	'feed' => { 'combined.xml' => { 'blags' => \@combined_feed, 'file' => 'combined.xml', 'feed' => 'combined' },
	            'logs.xml' => { 'blags' => \@log_feed, 'file' => 'logs.xml', 'feed' => 'logs' },
	            'ramblings.xml' => { 'blags' => \@rambling_feed, 'file' => 'ramblings.xml', 'feed' => 'ramblings' },
	          },
	'archive' => { 'archive.html' => { 'logs' => \@logs, 'ramblings' => \@ramblings, 'title' => 'Archive - ppplog.net' } },
	'about' => { 'about.html' => { 'title' => 'About - ppplog.net' } },
	'blag' => {},
);
# add individual blag entries to print job
foreach my $blag (values %blags) {
	$print_job{'blag'}->{"$BLAGREL/" . $$blag{'filename'}} = $blag;
}

# print
while(my($template, $files) = each %print_job) {
	while(my($file, $data) = each %$files) {
		open(my $fh, ">", "$DESTDIR/$file") or die "failed to open '$DESTDIR/$file' for writing: $!";
		print $fh Text::Caml->new->render($TEMPLATES{$template}, $data);
	}
}
