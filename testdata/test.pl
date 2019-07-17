#!/usr/bin/perl
##
# Build the test code to check that the toolchain works.
#
# We take a test script, conventionally called 'tests.txt', which
# contains:
#    A number of Group definitions
#    A number of Tests within those definitions
#
# Any definitions within the Group are inherited within the Test, and
# only acted on within the test (with a couple of exceptions).
#
# Groups are executed in order given in the description.
# Tests within the grounp in the order given in the description.
#
# Groups have names, to distinguish them from one another
# Tests have names, to distinguish them within the group.
#
# Tests will execute a command, using the supplied tool.
# The command (and many other of the parameters) may be parameterised
# to allow it to be run in different ways.
# Tests must return a given return code, or they will fail.
# Tests may be checked for specific output.
# Tests may check a single output file's content.
# Tests may be marked as disabled, to prevent them running, but keep
# them in the description.
#
# Checkers can be configured which check the content of generated
# files.
#
# Description file format:
#
# # at the start of a line marks a comment.
# Statements take the form:
#    <statement>: <argument>
#
# Group definitions start at a 'Group:' statement, and end with either a
# 'Test' statement, or another 'Group:' statement.
#
# Group: <group name>
#       - begins a Group
# Test: <test name>
#       - begins a Test definition
#
# When a Test definition is encountered, it begins with the same
# definitions as were present in the Group. Any subsequent statements
# will override the group statements. A statement may start with a '-'
# character (and have no argument) to remove any setting provided by the
# group.
#
# Statements currently defined are:
#
# Include: <filename>
#       - Include another file as if it were inline
# Group: <name>
#       - Begin a group definition
# Test: <name>
#       - Begin a test definition
# Command: <command>
#       - Command to execute
# File: <source filename>
#       - Source filename to apply
# Args: <arguments>
#       - Arbitrary arguments that may be substituted into the
#         command line
# Expect: <expectation filename>
#       - File to compare the output to
# Replace: <replacements filename>
#       - File containing regular expressions to filter output before
#         comparing to Expectation file. Replacement lines may be
#         commented with a '#' prefix.
# Creates: <output file>
#       - Specify a name of a file that is expected to be created.
#         If it's not present, the test fails.
# Length: <length of the created file>
#       - Expected length of the file; if it doesn't match, the test
#         will fail
# RC: <return code expected>
#       - Expected return code; if it's different the test will fail
#         Otherwise, the test must return 0.
# Input: <input file>
#       - A file to supply as input to the tool
# InputLine: <line>
#       - A string to supply to the tool, which will be followed by
#         a newline
# Disable: <message>
#       - Disable a test (or the group), with a message
# <checker>:<parameter>: <argument>
#       - Provide parameters to a specific checker.
#
# All of the arguments can has values substituted into them.
# The following substitutions are available:
#
#   $TOOL
#       - tool name, as supplied on the command line
#   $FILE
#       - filename, as supplied in the 'File' statement
#   $OFILE
#       - generated object file, in native format
#   $SFILE
#       - generated assembler file, in native format
#   $CFILE
#       - generated C file, in native format
#   $BASE
#       - base filename
#   $ARGS
#       - arguments, as supplied in the 'Args' statement
#   $ARG(1..)
#       - numbered arguments extracted from the .Args. statement
#
# Checkers are named by a short string, and contain parameters
# which can be used to confirm that the file was created correctly.
#
# Checkers and parameters:
#
# - 'aof' checker:
#
#   aof:totalareasize: <size>
#       - The sum of all the areas in the file
#
# - 'alf' checker:
#
#   alf:files: <number of files>
#       - The number of files in the library
#
# - 'text' checker:
#
#   text:matches: <filename>
#       - File to compare the content against
#   text:replace: <replacement file>
#       - File containing regular expressions to replace before
#         comparing to the matches file
#
# - 'binary' checker:
#
#   binary:matches: <filename>
#       - File to compare the content against (which must match exactly)
#   binary:checkfile: <filename>
#       - Check parts of the file according to a 'checkfile' containing
#         lines describing the checks to perform, in the form:
#           <offset> [word|byte|string>: <value>
#

use warnings;
use strict;

my $testtool = undef;
my $dir = undef;

# Whether we're debugging
my $debug_filename = 0;
my $debug_replace = 0;
my $debug_aof = 0;

# Matching for test selection
my $matchgroup_re = undef;
my $matchtest_re = undef;

# Verbose output?
my $verbose = 1;
my $showcmd = 0;

# Output controls
my $outputdump = 0;
my $outputsavedir = undef;

# Name of the test script to execute
my $testscript = "tests.txt";

# Generate Junit XML at the end? (the filename)
my $junitxml = undef;

