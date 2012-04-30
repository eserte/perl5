#!./perl

# This file tests the results of calling subroutines in the CORE::
# namespace with ampersand syntax.  In other words, it tests the bodies of
# the subroutines themselves, not the ops that they might inline themselves
# as when called as barewords.

# Other tests for CORE subs are in coresubs.t

BEGIN {
    chdir 't' if -d 't';
    @INC = qw(. ../lib);
    require "test.pl";
    $^P |= 0x100;
}

sub lis($$;$) {
  &is(map(@$_ ? "[@{[map $_//'~~u~~', @$_]}]" : 'nought', @_[0,1]), $_[2]);
}

package hov {
  use overload '%{}' => sub { +{} }
}
package sov {
  use overload '${}' => sub { \my $x }
}

my %op_desc = (
 evalbytes=> 'eval "string"',
 join     => 'join or string',
 readline => '<HANDLE>',
 readpipe => 'quoted execution (``, qx)',
 reset    => 'symbol reset',
 ref      => 'reference-type operator',
);
sub op_desc($) {
  return $op_desc{$_[0]} || $_[0];
}


# This tests that the &{} syntax respects the number of arguments implied
# by the prototype, plus some extra tests for the (_) prototype.
sub test_proto {
  my($o) = shift;

  # Create an alias, for the caller’s convenience.
  *{"my$o"} = \&{"CORE::$o"};

  my $p = prototype "CORE::$o";
  $p = '$;$' if $p eq '$_';

  if ($p eq '') {
    $tests ++;

    eval " &CORE::$o(1) ";
    like $@, qr/^Too many arguments for $o at /, "&$o with too many args";

  }
  elsif ($p =~ /^_;?\z/) {
    $tests ++;

    eval " &CORE::$o(1,2) ";
    my $desc = quotemeta op_desc($o);
    like $@, qr/^Too many arguments for $desc at /,
      "&$o with too many args";

    if (!@_) { return }

    $tests += 6;

    my($in,$out) = @_; # for testing implied $_

    # Since we have $in and $out values, we might as well test basic amper-
    # sand calls, too.

    is &{"CORE::$o"}($in), $out, "&$o";
    lis [&{"CORE::$o"}($in)], [$out], "&$o in list context";

    $_ = $in;
    is &{"CORE::$o"}(), $out, "&$o with no args";

    # Since there is special code to deal with lexical $_, make sure it
    # works in all cases.
    undef $_;
    {
      my $_ = $in;
      is &{"CORE::$o"}(), $out, "&$o with no args uses lexical \$_";
    }
    # Make sure we get the right pad under recursion
    my $r;
    $r = sub {
      if($_[0]) {
        my $_ = $in;
        is &{"CORE::$o"}(), $out,
           "&$o with no args uses the right lexical \$_ under recursion";
      }
      else {
        &$r(1)
      }
    };
    &$r(0);
    my $_ = $in;
    eval {
       is "CORE::$o"->(), $out, "&$o with the right lexical \$_ in an eval"
    };   
  }
  elsif ($p =~ '^;([$*]+)\z') { # ;$ ;* ;$$ etc.
    my $maxargs = length $1;
    $tests += 1;    
    eval " &CORE::$o((1)x($maxargs+1)) ";
    my $desc = quotemeta op_desc($o);
    like $@, qr/^Too many arguments for $desc at /,
        "&$o with too many args";
  }
  elsif ($p =~ '^([$*]+);?\z') { # Fixed-length $$$ or ***
    my $args = length $1;
    $tests += 2;    
    my $desc = quotemeta op_desc($o);
    eval " &CORE::$o((1)x($args-1)) ";
    like $@, qr/^Not enough arguments for $desc at /, "&$o w/too few args";
    eval " &CORE::$o((1)x($args+1)) ";
    like $@, qr/^Too many arguments for $desc at /, "&$o w/too many args";
  }
  elsif ($p =~ '^([$*]+);([$*]+)\z') { # Variable-length $$$ or ***
    my $minargs = length $1;
    my $maxargs = $minargs + length $2;
    $tests += 2;    
    eval " &CORE::$o((1)x($minargs-1)) ";
    like $@, qr/^Not enough arguments for $o at /, "&$o with too few args";
    eval " &CORE::$o((1)x($maxargs+1)) ";
    like $@, qr/^Too many arguments for $o at /, "&$o with too many args";
  }
  elsif ($p eq '_;$') {
    $tests += 1;

    eval " &CORE::$o(1,2,3) ";
    like $@, qr/^Too many arguments for $o at /, "&$o with too many args";
  }
  elsif ($p eq '@') {
    # Do nothing, as we cannot test for too few or too many arguments.
  }
  elsif ($p =~ '^[$*;]+@\z') {
    $tests ++;    
    $p =~ ';@';
    my $minargs = $-[0];
    eval " &CORE::$o((1)x($minargs-1)) ";
    my $desc = quotemeta op_desc($o);
    like $@, qr/^Not enough arguments for $desc at /,
       "&$o with too few args";
  }
  elsif ($p =~ /^\*\\\$\$(;?)\$\z/) { #  *\$$$ and *\$$;$
    $tests += 5;

    eval "&CORE::$o(1,1,1,1,1)";
    like $@, qr/^Too many arguments for $o at /,
         "&$o with too many args";
    eval " &CORE::$o((1)x(\$1?2:3)) ";
    like $@, qr/^Not enough arguments for $o at /,
         "&$o with too few args";
    eval " &CORE::$o(1,[],1,1) ";
    like $@, qr/^Type of arg 2 to &CORE::$o must be scalar reference at /,
        "&$o with array ref arg";
    eval " &CORE::$o(1,1,1,1) ";
    like $@, qr/^Type of arg 2 to &CORE::$o must be scalar reference at /,
        "&$o with scalar arg";
    eval " &CORE::$o(1,bless([], 'sov'),1,1) ";
    like $@, qr/^Type of arg 2 to &CORE::$o must be scalar reference at /,
        "&$o with non-scalar arg w/scalar overload (which does not count)";
  }
  elsif ($p =~ /^\\%\$*\z/) { #  \% and \%$$
    $tests += 5;

    eval "&CORE::$o(" . join(",", (1) x length $p) . ")";
    like $@, qr/^Too many arguments for $o at /,
         "&$o with too many args";
    eval " &CORE::$o(" . join(",", (1) x (length($p)-2)) . ") ";
    like $@, qr/^Not enough arguments for $o at /,
         "&$o with too few args";
    my $moreargs = ",1" x (length($p) - 2);
    eval " &CORE::$o([]$moreargs) ";
    like $@, qr/^Type of arg 1 to &CORE::$o must be hash reference at /,
        "&$o with array ref arg";
    eval " &CORE::$o(*foo$moreargs) ";
    like $@, qr/^Type of arg 1 to &CORE::$o must be hash reference at /,
        "&$o with typeglob arg";
    eval " &CORE::$o(bless([], 'hov')$moreargs) ";
    like $@, qr/^Type of arg 1 to &CORE::$o must be hash reference at /,
        "&$o with non-hash arg with hash overload (which does not count)";
  }
  elsif ($p =~ /^\\\[(\$\@%&?\*)](\$\@)?\z/) {
    $tests += 4;

    unless ($2) {
      $tests ++;
      eval " &CORE::$o(1,2) ";
      like $@, qr/^Too many arguments for $o at /,
        "&$o with too many args";
    }
    eval { &{"CORE::$o"}($2 ? 1 : ()) };
    like $@, qr/^Not enough arguments for $o at /,
         "&$o with too few args";
    my $more_args = $2 ? ',1' : '';
    eval " &CORE::$o(2$more_args) ";
    like $@, qr/^Type of arg 1 to &CORE::$o must be reference to one of(?x:
                ) \[\Q$1\E] at /,
        "&$o with non-ref arg";
    eval " &CORE::$o(*STDOUT{IO}$more_args) ";
    like $@, qr/^Type of arg 1 to &CORE::$o must be reference to one of(?x:
                ) \[\Q$1\E] at /,
        "&$o with ioref arg";
    my $class = ref *DATA{IO};
    eval " &CORE::$o(bless(*DATA{IO}, 'hov')$more_args) ";
    like $@, qr/^Type of arg 1 to &CORE::$o must be reference to one of(?x:
                ) \[\Q$1\E] at /,
        "&$o with ioref arg with hash overload (which does not count)";
    bless *DATA{IO}, $class;
    if (do {$1 !~ /&/}) {
      $tests++;
      eval " &CORE::$o(\\&scriggle$more_args) ";
      like $@, qr/^Type of arg 1 to &CORE::$o must be reference to one (?x:
                  )of \[\Q$1\E] at /,
        "&$o with coderef arg";
    }    
  }

  else {
    die "Please add tests for the $p prototype";
  }
}

