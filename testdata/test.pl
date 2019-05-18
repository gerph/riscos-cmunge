#!/usr/bin/perl
##
# Build the test code to check that objasm works.
#

use warnings;
use strict;

my $testtool = undef;
my $dir = undef;

my $group = undef;
my $test = undef;
my $acc = undef;

# Whether we're debugging
my $debug_filename = 0;
my $debug_replace = 0;
my $debug_aof = 0;

# Verbose output?
my $verbose = 1;
my $showcmd = 0;

# Show failure output
my $outputdump = 0;

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
        elsif ($switch eq 'junitxml')
        {
            $junitxml = shift;
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
    print "    -show-command    Show command executed\n";
    print "    -show-output     Show output on failure\n";
    print "    -debug <type>    Enable debug types as comma-separated list\n";
    exit 1;
}

my $extensions_re = "s|c|h|cmhg|s_c|o";

my ($none, $testtoolname) = ($testtool =~ /(^|\/)([^\/]*)$/);

# NOTE: Wrong for RISC OS.
my $testscript = "$dir/tests.txt";

my %testparams = map { $_ => 1 } (
        'command',
        'expect',
        'creates',
        'length',
        'rc',
        'file',
        'replace',
    );

my %handlers = (
        'text' => \&text_check,
        'aof' => \&aof_check,
        'alf' => \&alf_check,
    );


