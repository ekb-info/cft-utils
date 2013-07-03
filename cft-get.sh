#!/bin/sh

FILE="${1}"

if [ -z "${FILE}" ]; then
	echo "USAGE: ${0##*/} <file>"
	exit
fi

source /etc/cft/cft.conf || exit 1

scp ${CFT_OPTS} -p -P "${CFT_PORT}" "${CFT_HOST}":"${FILE}" ./