# Test that &CORE::foo calls without parentheses (no new @_) can handle the
# total absence of any @_ without crashing.
undef *_;
&CORE::wantarray;
$tests++;
pass('no crash with &CORE::foo when *_{ARRAY} is undef');

test_proto '__FILE__';
test_proto '__LINE__';
test_proto '__PACKAGE__';
test_proto '__SUB__';

is file(), 'frob'    , '__FILE__ does check its caller'   ; ++ $tests;
is line(),  5        , '__LINE__ does check its caller'   ; ++ $tests;
is pakg(), 'stribble', '__PACKAGE__ does check its caller'; ++ $tests;
sub __SUB__test { &my__SUB__ }
is __SUB__test, \&__SUB__test, '&__SUB__';                  ++ $tests;

test_proto 'abs', -5, 5;

test_proto 'accept';
$tests += 6; eval q{
  is &CORE::accept(qw{foo bar}), undef, "&accept";
  lis [&{"CORE::accept"}(qw{foo bar})], [undef], "&accept in list context";

  &myaccept(my $foo, my $bar);
  is ref $foo, 'GLOB', 'CORE::accept autovivifies its first argument';
  is $bar, undef, 'CORE::accept does not autovivify its second argument';
  use strict;
  undef $foo;
  eval { 'myaccept'->($foo, $bar) };
  like $@, qr/^Can't use an undefined value as a symbol reference at/,
      'CORE::accept will not accept undef 2nd arg under strict';
  is ref $foo, 'GLOB', 'CORE::accept autovivs its first arg under strict';
};