my @groups;
open(my $testfh, "< $testscript") || die "Cannot open test script '$testscript': $!";
while (<$testfh>)
{
    chomp;
    next if (/^ *#/ || /^ *$/);

    my $handler;
    my ($cmd, $arg) = (/^([A-Za-z]+): +(.*?) *$/);
    if (!$cmd)
    {
        # Not a base command specification; so try a handler value.
        ($handler, $cmd, $arg) = (/^([A-Za-z]+):([A-Za-z]+): *(.*?) *$/);
        $handler = lc $handler;
        if (!defined $handlers{$handler})
        {
            die "Unrecognised handler '$handler' in '$_'";
        }
    }

    if (!$cmd)
    {
        die "Cannot understand line '$_'";
    }

    if (defined $handler)
    {
        if (!defined $acc->{$handler})
        {
            $acc->{$handler} = {};
        }
        $acc->{$handler}->{lc $cmd} = $arg;
    }
    elsif ($cmd eq 'Group')
    {
        $group = {
                'group' => $arg,
                'tests' => [],
                'pass' => 0,
                'fail' => 0,
                'crash' => 0,
            };
        delete $acc->{'tests'};
        $test = undef;
        $acc = $group;
        push @groups, $group;
    }
    elsif ($cmd eq 'Test')
    {
        $test = {
                %$group,
                'name' => $arg,
            };
        push @{$group->{'tests'}}, $test;
        delete $test->{'tests'};
        $acc = $test;
    }
    elsif (defined($testparams{lc $cmd}))
    {
        $acc->{lc $cmd} = $arg;
    }
    else
    {
        die "Unknown command '$cmd' in '$_'";
    }
}

sub setup_variables
{
    my ($test) = @_;
    my $vars = {};

    $vars->{'TOOL'} = $testtool;
    $vars->{'FILE'} = $test->{'file'} || '';
    if (!$test->{'file'})
    {
        $vars->{'OFILE'} = '';
        $vars->{'SFILE'} = '';
        $vars->{'BASE'} = '';
    }
    elsif ($test->{'file'} =~ /^($extensions_re)\.(.*)/)
    {
        $vars->{'OFILE'} = "o.$2";
        $vars->{'SFILE'} = "s.$2";
        $vars->{'BASE'} = "$2";
    }
    elsif ($test->{'file'} =~ /^($extensions_re)\/(.*)/)
    {
        $vars->{'OFILE'} = "o/$2";
        $vars->{'SFILE'} = "s/$2";
        $vars->{'BASE'} = "$2";
    }
    else
    {
        die "Unrecognised filename format: '$test->{'file'}'"
    }

    return $vars;
}

sub substitute
{
    my ($str, $vars) = @_;
    return $str if (!defined $str);

    $str =~ s/\$([A-Z]+)/$vars->{$1} || die "Variable '$1' not defined in '$str'"/eg;
    return $str;
}

sub number
{
    my ($str) = @_;
    return undef if (!defined $str);

    if ($str =~ /^0x([0-9a-fA-F]+)$/)
    {
        return hex($str);
    }
    return $str;
}

sub native_filename
{
    my ($filename) = @_;
    my $dirsep;

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
        if (m!^s([^a-zA-Z0-9])(.*)\1(.*)\1([mgs])$!)
        {
            my $from = $2;
            my $to = $3;
            my $opts = $4;

            #print "REPLACE: '$from' => '$to' '$opts'\n" if ($debug_replace);
            if (!defined $opts)
            {
                $output =~ s/$from/$to/;
            }
            elsif ($opts eq 'g')
            {
                $output =~ s/$from/$to/g;
            }
            elsif ($opts eq 's' || $opts eq 'm')
            {
                # Treat both these options as the same thing,
                # and applying globally.
                $output =~ s/$from/$to/smg;
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

sub run_test
{
    my ($test) = @_;
    my $vars = setup_variables($test);

    my $name = $test->{'name'};
    my $cmd = substitute($test->{'command'}, $vars);
    my $creates = substitute($test->{'creates'}, $vars);
    my $length = substitute($test->{'length'}, $vars);
    my $expect = substitute($test->{'expect'}, $vars);
    my $replacements = substitute($test->{'replace'}, $vars);
    my $wantrc = substitute($test->{'rc'}, $vars) || 0;

    $length = number($length);

    if (defined($creates))
    {
        $creates = native_filename($creates);
        unlink($creates);
    }

    printf '  %-34s : ', $name;
    my $cmdtorun = $cmd;
    if ($cmdtorun !~ / 2>/)
    {
        $cmdtorun .= ' 2>&1';
    }
    my $output = `$cmdtorun`;
    my $sig = ($? & 255);
    my $rc = $sig ? 128+$sig : ($? >> 8);

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
            open(my $fh, "> $native_expect-actual");
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
            for my $handler (keys %handlers)
            {
                if (defined $test->{$handler})
                {
                    my $args = $test->{$handler};
                    my $func = $handlers{$handler};
                    eval {
                        $fail = & $func ($creates, $args);
                    };
                    if ($@)
                    {
                        $fail = "Exception: $@";
                        chomp $fail;
                    }
                    if ($fail)
                    {
                        $fail = "$handler: $fail";
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

    return 2 if ($sig);
    return $fail ? 1 : 0;
}


sub write_junitxml
{
    my ($output, @groups) = @_;
    my $nerrors = 0;
    my $nfailures = 0;
    my $ntests = 0;

    # sum the counts for the top level testsuite
    for my $group (@groups)
    {
        $nerrors += $group->{'crash'};
        $nfailures += $group->{'fail'};
        $ntests += $group->{'pass'} + $nerrors + $nfailures;
    }

    open(my $fh, "> $output") || die "Cannot write JunitXML file '$output': $!";

    print $fh "<?xml version=\"1.0\"?>\n";
    print $fh "<testsuites tests=\"$ntests\" failures=\"$nfailures\" errors=\"$nerrors\">\n";
    for my $group (@groups)
    {
        $nerrors = $group->{'crash'};
        $nfailures = $group->{'fail'};
        $ntests = $group->{'pass'} + $nerrors + $nfailures;
        print $fh "  <testsuite name=\"$group->{'group'}\" tests=\"$ntests\" failures=\"$nfailures\" errors=\"$nerrors\">\n";
        for my $test (@{ $group->{'tests'} })
        {
            next if (!defined $test->{'result'});
            print $fh "    <testcase classname=\"ToolTest\" name=\"$test->{'name'}\"";
            if ($test->{'result'} eq 'pass')
            {
                print $fh " />\n";
            }
            else
            {
                my $message = "$test->{'result'}: $test->{'result_message'}";
                print $fh ">\n";
                my $tag = $test->{'result'} eq 'fail' ? 'failure' : 'error';
                print $fh "      <$tag message=\"$message\">";
                my $output = "$test->{'result_output'}";
                # Escape any ]]> that might confuse the CDATA
                $output =~ s/]]>/]]]]><!\[CDATA\[>/g;
                print $fh "<![CDATA[${output}]]>\n;";
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
        $word = unpack 'n', $word;
    }
    else
    {
        $word = unpack 'v', $word;
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
            open(my $fh, "> $native_expect-actual");
            print $fh $txt;
            close($fh);
            return "Does not match expected text file";
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

my $pass = 0;
my $fail = 0;
my $crash = 0;
for my $group (@groups)
{
    print "$group->{'group'}:\n";
    for my $test (@{ $group->{'tests'} })
    {
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
    }
}

print "\n";
print "-----------\n";
print "Pass:  $pass\n";
print "Fail:  $fail\n";
print "Crash: $crash\n";

if ($junitxml)
{
    write_junitxml($junitxml, @groups);
}

exit(($fail+$crash) == 0 ? 0 : 1);
