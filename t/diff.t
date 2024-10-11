#!/usr/bin/env perl

use 5.014;
use warnings;
use re '/msx';

use English qw( -no_match_vars );
use File::Basename;
use File::Temp;
use Rex::Commands::File 1.012;
use Rex::Hook::File::Diff;
use Test2::V0 0.000071;
use Test::Output 0.03;

our $VERSION = '9999';

plan tests => 3;

my $null = File::Spec->devnull();

## no critic ( ProhibitComplexRegexes )

subtest 'quick file lifecycle' => sub {
    my $file = File::Temp->new( TEMPLATE => "$PROGRAM_NAME.XXXX" )->filename();
    my $rex_tmp_filename = Rex::Commands::File::get_tmp_file_name($file);

    my @tests = (
        {
            scenario        => 'create file with content',
            coderef         => sub { file $file, content => '1' },
            expected_output => qr{
              \A                                   # start of output
              \QDiff for: $file\E\n                # leading message
              \Q--- $null\E(\s+.*?)?\n             # header for original file
              \Q+++ $rex_tmp_filename\E(\s+.*?)?\n # header for new file
                (\Q@@ -0,0 +1 @@\E)                # hunk header
                |                                  # or
                (\Q@@ -1,0 +1,1 @@\E)              # solaris hunk header
              \n                                   # new line
              \Q+1\E\n                             # added line
              \Z                                   # end of output
            },
        },
        {
            scenario        => 'remove file with content',
            coderef         => sub { file $file, ensure => 'absent' },
            expected_output => qr{
              \A                       # start of output
              \QDiff for: $file\E\n    # leading message
              \Q--- $file\E(\s+.*?)?\n # header for original file
              \Q+++ $null\E(\s+.*?)?\n # header for new file
                (\Q@@ -1 +0,0 @@\E)    # hunk header
                |                      # or
                (\Q@@ -1,1 +1,0 @@\E)  # solaris hunk header
              \n                       # new line
              \Q-1\E\n                 # added line
              \Z                       # end of output
            },
        },
    );

    run_tests(@tests);
};

subtest 'full file lifecycle' => sub {
    my $file = File::Temp->new( TEMPLATE => "$PROGRAM_NAME.XXXX" )->filename();
    my $rex_tmp_filename = Rex::Commands::File::get_tmp_file_name($file);

    my @tests = (
        {
            scenario        => 'create empty file',
            coderef         => sub { file $file, ensure => 'present' },
            expected_output => qr{
                \A                                   # start of output
                (                                    # start of optional explicit message
                    \QDiff for: $file\E\n            # leading message
                    \QNo differences encountered\E\n # message about matching content on solaris
                )?                                   # end of optional explicit message
                \Z                                   # end of output
            },
        },
        {
            scenario        => 'add line to file',
            coderef         => sub { file $file, content => '1' },
            expected_output => qr{
              \A                                   # start of output
              \QDiff for: $file\E\n                # leading message
              \Q--- $file\E(\s+.*?)?\n             # header for original file
              \Q+++ $rex_tmp_filename\E(\s+.*?)?\n # header for new file
                (\Q@@ -0,0 +1 @@\E)                # hunk header
                |                                  # or
                (\Q@@ -1,0 +1,1 @@\E)              # solaris hunk header
              \n                                   # new line
              \Q+1\E\n                             # added line
              \Z                                   # end of output
            },
        },
        {
            scenario        => 'modify line in file',
            coderef         => sub { file $file, content => '2' },
            expected_output => qr{
              \A                                   # start of output
              \QDiff for: $file\E\n                # leading message
              \Q--- $file\E(\s+.*?)?\n             # header for original file
              \Q+++ $rex_tmp_filename\E(\s+.*?)?\n # header for new file
                (\Q@@ -1 +1 @@\E)                  # hunk header
                |                                  # or
                (\Q@@ -1,1 +1,1 @@\E)              # solaris hunk header
              \n                                   # new line
              \Q-1\E\n                             # removed line
              \Q+2\E\n                             # added line
              \Z                                   # end of output
            },
        },
        {
            scenario        => 'remove line from file',
            coderef         => sub { file $file, content => q() },
            expected_output => qr{
              \A                                   # start of output
              \QDiff for: $file\E\n                # leading message
              \Q--- $file\E(\s+.*?)?\n             # header for original file
              \Q+++ $rex_tmp_filename\E(\s+.*?)?\n # header for new file
                (\Q@@ -1 +0,0 @@\E)                # hunk header
                |                                  # or
                (\Q@@ -1,1 +1,0 @@\E)              # solaris hunk header
              \n                                   # new line
              \Q-2\E\n                             # removed line
              \Z                                   # end of output
            },
        },
        {
            scanario        => 'remove empty file',
            coderef         => sub { file $file, ensure => 'absent' },
            expected_output => qr{
                \A                                   # start of output
                (                                    # start of optional explicit message
                    \QDiff for: $file\E\n            # leading message
                    \QNo differences encountered\E\n # message about matching content on solaris
                )?                                   # end of optional explicit message
                \Z                                   # end of output
            },
        },
    );

    run_tests(@tests);
};