my $arg;
while ($arg = shift)
{
    if ($arg =~ /^--?(.*)$/)
    {
        my $switch = $1;
        if ($switch eq 'v' || $switch eq 'verbose')
        {
            $verbose = 1;
        }
        elsif ($switch eq 'q' || $switch eq 'quiet')
        {
            $verbose = 0;
        }
        elsif ($switch eq 'show-command')
        {
            $showcmd = 1;
        }
        elsif ($switch eq 'show-output')
        {
            $outputdump = 1;
        }
        elsif ($switch eq 'save-output')
        {
            $outputsavedir= shift;
        }
        elsif ($switch eq 'junitxml')
        {
            $junitxml = shift;
        }
        elsif ($switch eq 'script')
        {
            $testscript = shift;
        }
        elsif ($switch eq 'group')
        {
            $matchgroup_re = shift;
        }
        elsif ($switch eq 'test')
        {
            $matchtest_re = shift;
        }
        elsif ($switch eq 'debug')
        {
            my @debug = split /, */, shift;
            for my $debugname (@debug)
            {
                if ($debugname eq 'filename' || $debugname eq 'all')
                { $debug_filename = 1; }
                if ($debugname eq 'replace' || $debugname eq 'all')
                { $debug_replace = 1; }
                if ($debugname eq 'aof' || $debugname eq 'all')
                { $debug_aof = 1; }
            }
        }
        else
        {
            die "Unrecognised switch: $arg\n";
        }
    }
    elsif (!defined $testtool)
    { $testtool = $arg; }
    elsif (!defined $dir)
    { $dir = $arg; }
    else
    {
        die "Extra argument not understood: $arg\n";
    }
}

if (!defined $testtool ||
    !defined $dir)
{
    print "Syntax: $0 [<options>] <test tool> <dir>\n";
    print "Options:\n";
    print "    -verbose         Verbose output\n";
    print "    -quiet           Not verbose output\n";
    print "    -scrpt <script>  Script file to read (default: 'tests.txt')\n";
    print "    -group <re>      Regular expression to match for group name\n";
    print "    -test <re>       Regular expression to match for test name\n";
    print "    -show-command    Show command executed\n";
    print "    -show-output     Show output on failure\n";
    print "    -save-output <dir>   Save all output to a directory\n";
    print "    -debug <type>    Enable debug types as comma-separated list\n";
    exit 1;
}

my $extensions_re = "s|hdr|c|h|cmhg|s_c|o|aof|bin|x";

my ($none, $testtoolname) = ($testtool =~ /(^|\/)([^\/]*)$/);

my %testparams = map { $_ => 1 } (
        'command',
        'expect',
        'disable',
        'creates',
        'length',
        'rc',
        'file',
        'args',
        'replace',
        'input',
        'inputline',
    );

my %checkers = (
        'text' => \&text_check,
        'aof' => \&aof_check,
        'alf' => \&alf_check,
        'binary' => \&binary_check,
    );

my $tempbase;
if ($^O eq 'riscos')
{
    $tempbase = "<Wimp\$ScrapDir>.tt-$$";
}
else
{
    $tempbase = "/tmp/tt-$$";
}
my %tempnames = ();

END {
    for my $name (keys %tempnames)
    {
        unlink $name;
    }
}

##
# Create a temporary filename.
sub tempfilename
{
    my ($name) = @_;
    my $filename = "$tempbase-$name";
    $tempnames{$filename} = 1;
    return $filename;
}


