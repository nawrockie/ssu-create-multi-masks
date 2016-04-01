#!/usr/bin/env perl
# EPN, Fri Apr  1 10:32:07 2016
#
use strict;
use warnings;
use Getopt::Long;
use Time::HiRes qw(gettimeofday);

require "epn-options.pm";
require "dnaorg.pm";

# hard-coded-paths:
my $exec_dir   = "/home/nawrocke/bin/";

#########################################################
# Command line and option processing using epn-options.pm
#
# opt_HH: 2D hash:
#         1D key: option name (e.g. "-h")
#         2D key: string denoting type of information 
#                 (one of "type", "default", "group", "requires", "incompatible", "preamble", "help")
#         value:  string explaining 2D key:
#                 "type":          "boolean", "string", "int" or "real"
#                 "default":       default value for option
#                 "group":         integer denoting group number this option belongs to
#                 "requires":      string of 0 or more other options this option requires to work, each separated by a ','
#                 "incompatiable": string of 0 or more other options this option is incompatible with, each separated by a ','
#                 "preamble":      string describing option for preamble section (beginning of output from script)
#                 "help":          string describing option for help section (printed if -h used)
#                 "setby":         '1' if option set by user, else 'undef'
#                 "value":         value for option, can be undef if default is undef
#
# opt_order_A: array of options in the order they should be processed
# 
# opt_group_desc_H: key: group number (integer), value: description of group for help output
my %opt_HH = ();      
my @opt_order_A = (); 
my %opt_group_desc_H = ();

# Add all options to %opt_HH and @opt_order_A.
# This section needs to be kept in sync (manually) with the &GetOptions call below
##     option            type       default               group   requires incompat    preamble-output                          help-output    
opt_Add("-h",           "boolean", 0,                        0,    undef, undef,       undef,                                   "display this help",                       \%opt_HH, \@opt_order_A);
$opt_group_desc_H{"1"} = "basic options";
opt_Add("-f",           "boolean", 0,                        1,    undef, undef,       "forcing directory overwrite",           "force; if dir <output dir> exists, overwrite it", \%opt_HH, \@opt_order_A);
opt_Add("-v",           "boolean", 0,                        1,    undef, undef,       "be verbose",                            "be verbose; output commands to stdout as they're run", \%opt_HH, \@opt_order_A);
opt_Add("-w",           "integer", 500,                      1,    undef, undef,       "allow <n> minutes for ssu-align jobs on farm",  "allow <n> minutes for ssu-align on farm to finish", \%opt_HH, \@opt_order_A);
$opt_group_desc_H{"2"} = "options for specifying domain-specific fasta files";
opt_Add("--archaea",    "string",  undef,                    2,    undef, undef,       "archaeal  sequence fasta file is <s>",  "archaeal  sequence fasta file is <s>",    \%opt_HH, \@opt_order_A);
opt_Add("--bacteria",   "string",  undef,                    2,    undef, undef,       "bacterial sequence fasta file is <s>",  "bacterial sequence fasta file is <s>",    \%opt_HH, \@opt_order_A);
$opt_group_desc_H{"3"} = "options affecting posterior probability based masking steps";
opt_Add("--pf",         "real",    "0.95",                   3,    undef, undef,       "include columns w/<x> fraction of seqs w/prob >= --pt <y>",  "include columns w/<x> fraction of seqs w/prob >= --pt <y>", \%opt_HH, \@opt_order_A);
opt_Add("--pt",         "real",    "0.95",                   3,    undef, undef,       "set probability threshold as <x>",                           "set probability threshold as <x>", \%opt_HH, \@opt_order_A);
$opt_group_desc_H{"4"} = "options for skipping stages and using files created in earlier runs";
opt_Add("--skipalign",  "boolean",  0,                        4,    undef, undef,       "skipping alignment stage, using alignments made in earlier run", "skipping alignment stage, using alignments made in earlier run", \%opt_HH, \@opt_order_A);

## This section needs to be kept in sync (manually) with the opt_Add() section above
my %GetOptions_H = ();
my $usage    = "Usage: ssu-create-multi-masks.pl [-options] <output dir>\n";
my $synopsis = "ssu-create-multi-masks.pl :: create masks of homologous positions for multiple domains";
#
my $options_okay = 
    &GetOptions('h'             => \$GetOptions_H{"-h"},
## basic options
                'f'             => \$GetOptions_H{"-f"},
                'v'             => \$GetOptions_H{"-v"},
                'w=s'           => \$GetOptions_H{"-w"},
## options for specifying input files
                'archaea=s'     => \$GetOptions_H{"--archaea"},
                'bacteria=s'    => \$GetOptions_H{"--bacteria"},
## options affecting posterior probability based masks
                'pf=s'          => \$GetOptions_H{"--pf"},
                'pt=s'          => \$GetOptions_H{"--pt"},
## options for skipping stages, using earlier results
                'skipalign'     => \$GetOptions_H{"--skipalign"});

