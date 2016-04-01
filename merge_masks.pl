#!/usr/bin/perl
#
# merge_masks.pl
# Eric Nawrocki
# EPN, Mon Nov 12 09:01:11 2007
#
# Usage: perl merge_masks.pl
#             <mask 1 (1s, 0s, single line, no spaces) with <x> 1s>
#             <mask 2 (1s, 0s, single line, no spaces) of length <x>>
#             
# Synopsis:
# Given mask 1 of length <lm1> with <x> 1s and mask 2 of length <x> with <y> 1s, 
# write a new mask of length <lm1> with <y> 1s, those columns from mask 1
# that correspond with the <y> columns from mask 2.
$usage = "Usage: perl merge_masks.pl\n\t<mask 1 (1s, 0s, single line, no spaces) w/<x> 1s>\n\t<mask 2 (1s, 0s, single line, no spaces) of length <x>>\n\n";


if(@ARGV != 2)
{
    print $usage;
    exit();
}

($lm1_file, $lm2_file) = @ARGV;

open(IN,  $lm1_file);
$lm1 = <IN>;
chomp $lm1;
@lm1_A = split("", $lm1);
close(IN);

$lm1_1s = 0; 
for($apos = 0; $apos < scalar(@lm1_A); $apos++) 
{ 
    if($lm1_A[$apos] eq '1') { $lm1_1s++; }
}

open(IN,  $lm2_file);
$lm2 = <IN>;
chomp $lm2;
@lm2_A = split("", $lm2);
close(IN);

$lm2_1s = 0; 
for($apos = 0; $apos < scalar(@lm2_A); $apos++) 
{ 
    if($lm2_A[$apos] eq '1') { $lm2_1s++; }
}


if(scalar(@lm2_A) != $lm1_1s) { printf("ERROR, mask 1 has %d 1s != length of mask 2 (%d)\n", $lm1_1s, scalar(@lm2_A)); exit(1); }
$lm_len = scalar(@lm1_A);

$cpos = 0;
$new_lm = "";
$new_lm1s = 0;
for($i = 0; $i < scalar(@lm1_A); $i++) 
{
    if($lm1_A[$i] eq '1') 
    {
	if($lm2_A[$cpos] eq '1') 
	{ 
	    $new_lm .= '1';
	    $new_lm1s++;
	    $new_lm_len++;
	}
	else { $new_lm .= '0'; $new_lm_len++ }
	$cpos++;
    }
    else { $new_lm .= '0'; $new_lm_len++; }
}

if($new_lm1s != $lm2_1s) { printf("ERROR, new mask has %d 1s != number of 1s in mask 2 (%d)\n", $new_lm1s, $lm2_1s); exit(1); }
if($new_lm_len != scalar(@lm1_A)) { printf("ERROR, new mask length %d != mask 1 length (%d)\n", $new_lm_len, scalar(@lm1_A)); exit(1); }
   
# make sure we only had 1s and 0s
$lm1 =~ s/1//g;
$lm2 =~ s/1//g;
$lm1 =~ s/0//g;
$lm2 =~ s/0//g;
if($lm1 ne "") { printf("ERROR, mask 1 has non-1/0 chars: $lm1\n"); exit(1); }
if($lm2 ne "") { printf("ERROR, mask 1 has non-1/0 chars: $lm2\n"); exit(1); }

printf("$new_lm\n");
