#!/bin/bash

S_DIR=/vz/template/cache/openvz
#D_HOST=ovzdl.sw.ru
D_HOST=download.openvz.org
D_DIR=/var/www/html/template/precreated
WILDCARD="*"
BATCHMODE="-o BatchMode=yes"
SSH="ssh $BATCHMODE"
SCP="scp $BATCHMODE -c blowfish"
RSYNC="rsync -avvPO"
ADD=
RSYNC_OPTIONS=
CHECK=yes

check_files() {
	local file
	for file in $*; do
		echo -n "Checking $file ."
		tar tf $file > /dev/null
		if [ "$?" != '0' ]; then
			echo " TAR_FAIL"
			echo "File $file is not a proper tarball -- ABORTING!" 1>&2
			exit 1
		fi
		echo -n "."
		if ! test -f $file.asc; then
			gpg -ab --batch $file
			echo -n .
		fi
		gpg --quiet --verify $file.asc 2>/dev/null
		if [ "$?" != '0' ]; then
			echo " GPG_FAIL"
			echo "File $file not signed -- ABORTING!" 1>&2
			exit 1
		fi
		echo " OK"
	done
}

while test $# -gt 0; do
case $1 in
	-c|--no-check|--nocheck)
		CHECK=no
		shift
		;;
	-b|--beta)
		S_DIR=$S_DIR/beta
		D_DIR=$D_DIR/beta
		shift
		;;
	-u|--unsup*)
		S_DIR=$S_DIR/unsupported
		D_DIR=$D_DIR/unsupported
		ADD=yes
		shift
		;;
	-t)
		shift
		WILDCARD=$1
		ADD=yes
		shift
		;;
	-n|--dry-run)
		shift
		RSYNC_OPTIONS="$RSYNC_OPTIONS -n"
		;;
	-a|--add)
		shift
		ADD=yes
		;;
	*)
		echo "ERROR: Invalid option: $1" 1>&2
		exit 1
esac
done

test "x$ADD" != "xyes" && RSYNC_OPTIONS="$RSYNC_OPTIONS --delete"

SRC=$S_DIR/${WILDCARD}.tar.gz

[ "$CHECK" = "no" ] || check_files $SRC

SRC=$(ls $S_DIR/${WILDCARD}.tar.gz{,.asc})
# do not use wildcard if not provided, copy the whole directory,
# otherwise --delete is not working
test "$WILDCARD" = "*" && SRC=$S_DIR/
echo "Uploading $SRC to $D_HOST:$D_DIR ..."
set -x
$RSYNC  --exclude /\*/\* \
	--exclude /\*/ \
	--exclude HEADER.html \
	--exclude .message \
	--exclude .listing \
	--exclude .\* \
	--exclude contrib \
	--exclude beta \
	--exclude unsupported \
	$RSYNC_OPTIONS -e ssh $SRC $D_HOST:$D_DIR || exit 1
set +x
echo "Copied everything to $D_HOST:$D_DIR"
echo "Creating .listing..."
$SSH $D_HOST "cd $D_DIR && ls *.tar.gz | sed 's/\.tar\.gz$//' > .listing && cat .listing"