my $total_seconds = -1 * secondsSinceEpoch(); # by multiplying by -1, we can just add another secondsSinceEpoch call at end to get total time
my $executable    = $0;
my $date          = scalar localtime();
my $version       = "0.1";
my $releasedate   = "Apr 2016";

# print help and exit if necessary
if((! $options_okay) || ($GetOptions_H{"-h"})) { 
  outputBanner(*STDOUT, $version, $releasedate, $synopsis, $date);
  opt_OutputHelp(*STDOUT, $usage, \%opt_HH, \@opt_order_A, \%opt_group_desc_H);
  if(! $options_okay) { die "ERROR, unrecognized option;"; }
  else                { exit 0; } # -h, exit with 0 status
}

# check that number of command line args is correct
if(scalar(@ARGV) != 1) {   
  print "Incorrect number of command line arguments.\n";
  print $usage;
  print "\nTo see more help on available options, do ssu-create-multi-masks.pl -h\n\n";
  exit(1);
}
my ($dir) = (@ARGV);

# set options in opt_HH
opt_SetFromUserHash(\%GetOptions_H, \%opt_HH);

# validate options (check for conflicts)
opt_ValidateSet(\%opt_HH, \@opt_order_A);

my $archaea_fafile  = opt_Get("--archaea", \%opt_HH);          # this will be undefined unless --archaea set on cmdline
my $bacteria_fafile = opt_Get("--bacteria", \%opt_HH);         # this will be undefined unless --archaea set on cmdline

# we require --archaea and --bacteria currently
if(! defined $archaea_fafile) { 
  die "ERROR --archaea not used, it has to be (currently)"; 
}
if(! defined $bacteria_fafile) { 
  die "ERROR --bacteria not used, it has to be (currently)"; 
}

