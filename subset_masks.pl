#!/usr/bin/perl
#
# subset_masks.pl
# Eric Nawrocki
# EPN, Wed Dec  5 18:08:26 2007
#
# Usage: perl subset_masks.pl
#             <mask 1 (1s, 0s, single line, no spaces) of length <x>>
#             <mask 2 (1s, 0s, single line, no spaces) of length <x>>
#             <output file for new mask>
#             
# Synopsis:
# Mask 1 has <y> columns, mask 2 has <z> columns. <y> must be greater than <z>.
# The set of columns with a 1 in mask 2 must be a subset of the columns with
# a 1 in mask 1. Print a new mask of length <y> with <z> 1s, a 1 for each
# column that has a 1 in both mask 1 and mask 2.
#

$usage = "Usage: perl subset_masks.pl\n\t<mask 1 (1s, 0s, single line, no spaces) of length <x>>\n\t<mask 2 (1s, 0s, single line, no spaces) of length <x>>\n\t<output file for new mask>\n\n";

if(@ARGV != 3)
{
    print $usage;
    exit();
}

($lm1_file, $lm2_file, $out_file) = @ARGV;

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

$new_lm = "";
$do_exit = 0;
for($i = 0; $i < scalar(@lm1_A); $i++) {
    if    ($lm1_A[$i] == 1 && $lm2_A[$i] == 1) { $new_lm .= '1'; $len++; $n1s++; }
    elsif ($lm1_A[$i] == 1 && $lm2_A[$i] == 0) { $new_lm .= '0'; $len++; }
    elsif ($lm1_A[$i] == 0 && $lm2_A[$i] == 1) { printf("ERROR column: $i is a 0 in lm1 and 1 in lm2, violation.\n"); $do_exit = 1; }
    elsif ($lm1_A[$i] == 0 && $lm2_A[$i] == 0) { ; } 
}
if($do_exit) { exit(1); }

# make sure we only had 1s and 0s
$lm1 =~ s/1//g;
$lm2 =~ s/1//g;
$lm1 =~ s/0//g;
$lm2 =~ s/0//g;
if($lm1 ne "") { printf("ERROR, mask 1 has non-1/0 chars: $lm1\n"); exit(1); }
if($lm2 ne "") { printf("ERROR, mask 1 has non-1/0 chars: $lm2\n"); exit(1); }

printf("New mask length            %4d\n", $len);
printf("Number of 1s                   %4d\n", $n1s);

open(OUT, ">" . $out_file);
print OUT $new_lm . "\n";
close(OUT);
printf("\nA new mask was written to $out_file.\n");


