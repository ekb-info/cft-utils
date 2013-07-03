#!/bin/sh

FILE="${1}"

if [ -z "${FILE}" ]; then
	echo "USAGE: ${0##*/} <file>"
	exit
fi

source /etc/cft/cft.conf || exit 1

if [ ! -e "${FILE}" ]; then
	echo "Local file ${FILE} not found"
	exit 1
fi

if [ ! -f "${FILE}" ]; then
	echo "Local file ${FILE} is not a regular file"
	exit 1
fi

ssh ${CFT_OPTS} -p "${CFT_PORT}" "${CFT_HOST}" cat "${FILE}" | diff -u "${FILE}" - |tail -n +3