#############################
# create the output directory
#############################
my $cmd;              # a command to run with runCommand()
my @early_cmd_A = (); # array of commands we run before our log file is opened
# check if the $dir exists, and that it contains the files we need
# check if our output dir $symbol exists
if($dir !~ m/\/$/) { $dir =~ s/\/$//; } # remove final '/' if it exists
if(opt_Get("--skipalign", \%opt_HH)) { 
  # validate dir exists
  if(! -d $dir) { 
    die "ERROR directory named $dir does not already exist. It must, because you used the --skipalign option."; }
}
else { 
  if(-d $dir) { 
    $cmd = "rm -rf $dir";
    if(opt_Get("-f", \%opt_HH)) { runCommand($cmd, opt_Get("-v", \%opt_HH), undef); push(@early_cmd_A, $cmd); }
    else                        { die "ERROR directory named $dir already exists. Remove it, or use -f to overwrite it."; }
  }
  if(-e $dir) { 
    $cmd = "rm $dir";
    if(opt_Get("-f", \%opt_HH)) { runCommand($cmd, opt_Get("-v", \%opt_HH), undef); push(@early_cmd_A, $cmd); }
    else                        { die "ERROR a file named $dir already exists. Remove it, or use -f to overwrite it."; }
  }
  # create the dir
  $cmd = "mkdir $dir";
  runCommand($cmd, opt_Get("-v", \%opt_HH), undef);
  push(@early_cmd_A, $cmd);
}

my $dir_tail = $dir;
$dir_tail =~ s/^.+\///; # remove all but last dir
my $out_root = $dir . "/" . $dir_tail . ".ssu-create-multi-masks";

#############################################
# output program banner and open output files
#############################################
# output preamble
my @arg_desc_A = ("output dir");
my @arg_A      = ($dir);
outputBanner(*STDOUT, $version, $releasedate, $synopsis, $date);
opt_OutputPreamble(*STDOUT, \@arg_desc_A, \@arg_A, \%opt_HH, \@opt_order_A);

# open the log and command files:
# set output file names and file handles, and open those file handles
my %ofile_info_HH = ();  # hash of information on output files we created,
                         # 1D keys: 
                         #  "fullpath":  full path to the file
                         #  "nodirpath": file name, full path minus all directories
                         #  "desc":      short description of the file
                         #  "FH":        file handle to output to for this file, maybe undef
                         # 2D keys:
                         #  "log": log file of what's output to stdout
                         #  "cmd": command file with list of all commands executed

# open the log and command files 
openAndAddFileToOutputInfo(\%ofile_info_HH, "log", $out_root . ".log", 1, "Output printed to screen");
openAndAddFileToOutputInfo(\%ofile_info_HH, "cmd", $out_root . ".cmd", 1, "List of executed commands");
openAndAddFileToOutputInfo(\%ofile_info_HH, "list", $out_root . ".list", 1, "List and description of all output files");
my $log_FH = $ofile_info_HH{"FH"}{"log"};
my $cmd_FH = $ofile_info_HH{"FH"}{"cmd"};
# output files are all open, if we exit after this point, we'll need
# to close these first.

# now we have the log file open, output the banner there too
outputBanner($log_FH, $version, $releasedate, $synopsis, $date);
opt_OutputPreamble($log_FH, \@arg_desc_A, \@arg_A, \%opt_HH, \@opt_order_A);

# output any commands we already executed to $log_FH
foreach $cmd (@early_cmd_A) { 
  print $cmd_FH $cmd . "\n";
}

###################################################
# make sure the required executables are executable
###################################################
my %execs_H = (); # hash with paths to all required executables
$execs_H{"ssu-align"}       = $exec_dir . "ssu-align";
$execs_H{"ssu-esl-alimap"}  = $exec_dir . "ssu-esl-alimap";
$execs_H{"ssu-mask"}        = $exec_dir . "ssu-mask";
validateExecutableHash(\%execs_H, $ofile_info_HH{"FH"});

############################################################################
# Step 1. Prepare the fasta files
############################################################################
my $FH_HR = $ofile_info_HH{"FH"}; # for convenience
my $progress_w = 80; # the width of the left hand column in our progress output, hard-coded
my $start_secs = outputProgressPrior("Preparing input for ssu-align", $progress_w, $log_FH, *STDOUT);

validateFileExistsAndIsNonEmpty($archaea_fafile,  "main", $FH_HR);
validateFileExistsAndIsNonEmpty($bacteria_fafile, "main", $FH_HR);
# they also need to end in .fa
if($archaea_fafile !~ m/\.fa$/) { 
  die "ERROR fasta files must end in \".fa\", $archaea_fafile does not."; 
}
if($bacteria_fafile !~ m/\.fa$/) { 
  die "ERROR fasta files must end in \".fa\", $bacteria_fafile does not."; 
}

# concatenate them:
my $archaea_root = removeDirPath($archaea_fafile);
$archaea_root =~ s/.fa$//;
my $bacteria_root = removeDirPath($bacteria_fafile);
$bacteria_root =~ s/.fa$//;
my $concat_file = $dir . "/". $archaea_root . "-" . $bacteria_root . ".fa";

runCommand("cat $archaea_fafile $bacteria_fafile > $concat_file", opt_Get("-v", \%opt_HH), $FH_HR);
outputProgressComplete($start_secs, undef, $log_FH, *STDOUT);

#############################################################################
# Step 2. Submit 6 ssu-align jobs to the cluster and wait for them to finish
#############################################################################
my $desc_string = (opt_Get("--skipalign", \%opt_HH)) ? 
    "Verifying ssu-align alignments exist (due to --skipalign)" : 
    "Submitting ssu-align jobs to cluster and waiting for them to finish";

$start_secs = outputProgressPrior($desc_string, $progress_w, $log_FH, *STDOUT);
  
my $njobs_submitted = 0;
my @sum_file_A = (); # all of the .sum files created by ssu-align
my @stk_file_A = (); # all of the .stk files created by ssu-align
foreach my $domain ("archaea", "bacteria") { 
  foreach my $fafile ($archaea_fafile, $bacteria_fafile, $concat_file) { 
    $njobs_submitted++;
    my $fafile_root = removeDirPath($fafile);
    $fafile_root =~ s/\.fa$//;
    my $dir_root = $fafile_root . "-to-" . $domain;
    my $out_dir = $dir . "/" . $dir_root;
    my $ssu_align_cmd = $execs_H{"ssu-align"} . " -f -n $domain --no-search $fafile $out_dir";
    my $jobname = "ssu-align." . $dir_root; 
    my $errfile = "ssu-align." . $dir_root . ".err";
    my $farm_cmd = "qsub -N $jobname -b y -v SGE_FACILITIES -P unified -S /bin/bash -cwd -V -j n -o /dev/null -e $errfile -m n -l h_rt=288000,h_vmem=8G,mem_free=8G -pe multicore 4 -R y " . "\"" . $ssu_align_cmd . "\" > /dev/null\n";
    my $ssu_align_sum_file = $out_dir . "/" . $dir_root . ".ssu-align.sum";
    my $ssu_align_stk_file = $out_dir . "/" . $dir_root . ".$domain.stk";
    if(! (opt_Get("--skipalign", \%opt_HH))) { 
      runCommand($farm_cmd, 0, $FH_HR);
    }
    push(@sum_file_A, $ssu_align_sum_file);
    push(@stk_file_A, $ssu_align_stk_file);
  }
}

if(opt_Get("--skipalign", \%opt_HH)) { 
  # validate all alignments exist
  foreach my $stk_file (@stk_file_A) { 
    validateFileExistsAndIsNonEmpty($stk_file, "main", $FH_HR);
  }
}
else { # --skipalign not used, wait for jobs to finish
  my $njobs_finished = wait_for_farm_jobs_to_finish(\@sum_file_A, "# SSU-ALIGN-SUCCESS", opt_Get("-w", \%opt_HH));
  if($njobs_finished != $njobs_submitted) { 
    DNAORG_FAIL(sprintf("ERROR in main() only $njobs_finished of the $njobs_submitted are finished after %d minutes. Increase wait time limit with -w", opt_Get("-w", \%opt_HH)), 1, \%{$ofile_info_HH{"FH"}});
  }
}
outputProgressComplete($start_secs, undef, $log_FH, *STDOUT);

##########
# Conclude
##########

$total_seconds += secondsSinceEpoch();
outputConclusionAndCloseFiles($total_seconds, $dir, \%ofile_info_HH);
exit 0;

###############
# SUBROUTINES #
###############

#################################################################
# Subroutine : wait_for_farm_jobs_to_finish()
# Incept:      EPN, Mon Feb 29 16:20:54 2016
#
# Purpose: Wait for jobs on the farm to finish by checking the final
#          line of their output files (in @{$outfile_AR}) to see
#          if the final line is exactly the string
#          $finished_string. We'll wait a maximum of $nmin
#          minutes, then return the number of jobs that have
#          finished. If all jobs finish before $nmin minutes we
#          return at that point.
#
# Arguments: 
#  $outfile_AR:      path to the cmscan executable file
#  $finished_str:    string that indicates a job is finished e.g. "[ok]"
#  $nmin:            number of minutes to wait
# 
# Returns:     Number of jobs (<= scalar(@{$outfile_AR})) that have
#              finished.
# 
# Dies: never.
#
################################################################# 
sub wait_for_farm_jobs_to_finish { 
  my $sub_name = "wait_for_farm_jobs_to_finish()";
  my $nargs_expected = 3;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($outfile_AR, $finished_str, $nmin) = @_;

  my $njobs = scalar(@{$outfile_AR});
  my $nfinished      = 0;   # number of jobs finished
  my $cur_sleep_secs = 15;  # number of seconds to wait between checks, we'll double this until we reach $max_sleep, every $doubling_secs seconds
  my $doubling_secs  = 120; # number of seconds to wait before doublign $cur_sleep
  my $max_sleep_secs = 120; # maximum number of seconds we'll wait between checks
  my $secs_waited    = 0;   # number of total seconds we've waited thus far
  while($secs_waited < (($nmin * 60) + $cur_sleep_secs)) { # we add $cur_sleep so we check one final time before exiting after time limit is reached
    # check to see if jobs are finished, every $cur_sleep seconds
    sleep($cur_sleep_secs);
    $secs_waited += $cur_sleep_secs;
    if($secs_waited >= $doubling_secs) { 
      $cur_sleep_secs *= 2;
      if($cur_sleep_secs > $max_sleep_secs) { # reset to max if we've exceeded it
        $cur_sleep_secs = $max_sleep_secs;
      }
    }

    $nfinished = 0; # important to reset this
    for(my $i = 0; $i < $njobs; $i++) { 
      if(-s $outfile_AR->[$i]) { 
        my $final_line = `tail -n 1 $outfile_AR->[$i]`;
        chomp $final_line;
        if($final_line eq $finished_str) { 
          $nfinished++;
        }
      }
    }
    if($nfinished == $njobs) { 
      # we're done break out of it
      return $nfinished;
    }
  }
  
  return $nfinished;
}