##
# Parse a test file, accumulating results in our structures.
#
# @param $testscript:   The script to read.
#
# @return:  An array containing the group of tests we want to run
sub parse_test_script
{
    my ($testscript) = (@_);
    my $group = undef;
    my $test = undef;
    my $acc = undef;

    my @groups;
    open(my $testfh, "< $testscript") || die "Cannot open test script '$testscript': $!";
    while (<$testfh>)
    {
        chomp;
        next if (/^ *#/ || /^ *$/);

        my $checker;
        my $minus;
        my ($cmd, $arg) = (/^([A-Za-z]+): +(.*?) *$/);
        if (!$cmd)
        {
            ($minus, $cmd) = (/^(-?)([A-Za-z]+):$/);
        }
        if (!$cmd)
        {
            # Not a base command specification; so try a checker value.
            ($checker, $cmd, $arg) = (/^([A-Za-z]+):([A-Za-z]+): *(.*?) *$/);
            $checker = lc $checker;
            if (!defined $checkers{$checker})
            {
                die "Unrecognised checker '$checker' in '$_'";
            }
        }

        if (!$cmd)
        {
            die "Cannot understand line '$_'";
        }

        if (defined $checker)
        {
            if (!defined $acc->{$checker})
            {
                $acc->{$checker} = {};
            }
            $acc->{$checker}->{lc $cmd} = $arg;
        }
        elsif ($cmd eq 'Include')
        {
            # Process an include file
            push @groups, parse_test_script($arg);
        }
        elsif ($cmd eq 'Group')
        {
            $group = {
                    'group-index' => scalar(@groups),
                    'group' => $arg,
                    'tests' => [],
                    'pass' => 0,
                    'fail' => 0,
                    'crash' => 0,
                    'skip' => 0,
                };
            delete $acc->{'tests'};
            $test = undef;
            $acc = $group;
            push @groups, $group;

            if ($matchgroup_re && $group->{'group'} !~ /$matchgroup_re/)
            {
                $group->{'skip'} = 1;
            }
        }
        elsif ($cmd eq 'Test')
        {
            $test = {
                    %$group,
                    'test-index' => scalar(@{$group->{'tests'}}),
                    'name' => $arg,
                };
            for my $key (keys %$test)
            {
                if (ref($test->{$key}) eq 'HASH')
                {
                    # If the element was a hash, copy it.
                    $test->{$key} = { %{$test->{$key}} };
                }
            }
            push @{$group->{'tests'}}, $test;
            delete $test->{'tests'};
            $acc = $test;

            if ($matchtest_re && $test->{'name'} !~ /$matchtest_re/)
            {
                $test->{'skip'} = 1;
            }
        }
        elsif (defined($testparams{lc $cmd}))
        {
            if ($minus)
            {
                undef $acc->{lc $cmd};
            }
            else
            {
                $acc->{lc $cmd} = $arg;
            }
        }
        else
        {
            die "Unknown command '$cmd' in '$_'";
        }
    }

    return @groups;
}

sub setup_variables
{
    my ($test) = @_;
    my $vars = {};

    $vars->{'TOOL'} = $testtool;
    $vars->{'FILE'} = $test->{'file'} || '';
    $vars->{'ARGS'} = $test->{'args'} || '';
    my @args = split / +/, $vars->{'ARGS'};
    my $argn = 1;
    for my $arg (@args)
    {
        $vars->{'ARG' . $argn} = $arg;
        $argn++;
    }
    if (!$test->{'file'})
    {
        $vars->{'OFILE'} = '';
        $vars->{'SFILE'} = '';
        $vars->{'CFILE'} = '';
        $vars->{'HFILE'} = '';
        $vars->{'BASE'} = '';
    }
    elsif ($test->{'file'} =~ /(^|.*\.)($extensions_re)\.(.*)/)
    {
        $vars->{'OFILE'} = "$1o.$3";
        $vars->{'SFILE'} = "$1s.$3";
        $vars->{'CFILE'} = "$1c.$3";
        $vars->{'HFILE'} = "$1h.$3";
        $vars->{'BASE'} = "$3";
    }
    elsif ($test->{'file'} =~ /^(^|.*\/)($extensions_re)\/(.*)/)
    {
        $vars->{'OFILE'} = "$1o/$3";
        $vars->{'SFILE'} = "$1s/$3";
        $vars->{'CFILE'} = "$1c/$3";
        $vars->{'HFILE'} = "$1h/$3";
        $vars->{'BASE'} = "$3";
    }
    else
    {
        die "Unrecognised filename format: '$test->{'file'}'"
    }

    return $vars;
}


##
# Perform escaping on a parameter.
#
# @param $param         What to escape
# @param $escapetype    How to escape:
#                           0 => not at all
#                           1 => shell escaping
sub escape
{
    my ($param, $escapetype) = @_;
    if (defined $escapetype && $escapetype == 1)
    {
        $param =~ s/(['";&])/\\$1/g;
    }
    return $param;
}

sub substitute
{
    my ($str, $vars, $escapetype) = @_;
    return $str if (!defined $str);

    $str =~ s/(^|[^\\])\$([A-Z]+[0-9]*)/$1 . (defined($vars->{$2}) ? escape($vars->{$2}, $escapetype) : '$' . $2)/eg;
    return $str;
}

sub number
{
    my ($str) = @_;
    return undef if (!defined $str);

    if ($str =~ /^(0x|&)([0-9a-fA-F]+)$/)
    {
        return hex($2);
    }
    return $str;
}

sub native_filename
{
    my ($filename) = @_;
    my $dirsep;

    die "No filename passed to native_filename" if (!defined $filename);

    if ($^O eq 'riscos')
    {
        $dirsep = '.';
    }
    else
    {
        $dirsep = '/';
    }

    print "('$filename'" if ($debug_filename);
    if ($filename =~ /^(.*)\/($extensions_re)$/)
    { # Unix layout, RISC OS syntax
        $filename = "$2$dirsep$1";
    }
    elsif ($filename =~ /^(.*)\.($extensions_re)$/)
    { # Unix layout, Unix syntax
        $filename = "$2$dirsep$1";
    }
    elsif ($filename =~ /^($extensions_re)\/(.*)$/)
    { # RISCO OS layout, Unix syntax
        $filename = "$1$dirsep$2";
    }
    elsif ($filename =~ /^($extensions_re)\.(.*)$/)
    { # RISC OS layout, RISC OS syntax
        $filename = "$1$dirsep$2";
    }
    print " => '$filename' : $dirsep)" if ($debug_filename);

    # Filename is now in Unix layout, using native syntax
    return $filename;
}

##
# Read a file, given a possibly RISC OS filename.
#
# @param $expect    Filename to read
# @param $label     What the file is, for reporting errors
#
# @return file content.
sub read_file
{
    my ($expect, $label) = @_;
    $expect = native_filename($expect);
    my $expected = '';
    if (-f "$expect")
    {
        open(my $fh, "< $expect") || die "Cannot read $label '$expect': $!";
        while (<$fh>)
        { $expected .= $_; }
        close($fh);
    }
    return $expected;
}

##
# Apply a replacements file that contains simple replacements to fix up text.
#
# @param $replacements  Filename containing replacements
# @param $output        The output to perform replacement on
#
# @return New output, with replacements applied.
sub apply_replacements
{
    my ($replacements, $output) = @_;
    open(my $fh, "< $replacements") || die "Cannot read replacements file '$replacements': $!";
    while (<$fh>)
    {
        chomp;
        next if (/^\s*$/ || /^#/);
        if (m!^s([^a-zA-Z0-9])(.*[^\\]|)\1(.*[^\\]|)\1([mgs]?)$!)
        {
            my $sym = $1;
            my $from = $2;
            my $to = $3;
            my $opts = $4;

            $from =~ s/\\$sym/$sym/g;
            $to =~ s/\\$sym/$sym/g;

            print "REPLACE: '$from' => '$to' '$opts'\n" if ($debug_replace);
            if (!defined $opts || $opts eq '')
            {
                $to =~ s!\/!\\/!g;
                eval "\$output =~ s/\$from/$to/;";
            }
            elsif ($opts eq 'g')
            {
                $to =~ s!\/!\\/!g;
                eval "\$output =~ s/\$from/$to/g;";
            }
            elsif ($opts eq 's' || $opts eq 'm')
            {
                # Treat both these options as the same thing,
                # and applying globally.
                $to =~ s!\/!\\/!g;
                eval "\$output =~ s/\$from/$to/smg;";
            }
        }
        else
        {
            die "Unrecognised replacement line: '$_'";
        }
    }
    close($fh);

    return $output;
}

##
# Run a specified test.
#
# Uses the parameters in the test to determine how the test should
# be run.
#
# @param $test      Test parameters
#
# @retval 0     Test passed
# @retval 1     Test failed for some reason
# @retval 2     Test crashed (signal generated)
# @retval -1    Test skipped

sub run_test
{
    my ($test) = @_;
    my $vars = setup_variables($test);

    my $name = $test->{'name'};
    my $disable = substitute($test->{'disable'}, $vars);
    my $cmd = substitute($test->{'command'}, $vars, 1);
    my $creates = substitute($test->{'creates'}, $vars);
    my $length = substitute($test->{'length'}, $vars);
    my $expect = substitute($test->{'expect'}, $vars);
    my $replacements = substitute($test->{'replace'}, $vars);
    my $wantrc = substitute($test->{'rc'}, $vars) || 0;
    my $input = substitute($test->{'input'}, $vars);
    my $inputline = substitute($test->{'inputline'}, $vars);

    $length = number($length);

    if (defined($creates))
    {
        $creates = native_filename($creates);
        unlink($creates);
    }

    printf '  %-34s : ', $name;

    if ($disable)
    {
        # They requested this test not run for a reason.
        $test->{'skip'} = 1;
        $test->{'result'} = 'skip';
        $test->{'result_message'} = $disable;
        print "SKIP: $disable\n";
        return -1;
    }

    my $cmdtorun = $cmd;
    if ($^O ne 'riscos')
    {
        # Make the parameters safe for unix-like shells
        $cmdtorun =~ s/([$()&*?;~|`])/\\$1/g;
    }
    if ($cmdtorun !~ / 2>/)
    {
        $cmdtorun .= ' 2>&1';
    }
    if (defined $input)
    {
        $input = native_filename($input);
    }
    elsif (defined $inputline)
    {
        $input = tempfilename('input');
        open(my $infh, "> $input") || die "Cannot create temporary input file '$input': $!";
        print $infh "$inputline\n";
        close($infh);
    }
    if (defined $input)
    {
        $cmdtorun .= " < $input";
    }
    my $output = `$cmdtorun`;
    my $sig = ($? & 255);
    my $rc = $sig ? 128+$sig : ($? >> 8);
    if ($? == -1)
    {
        # File not found
        $sig = -1;
        $rc = 128;
        $output = "$cmdtorun could not be found";
    }

    my $fail = undef;
    if ($rc != $wantrc)
    {
        $fail = "Expected RC $wantrc, got $rc";
    }
    if (!$fail && defined $expect)
    {
        my $expected = read_file($expect, 'expect file');
        my $native_expect = native_filename($expect);

        # If they supplied replacements, see if we can apply them
        if ($replacements)
        {
            $output = apply_replacements($replacements, $output);
        }
        if ($output ne $expected)
        {
            $fail = "Expected output did not match";
            open(my $fh, "> $native_expect-actual") || die "Could not write expected output to '$native_expect-actual': $!";
            print $fh $output;
            close($fh);
        }
        else
        {
            unlink "$native_expect-actual"
        }
    }
    if (!$fail && defined $creates)
    {
        if (!-f $creates)
        {
            $fail = "Expected to create $creates, but didn't";
        }
        elsif (defined $length)
        {
            my $gotlength = -s $creates;
            if ($gotlength != $length)
            {
                $fail = "Expected output length $length, but got $gotlength";
            }
        }

        if (!$fail)
        {
            for my $checker (keys %checkers)
            {
                if (defined $test->{$checker})
                {
                    my %args = %{$test->{$checker}};
                    my $func = $checkers{$checker};
                    eval {
                        for my $key (keys %args)
                        {
                            $args{$key} = substitute($args{$key}, $vars);
                        }
                        $fail = & $func ($creates, \%args);
                    };
                    if ($@)
                    {
                        $fail = "Exception: $@";
                        chomp $fail;
                    }
                    if ($fail)
                    {
                        $fail = "$checker: $fail";
                        last;
                    }
                }
            }
        }

        # Clear away the successfully created file.
        if (!$fail)
        {
            unlink $creates;
        }
    }
    if ($fail)
    {
        if ($sig)
        {
            print "CRASH: $fail\n";
            $test->{'result'} = 'crash';
        }
        else
        {
            print "FAIL: $fail\n";
            $test->{'result'} = 'fail';
        }
        $test->{'result_message'} = $fail;
        $test->{'result_output'} = $output;
    }
    else
    {
        print "OK\n";
        $test->{'result'} = 'pass';
    }
    if ($verbose)
    {
        $cmd =~ s/\Q$testtool/<$testtoolname>/g;
        if ($showcmd)
        {
            print "    $cmd\n";
        }
        if ($fail)
        {
            if ($outputdump)
            {
                print map { "    $_\n" } split /\n/, $output;
            }
        }
    }

    if ($outputsavedir)
    {
        my $dir = "$outputsavedir";
        mkdir "$dir";
        my $subdir = $test->{'group'};
        $subdir =~ s/ /-/g;
        $subdir =~ s/\//_/g;
        $dir = sprintf "%s/%03d_%s", $dir, $test->{'group-index'}, $subdir;
        mkdir "$dir";
        my $leaf = $name;
        $name =~ s/ /-/g;
        $name =~ s/\//_/g;
        my $path = sprintf "%s/%03d_%s.log", $dir, $test->{'test-index'}, $leaf;

        open(my $fh, "> $path") || die "Cannot open output save file '$path': $!";
        print $fh $output;
        close($fh);
    }

    return 2 if ($sig);
    return $fail ? 1 : 0;
}


sub xml_escape
{
    my ($str) = @_;
    $str =~ s/&/&amp;/g;
    $str =~ s/</&lt;/g;
    $str =~ s/>/&gt;/g;
    $str =~ s/'/&apos;/g;
    $str =~ s/"/&quot;/g;

    return $str;
}


sub write_junitxml
{
    my ($output, @groups) = @_;
    my $nerrors = 0;
    my $nfailures = 0;
    my $ntests = 0;
    my $nskipped = 0;

    my %result_tag_name = (
            'pass' => undef,
            'skip' => 'skipped',
            'fail' => 'failure',
            'crash' => 'error',
        );
    my %has_message = (
            'skip' => 0,
            'fail' => 1,
            'crash' => 1,
        );

    # sum the counts for the top level testsuite
    for my $group (@groups)
    {
        $nerrors += $group->{'crash'};
        $nfailures += $group->{'fail'};
        $ntests += $group->{'pass'} + $nerrors + $nfailures;
        $nskipped += $group->{'skip'};
    }

    open(my $fh, "> $output") || die "Cannot write JunitXML '$output': $!";

    print $fh "<?xml version=\"1.0\"?>\n";
    # FIXME: Should skipped be mapped to 'disabled' at the top level?
    print $fh "<testsuites tests=\"$ntests\" failures=\"$nfailures\" errors=\"$nerrors\">\n";
    for my $group (@groups)
    {
        $nerrors = $group->{'crash'};
        $nfailures = $group->{'fail'};
        $ntests = $group->{'pass'} + $nerrors + $nfailures;
        $nskipped = $group->{'skip'};
        print $fh "  <testsuite name=\"" . xml_escape($group->{'group'}) . "\" tests=\"$ntests\" failures=\"$nfailures\" errors=\"$nerrors\" skipped=\"$nskipped\">\n";
        for my $test (@{ $group->{'tests'} })
        {
            next if (!defined $test->{'result'});
            print $fh "    <testcase classname=\"ToolTest\" name=\"" . xml_escape($test->{'name'}) . "\"";
            if ($test->{'result'} eq 'pass')
            {
                print $fh " />\n";
            }
            else
            {
                my $message = "$test->{'result'}: $test->{'result_message'}";
                print $fh ">\n";
                my $tag = $result_tag_name{ $test->{'result'} };
                print $fh "      <$tag";
                if ($has_message{ $test->{'result'} })
                {
                    print $fh " message=\"$message\"";
                }
                print $fh ">";
                my $output = $test->{'result_output'};
                if ($output)
                {
                    # Escape any ]]> that might confuse the CDATA
                    $output =~ s/]]>/]]]]><!\[CDATA\[>/g;
                    print $fh "<![CDATA[${output}]]>\n;";
                }
                print $fh "      </$tag>\n";
                print $fh "    </testcase>\n";
            }
        }
        print $fh "  </testsuite>\n";
    }
    print $fh "</testsuites>\n";
    close($fh);
}


#######################################################################

# Chunk file constants
my $ChunkFileId = 0xC3CBC6C5;
my $ChunkFileIdReverse = 0xC5C6CBC3;

# AOF Chunk file constants
my $aof_prefix = 'OBJ_';
my $aof_header = 'OBJ_HEAD';
my $aof_areas = 'OBJ_AREA';
my $aof_identification = 'OBJ_IDFN';
my $aof_symbols = 'OBJ_SYMT';
my $aof_strings = 'OBJ_STRT';

# ALF Chunk file constants
my $alf_prefix = 'LIB_';
my $alf_timestamp = 'LIB_TIME';
my $alf_version = 'LIB_VRSN';
my $alf_directory = 'LIB_DIRY';


##
# Read a 32bit word
sub readword
{
    my ($cfd) = @_;
    my $word;
    if (sysread($cfd->{'fh'}, $word, 4) != 4)
    {
        die "Short read of word";
    }
    if ($cfd->{'reverse'})
    {
        $word = unpack 'N', $word;
    }
    else
    {
        $word = unpack 'V', $word;
    }
    if ($word < 0)
    {
        die "Read a negative words?!";
    }
    return $word;
}

##
# Read a fixed length string
sub readfixedstring
{
    my ($cfd, $len) = @_;
    my $str;
    sysread($cfd->{'fh'}, $str, $len);
    return $str;
}


##
# Process a chunk file
sub chunkfile
{
    my ($filename) = @_;
    my $cf = {
            'filesize' => -s $filename,
            'endian' => 'unknown',
            'MaxChunks' => 0,
            'NumChunks' => 0,
            'chunks' => [],
            'chunknames' => {},
        };
    open(my $cfh, "< $filename") || die "Cannot read chunk file '$filename'\n";
    my $cfd = {
            'fh' => $cfh,
            'reverse' => 0,
        };

    my $word = readword($cfd);
    if ($word == $ChunkFileId)
    {
        $cf->{'endian'} = 'little';
    }
    elsif ($word == $ChunkFileIdReverse)
    {
        $cf->{'endian'} = 'big';
        $cfd->{'reverse'} = 1;
    }


    $cf->{'cfd'} = $cfd;
    $cf->{'MaxChunks'} = readword($cfd);
    $cf->{'NumChunks'} = readword($cfd);

    my $filesize = $cf->{'filesize'};

    for my $n (0..$cf->{'MaxChunks'}-1)
    {
        my $chunkid = readfixedstring($cfd, 8);
        my $fileoffset = readword($cfd);
        my $size = readword($cfd);
        my $chunk_header = {
                'index' => $n,
                'chunkId' => $chunkid,
                'fileOffset' => $fileoffset,
                'size' => $size,
            };
        push @{$cf->{'chunks'}}, $chunk_header;
        $cf->{'chunknames'}->{$chunkid} = $chunk_header;

        if ($chunk_header->{'fileOffset'} > $filesize)
        {
            die "Chunk #$n starts at $chunk_header->{'fileOffset'}, which is > $filesize\n";
        }
        my $end = $chunk_header->{'fileOffset'} + $chunk_header->{'size'};
        if ($end > $filesize)
        {
            die "Chunk #$n end at $end, which is > $filesize\n";
        }
    }

    return $cf;
}


#######################################################################

# AOF-specific settings

# Attribute flags
my $aof_attribute_absolute = (1<<8);
my $aof_attribute_code = (1<<9);
my $aof_attribute_common = (1<<10);
my $aof_attribute_commonref = (1<<11);
my $aof_attribute_zeroinit = (1<<12);
my $aof_attribute_readonly = (1<<13);
my $aof_attribute_pic = (1<<14);
my $aof_attribute_debug = (1<<15);
my $aof_attribute_code_32bit = (1<<16);
my $aof_attribute_code_reentrant = (1<<17);
my $aof_attribute_code_fpe = (1<<18);
my $aof_attribute_code_swst = (1<<19);
my $aof_attribute_code_thumb = (1<<20);
my $aof_attribute_code_halfword = (1<<21);
my $aof_attribute_code_interworking = (1<<22);
my $aof_attribute_data_based = (1<<20);
my $aof_attribute_data_shared = (1<<21);
my $aof_attribute_data_sharedmask = (15<<24);
my $aof_attribute_data_sharedshift = (24);


sub aof_header
{
    my ($cf) = @_;
    my $cfd = $cf->{'cfd'};
    my $chunk = $cf->{'chunknames'}->{$aof_header};
    if (!defined $chunk)
    {
        return {};
    }
    seek($cfd->{'fh'}, $chunk->{'fileOffset'}, 0);

    $chunk->{'ObjectFileType'} = readword($cfd);
    $chunk->{'VersionId'} = readword($cfd);
    $chunk->{'NumberOfAreas'} = readword($cfd);
    $chunk->{'NumberOfSymbols'} = readword($cfd);
    $chunk->{'EntryAreaIndex'} = readword($cfd);
    $chunk->{'EntryAreaOffset'} = readword($cfd);
    $chunk->{'AreaHeaders'} = [];

    $chunk->{'totalAreaSize'} = 0;

    for my $areanum (0..$chunk->{'NumberOfAreas'}-1)
    {
        # 5 words per area
        my $area = {
                'AreaNameSID' => readword($cfd),
                'Attributes' => readword($cfd),
                'AreaSize' => readword($cfd),
                'NumberOfRelocations' => readword($cfd),
                'BaseAddress' => readword($cfd),
            };
        push @{ $chunk->{'AreaHeaders'} }, $area;
        $area->{'Alignment'} = 1<<($area->{'Attributes'} & 255);

        if ($debug_aof) {
            print "AOFArea:\n";
            print map { "  $_: $area->{$_}\n" } ('AreaNameSID',
                                                 'Attributes',
                                                 'AreaSize',
                                                 'NumberOfRelocations',
                                                 'BaseAddress',
                                                 'Alignment');
        }

        $chunk->{'totalAreaSize'} += $area->{'AreaSize'};
    }

    return $chunk;
}

sub aof_strings
{
    my ($cf) = @_;
    my $cfd = $cf->{'cfd'};
    my $chunk = $cf->{'chunknames'}->{$aof_strings};
    if (!defined $chunk)
    {
        return {};
    }
    sysseek($cfd->{'fh'}, $chunk->{'fileOffset'}, 0);

    $chunk->{'tablelength'} = readword($cfd);
    sysseek($cfd->{'fh'}, $chunk->{'fileOffset'}, 0);
    $chunk->{'table'} = '';
    sysread($cfd->{'fh'}, $chunk->{'table'}, $chunk->{'tablelength'});

    return $chunk;
}

sub aof_identification
{
    my ($cf) = @_;
    my $cfd = $cf->{'cfd'};
    my $chunk = $cf->{'chunknames'}->{$aof_identification};
    if (!defined $chunk)
    {
        return {};
    }
    sysseek($cfd->{'fh'}, $chunk->{'fileOffset'}, 0);

    my $name = readfixedstring($cfd, $chunk->{'size'});
    $name =~ s/\0.*$//;
    $chunk->{'Identification'} = $name;

    return $chunk;
}

# Checking function

sub aof_check
{
    my ($filename, $args) = @_;

    my $cf = chunkfile($filename);
    my $header = aof_header($cf);

    # FIXME: Version check?

    my $areasize = $header->{'totalAreaSize'};
    if ($areasize % 4 != 0)
    {
        return "Total area size must be a multiple of 4, but got $areasize";
    }

    if (defined $args->{'totalareasize'} &&
        $args->{'totalareasize'} != $areasize)
    {
        return "Expected total area size $args->{'totalareasize'}, but got $areasize";
    }

    return undef;
}

#######################################################################

# ALF-specific settings

sub alf_directory
{
    my ($cf) = @_;
    my $cfd = $cf->{'cfd'};
    my $chunk = $cf->{'chunknames'}->{$alf_directory};
    if (!defined $chunk)
    {
        die "No ALF directory '$alf_directory' present in Chunk File\n";
    }
    sysseek($cfd->{'fh'}, $chunk->{'fileOffset'}, 0);

    $chunk->{'Directory'} = [];
    my $end = $chunk->{'fileOffset'} + $chunk->{'size'};
    while (sysseek($cfd->{'fh'}, 0, 1) < $end)
    {
        my $entry = {
                'ChunkIndex' => readword($cfd),
                'EntryLength' => readword($cfd),
                'DataLength' => readword($cfd),
            };
        if ($entry->{'EntryLength'} == 0)
        {
            die "EntryLength is stupid?"
        }
        $entry->{'Data'} = readfixedstring($cfd, $entry->{'DataLength'} - 8);
        my $name = "$entry->{'Data'}";
        $name =~ s/\0.*$//;
        $entry->{'Name'} = $name;
        $entry->{'TimeStampHi'} = readword($cfd);
        $entry->{'TimeStampLo'} = readword($cfd);
        push @{$chunk->{'Directory'}}, $entry;
    }

    return $chunk;
}

sub alf_timestamp
{
    my ($cf) = @_;
    my $cfd = $cf->{'cfd'};
    my $chunk = $cf->{'chunknames'}->{$alf_directory};
    if (!defined $chunk)
    {
        return {};
    }
    sysseek($cfd->{'fh'}, $chunk->{'fileOffset'}, 0);

    $chunk->{'TimeStampHi'} = readword($cfd);
    $chunk->{'TimeStampLo'} = readword($cfd);

    return $chunk;
}

sub alf_version
{
    my ($cf) = @_;
    my $cfd = $cf->{'cfd'};
    my $chunk = $cf->{'chunknames'}->{$alf_version};
    if (!defined $chunk)
    {
        return {};
    }
    sysseek($cfd->{'fh'}, $chunk->{'fileOffset'}, 0);

    if ($chunk->{'size'} != 4)
    {
        die "Version chunk is $chunk->{'size'} bytes, should be 4";
    }

    $chunk->{'Version'} = readword($cfd);

    return $chunk;
}

# Checking function

sub alf_check
{
    my ($filename, $args) = @_;

    my $cf = chunkfile($filename);
    my $dir = alf_directory($cf);

    my $version = alf_version($cf);
    if ($version->{"Version"} != 1)
    {
        die "Unrecognised ALF version: $version (only 1 supported)";
    }

    my $files = $dir->{'Directory'};
    my $nfiles = scalar(@$files);
    if ($args->{'files'} != $nfiles)
    {
        return "Expected $args->{'files'}, but got $nfiles";
    }

    return undef;
}

#######################################################################

# Text-specific settings


# Checking function

sub text_check
{
    my ($filename, $args) = @_;

    my $txt = read_file($filename, 'generated text file');

    if ($args->{'replace'})
    {
        $txt = apply_replacements($args->{'replace'}, $txt);
    }
    if ($args->{'matches'})
    {
        my $expected = read_file($args->{'matches'}, 'expected text file');
        my $native_expect = native_filename($args->{'matches'});
        if ($txt ne $expected)
        {
            open(my $fh, "> $native_expect-actual")
                || die "Cannot write actual output content '$native_expect-actual': $!";
            print $fh $txt;
            close($fh);
            return "Does not match expected text file (see $native_expect-actual)";
        }
        else
        {
            unlink "$native_expect-actual"
        }
    }

    return undef;
}

#######################################################################

# Binary-specific settings


sub binary_load
{
    my ($filename) = @_;
    my $bin = {
            'filename' => $filename,
            'data' => read_file($filename, 'generated binary file'),
            'size' => -s $filename,
        };

    return $bin;
}


##
# Read a word from the file
sub binary_word
{
    my ($bin, $offset) = @_;
    if ($offset + 4 > $bin->{'size'})
    {
        die "Word offset '$offset' is outside binary file (length $bin->{'size'})";
    }
    my $word = substr($bin->{'data'}, $offset, 4);
    my $value = unpack('V', $word);
    return $value;
}


##
# Read a byte from the file
sub binary_byte
{
    my ($bin, $offset) = @_;
    if ($offset + 4 > $bin->{'size'})
    {
        die "Byte offset '$offset' is outside binary file (length $bin->{'size'})";
    }
    my $word = substr($bin->{'data'}, $offset, 1);
    my $value = unpack('C', $word);
    return $value;
}


##
# Read a string from the file
sub binary_string
{
    my ($bin, $offset) = @_;
    if ($offset + 1 > $bin->{'size'})
    {
        die "String offset '$offset' is outside binary file (length $bin->{'size'})";
    }
    my $str = substr($bin->{'data'}, $offset);
    my $value = unpack('Z*', $str);
    return $value;
}


# Checking function

sub binary_check
{
    my ($filename, $args) = @_;

    my $bin = binary_load($filename);

    if ($args->{'checkfile'})
    {
        my $native_expect = native_filename($args->{'checkfile'});
        open(my $fh, "< $native_expect") || die "Cannot read binary check file '$native_expect': $!\n";
        my @fail;
        while (<$fh>)
        {
            chomp;
            if (/^ *#/)
            {
                # Comment line
                next;
            }
            if (! s/^([0-9a-fx&]+) +//i)
            {
                die "Unrecognised offset in: '$_'\n";
            }
            my $offset = number($1);

            if (/word: (.*)$/i)
            {
                my $expect = $1;
                $expect = number($expect);
                my $value = binary_word($bin, $offset);
                if ($expect != $value)
                {
                    push @fail, sprintf "Word at offset 0x%x was 0x%08x, expected 0x%08x", $offset, $value, $expect;
                }
            }
            elsif (/byte: (.*)$/i)
            {
                my $expect = $1;
                $expect = number($expect);
                my $value = binary_byte($bin, $offset);
                if ($expect != $value)
                {
                    push @fail, sprintf "Byte at offset 0x%x was 0x%02x, expected 0x%02x", $offset, $value, $expect;
                }
            }
            elsif (/string: (.*)$/i)
            {
                my $expect = $1;
                my $value = binary_string($bin, $offset);
                if ($expect ne $value)
                {
                    push @fail, sprintf "String at offset 0x%x was '%s', expected '%s'", $offset, $value, $expect;
                }
            }
            else
            {
                die "Unrecognised binary checkfile directive: $_";
            }
        }
        close($fh);
        if (@fail)
        {
            my $number = scalar(@fail);
            if ($number > 1)
            {
                return "$number binary checks failed:\n" . join("\n", @fail);
            }
            return $fail[0];
        }
    }

    if ($args->{'matches'})
    {
        my $expected = read_file($args->{'matches'}, 'expected binary file');
        my $native_expect = native_filename($args->{'matches'});
        if ($bin->{'data'} ne $expected)
        {
            open(my $fh, "> $native_expect-actual")
                || die "Cannot write actual output content '$native_expect-actual': $!";
            print $fh $bin->{'data'};
            close($fh);
            return "Does not match expected binary file (see $native_expect-actual)";
        }
        else
        {
            unlink "$native_expect-actual"
        }
    }

    return undef;
}


#######################################################################

# Actual tests

# Execute in the directory requested
# NOTE: On RISC OS, this is destructive, as there is only one CWD.
chdir "$dir";

# Ensure we output immediately, so that stderr appears in a sane place
$| = 1;

my @groups = parse_test_script($testscript);

my $pass = 0;
my $fail = 0;
my $crash = 0;
my $skip = 0;
for my $group (@groups)
{
    if ($group->{'skip'})
    {
        # No need to mark individual tests; they will have been
        # flagged as skipped already.
        $group->{'skip'} = scalar(@{ $group->{'tests'} });
        $skip += $group->{'skip'};
        next;
    }
    print "$group->{'group'}:\n";
    $group->{'skip'} = 0;
    for my $test (@{ $group->{'tests'} })
    {
        if ($test->{'skip'})
        {
            # The command line matching requested skipping
            $group->{'skip'}++;
            $test->{'result'} = 'skip';
            $skip++;
            next;
        }
        my $state = run_test($test);
        if ($state == 0)
        {
            $group->{'pass'}++;
            $pass++;
        }
        elsif ($state == 1)
        {
            $group->{'fail'}++;
            $fail++;
        }
        elsif ($state == 2)
        {
            $group->{'crash'}++;
            $crash++;
        }
        elsif ($state == -1)
        {
            $group->{'skip'}++;
            $skip++;
        }
    }
}

print "\n";
print "-----------\n";
printf "Pass:  %6i\n", $pass;
printf "Fail:  %6i\n", $fail;
printf "Crash: %6i\n", $crash;
printf "Skip:  %6i\n", $skip;
print "-----------\n";
my $total = $pass + $fail + $crash;
printf "Total run:   %6i\n", $total;
if ($total != 0)
{
    printf "Pass ratio:  %6.2f %%\n", 100 * $pass / $total;
    printf "Fail ratio:  %6.2f %%\n", 100 * $fail / $total;
    if ($crash)
    {
        printf "Crash ratio: %6.2f %%\n", 100 * $crash / $total;
    }
}

if ($junitxml)
{
    write_junitxml($junitxml, @groups);
}

exit(($fail+$crash) == 0 ? 0 : 1);
