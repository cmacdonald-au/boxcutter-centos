#!/bin/sh -e

if [ -z $SSH_USERNAME ]; then
	echo "kickstart.sh; SSH_USERNAME: required"
	exit -1
fi

if [ -z $SSH_PASSWORD ]; then
	echo "kickstart.sh; SSH_PASSWORD: required"
	exit -1
fi

if [ -z $ROOT_PASSWORD ]; then
	echo "kickstart.sh; ROOT_PASSWORD: required"
	exit -1
fi

if [ ! -f $1 ]; then
	echo "File $1 not a file"
	exit -1
fi

OUTPUTFILE=$(echo $1 | sed -Ee 's,\.tpl$,.cfg,')
echo "==> Writing: $OUTPUTFILE"
sed -e "s/%%SSH_USERNAME%%/${SSH_USERNAME}/g" -e "s/%%SSH_PASSWORD%%/${SSH_PASSWORD}/g" $1 > $OUTPUTFILE;