test_proto 'alarm';
test_proto 'atan2';

test_proto 'bind';
$tests += 3;
is &CORE::bind('foo', 'bear'), undef, "&bind";
lis [&CORE::bind('foo', 'bear')], [undef], "&bind in list context";
eval { &mybind(my $foo, "bear") };
like $@, qr/^Bad symbol for filehandle at/,
     'CORE::bind dies with undef first arg';

test_proto 'binmode';
$tests += 3;
is &CORE::binmode(qw[foo bar]), undef, "&binmode";
lis [&CORE::binmode(qw[foo bar])], [undef], "&binmode in list context";
is &mybinmode(foo), undef, '&binmode with one arg';

test_proto 'bless';
$tests += 3;
like &CORE::bless([],'parcel'), qr/^parcel=ARRAY/, "&bless";
like join(" ", &CORE::bless([],'parcel')),
     qr/^parcel=ARRAY(?!.* )/, "&bless in list context";
like &mybless([]), qr/^main=ARRAY/, '&bless with one arg';

test_proto 'break';
{ $tests ++;
  my $tmp;
  CORE::given(1) {
    CORE::when(1) {
      &mybreak;
      $tmp = 'bad';
    }
  }
  is $tmp, undef, '&break';
}

test_proto 'caller';
$tests += 4;
sub caller_test {
    is scalar &CORE::caller, 'hadhad', '&caller';
    is scalar &CORE::caller(1), 'main', '&caller(1)';
    lis [&CORE::caller], [caller], '&caller in list context';
    # The last element of caller in list context is a hint hash, which
    # may be a different hash for caller vs &CORE::caller, so an eq com-
    # parison (which lis() uses for convenience) won’t work.  So just
    # pop the last element, since the rest are sufficient to prove that
    # &CORE::caller works.
    my @ampcaller = &CORE::caller(1);
    my @caller    = caller(1);
    pop @ampcaller; pop @caller;
    lis \@ampcaller, \@caller, '&caller(1) in list context';
}
sub {
   package hadhad;
   ::caller_test();
}->();

test_proto 'chmod';
$tests += 3;
is &CORE::chmod(), 0, '&chmod with no args';
is &CORE::chmod(0666), 0, '&chmod';
lis [&CORE::chmod(0666)], [0], '&chmod in list context';

