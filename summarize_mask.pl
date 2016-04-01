#!/usr/bin/perl
#
# summarize_mask.pl
# Eric Nawrocki
# EPN, Thu Mar 17 21:24:28 2016
#
# Usage: perl summarize_mask.pl
#             <mask (1s, 0s, single line, no spaces) of length <x>>
#             
# Synopsis:
# Summarize (count 1s and 0s) in a mask file, and print that information
# out.
#
$usage = "Usage: perl summarize_mask.pl\n\t<mask (1s, 0s, single line, no spaces) of length <x>>\n\n";

if(@ARGV != 1)
{
    print $usage;
    print $options_usage;
    exit();
}

($lm_file) = ($ARGV[0]);

open(IN,  $lm_file) || die "ERROR unable to open $lm_file";
$lm = <IN>;
chomp $lm;
@lm_A = split("", $lm);
close(IN);

$lm_1s  = 0;
$lm_0s  = 0;
$lm_len = 0;
for($i = 0; $i < scalar(@lm_A); $i++) {
  if   ($lm_A[$i] == 1) { $lm_1s++; }
  elsif($lm_A[$i] == 0) { $lm_0s++; }
  else { die "ERROR unexpected value in mask: $lm_A[$i]\n"; }
  $lm_len++;
}
printf("Mask len: $lm_len\n");
printf("Num 1s:   $lm_1s\n");
printf("Num 0s:   $lm_0s\n");
