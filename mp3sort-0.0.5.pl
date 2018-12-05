#!/usr/bin/perl

####
# mp3sort.pl - MP3 Sorter which sorts mp3s according to tags. 
####

my $VERSION = "0.0.5";

## Changelog:
# v.0.0.4 - Removes whitespaces from tags and corrects them on copy 
# v.0.0.3 - Made it actually usefull, fixed some behaviour
# v.0.0.2 - Added Most wanted functions
# v.0.0.1 - Initial private Release


## Todo:
# - Check for sane tags. 
# - Proper return value and behaviour on no arguments


## Done:
# x Define exceptions and sort them differnetly
# x Remove exessive whitespace from end of tag
# x Check wheter path exists before attempting to mkpath
# x Support for ogg
# x Take filename as argument
# x check empty tags tags with whitespace 
# x remove trailing whitespace from tags
# x replaced tracks '05/10' witth '05 of 10'
# x fixed a logic bug when no album is defined

## Wishlist:
# - check for "cd2" in album tag move it to disc tag 
# - move/copy switch
# - recurse switch
# - verbosity switch
# - find mp3s automatically
# - recurse sub dir
# - Check mp3 integrity 
# - In case of file allready exists, create md5sum of both 
#  - if match then discard one side
#  - safe duplicates by name somewhere else  
#  - move the one with higher bitrate to the dir 
# - Sort duplicates compare bitrates/length
# - Uppercase first Letter of Artist and in case of more than one word
#   all following words aswell. 
# - Check Title against kown lists of artist, for stupid tagger people. 


#use strict;
use Image::ExifTool;
use File::Copy;
use File::Path;

$filename = "@ARGV[0]";
$music_repo = "/mnt/audio/music_sorted";

# These should be matched caseless
@inval_artist_tags = ( "Artist", "No Artist", "Various", 'V/A', "VA", "Various Artists", "Diverse","_NOARTIST" );


#### CODE #### 

$exifTool = new Image::ExifTool;
$exifTool_newfile = new Image::ExifTool;


# Extract Information from File on argumentlist 
$error_on_read = $exifTool->ExtractInfo($filename);
#if ( not $error_on_read eq "1" ) {
#	print STDERR "Failed to read tags from $filename \n";
#	exit $error_on_read;
#}



# Get Filetype and Check it. 
$filetype = Image::ExifTool::GetFileType($filename);
$filetype = lc($filetype);

# Bail on unknown format
if ( not $filetype eq "mp3" || "ogg" ) {
	print STDERR "$filename is not an mp3 or ogg file.\n";
	exit 1;
}
@avail_tags = $exifTool->GetFoundTags($filename);


foreach (@avail_tags) { 
	if ( $_ == "Album" ) {
	$has_album = 1;
	}
}


# Fetch Values from File
$artist = $exifTool->GetValue(Artist);
$title = $exifTool->GetValue(Title);
$album = $exifTool->GetValue(Album);
$track = $exifTool->GetValue(Track);
$disc = $exifTool->GetValue(PartOfSet);


###
# SCAN+Clean Tags 
###

# Scan for empty tags
@tags = ( $artist,$title,$album,$track,$disc );

# Remove Slashes
# Remove Blanks at EOS
# Reduce Blank Tags to 0 Whitespace
for ( $i = 0 ; $i <= 4; $i++ ) {
	$tags[$i] =~ s/\ *$//g;
	$tags[$i] =~ s/\//+/g;
	$tags[$i] =~ s/^\s+$//g;
}

$tags[3] =~ s/\// of /;

$new_track = $tags[3];
$new_artist = $tags[0];
$new_title = $tags[1];
$new_album = $tags[2]; 

if ( not ${tags[4]} eq "" ) {
	$new_disc = "CD${tags[4]}"; 
}

#print "track $new_track\n";
#print "pretrack $track\n";
#print "artist $new_artist\n";
#print "album $new_album\n";
#print "title $new_title\n";

###
# LOGIC for sorting + Path Constuction
###

# Check for empty tags and apply logic
if ( $new_artist eq "") {
	if ( $new_title eq "" ) {
		print STDERR "No Title & Artist: $filename \n";
		exit 1;
	}
	print STDERR "No Artist: $filename \n";
	exit 1;
}

if ( $new_artist eq ""  ) {
	print STDERR "Bullshit tags detected: $new_artist in $filename \n";
	exit 1;
}

foreach (@inval_artist_tags) {
	if ( lc $new_artist eq lc $_ ) {
		print STDERR "ERROR: Bad tag in $new_artist = $_ $filename \n";
		exit 1;
	}
	next; 
}

if ( $new_album eq "" ) {
	$filepathandname = "$music_repo/$new_artist/$new_artist - $new_title.$filetype"; 
} else {
	if ( $new_track eq "" ) {
		print STDERR "Album but no Track specified! $filename\n";
		exit 1;
	}
	$filepathandname = "$music_repo/$new_artist/$new_album/$new_disc/$new_artist - $new_album - $new_track - $new_title.$filetype";
}





###
# Copy File after check,  
###

if (not -e "$music_repo/$new_artist/$new_album/$new_disc" ) {
	mkpath("$music_repo/$new_artist/$new_album/$new_disc") or die "Cannot create Path $music_repo/$new_artist/$new_album/$new_disc \n";
}

copy($filename,$filepathandname) or die "File $filename cannot be copied to $filepathandname.\n";





###
#  Write Sanatized tags
###

if ( not $new_title eq $title ) {
	$newfile_return_val = $exifTool_newfile->SetNewValue("Title", $new_title);
	print "Writing Title: $new_title to $filepathandname \n";
}


if ( not $new_album eq $album ) {
	if ( $new_album eq "" ) {
		if ( $has_album eq "" ) {
		print "Blanking Album: $filepathandname \n";
		$newfile_return_val = $exifTool_newfile->SetNewValue("Album", $new_album, DelValue => 1);
		}
	}
	else {
		print "Writing Album: $album $new_album $filepathandname \n";
		$newfile_return_val = $exifTool_newfile->SetNewValue("Album", $new_album);
	}
}

if ( not $new_artist eq $artist ) {
	$newfile_return_val = $exifTool_newfile->SetNewValue("Artist", $new_artist);
	print "Writing Artist: $new_artist to $filepathandname \n";
}