test_proto 'chown';
$tests += 4;
is &CORE::chown(), 0, '&chown with no args';
is &CORE::chown(1), 0, '&chown with 1 arg';
is &CORE::chown(1,2), 0, '&chown';
lis [&CORE::chown(1,2)], [0], '&chown in list context';

test_proto 'chr', 5, "\5";
test_proto 'chroot';

test_proto 'close';
{
  last if is_miniperl;
  $tests += 3;
  
  open my $fh, ">", \my $buffalo;
  print $fh 'an address in the outskirts of Jersey';
  ok &CORE::close($fh), '&CORE::close retval';
  print $fh 'lalala';
  is $buffalo, 'an address in the outskirts of Jersey',
     'effect of &CORE::close';
  # This has to be a separate variable from $fh, as re-using the same
  # variable can cause the tests to pass by accident.  That actually hap-
  # pened during developement, because the second close() was reading
  # beyond the end of the stack and finding a $fh left over from before.
  open my $fh2, ">", \($buffalo = '');
  select+(select($fh2), do {
     print "Nasusiro Tokasoni";
     &CORE::close();
     print "jfd";
     is $buffalo, "Nasusiro Tokasoni", '&CORE::close with no args';
  })[0];
}
lis [&CORE::close('tototootot')], [''], '&close in list context'; ++$tests;

test_proto 'closedir';
$tests += 2;
is &CORE::closedir(foo), undef, '&CORE::closedir';
lis [&CORE::closedir(foo)], [undef], '&CORE::closedir in list context';

test_proto 'connect';
$tests += 2;
is &CORE::connect('foo','bar'), undef, '&connect';
lis [&myconnect('foo','bar')], [undef], '&connect in list context';

test_proto 'continue';
$tests ++;
CORE::given(1) {
  CORE::when(1) {
    &mycontinue();
  }
  pass "&continue";
}

test_proto 'cos';
test_proto 'crypt';

test_proto 'dbmclose';
test_proto 'dbmopen';
{
  last unless eval { require AnyDBM_File };
  $tests ++;
  my $filename = tempfile();
  &mydbmopen(\my %db, $filename, 0666);
  $db{1} = 2; $db{3} = 4;
  &mydbmclose(\%db);
  is scalar keys %db, 0, '&dbmopen and &dbmclose';
}

test_proto 'die';
eval { dier('quinquangle') };
is $@, "quinquangle at frob line 6.\n", '&CORE::die'; $tests ++;

test_proto $_ for qw(
 endgrent endhostent endnetent endprotoent endpwent endservent
);

