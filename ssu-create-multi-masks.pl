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
$opt_group_desc_H{"2"} = "options for specifying domain-specific files";
opt_Add("--arcfasta",    "string",  undef,                    2,    undef, undef,       "archaeal  sequence fasta file is <s>",  "archaeal  sequence fasta file is <s>",    \%opt_HH, \@opt_order_A);
opt_Add("--bacfasta",    "string",  undef,                    2,    undef, undef,       "bacterial sequence fasta file is <s>",  "bacterial sequence fasta file is <s>",    \%opt_HH, \@opt_order_A);
opt_Add("--arcmask",     "string",  undef,                    2,    undef, undef,       "archaeal  default mask file is <s>",    "archaeal  default mask file is <s>",      \%opt_HH, \@opt_order_A);
opt_Add("--bacmask",     "string",  undef,                    2,    undef, undef,       "bacterial default mask file is <s>",    "bacterial default mask file is <s>",      \%opt_HH, \@opt_order_A);
$opt_group_desc_H{"3"} = "options affecting coverage based masking steps";
opt_Add("--cthresh",     "real",    "0.90",                   3,    undef, undef,      "set coverage threshold as <x>",                              "set coverage threshold as <x>", \%opt_HH, \@opt_order_A);
$opt_group_desc_H{"4"} = "options for turning on and modifying posterior probability based masking steps";
opt_Add("--pp",          "boolean", 0,                        4,    undef, undef,       "merge coverage mask with posterior-probability based masks", "merge coverage mask with posterior-probability based masks instead of with default masks", \%opt_HH, \@opt_order_A);
opt_Add("--pthresh",     "real",    "0.90",                   4,   "--pp", undef,       "set probability threshold as <x>",                           "set probability threshold as <x>", \%opt_HH, \@opt_order_A);
opt_Add("--pfract",      "real",    "0.90",                   4,   "--pp", undef,       "include columns w/<x> fraction of seqs w/prob >= --pthresh <y>",  "include columns w/<x> fraction of seqs w/prob >= --pthresh <y>", \%opt_HH, \@opt_order_A);
$opt_group_desc_H{"5"} = "options for skipping stages and using files created in earlier runs";
opt_Add("--skipalign",  "boolean",  0,                        5,    undef, undef,       "skipping alignment stage, using alignments made in earlier run", "skipping alignment stage, using alignments made in earlier run", \%opt_HH, \@opt_order_A);

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
                'arcfasta=s'    => \$GetOptions_H{"--arcfasta"},
                'bacfasta=s'    => \$GetOptions_H{"--bacfasta"},
                'arcmask=s'     => \$GetOptions_H{"--arcmask"},
                'bacmask=s'     => \$GetOptions_H{"--bacmask"},
## options affecting coverage based masks
                'cthresh=s'     => \$GetOptions_H{"--cthresh"},
## options affecting posterior probability based masks
                'pp'            => \$GetOptions_H{"--pp"},
                'pthresh=s'     => \$GetOptions_H{"--pthresh"},
                'pfract=s'      => \$GetOptions_H{"--pfract"},
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

my $archaea_fafile       = opt_Get("--arcfasta", \%opt_HH);        # this will be undefined unless --arcfasta set on cmdline
my $bacteria_fafile      = opt_Get("--bacfasta", \%opt_HH);        # this will be undefined unless --bacfasta set on cmdline
my $archaea_df_maskfile  = opt_Get("--arcmask", \%opt_HH);         # this will be undefined unless --arcmask set on cmdline
my $bacteria_df_maskfile = opt_Get("--bacmask", \%opt_HH);         # this will be undefined unless --bacmask set on cmdline

my %cov_df_merged_mask_H = (); # key: domain (e.g. "archaea"), value mask file with merged cov+df mask
my %cov_pp_merged_mask_H = (); # key: domain (e.g. "archaea"), value mask file with merged cov+pp mask