subtest 'file command with source option' => sub {
    my $file = File::Temp->new( TEMPLATE => "$PROGRAM_NAME.XXXX" )->filename();
    my $rex_tmp_filename = Rex::Commands::File::get_tmp_file_name($file);
    my $red = qr/\e\[1;31m/;
    my $green = qr/\e\[1;32m/;
    my $reset_color = qr/\e\[0m/;

    my @tests = (
        {
            scenario        => 'create file',
            coderef         => sub { file $file, source => 'files/create_file' },
            expected_output => qr{
              \A                                   # start of output
              \QDiff for: \E$file\n                # leading message
              \Q--- $null\E(\s+.*?)?\n             # header for original file
              \Q+++ $rex_tmp_filename\E(\s+.*?)?\n # header for new file
                (\Q@@ -0,0 +1 @@\E)                # hunk header
                |                                  # or
                (\Q@@ -1,0 +1,1 @@\E)              # solaris hunk header
              \n                                   # new line
              \Q+1\E\n                             # added line
              \Z                                   # end of output
            },
        },
        {
            scenario        => 'add line',
            coderef         => sub { file $file, source => 'files/add_line' },
            expected_output => qr{
              \A                                   # start of output
              \QDiff for: \E$file\n                # leading message
              \Q--- $file\E(\s+.*?)?\n             # header for original file
              \Q+++ $rex_tmp_filename\E(\s+.*?)?\n # header for new file
                (\Q@@ -1 +1,2 @@\E)                # hunk header
                |                                  # or
                (\Q@@ -1,1 +1,2 @@\E)              # solaris hunk header
              \n                                   # new line
              \Q 1\E\n                             # unchanged line
              \Q+2\E\n                             # added line
              \Z                                   # end of output
            },
        },
        {
            scenario        => 'modify line',
            coderef         => sub { file $file, source => 'files/modify_line' },
            expected_output => qr{
              \A                                   # start of output
              \QDiff for: \E$file\n                # leading message
              \Q--- $file\E(\s+.*?)?\n             # header for original file
              \Q+++ $rex_tmp_filename\E(\s+.*?)?\n # header for new file
              \Q@@ -1,2 +1,2 @@\E\n                # hunk
              \Q 1\E\n                             # unchanged line
              $red\Q-2\E$reset_color\n             # removed line
              $green\Q+3\E$reset_color\n           # added line
              \Z                                   # end of output
            },
        },
        {
            scenario        => 'remove line',
            coderef         => sub { file $file, source => 'files/remove_line' },
            expected_output => qr{
              \A                                   # start of output
              \QDiff for: \E$file\n                # leading message
              \Q--- $file\E(\s+.*?)?\n             # header for original file
              \Q+++ $rex_tmp_filename\E(\s+.*?)?\n # header for new file
                (\Q@@ -1,2 +1 @@\E)                # hunk header
                |                                  # or
                (\Q@@ -1,2 +1,1 @@\E)              # solaris hunk header
              \n                                   # new line
              \Q 1\E\n                             # unchanged line
              \Q-3\E\n                             # removed line
              \Z                                   # end of output
            },
        },
        {
            scenario        => 'remove file',
            coderef         => sub { file $file, ensure => 'absent' },
            expected_output => qr{
              \A                       # start of output
              \QDiff for: \E$file\n    # leading message
              \Q--- $file\E(\s+.*?)?\n # header for original file
              \Q+++ $null\E(\s+.*?)?\n # header for new file
                (\Q@@ -1 +0,0 @@\E)    # hunk header
                |                      # or
                (\Q@@ -1,1 +1,0 @@\E)  # solaris hunk header
              \n                       # new line
              \Q-1\E\n                 # removed line
              \Z                       # end of output
            },
        },
    );

    run_tests(@tests);
};

sub run_tests {
    my @tests = @_;

    for my $test (@tests) {
        stdout_like(
            \&{ $test->{coderef} },
            $test->{expected_output},
            $test->{scenario},
        );
    }

    return;
}