test_proto 'evalbytes';
$tests += 4;
{
  chop(my $upgraded = "use utf8; '\xc4\x80'" . chr 256);
  is &myevalbytes($upgraded), chr 256, '&evalbytes';
  # Test hints
  require strict;
  strict->import;
  &myevalbytes('
    is someone, "someone", "run-time hint bits do not leak into &evalbytes"
  ');
  use strict;
  BEGIN { $^H{coreamp} = 42 }
  $^H{coreamp} = 75;
  &myevalbytes('
    BEGIN {
      is $^H{coreamp}, 42, "compile-time hh propagates into &evalbytes";
    }
    ${"frobnicate"}
  ');
  like $@, qr/strict/, 'compile-time hint bits propagate into &evalbytes';
}

test_proto 'exit';
$tests ++;
is runperl(prog => '&CORE::exit; END { print qq-ok\n- }'), "ok\n",
  '&exit with no args';

test_proto 'fork';

test_proto 'formline';
$tests += 3;
is &myformline(' @<<< @>>>', 1, 2), 1, '&myformline retval';
is $^A,        ' 1       2', 'effect of &myformline';
lis [&myformline('@')], [1], '&myformline in list context';

test_proto 'exp';

test_proto 'fc';
$tests += 2;
{
  my $sharp_s = "\xdf";
  is &myfc($sharp_s), $sharp_s, '&fc, no unicode_strings';
  use feature 'unicode_strings';
  is &myfc($sharp_s), "ss", '&fc, unicode_strings';
}

test_proto 'fcntl';

test_proto 'fileno';
$tests += 2;
is &CORE::fileno(\*STDIN), fileno STDIN, '&CORE::fileno';
lis [&CORE::fileno(\*STDIN)], [fileno STDIN], '&CORE::fileno in list cx';

test_proto 'flock';
test_proto 'fork';

test_proto 'getc';
{
  last if is_miniperl;
  $tests += 3;
  local *STDIN;
  open my $fh, "<", \(my $buf='falo');
  open STDIN, "<", \(my $buf2 = 'bison');
  is &mygetc($fh), 'f', '&mygetc';
  is &mygetc(), 'b', '&mygetc with no args';
  lis [&mygetc($fh)], ['a'], '&mygetc in list context';
}

test_proto "get$_" for qw '
  grent grgid grnam hostbyaddr hostbyname hostent login netbyaddr netbyname
  netent peername
';

test_proto 'getpgrp';
eval {&mygetpgrp()};
pass '&getpgrp with no args does not crash'; $tests++;

test_proto "get$_" for qw '
  ppid priority protobyname protobynumber protoent
  pwent pwnam pwuid servbyname servbyport servent sockname sockopt
';

# Make sure the following tests test what we think they are testing.
ok ! $CORE::{glob}, '*CORE::glob not autovivified yet'; $tests ++;
{
  # Make sure ck_glob does not respect the override when &CORE::glob is
  # autovivified (by test_proto).
  local *CORE::GLOBAL::glob = sub {};
  test_proto 'glob';
}
$_ = "t/*.t";
@_ = &myglob($_);
is join($", &myglob()), "@_", '&glob without arguments';
is join($", &myglob("t/*.t")), "@_", '&glob with an arg';
$tests += 2;

test_proto 'gmtime';
&CORE::gmtime;
pass '&gmtime without args does not crash'; ++$tests;

test_proto 'hex', ff=>255;

test_proto 'index';
$tests += 3;
is &myindex("foffooo","o",2),4,'&index';
lis [&myindex("foffooo","o",2)],[4],'&index in list context';
is &myindex("foffooo","o"),1,'&index with 2 args';

test_proto 'int', 1.5=>1;
test_proto 'ioctl';

test_proto 'join';
$tests += 2;
is &myjoin('a','b','c'), 'bac', '&join';
lis [&myjoin('a','b','c')], ['bac'], '&join in list context';

test_proto 'kill'; # set up mykill alias
if ($^O ne 'riscos') {
    $tests ++;
    ok( &mykill(0, $$), '&kill' );
}

test_proto 'lc', 'A', 'a';
test_proto 'lcfirst', 'AA', 'aA';
test_proto 'length', 'aaa', 3;
test_proto 'link';
test_proto 'listen';

test_proto 'localtime';
&CORE::localtime;
pass '&localtime without args does not crash'; ++$tests;

test_proto 'lock';
$tests += 6;
is \&mylock(\$foo), \$foo, '&lock retval when passed a scalar ref';
lis [\&mylock(\$foo)], [\$foo], '&lock in list context';
is &mylock(\@foo), \@foo, '&lock retval when passed an array ref';
is &mylock(\%foo), \%foo, '&lock retval when passed a ash ref';
is &mylock(\&foo), \&foo, '&lock retval when passed a code ref';
is \&mylock(\*foo), \*foo, '&lock retval when passed a glob ref';

test_proto 'log';

test_proto 'mkdir';
# mkdir is tested with implicit $_ at the end, to make the test easier

test_proto "msg$_" for qw( ctl get rcv snd );

test_proto 'not';
$tests += 2;
is &mynot(1), !1, '&not';
lis [&mynot(0)], [!0], '&not in list context';

test_proto 'oct', '666', 438;

test_proto 'open';
$tests += 5;
$file = 'test.pl';
ok &myopen('file'), '&open with 1 arg' or warn "1-arg open: $!";
like <file>, qr|^#|, 'result of &open with 1 arg';
close file;
{
  ok &myopen(my $fh, "test.pl"), 'two-arg &open';
  ok $fh, '&open autovivifies';
  like <$fh>, qr '^#', 'result of &open with 2 args';
  last if is_miniperl;
  $tests +=2;
  ok &myopen(my $fh2, "<", \"sharummbles"), 'retval of 3-arg &open';
  is <$fh2>, 'sharummbles', 'result of three-arg &open';
}

test_proto 'opendir';
test_proto 'ord', chr(64), 64;

test_proto 'pack';
$tests += 2;
is &mypack("H*", '5065726c'), 'Perl', '&pack';
lis [&mypack("H*", '5065726c')], ['Perl'], '&pack in list context';

test_proto 'pipe';
test_proto 'quotemeta', '$', '\$';

test_proto 'rand';
$tests += 3;
like &CORE::rand, qr/^0[.\d]*\z/, '&rand';
unlike join(" ", &CORE::rand), qr/ /, '&rand in list context';
&cmp_ok(&CORE::rand(78), qw '< 78', '&rand with 2 args');

test_proto 'read';
{
  last if is_miniperl;
  $tests += 5;
  open my $fh, "<", \(my $buff = 'morays have their mores');
  ok &myread($fh, \my $input, 6), '&read with 3 args';
  is $input, 'morays', 'value read by 3-arg &read';
  ok &myread($fh, \$input, 6, 6), '&read with 4 args';
  is $input, 'morays have ', 'value read by 4-arg &read';
  is +()=&myread($fh, \$input, 6), 1, '&read in list context';
}

test_proto 'readdir';

test_proto 'readline';
{
  local *ARGV = *DATA;
  $tests ++;
  is scalar &myreadline,
    "I wandered lonely as a cloud\n", '&readline w/no args';
}
{
  last if is_miniperl;
  $tests += 2;
  open my $fh, "<", \(my $buff = <<END);
The Recursive Problem
---------------------
I have a problem I cannot solve.
The problem is that I cannot solve it.
END
  is &myreadline($fh), "The Recursive Problem\n",
    '&readline with 1 arg';
  lis [&myreadline($fh)], [
       "---------------------\n",
       "I have a problem I cannot solve.\n",
       "The problem is that I cannot solve it.\n",
      ], '&readline in list context';
}

test_proto 'readlink';
test_proto 'readpipe';
test_proto 'recv';

use if !is_miniperl, File::Spec::Functions, qw "catfile";
use if !is_miniperl, File::Temp, 'tempdir';

test_proto 'rename';
{
    last if is_miniperl;
    $tests ++;
    my $dir = tempdir(uc cleanup => 1);
    my $tmpfilenam = catfile $dir, 'aaa';
    open my $fh, ">", $tmpfilenam or die "cannot open $tmpfilenam: $!";
    close $fh or die "cannot close $tmpfilenam: $!";
    &myrename("$tmpfilenam", $tmpfilenam = catfile $dir,'bbb');
    ok open(my $fh, '>', $tmpfilenam), '&rename';
}

test_proto 'ref', [], 'ARRAY';

test_proto 'reset';
$tests += 2;
my $oncer = sub { "a" =~ m?a? };
&$oncer;
&myreset;
ok &$oncer, '&reset with no args';
package resettest {
  $b = "c";
  $banana = "cream";
  &::myreset('b');
  ::lis [$b,$banana],[(undef)x2], '1-arg &reset';
}

test_proto 'reverse';
$tests += 2;
is &myreverse('reward'), 'drawer', '&reverse';
lis [&myreverse(qw 'dog bites man')], [qw 'man bites dog'],
  '&reverse in list context';

test_proto 'rewinddir';

test_proto 'rindex';
$tests += 3;
is &myrindex("foffooo","o",2),1,'&rindex';
lis [&myrindex("foffooo","o",2)],[1],'&rindex in list context';
is &myrindex("foffooo","o"),6,'&rindex with 2 args';

test_proto 'rmdir';

test_proto 'seek';
{
    last if is_miniperl;
    $tests += 1;
    open my $fh, "<", \"misled" or die $!;
    &myseek($fh, 2, 0);
    is <$fh>, 'sled', '&seek in action';
}

test_proto 'seekdir';

# Can’t test_proto, as it has none
$tests += 8;
*myselect = \&CORE::select;
is defined prototype &myselect, defined prototype "CORE::select",
   'prototype of &select (or lack thereof)';
is &myselect, select, '&select with no args';
{
  my $prev = select;
  is &myselect(my $fh), $prev, '&select($arg) retval';
  is lc ref $fh, 'glob', '&select autovivifies';
  is select=~s/\*//rug, (*$fh."")=~s/\*//rug, '&select selects';
  select $prev;
}
eval { &myselect(1,2) };
like $@, qr/^Not enough arguments for select system call at /,
      ,'&myselect($two,$args)';
eval { &myselect(1,2,3) };
like $@, qr/^Not enough arguments for select system call at /,
      ,'&myselect($with,$three,$args)';
eval { &myselect(1,2,3,4,5) };
like $@, qr/^Too many arguments for select system call at /,
      ,'&myselect($a,$total,$of,$five,$args)';
&myselect((undef)x3,.25);
# Just have to assume that worked. :-) If we get here, at least it didn’t
# crash or anything.

test_proto "sem$_" for qw "ctl get op";

test_proto 'send';

test_proto "set$_" for qw '
  grent hostent netent
';

test_proto 'setpgrp';
$tests +=2;
eval { &mysetpgrp( 0) };
pass "&setpgrp with one argument";
eval { &mysetpgrp };
pass "&setpgrp with no arguments";

test_proto "set$_" for qw '
  priority protoent pwent servent sockopt
';

test_proto "shm$_" for qw "ctl get read write";
test_proto 'shutdown';
test_proto 'sin';
test_proto 'sleep';
test_proto "socket$_" for "", "pair";

test_proto 'sprintf';
$tests += 2;
is &mysprintf("%x", 65), '41', '&sprintf';
lis [&mysprintf("%x", '65')], ['41'], '&sprintf in list context';

test_proto 'sqrt', 4, 2;

test_proto 'srand';
$tests ++;
&CORE::srand;
pass '&srand with no args does not crash';

test_proto 'substr';
$tests += 5;
$_ = "abc";
is &mysubstr($_, 1, 1, "d"), 'b', '4-arg &substr';
is $_, 'adc', 'what 4-arg &substr does';
is &mysubstr("abc", 1, 1), 'b', '3-arg &substr';
is &mysubstr("abc", 1), 'bc', '2-arg &substr';
&mysubstr($_, 1) = 'long';
is $_, 'along', 'lvalue &substr';

test_proto 'symlink';
test_proto 'syscall';

test_proto 'sysopen';
$tests +=2;
{
  &mysysopen(my $fh, 'test.pl', 0);
  pass '&sysopen does not crash with 3 args';
  ok $fh, 'sysopen autovivifies';
}

test_proto 'sysread';
test_proto 'sysseek';
test_proto 'syswrite';

test_proto 'tell';
{
  $tests += 2;
  open my $fh, "test.pl" or die "Cannot open test.pl";
  <$fh>;
  is &mytell(), tell($fh), '&tell with no args';
  is &mytell($fh), tell($fh), '&tell with an arg';
}

test_proto 'telldir';

test_proto 'tie';
test_proto 'tied';
$tests += 3;
{
  my $fetches;
  package tier {
    sub TIESCALAR { bless[] }
    sub FETCH { ++$fetches }
  }
  my $tied;
  my $obj = &mytie(\$tied, 'tier');
  is &mytied(\$tied), $obj, '&tie and &tied retvals';
  () = "$tied";
  is $fetches, 1, '&tie actually ties';
  &CORE::untie(\$tied);
  () = "$tied";
  is $fetches, 1, '&untie unties';
}

test_proto 'time';
$tests += 2;
like &mytime, '^\d+\z', '&time in scalar context';
like join('-', &mytime), '^\d+\z', '&time in list context';

test_proto 'times';
$tests += 2;
like &mytimes, '^[\d.]+\z', '&times in scalar context';
like join('-',&mytimes), '^[\d.]+-[\d.]+-[\d.]+-[\d.]+\z',
   '&times in list context';

test_proto 'uc', 'aa', 'AA';
test_proto 'ucfirst', 'aa', "Aa";

test_proto 'umask';
$tests ++;
is &myumask, umask, '&umask with no args';

test_proto 'unpack';
$tests += 2;
$_ = 'abcd';
is &myunpack("H*"), '61626364', '&unpack with one arg';
is &myunpack("H*", "bcde"), '62636465', '&unpack with two arg';


test_proto 'untie'; # behaviour already tested along with tie(d)

test_proto 'utime';
$tests += 2;
is &myutime(undef,undef), 0, '&utime';
lis [&myutime(undef,undef)], [0], '&utime in list context';

test_proto 'vec';
$tests += 3;
is &myvec("foo", 0, 4), 6, '&vec';
lis [&myvec("foo", 0, 4)], [6], '&vec in list context';
$tmp = "foo";
++&myvec($tmp,0,4);
is $tmp, "goo", 'lvalue &vec';

test_proto 'wait';
test_proto 'waitpid';

test_proto 'wantarray';
$tests += 4;
my $context;
my $cx_sub = sub {
  $context = qw[void scalar list][&mywantarray + defined mywantarray()]
};
() = &$cx_sub;
is $context, 'list', '&wantarray with caller in list context';
scalar &$cx_sub;
is($context, 'scalar', '&wantarray with caller in scalar context');
&$cx_sub;
is($context, 'void', '&wantarray with caller in void context');
lis [&mywantarray],[wantarray], '&wantarray itself in list context';

test_proto 'warn';
{ $tests += 3;
  my $w;
  local $SIG{__WARN__} = sub { $w = shift };
  is &mywarn('a'), 1, '&warn retval';
  is $w, "a at " . __FILE__ . " line " . (__LINE__-1) . ".\n", 'warning';
  lis [&mywarn()], [1], '&warn retval in list context';
}

test_proto 'write';
$tests ++;
eval {&mywrite};
like $@, qr'^Undefined format "STDOUT" called',
   "&write without arguments can handle the null";

# This is just a check to make sure we have tested everything.  If we
# haven’t, then either the sub needs to be tested or the list in
# gv.c is wrong.
{
  last if is_miniperl;
  require File::Spec::Functions;
  my $keywords_file =
   File::Spec::Functions::catfile(
      File::Spec::Functions::updir,'regen','keywords.pl'
   );
  open my $kh, $keywords_file
    or die "$0 cannot open $keywords_file: $!";
  while(<$kh>) {
    if (m?__END__?..${\0} and /^[-+](.*)/) {
      my $word = $1;
      next if
       $word =~ /^(?:s(?:t(?:ate|udy)|(?:pli|or)t|calar|ay|ub)?|d(?:ef
                  ault|ump|o)|p(?:r(?:ototype|intf?)|ackag
                  e|os)|e(?:ls(?:if|e)|val|q)|g(?:[et]|iven|oto
                  |rep)|u(?:n(?:less|def|til)|se)|l(?:(?:as)?t|ocal|e)|re
                  (?:quire|turn|do)|__(?:DATA|END)__|for(?:each|mat)?|(?:
                  AUTOLOA|EN)D|n(?:e(?:xt)?|o)|C(?:HECK|ORE)|wh(?:ile|en)
                  |(?:ou?|t)r|m(?:ap|y)?|UNITCHECK|q[qrwx]?|x(?:or)?|DEST
                  ROY|BEGIN|INIT|and|cmp|if|y)\z/x;
      $tests ++;
      ok   exists &{"my$word"}
        || (eval{&{"CORE::$word"}}, $@ =~ /cannot be called directly/),
     "$word either has been tested or is not ampable";
    }
  }
}

# Add new tests above this line.

# This test must come last (before the test count test):

{
  last if is_miniperl;
  require Cwd;
  import Cwd;
  $tests += 3;
  require File::Temp ;
  my $dir = File::Temp::tempdir(uc cleanup => 1);
  my $cwd = cwd();
  chdir($dir);

  # Make sure that implicit $_ is not applied to mkdir’s second argument.
  local $^W = 1;
  my $warnings;
  local $SIG{__WARN__} = sub { ++$warnings };

  my $_ = 'Phoo';
  ok &mymkdir(), '&mkdir';
  like <*>, qr/^phoo(.DIR)?\z/i, 'mkdir works with implicit $_';

  is $warnings, undef, 'no implicit $_ for second argument to mkdir';

  chdir($cwd); # so auto-cleanup can remove $dir
}

# ------------ END TESTING ----------- #

done_testing $tests;

#line 3 frob

sub file { &CORE::__FILE__ }
sub line { &CORE::__LINE__ } # 5
sub dier { &CORE::die(@_)  } # 6
package stribble;
sub main::pakg { &CORE::__PACKAGE__ }

# Please do not add new tests here.
package main;
CORE::__DATA__
I wandered lonely as a cloud
That floats on high o’er vales and hills,
And all at once I saw a crowd, 
A host of golden daffodils!
Beside the lake, beneath the trees,
Fluttering, dancing, in the breeze.
-- Wordsworth