# we require --archaea and --bacteria currently
if(! defined $archaea_fafile) { 
  die "ERROR --arcfasta not used, it has to be (currently)"; 
}
if(! defined $bacteria_fafile) { 
  die "ERROR --bacfasta not used, it has to be (currently)"; 
}
# we also require --arcmask and --bacmask unless --pp was used
if(! opt_Get("--pp", \%opt_HH)) { 
  if(! defined $archaea_df_maskfile) { 
    die "ERROR --arcmask not used, it has to be (currently)"; 
  }
  if(! defined $bacteria_df_maskfile) { 
    die "ERROR --bacmask not used, it has to be (currently)"; 
  }
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
$execs_H{"ssu-draw"}        = $exec_dir . "ssu-draw";
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
my @sum_file_A      = (); # all of the .sum files created by ssu-align
my @stk_file_A      = (); # all of the .stk files created by ssu-align
my @ssu_mask_cmd_A  = (); # all of the ssu-mask commands to run in step 3
my @ssu_mask_file_A = (); # all of the ssu-mask output files that will be created in step 3
my @out_dir_A       = (); # all of the output directories created by ssu-align 

my @concat_stk_file_A = (); # stk files created by ssu-align for alignments of concatenated fasta files
my @concat_out_dir_A  = (); # output directories created by ssu-align for alignments of concatenated fasta files

my %fafile_H = ();
$fafile_H{"archaea"}          = $archaea_fafile;
$fafile_H{"bacteria"}         = $bacteria_fafile;
$fafile_H{"archaea-bacteria"} = $concat_file;

foreach my $domain ("archaea", "bacteria") { 
  foreach my $key (sort keys %fafile_H) { 
    my $fafile   = $fafile_H{$key};
    my $out_root = create_out_root($fafile, $domain);
    my $out_dir  = $dir . "/" . $out_root;

    # the ssu-align command
    my $ssu_align_cmd = $execs_H{"ssu-align"} . " -f -n $domain --no-search $fafile $out_dir";

    my $jobname = "ssu-align." . $out_root; 
    my $errfile = "ssu-align." . $out_root . ".err";
    my $farm_cmd = "qsub -N $jobname -b y -v SGE_FACILITIES -P unified -S /bin/bash -cwd -V -j n -o /dev/null -e $errfile -m n -l h_rt=288000,h_vmem=8G,mem_free=8G -pe multicore 4 -R y " . "\"" . $ssu_align_cmd . "\" > /dev/null\n";
    $njobs_submitted++;

    my $ssu_align_sum_file = $out_dir . "/" . $out_root . ".ssu-align.sum";
    my $ssu_align_stk_file = $out_dir . "/" . $out_root . ".$domain.stk";
    if(! (opt_Get("--skipalign", \%opt_HH))) { 
      runCommand($farm_cmd, opt_Get("-v", \%opt_HH), $FH_HR);
    }
    push(@out_dir_A,  $out_dir);
    push(@sum_file_A, $ssu_align_sum_file);
    push(@stk_file_A, $ssu_align_stk_file);
  }
}

#    # if we're a concatenated alignment, we'll map these guys later
#    if($key eq "archaea-bacteria") { 
#      push(@concat_stk_file_A, $ssu_align_stk_file);
#      push(@concat_out_dir_A,  $out_dir);
#    }
#    else { # else if we're not a concatenated alignment, we'll mask later based on posterior probability
#      my $ssu_mask_cmd  = $execs_H{"ssu-mask"} . " $pf_option $pt_option $out_dir > /dev/null";
#      my $ssu_mask_file = $out_dir . "/" . $dir_root . ".$domain.mask";
#      push(@ssu_mask_cmd_A,  $ssu_mask_cmd);
#      push(@ssu_mask_file_A, $ssu_mask_file);

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

##################################################################
# Step 4. Run ssu-esl-alimap on the multi-domain alignments
##################################################################
# map the two alignments of the combined archaea+bacteria to each other
$start_secs = outputProgressPrior("Running ssu-esl-alimap on the alignments of the concatenated fasta files", $progress_w, $log_FH, *STDOUT);

my $key = "archaea-bacteria";
my $domain = "archaea";
my $fafile = $fafile_H{$key};

my $out_root_archaea  = create_out_root($fafile, "archaea");
my $out_root_bacteria = create_out_root($fafile, "bacteria");

my $out_dir_archaea   = $dir . "/" . $out_root_archaea;
my $out_dir_bacteria  = $dir . "/" . $out_root_bacteria;

my $ssu_align_stk_file_archaea  = $out_dir_archaea  . "/" . $out_root_archaea  . ".archaea.stk";
my $ssu_align_stk_file_bacteria = $out_dir_bacteria . "/" . $out_root_bacteria . ".bacteria.stk";

my $mask_file_archaea  = $out_dir_archaea  . ".mask";
my $mask_file_bacteria = $out_dir_bacteria . ".mask";

my $alimap_file_archaea  = $out_dir_archaea  . ".ssu-esl-alimap";
my $alimap_file_bacteria = $out_dir_bacteria . ".ssu-esl-alimap";

my $map_cmd_archaea  = $execs_H{"ssu-esl-alimap"} . " --mask-rf2rf $mask_file_archaea  $ssu_align_stk_file_archaea  $ssu_align_stk_file_bacteria > $alimap_file_archaea";
my $map_cmd_bacteria = $execs_H{"ssu-esl-alimap"} . " --mask-rf2rf $mask_file_bacteria $ssu_align_stk_file_bacteria $ssu_align_stk_file_archaea  > $alimap_file_bacteria";

runCommand($map_cmd_archaea,  opt_Get("-v", \%opt_HH), $FH_HR);
runCommand($map_cmd_bacteria, opt_Get("-v", \%opt_HH), $FH_HR);

addClosedFileToOutputInfo(\%ofile_info_HH, "map_archaea", $alimap_file_archaea,   1, sprintf("ssu-esl-alimap output for map of alignment %s to %s", removeDirPath($ssu_align_stk_file_archaea), removeDirPath($ssu_align_stk_file_bacteria)));
addClosedFileToOutputInfo(\%ofile_info_HH, "map_bacteria", $alimap_file_bacteria, 1, sprintf("ssu-esl-alimap output for map of alignment %s to %s", removeDirPath($ssu_align_stk_file_bacteria), removeDirPath($ssu_align_stk_file_archaea)));

my @tmp_mask_A = (); # temporary array storing mask file $mask_file_archaea or $mask_file_bacteria, used only for meaningful output in call to addClosedFileToOutputInfo() below
my $tmp_ninc = 0;    # temporary scalar storing number of included positions in mask file $mask_file_archaea or $mask_file_bacteria, used only for meaningful output in call to addClosedFileToOutputInfo() below

$tmp_ninc = parse_mask_file($mask_file_archaea, \@tmp_mask_A, $FH_HR);
addClosedFileToOutputInfo(\%ofile_info_HH, "mapmask_archaea", $mask_file_archaea,   1, sprintf("archaeal mask  (%d len, %d included) mapping alignment %s to %s", scalar(@tmp_mask_A)-1, $tmp_ninc, removeDirPath($ssu_align_stk_file_archaea), removeDirPath($ssu_align_stk_file_bacteria)));

$tmp_ninc = parse_mask_file($mask_file_bacteria, \@tmp_mask_A, $FH_HR);
addClosedFileToOutputInfo(\%ofile_info_HH, "mapmask_bacteria", $mask_file_bacteria, 1, sprintf("bacterial mask (%d len, %d included) mapping alignment %s to %s", scalar(@tmp_mask_A)-1, $tmp_ninc, removeDirPath($ssu_align_stk_file_bacteria), removeDirPath($ssu_align_stk_file_archaea)));

outputProgressComplete($start_secs, undef, $log_FH, *STDOUT);

######################################
# Step 5. Parse the esl-alimap output 
######################################
$start_secs = outputProgressPrior("Parsing ssu-esl-alimap output", $progress_w, $log_FH, *STDOUT);

my $rflen_archaea;           # nongap-RF length of archaeal model
my $rflen_bacteria;          # nongap-RF length of bacterial model
my @rf_archaea_map_A  = ();  # [0..$rfpos..$rflen_archaea-1] bacterial $rfpos this archaeal $rfpos maps to, -1 if none
my @rf_bacteria_map_A = ();  # [0..$rfpos..$rflen_bacteria-1] bacterial $rfpos this archaeal $rfpos maps to, -1 if none
my $rf_archaea_nmap;         # number of nongap-RF positions in archaea  that esl-alimap is able to map to bacteria
my $rf_bacteria_nmap;        # number of nongap-RF positions in bacteria that esl-alimap is able to map to archaea, should be same as $rf_archaea_nmap
my @rf_archaea_cov_A  = ();  # [0..$rfpos..$rflen_archaea_nmap-1] fraction of nucleotides aligned to $rfpos in archaea-based alignment
                             # that also exist in mapped position in the bacteria-based alignment
my @rf_bacteria_cov_A = ();  # [0..$rfpos..$rflen_bacteria_nmap-1] fraction of nucleotides aligned to $rfpos in bacteria-based alignment
                             # that also exist in mapped position in the archaea-based alignment

$rflen_archaea  = parse_esl_alimap_output($alimap_file_archaea,  \@rf_archaea_map_A,  \@rf_archaea_cov_A,  \$rf_archaea_nmap,  $FH_HR);
$rflen_bacteria = parse_esl_alimap_output($alimap_file_bacteria, \@rf_bacteria_map_A, \@rf_bacteria_cov_A, \$rf_bacteria_nmap, $FH_HR);

outputProgressComplete($start_secs, undef, $log_FH, *STDOUT);

######################################
# Step 6. Create coverage based masks
######################################
$start_secs = outputProgressPrior("Creating coverage-based masks", $progress_w, $log_FH, *STDOUT);

if($rf_archaea_nmap != $rf_bacteria_nmap) { 
  DNAORG_FAIL(sprintf("ERROR, number of mapped positions differs between archaeal and bacteria maps, this shouldn't happen; archaea: %d != bacteria: %d", $rf_archaea_nmap, $rf_bacteria_nmap), 1, $FH_HR);
}

# create the new coverage-based mask for archaea, 
# rfpos $rfpos is a '1' (included by the mask) iff:
# - it maps to a position ($rfpos_bacteria) in bacteria
# - the coverage of $rfpos_archaea  in the archaeal  alignment >= $cov_thresh
# - the coverage of $rfpos_bacteria in the bacterial alignment >= $cov_thresh
my $rfpos_archaea;
my $rfpos_bacteria;
my $cov_thresh = opt_Get("--cthresh", \%opt_HH);
my @rf_archaea_cov_mask_A = ();  # [1..$rfpos_archaea $rflen_archaea]: '1' if position $rfpos_archaea
                                 # is included by coverage based mask, else '0'
my @rf_bacteria_cov_mask_A = (); # [1..$rfpos_bacteria $rflen_bacteria]: '1' if position $rfpos_bacteria
                                 # is included by coverage based mask, else '0'

# get the mask in archaeal coordinates
for($rfpos_archaea = 1; $rfpos_archaea <= $rflen_archaea; $rfpos_archaea++) { 
  $rfpos_bacteria = $rf_archaea_map_A[$rfpos_archaea];
  # printf("rfpos_archaea: $rfpos_archaea, rfpos_bacteria: $rfpos_bacteria\n");
  if($rfpos_bacteria != -1) { 
    $rf_archaea_cov_mask_A[$rfpos_archaea] = (($rf_archaea_cov_A[$rfpos_archaea]   >= $cov_thresh) && 
                                              ($rf_bacteria_cov_A[$rfpos_bacteria] >= $cov_thresh)) ? 1 : 0;
  }
  else { 
    $rf_archaea_cov_mask_A[$rfpos_archaea] = 0; # this position in archaea wasn't mappable to a position in bacteria
  }
}

# get the mask in bacterial coordinates
for($rfpos_bacteria = 1; $rfpos_bacteria <= $rflen_bacteria; $rfpos_bacteria++) { 
  $rfpos_archaea = $rf_bacteria_map_A[$rfpos_bacteria];
  if($rfpos_archaea != -1) { 
    $rf_bacteria_cov_mask_A[$rfpos_bacteria] = (($rf_bacteria_cov_A[$rfpos_bacteria]   >= $cov_thresh) && 
                                              ($rf_archaea_cov_A[$rfpos_archaea] >= $cov_thresh)) ? 1 : 0;
  }
  else { 
    $rf_bacteria_cov_mask_A[$rfpos_bacteria] = 0; # this position in bacteria wasn't mappable to a position in archaea
  }
}

# output the masks
my $rf_archaea_cov_mask_file = $dir . "/" . create_out_root($fafile_H{"archaea-bacteria"}, "archaea") . ".cov.mask";
my $rf_archaea_cov_ninc = output_mask_file($rf_archaea_cov_mask_file, \@rf_archaea_cov_mask_A, $rflen_archaea, $FH_HR);
addClosedFileToOutputInfo(\%ofile_info_HH, "archaea_cov_mask", $rf_archaea_cov_mask_file, 1, sprintf("archaeal mask  (%d len, %d included) based on coverage (cthresh: %.2f) of map between archaeal- and bacterial-based alignments of all sequences", $rflen_archaea, $rf_archaea_cov_ninc, $cov_thresh));

my $rf_bacteria_cov_mask_file = $dir . "/" . create_out_root($fafile_H{"archaea-bacteria"}, "bacteria") . ".cov.mask";
my $rf_bacteria_cov_ninc = output_mask_file($rf_bacteria_cov_mask_file, \@rf_bacteria_cov_mask_A, $rflen_bacteria, $FH_HR);
addClosedFileToOutputInfo(\%ofile_info_HH, "bacteria_cov_mask", $rf_bacteria_cov_mask_file, 1, sprintf("bacterial mask (%d len, %d included) based on coverage (chtresh: %.2f) of map between archaeal- and bacterial-based alignments of all sequences", $rflen_bacteria, $rf_bacteria_cov_ninc, $cov_thresh));

# sanity check
if($rf_archaea_cov_ninc != $rf_bacteria_cov_ninc) { 
  DNAORG_FAIL(sprintf("ERROR, number of positions included for archaea in coverage based mask %d, differs from number of positions included for bacteria: %d", $rf_archaea_cov_ninc, $rf_bacteria_cov_ninc), 1, $FH_HR);
}

outputProgressComplete($start_secs, undef, $log_FH, *STDOUT);

#######################################################################
# Step 7 is performed by default, but is skipped if --pp used.
# If --pp is ued, steps 9-11 are performed instead.
#######################################################################
if(! opt_Get("--pp", \%opt_HH)) { 
  #################################################################################################
  # Step 7. Merge coverage-based and default 0.1 SSU-ALIGN masks into new masks (UNLESS --pp USED) 
  #################################################################################################
  $start_secs = outputProgressPrior("Merging coverage and SSU-ALIGN-0.1 based masks", $progress_w, $log_FH, *STDOUT);
  
  my @rf_archaea_df_mask_A   = ();           # the archaeal default mask
  my @rf_bacteria_df_mask_A  = ();           # the bacterial default mask
  my @rf_archaea_cov_df_merged_mask_A  = (); # the merged archaeal coverage and default mask
  my @rf_bacteria_cov_df_merged_mask_A = (); # the merged bacterial coverage and default mask

  $rf_archaea_df_mask_A[0]  = undef;
  $rf_bacteria_df_mask_A[0] = undef;
  $rf_archaea_cov_df_merged_mask_A[0]  = undef;
  $rf_bacteria_cov_df_merged_mask_A[0] = undef;
  
  # input the default masks (we have the other masks we need already stored
  parse_mask_file($archaea_df_maskfile,  \@rf_archaea_df_mask_A,  $FH_HR);
  parse_mask_file($bacteria_df_maskfile, \@rf_bacteria_df_mask_A, $FH_HR);
  
  # archaea
  for($rfpos_archaea = 1; $rfpos_archaea <= $rflen_archaea; $rfpos_archaea++) { 
    $rfpos_bacteria = $rf_archaea_map_A[$rfpos_archaea];
    if($rfpos_bacteria != -1) { 
      $rf_archaea_cov_df_merged_mask_A[$rfpos_archaea] = ($rf_archaea_cov_mask_A[$rfpos_archaea] &&
                                                          $rf_archaea_df_mask_A[$rfpos_archaea] && 
                                                          $rf_bacteria_df_mask_A[$rfpos_bacteria]) ? 1 : 0;
    }
    else { 
      $rf_archaea_cov_df_merged_mask_A[$rfpos_archaea] = 0;
    }
  }
  my $rf_archaea_cov_df_merged_mask_file = $dir . "/" . create_out_root($fafile_H{"archaea-bacteria"}, "archaea") . ".cov-and-df.mask";
  my $rf_archaea_cov_df_merged_ninc = output_mask_file($rf_archaea_cov_df_merged_mask_file, \@rf_archaea_cov_df_merged_mask_A, $rflen_archaea, $FH_HR);
  addClosedFileToOutputInfo(\%ofile_info_HH, "archaea_cov_df_merged_mask", $rf_archaea_cov_df_merged_mask_file, 1, sprintf("archaeal mask  (%d len, %d included) created by merging coverage (cthresh: %.2f) and default SSU-ALIGN 0.1 masks", 
                                                                                                                           $rflen_archaea, $rf_archaea_cov_df_merged_ninc, $cov_thresh));
  $cov_df_merged_mask_H{"archaea"} = $rf_archaea_cov_df_merged_mask_file;
  
  # bacteria
  for($rfpos_bacteria = 1; $rfpos_bacteria <= $rflen_bacteria; $rfpos_bacteria++) { 
    $rfpos_archaea = $rf_bacteria_map_A[$rfpos_bacteria];
    if($rfpos_archaea != -1) { 
      $rf_bacteria_cov_df_merged_mask_A[$rfpos_bacteria] = ($rf_bacteria_cov_mask_A[$rfpos_bacteria] &&
                                                            $rf_bacteria_df_mask_A[$rfpos_bacteria] && 
                                                            $rf_archaea_df_mask_A[$rfpos_archaea]) ? 1 : 0;
    }
    else { 
      $rf_bacteria_cov_df_merged_mask_A[$rfpos_bacteria] = 0;
    }
  }
  my $rf_bacteria_cov_df_merged_mask_file = $dir . "/" . create_out_root($fafile_H{"archaea-bacteria"}, "bacteria") . ".cov-and-df.mask";
  my $rf_bacteria_cov_df_merged_ninc = output_mask_file($rf_bacteria_cov_df_merged_mask_file, \@rf_bacteria_cov_df_merged_mask_A, $rflen_bacteria, $FH_HR);
  addClosedFileToOutputInfo(\%ofile_info_HH, "bacteria_cov_df_merged_mask", $rf_bacteria_cov_df_merged_mask_file, 1, sprintf("bacterial mask (%d len, %d included) created by merging coverage (cthresh: %.2f) and default SSU-ALIGN 0.1 masks", 
                                                                                                                             $rflen_bacteria, $rf_bacteria_cov_df_merged_ninc, $cov_thresh));
  $cov_df_merged_mask_H{"bacteria"} = $rf_bacteria_cov_df_merged_mask_file;
  
  # sanity check
  if($rf_archaea_cov_df_merged_ninc != $rf_bacteria_cov_df_merged_ninc) { 
    DNAORG_FAIL(sprintf("ERROR, number of positions included for archaea in merged mask cov and df mask %d, differs from number of positions included for bacteria: %d", $rf_archaea_cov_df_merged_ninc, $rf_bacteria_cov_df_merged_ninc), 1, $FH_HR);
  }
  
  outputProgressComplete($start_secs, undef, $log_FH, *STDOUT);
} # end of if (! opt_Get("--pp", \%opt_HH)) 

################################################################################################################
# Steps 9-11 are OPTIONAL, we only do them if --pp was used. These pertain to posterior-probability based masks
################################################################################################################
if(opt_Get("--pp", \%opt_HH)) { 
  #############################################################################################################################
  # Step 9. Run ssu-mask on each of the single domain sequence ssu-align created alignments (OPTIONAL, we do this if --pp used)
  #############################################################################################################################
  $start_secs = outputProgressPrior("Running ssu-mask on all of the ssu-align created alignments", $progress_w, $log_FH, *STDOUT);
  my %pp_mask_file_HH = (); # 2D hash, 1st dim key: model, 2nd dim key: sequences aligned 
  my $pf_option = "--pf " . opt_Get("--pfract", \%opt_HH);
  my $pt_option = "--pt " . opt_Get("--pthresh", \%opt_HH);
  my $pf_key    = "pf." . int(100 * opt_Get("--pfract", \%opt_HH));
  my $pt_key    = "pt." . int(100 * opt_Get("--pthresh", \%opt_HH));
  
  foreach my $domain ("archaea", "bacteria") { 
    foreach my $key (sort keys %fafile_H) { 
      my $fafile = $fafile_H{$key};
      my $out_root = create_out_root($fafile, $domain);
      my $out_dir  = $dir . "/" . $out_root;
      
      if($key ne "archaea-bacteria") { 
        # mask this alignment
        my $ssu_mask_cmd  = $execs_H{"ssu-mask"} . " $pf_option $pt_option $out_dir > /dev/null";
        my $ssu_mask_file = $out_dir . "/" . $out_root . ".$domain.mask";
        $pp_mask_file_HH{$domain}{$key} = $ssu_mask_file;
        runCommand($ssu_mask_cmd, opt_Get("-v", \%opt_HH), $FH_HR);
        # addClosedFileToOutputInfo(\%ofile_info_HH, "ssu-mask.$domain.$key", $ssu_mask_file, 1, sprintf("ssu-mask mask file for %s-based alignment of %s sequences", $domain, $key));
      }
    }
  }
  outputProgressComplete($start_secs, undef, $log_FH, *STDOUT);

  #######################################################################################
  # Step 10. Create posterior-probability based masks (OPTIONAL, we do this if --pp used)
  #######################################################################################
  my @rf_archaea_pp_joint_mask_A = ();  # [1..$rfpos_archaea $rflen_archaea]: '1' if position $rfpos_archaea
                                        # is included by the posterior probability-based mask, else '0'
  my @rf_bacteria_pp_joint_mask_A = (); # [1..$rfpos_bacteria $rflen_bacteria]: '1' if position $rfpos_bacteria
                                        # is included by the posterior probability-based based mask, else '0'
  $start_secs = outputProgressPrior("Creating posterior probability-based masks", $progress_w, $log_FH, *STDOUT);
  
  if($rf_archaea_nmap != $rf_bacteria_nmap) { 
    DNAORG_FAIL(sprintf("ERROR, number of mapped positions differs between archaeal and bacteria maps, this shouldn't happen; archaea: %d != bacteria: %d", $rf_archaea_nmap, $rf_bacteria_nmap), 1, $FH_HR);
  }
  
  # create the posterior probability based mask for archaea, 
  # rfpos $rfpos is a '1' (included by the mask) iff:
  # - it maps to a position ($rfpos_bacteria) in bacteria
  # - <x> (from --pfract <x>) fraction of bacteria sequences aligned to
  #   the archaeal model have a posterior probability above <y> (from
  #   --pthresh <y>) in position $rfpos_archaea
  # - <x> (from --pfract <x>) fraction of archaea sequences aligned to
  #   the bacterial model have a posterior probability above <y> (from
  #   --pthresh <y>) in position $rfpos_bacteria
  my @rf_archaea_pp_A = (); 
  my @rf_bacteria_pp_A = (); 
  parse_mask_file($pp_mask_file_HH{"archaea"}{"bacteria"}, \@rf_archaea_pp_A, $FH_HR);
  parse_mask_file($pp_mask_file_HH{"bacteria"}{"archaea"}, \@rf_bacteria_pp_A, $FH_HR);

  # get the pp-based mask in archaeal coordinates
  for($rfpos_archaea = 1; $rfpos_archaea <= $rflen_archaea; $rfpos_archaea++) { 
    $rfpos_bacteria = $rf_archaea_map_A[$rfpos_archaea];
    # printf("rfpos_archaea_pp_A[$rfpos_archaea]: %d, rfpos_bacteria_pp_A[$rfpos_bacteria]: %d\n", $rf_archaea_pp_A[$rfpos_archaea], $rf_bacteria_pp_A[$rfpos_bacteria]);
    if($rfpos_bacteria != -1) { 
      $rf_archaea_pp_joint_mask_A[$rfpos_archaea] = ($rf_archaea_pp_A[$rfpos_archaea] &&
                                                     $rf_bacteria_pp_A[$rfpos_bacteria]) ? 1 : 0;
    }
    else { 
      $rf_archaea_pp_joint_mask_A[$rfpos_archaea] = 0; # this position in archaea wasn't mappable to a position in bacteria
    }
  }
  
  # get the pp-mask in bacterial coordinates
  for($rfpos_bacteria = 1; $rfpos_bacteria <= $rflen_bacteria; $rfpos_bacteria++) { 
    $rfpos_archaea = $rf_bacteria_map_A[$rfpos_bacteria];
    if($rfpos_archaea != -1) { 
      $rf_bacteria_pp_joint_mask_A[$rfpos_bacteria] = ($rf_bacteria_pp_A[$rfpos_bacteria] &&
                                                       $rf_archaea_pp_A[$rfpos_archaea]) ? 1 : 0;
    }
    else { 
      $rf_bacteria_pp_joint_mask_A[$rfpos_bacteria] = 0; # this position in bacteria wasn't mappable to a position in archaea
    }
  }
  
  # output the masks
  my $rf_archaea_pp_joint_mask_file = $dir . "/" . create_out_root($fafile_H{"archaea-bacteria"}, "archaea") . ".pp.mask";
  
  my $rf_archaea_pp_joint_ninc = output_mask_file($rf_archaea_pp_joint_mask_file, \@rf_archaea_pp_joint_mask_A, $rflen_archaea, $FH_HR);
  addClosedFileToOutputInfo(\%ofile_info_HH, "archaea_pp_joint_mask", $rf_archaea_pp_joint_mask_file, 1, sprintf("archaeal mask  (%d len, %d included) based on posterior probabilities (pfract: %.2f, pthresh: %.2f) of cross-domain alignments", 
                                                                                                                 $rflen_archaea, $rf_archaea_pp_joint_ninc, opt_Get("--pfract", \%opt_HH), opt_Get("--pthresh", \%opt_HH)));
  
  my $rf_bacteria_pp_joint_mask_file = $dir . "/" . create_out_root($fafile_H{"archaea-bacteria"}, "bacteria") . ".pp.mask";
  my $rf_bacteria_pp_joint_ninc = output_mask_file($rf_bacteria_pp_joint_mask_file, \@rf_bacteria_pp_joint_mask_A, $rflen_bacteria, $FH_HR);
  addClosedFileToOutputInfo(\%ofile_info_HH, "bacteria_pp_joint_mask", $rf_bacteria_pp_joint_mask_file, 1, sprintf("bacterial mask (%d len, %d included) based on posterior probabilities (pfract: %.2f, pthresh %.2f) of cross-domain alignments", 
                                                                                                                   $rflen_bacteria, $rf_bacteria_pp_joint_ninc, opt_Get("--pfract", \%opt_HH), opt_Get("--pthresh", \%opt_HH)));
  
  # sanity check
  if($rf_archaea_pp_joint_ninc != $rf_bacteria_pp_joint_ninc) { 
    DNAORG_FAIL(sprintf("ERROR, number of positions included for archaea in coverage based mask %d, differs from number of positions included for bacteria: %d", $rf_archaea_pp_joint_ninc, $rf_bacteria_pp_joint_ninc), 1, $FH_HR);
  }
  
  outputProgressComplete($start_secs, undef, $log_FH, *STDOUT);

  ###################################################################################################################
  # Step 11. Merge coverage-based and posterior-probability based masks into new masks (OPTIONAL, we do this if --pp)
  ###################################################################################################################
  $start_secs = outputProgressPrior("Merging coverage and posterior probability-based masks", $progress_w, $log_FH, *STDOUT);

  my @rf_archaea_cov_pp_merged_mask_A  = (); # merged mask of coverage and pp joint masks
  my @rf_bacteria_cov_pp_merged_mask_A = (); # merged mask of coverage and pp joint masks
  $rf_archaea_cov_pp_merged_mask_A[0]  = undef;
  $rf_bacteria_cov_pp_merged_mask_A[0] = undef;

  # archaea
  # input the 2 archaeal masks
  for($rfpos_archaea = 1; $rfpos_archaea <= $rflen_archaea; $rfpos_archaea++) { 
    $rf_archaea_cov_pp_merged_mask_A[$rfpos_archaea] = ($rf_archaea_cov_mask_A[$rfpos_archaea] eq "1" && 
                                                        $rf_archaea_pp_joint_mask_A[$rfpos_archaea] eq "1") ? 1 : 0;
  }
  my $rf_archaea_cov_pp_merged_mask_file = $dir . "/" . create_out_root($fafile_H{"archaea-bacteria"}, "archaea") . ".cov-and-pp.mask";
  my $rf_archaea_cov_pp_merged_ninc = output_mask_file($rf_archaea_cov_pp_merged_mask_file, \@rf_archaea_cov_pp_merged_mask_A, $rflen_archaea, $FH_HR);
  addClosedFileToOutputInfo(\%ofile_info_HH, "archaea_cov_pp_merged_mask", $rf_archaea_cov_pp_merged_mask_file, 1, sprintf("archaeal mask  (%d len, %d included) created by merging coverage (cthresh: %.2f) and pp-based (pfract: %.2f, pthresh: %.2f) masks", 
                                                                                                                           $rflen_archaea, $rf_archaea_cov_pp_merged_ninc, $cov_thresh, opt_Get("--pfract", \%opt_HH),  opt_Get("--pthresh", \%opt_HH)));
  $cov_pp_merged_mask_H{"archaea"} = $rf_archaea_cov_pp_merged_mask_file;

  # bacteria
  # input the 2 bacterial masks
  for($rfpos_bacteria = 1; $rfpos_bacteria <= $rflen_bacteria; $rfpos_bacteria++) { 
    $rf_bacteria_cov_pp_merged_mask_A[$rfpos_bacteria] = ($rf_bacteria_cov_mask_A[$rfpos_bacteria] eq "1" && 
                                                          $rf_bacteria_pp_joint_mask_A[$rfpos_bacteria] eq "1") ? 1 : 0;
  }
  my $rf_bacteria_cov_pp_merged_mask_file = $dir . "/" . create_out_root($fafile_H{"archaea-bacteria"}, "bacteria") . ".cov-and-pp.mask";
  my $rf_bacteria_cov_pp_merged_ninc = output_mask_file($rf_bacteria_cov_pp_merged_mask_file, \@rf_bacteria_cov_pp_merged_mask_A, $rflen_bacteria, $FH_HR);
  addClosedFileToOutputInfo(\%ofile_info_HH, "bacteria_cov_pp_merged_mask", $rf_bacteria_cov_pp_merged_mask_file, 1, sprintf("bacterial mask (%d len, %d included) created by merging coverage (cthresh: %.2f) and pp-based (pfract: %.2f, pthresh: %.2f) masks", 
                                                                                                                             $rflen_bacteria, $rf_bacteria_cov_pp_merged_ninc, $cov_thresh, opt_Get("--pfract", \%opt_HH),  opt_Get("--pthresh", \%opt_HH)));
  $cov_pp_merged_mask_H{"bacteria"} = $rf_bacteria_cov_pp_merged_mask_file;

  # sanity check
  if($rf_archaea_cov_pp_merged_ninc != $rf_bacteria_cov_pp_merged_ninc) { 
    DNAORG_FAIL(sprintf("ERROR, number of positions included for archaea in merged cov and pp mask %d, differs from number of positions included for bacteria: %d", $rf_archaea_cov_pp_merged_ninc, $rf_bacteria_cov_pp_merged_ninc), 1, $FH_HR);
  }

  outputProgressComplete($start_secs, undef, $log_FH, *STDOUT);
} # end of 'if(opt_Get("--pp", \%opt_HH))'

###########################################################################################################################
# Step 12. Create SS diagrams of the merged masks (coverage merged with default, or coverage merged with pp (if --pp used)
###########################################################################################################################
$start_secs = outputProgressPrior("Creating secondary structure diagrams of the masks", $progress_w, $log_FH, *STDOUT);
foreach my $domain ("archaea", "bacteria") { 
  my $out_root = create_out_root($fafile_H{$domain}, $domain);
  my $out_dir  = $dir . "/" . $out_root;
  
  # first, make a SS diagram of only the masks, with pink/black coloring, using ssu-mask
  # on the alignments we created in step 2 (or earlier if --skipalign is used)
  my $alignment_file  = $out_dir . "/" . $out_root . ".$domain.stk";
  my $mask_file_to_draw = (opt_Get("--pp", \%opt_HH)) ? $cov_pp_merged_mask_H{$domain} : $cov_df_merged_mask_H{$domain};
  my $ssu_mask_cmd  = $execs_H{"ssu-mask"} . " -s $mask_file_to_draw -a $alignment_file > /dev/null";
  my $mask_ss_file  = $out_root . ".$domain.mask.pdf";
  my $mask_aln_file = $out_root . ".$domain.mask.stk";
  my $mask_sum_file = $out_root . ".$domain.ssu-mask.sum";
  my $mask_log_file = $out_root . ".$domain.ssu-mask.log";
  
  runCommand($ssu_mask_cmd, opt_Get("-v", \%opt_HH), $FH_HR);
  
  # we only need the mask diagram, remove the other files
  removeFileUsingSystemRm($mask_aln_file, undef, \%opt_HH, $FH_HR);
  removeFileUsingSystemRm($mask_sum_file, undef, \%opt_HH, $FH_HR);
  removeFileUsingSystemRm($mask_log_file, undef, \%opt_HH, $FH_HR);
  
  # move the secondary structure file into the directory we want it in
  my $mv_cmd = "mv $mask_ss_file $dir";
  runCommand($mv_cmd, opt_Get("-v", \%opt_HH), $FH_HR);
  $mask_ss_file = $dir . "/" . $mask_ss_file;
  addClosedFileToOutputInfo(\%ofile_info_HH, $domain . "-mask-ss-diagram", $mask_ss_file, 1, sprintf("structure diagram of merged coverage and %s mask for %s", opt_Get("--pp", \%opt_HH) ? "pp" : "default", $domain));
  
  # now project the mask onto the aligned sequences from the input fasta file
  my $ssu_draw_cmd  = $execs_H{"ssu-draw"} . " -s $mask_file_to_draw -a $alignment_file > /dev/null";
  my $draw_ss_file  = $out_root . ".$domain.pdf";
  my $draw_tab_file = $out_root . ".$domain.drawtab";
  my $draw_sum_file = $out_root . ".$domain.ssu-draw.sum";
  my $draw_log_file = $out_root . ".$domain.ssu-draw.log";
  
  runCommand($ssu_draw_cmd, opt_Get("-v", \%opt_HH), $FH_HR);
  
  # we only need the mask diagram, remove the other files
  removeFileUsingSystemRm($draw_tab_file, undef, \%opt_HH, $FH_HR);
  removeFileUsingSystemRm($draw_sum_file, undef, \%opt_HH, $FH_HR);
  removeFileUsingSystemRm($draw_log_file, undef, \%opt_HH, $FH_HR);
  
  # move the secondary structure file into the directory we want it in
  $mv_cmd = "mv $draw_ss_file $dir";
  runCommand($mv_cmd, opt_Get("-v", \%opt_HH), $FH_HR);
  $draw_ss_file = $dir . "/" . $draw_ss_file;
  addClosedFileToOutputInfo(\%ofile_info_HH, $domain . "--aln-ss-diagram", $draw_ss_file, 1, sprintf("structure diagram of merged coverage and %s mask overlaid on alignment %s", opt_Get("--pp", \%opt_HH) ? "pp" : "default", $out_root . ".$domain.stk"));
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

#################################################################
# Subroutine : create_out_root()
# Incept:      EPN, Mon Apr  4 09:51:41 2016
#
# Purpose: Given a fasta file name, domain, and output directory
#          name, create the 'output root', a string that output
#          files related to this combination of $domain and 
#          $fafile will be named.
#
# Arguments: 
#  $fafile:      fasta file name
#  $domain:      domain, e.g. "archaea"
# 
# Returns:     $out_root, a string for output file names.
# 
# Dies: never.
#
################################################################# 
sub create_out_root { 
  my $sub_name = "create_out_root()";
  my $nargs_expected = 2;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($fafile, $domain) = @_;

  my $fafile_root = removeDirPath($fafile);
  $fafile_root =~ s/\.fa$//;

  my $dir_root = $fafile_root . "-to-" . $domain;

  return $dir_root;
}

#################################################################
# Subroutine : parse_esl_alimap_output()
# Incept:      EPN, Mon Apr  4 10:31:20 2016
#
# Purpose: Given esl-alimap output, parse it. 
#          Fill @{$rf_map_A}, $$rf_nmap, and 
#          @{$rf_cov_A}.
#
# Arguments: 
#  $infile:      the esl-alimap output
#  $rf_map_AR:   reference to the 'map' array to fill
#                [1..$rfpos1..$rflen]: $rfpos2, $rfpos2 is 
#                the nongap RF position in alignment 2 that 
#                $rfpos1 maps to, -1 if none.
#                $rf_map_AR[0] is always -1.
#  $rf_cov_AR:   reference to the 'coverage' array to fill
#                [1..$rfpos1..$rflen]: $x, $x is the fraction
#                of nucleotides in $rfpos1 in alignment 1 that
#                are also in $rf_map_AR[$rfpos1]=$rfpos2 position
#                in alignment 2. -1 if $rf_map_AR[$rfpos1] == -1.
#                $rf_cov_AR[0] is always -1.
#  $rf_nmap_R:   reference to the scalar to fill with 
#                the number of nongap-RF positions in alignment
#                2 that nongap-RF positions in alignment 1 
#                map to, this is the number of non '-1' values
#                in @{$rf_map_AR}.
#  $FH_HR:       ref to hash of open file handles
# 
# Returns:     The non-gap RF length of alignment 1 in the output.
# 
# Dies: if we can't open $infile.
#
################################################################# 
sub parse_esl_alimap_output {
  my $sub_name = "parse_esl_alimap_output()";
  my $nargs_expected = 5;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($infile, $rf_map_AR, $rf_cov_AR, $rf_nmap_R, $FH_HR) = @_;

  open(IN, $infile) || fileOpenFailure($infile, $sub_name, $!, "reading", $FH_HR);

  # example of output:
  ## test/archaea-0p1-bacteria-0p1-to-bacteria/archaea-0p1-bacteria-0p1-to-bacteria.bacteria.stk alignment length:              1836
  ## test/archaea-0p1-bacteria-0p1-to-archaea/archaea-0p1-bacteria-0p1-to-archaea.archaea.stk alignment length:              2092
  ##     msa 1              msa 2                           
  ## ------------       ------------                        
  ## rfpos   apos       rfpos   apos     num common residues
  ## -----  -----       -----  -----   ---------------------
  #      -   1836  -->      -   2092      3 /     4 (0.7500)
  #   1582   1835  -->      -   2091     39 /    39 (1.0000)
  #   1581   1834  -->      -   2090     46 /    46 (1.0000)
  #   1580   1833  -->      -   2089     74 /    74 (1.0000)
  #   1579   1832  -->      -   2088     89 /    89 (1.0000)
  #   1578   1831  -->   1508   2087    108 /   108 (1.0000)
  #   1577   1830  -->   1507   2086    113 /   113 (1.0000)
  ##    $1     $2          $3     $4     $5      $6  $7

  # initialize
  $rf_map_AR->[0] = -1;
  $rf_cov_AR->[0] = -1;
  my $rf_nmap = 0;
  my $rflen   = 0;

  my $line;
  while($line = <IN>) { 
    if($line !~ m/^\#/) { 
      $line =~ s/^\s+//; # remove leading whitespace
      if($line =~ /(\S+)\s+(\S+)\s+\-\-\>\s+(\S+)\s+(\S+)\s+(\d+)\s+\/\s+(\d+)\s+\((\S+)\)/) { 
        my ($rfpos1, $rfpos2, $ncommon, $ntotal, $fcov) = ($1, $3, $5, $6, $7);
        if(verify_integer($rfpos1)) { 
          # this is a nongap rf position in alignment 1
          if($rfpos1 > $rflen) { 
            $rflen = $rfpos1;
          }
          if(verify_integer($rfpos2)) { 
            # this is a nongap rf position in alignment 2
            $rf_map_AR->[$rfpos1] = $rfpos2;
            $rf_cov_AR->[$rfpos1] = $fcov;
            $rf_nmap++;
          }
          else { 
            $rf_map_AR->[$rfpos1] = -1;
            $rf_cov_AR->[$rfpos1] = -1;
          }
          # printf("in $sub_name, rfpos: $rfpos1, map: %d, cov: %.2f\n", $rf_map_AR->[$rfpos1], $rf_cov_AR->[$rfpos1]);
        }
      }
    }
  }

  # now that we have $rflen, go back and fill in all undefined values in @{$rf_map_AR} and @{$rf_cov_AR}
  for(my $rfpos1 = 1; $rfpos1 <= $rflen; $rfpos1++) { 
    if(! defined $rf_map_AR->[$rfpos1]) { 
      $rf_map_AR->[$rfpos1] = -1;
    }
    if(! defined $rf_cov_AR->[$rfpos1]) { 
      $rf_cov_AR->[$rfpos1] = -1;
    }
  }

  $$rf_nmap_R = $rf_nmap;

  return $rflen;
}

#################################################################
# Subroutine : output_mask_file()
# Incept:      EPN, Mon Apr  4 15:10:15 2016
#
# Purpose: Output a mask file, given an array @{$AR} with '0'
#          and '1' values from [1..$len], write a mask file
#          with a single line of length $len with '0's and '1's.
#
# Arguments: 
#  $outfile: name of output file to create
#  $AR:      ref to array of '0's and '1's, only use elements [1..$len]
#  $len:     number of elements in @{$AR} (scalar(@{$AR} == $len+1)
#  $FH_HR:   ref to hash of open file handles
#
# Returns:   Number of '1's printed to $outfile (number of 
#            positions included by the mask).
# 
# Dies: If we can't open $outfile for writing.
#       If scalar(@{$AR} != ($len+1)).
#       If any value in @{$AR} is not '0' or '1' within 1..$len
################################################################# 
sub output_mask_file { 
  my $sub_name = "output_mask_file()";
  my $nargs_expected = 4;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($outfile, $AR, $len, $FH_HR) = @_;

  if(scalar(@{$AR}) != ($len+1)) { 
    DNAORG_FAIL("ERROR in $sub_name, array length not equal to 1 plus $len", 1, $FH_HR);
  }
  for(my $pos = 1; $pos <= $len; $pos++) { 
    if(($AR->[$pos] ne "0") && ($AR->[$pos] ne "1")) { 
      DNAORG_FAIL(sprintf("ERROR in $sub_name, position $pos in passed in array has a value that is not a '0' and not a '1': %s", $AR->[$pos]), 1, $FH_HR);
    }
  }
      
  my $ninc = 0;
  open(OUT, ">", $outfile) || fileOpenFailure($outfile, $sub_name, $!, "writing", $FH_HR);
  for(my $pos = 1; $pos <= $len; $pos++) { 
    if($AR->[$pos] eq "1") { 
      $ninc++;
    }
    print OUT $AR->[$pos];
  }
  print OUT "\n";
  close(OUT);

  return $ninc;
}

#################################################################
# Subroutine : parse_mask_file()
# Incept:      EPN, Tue Apr  5 08:52:38 2016
#
# Purpose: Read a mask file and store it as an array in @{$AR}.
#          $AR->[$x] = '0' or '1', for position $x = 1..$len.
#
# Arguments: 
#  $infile:  name of input mask file to parse
#  $AR:      ref to array of '0's and '1's, only use elements [1..$len]
#  $FH_HR:   ref to hash of open file handles
#
# Returns:   Number of '1's in the mask.
# 
# Dies: If we can't open $infile for reading.
#       If $infile has more or less than 1 line.
#       If any character in the only line of $infile
#       is not a '1' or a '0'.
################################################################# 
sub parse_mask_file { 
  my $sub_name = "parse_mask_file()";
  my $nargs_expected = 3;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($infile, $AR, $FH_HR) = @_;

  @{$AR} = ();
  $AR->[0] = undef; # undefined

  open(IN, $infile) || fileOpenFailure($infile, $sub_name, $!, "reading", $FH_HR);
  my $maskline = <IN>;
  chomp $maskline;

  my @maskline_A = split("", $maskline);
  my $masklen = scalar(@maskline_A);
  my $ninc = 0;
  for(my $pos = 1; $pos <= $masklen; $pos++) { 
    if(($maskline_A[($pos-1)] ne "1") && 
       ($maskline_A[($pos-1)] ne "0")) {
      DNAORG_FAIL(sprintf("ERROR in $sub_name, position $pos of mask read from $infile is a %s, but it should be a 1 or a 0", $maskline_A[($pos-1)]),  1, $FH_HR);
    }
    if($maskline_A[($pos-1)] eq "1") { 
      $ninc++;
    }
    $AR->[$pos] = $maskline_A[($pos-1)];
  }
  $maskline = <IN>;
  if($maskline) { 
    DNAORG_FAIL("ERROR in $sub_name, read more than 1 line in mask file $infile", 1, $FH_HR);
  }
  close(IN);

  return $ninc;
}
