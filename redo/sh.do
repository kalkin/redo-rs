exec >&2
redo-ifchange ../t/shelltest.od

rm -rf $1.new
mkdir $1.new

GOOD=
WARN=

# Note: list low-functionality, maximally POSIX-like shells before more
# powerful ones.  We want weaker shells to take precedence, as long as they
# pass the tests, because weaker shells are more likely to point out when you
# use some non-portable feature.
for sh in dash /usr/xpg4/bin/sh ash posh \
		lksh mksh ksh ksh88 ksh93 pdksh \
		zsh bash busybox /bin/sh; do
	printf " %-22s" "$sh..."
	FOUND=`which $sh 2>/dev/null` || { echo "missing"; continue; }
	
	# It's important for the file to actually be named 'sh'.  Some
	# shells (like bash and zsh) only go into POSIX-compatible mode if
	# they have that name.  If they're not in POSIX-compatible mode,
	# they'll fail the test.
	rm -f $1.new/sh
	ln -s $FOUND $1.new/sh
	SH=$PWD/$1.new/sh
	
	set +e
	( cd ../t && "$SH" shelltest.od ) >shelltest.tmp 2>&1
	RV=$?
	set -e
	
	msgs=
	crash=
	while read line; do
		#echo "line: '$line'" >&2
		stripw=${line#warning: }
		stripf=${line#failed: }
		strips=${line#skip: }
		crash=$line
		[ "$line" = "$stripw" ] || msgs="$msgs W$stripw"
		[ "$line" = "$stripf" ] || msgs="$msgs F$stripf"
		[ "$line" = "$strips" ] || msgs="$msgs s$strips"
	done <shelltest.tmp
	rm -f shelltest.tmp
	msgs=${msgs# }
	crash=${crash##*:}
	crash=${crash# }
	
	case $RV in
		40) echo "ok $msgs"; [ -n "$GOOD" ] || GOOD=$FOUND ;;
		41) echo "failed    $msgs" ;;
		42) echo "warnings  $msgs"; [ -n "$WARN" ] || WARN=$FOUND ;;
		*)  echo "crash     $crash" ;;
	esac
done

rm -rf $1.new $3

if [ -n "$GOOD" ]; then
	echo "Selected perfect shell: $GOOD"
	ln -s $GOOD $3
elif [ -n "$WARN" ]; then
	echo "Selected mostly good shell: $WARN"
	ln -s $WARN $3
else
	echo "No good shells found!  Maybe install dash, bash, or zsh."
	exit 13
fi
