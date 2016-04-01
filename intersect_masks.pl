#!/usr/bin/perl
#
# intersect_masks.pl
# Eric Nawrocki
# EPN, Fri Oct 19 17:48:58 2007
#
# Usage: perl intersect_masks.pl
#             <mask 1 (1s, 0s, single line, no spaces) of length <x>>
#             <mask 2 (1s, 0s, single line, no spaces) of length <x>>
#             
# Synopsis:
# Intersect 2 identically lengthed masks. New mask will have a '1'
# at any position where both mask 1 and 2 have a '1', and a '0' at
# all other positions.
#
$usage = "Usage: perl intersect_masks.pl\n\t<mask 1 (1s, 0s, single line, no spaces) of length <x>>\n\t<mask 2 (1s, 0s, single line, no spaces) of length <x>>\n\t<name for output mask>\n\n";

if(@ARGV != 3)
{
    print $usage;
    print $options_usage;
    exit();
}

($lm1_file, $lm2_file, $intersection_file) = @ARGV;

open(IN,  $lm1_file);
$lm1 = <IN>;
chomp $lm1;
@lm1_A = split("", $lm1);
close(IN);

open(IN,  $lm2_file);
$lm2 = <IN>;
chomp $lm2;
@lm2_A = split("", $lm2);
close(IN);

if(scalar(@lm1_A) != scalar(@lm2_A)) { printf("ERROR, mask 1 is (length %d) != length of mask 2 (%d)\n", scalar(@lm1_A), scalar(@lm2_A)); exit(1); }
$lm_len = scalar(@lm1_A);

$new_lm = ""; # only used if -i option enabled
for($i = 0; $i < scalar(@lm1_A); $i++) {
    if($lm1_A[$i] == 1) { $lm1_1s++; }
    if($lm2_A[$i] == 1) { $lm2_1s++; }
    if(($lm1_A[$i] == 1) && ($lm2_A[$i] == 1)) { 
	$overlap++;
	$new_lm .= '1';
    }
    else { $new_lm .= '0'; }
}
# make sure we only had 1s and 0s
$lm1 =~ s/1//g;
$lm2 =~ s/1//g;
$lm1 =~ s/0//g;
$lm2 =~ s/0//g;
if($lm1 ne "") { printf("ERROR, mask 1 has non-1/0 chars: $lm1\n"); exit(1); }
if($lm2 ne "") { printf("ERROR, mask 1 has non-1/0 chars: $lm2\n"); exit(1); }

printf("Mask length                %4d\n", $lm_len);
printf("Mask 1                     %4d 1s\t%4d 0s\n", $lm1_1s, ($lm_len - $lm1_1s));
printf("Mask 2                     %4d 1s\t%4d 0s\n", $lm2_1s, ($lm_len - $lm2_1s));
printf("Overlap of 1s                  %4d\n", $overlap);
printf("Overlap of 1s fraction total   %.4f\n", ($overlap/$lm_len));
printf("Overlap of 1s fraction mask 1  %.4f\n", ($overlap/$lm1_1s));
printf("Overlap of 1s fraction mask 2  %.4f\n", ($overlap/$lm2_1s));

open(OUT, ">" . $intersection_file);
print OUT $new_lm . "\n";
close(OUT);
printf("\nA new mask, the intersection of $lm1_file and $lm2_file was written to $intersection_file.\n");


