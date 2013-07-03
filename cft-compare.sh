#!/bin/sh

source /etc/cft/cft.conf || exit 1

print_help() {
  echo "USAGE: ${0##*\/} [-v]"
,,echo,'     -s --show             Show selected (D,F,d,f,l,s,c,p,o,g,U,E,e,g,b,u)'
  echo '     -C --show-conf        Show CONFIGS section'
  echo '     -P --show-pkg         Show PKG section'
  echo '     -v --verbose          Be verbose'
  echo '        --help             Print this help'
}

SHOW_ITEMS="DFdflscpogUEexbu"

# разбор параметров
while [ -n "${1}" ]; do
  case "${1}" in

    -v|--verbose)
      VERBOSE=yes
      ;;
    -s|--show)
      if [ -n "${2}" ]; then
        SHOW_ITEMS="${2}"
      else
        echo 'show items argument required' >&2
  exit 1
      fi
      shift
      ;;
    -C|--show-conf)
      SHOW_ITEMS="DFdflscpogU"
      ;;
    -P|--show-pkg)
      SHOW_ITEMS="Eexbu"
      ;;
    -h|--help)
      print_help
      exit
      ;;
    *)
      print_help
      echo "Unknown option ${1}" >&2
      exit 1
      ;;
  esac
  shift
done

print_block() {
  [ -z "${2}" ] && return 0
  [ "${SHOW_ITEMS/[${3}]/}" = "${SHOW_ITEMS}" ] && return 0
  COUNT=$(echo "${2}" |wc -l)
  echo "==${3}= ${1} [${COUNT}]"
  if [ "${VERBOSE}" = yes -a -n "${2}" ]; then
    echo "${2}"
    echo
  fi
}

if [ "${SHOW_ITEMS/[DFdflscpogU]/}" != "${SHOW_ITEMS}" ]; then
  RSYNC_DATA=$(\
    rsync ${CONFIG_SYNC_OPTS} \
      --exclude-from=/etc/cft/config-exclude.list \
      --include-from=/etc/cft/config-include.list \
      -f '- /*' \
      --dry-run -avicxH -n --no-t --delete --omit-dir-times -e "ssh -p ${CFT_PORT} ${CFT_OPTS}" "${CFT_HOST}":/ / \
    | head -n-3 \
    |tail -n +2)
  
  UNTRACKED_DIRS=$(echo "${RSYNC_DATA}" | grep '^\*deleting   .*/$' |sed 's#^\*deleting   #/#')
  UNTRACKED_FILES=$(echo "${RSYNC_DATA}" | grep '^\*deleting   .*[^/]$' |sed 's#^\*deleting   #/#')
  MISSING_DIRS=$(echo "${RSYNC_DATA}"  |grep '^cd+++++++++ ' |sed 's#^cd+++++++++ #/#')
  MISSING_FILES=$(echo "${RSYNC_DATA}"  |grep '^>f+++++++++ ' |sed 's#^>f+++++++++ #/#')
  MISSING_LINKS=$(echo "${RSYNC_DATA}"  |grep '^cL+++++++++ ' |sed 's#^cL+++++++++ #/#')
  MODIFIED_LINKS=$(echo "${RSYNC_DATA}"  |grep '^cLc\........ ' |sed 's#^cLc\........ #/#')
  MODIFIED_FILES=$(echo "${RSYNC_DATA}"  |grep '^>fc........ ' |sed 's#^>fc........ #/#')
  CHANGED_PERMS=$(echo "${RSYNC_DATA}"  |grep '^.....p..... ' |sed 's#^.....p..... #/#')
  CHANGED_OWNER=$(echo "${RSYNC_DATA}"  |grep '^......o.... ' |sed 's#^......o.... #/#')
  CHANGED_GROUP=$(echo "${RSYNC_DATA}"  |grep '^.......g... ' |sed 's#^.......g.. #/#')
  UNKNOWN=$(echo "${RSYNC_DATA}" \
    |grep -v '^\(\*deleting\|..+++++++++\|cLc\........\|>fc........\|.....p.....\|......o....\|.......g...\) ')
  
  echo 'CONFIGS:'
  
  print_block 'UNTRACKED DIRS' "${UNTRACKED_DIRS}" D
  print_block 'UNTRACKED FILES' "${UNTRACKED_FILES}" F
  
  print_block 'MISSING DIRS' "${MISSING_DIRS}" d
  print_block 'MISSING FILES' "${MISSING_FILES}" f
  print_block 'MISSING LINKS' "${MISSING_LINKS}" l
  
  print_block 'MODIFIED LINKS' "${MODIFIED_LINKS}" s
  print_block 'MODIFIED FILES' "${MODIFIED_FILES}" c
  
  print_block 'CHANGED PERMISSIONS' "${CHANGED_PERMS}" p
  print_block 'CHANGED OWNER' "${CHANGED_OWNER}" o
  print_block 'CHANGED GROUP' "${CHANGED_GROUP}" g
  
  print_block 'UNKNOWN (!) CHANGE' "${UNKNOWN}" U
fi

if [ "${SHOW_ITEMS/[Eexbu]/}" != "${SHOW_ITEMS}" ]; then
  RSYNC_PACKAGE_USE=$(\
    rsync --dry-run -drvic -n --no-t --delete --omit-dir-times -e "ssh -p ${CFT_PORT} ${CFT_OPTS}" -f '+ */*/IUSE' -f '- */*/**' -f '- .cache' "${CFT_HOST}":/var/db/pkg/ /var/db/pkg/ \
    | head -n-3 \
    |tail -n +2)
  
  RSYNC_PACKAGE=$(\
    echo "${RSYNC_PACKAGE_USE}" \
    |grep -v '^[^/]\+/$\|^[^/]\+$\|/IUSE$' \
    |sed -e 's#/$##' -e 's/^cd+++++++++ /+ /' -e 's/^\*deleting   /- /' -e 's/^cannot delete non-empty directory: /- /' \
    |sort -nk2 \
    |uniq \
    |sed 's/-\([0-9]\)/ \1/' \
    |sort -k2 -Vk3 \
    |awk '{if (ln==$2) {print $1,$2,lv,"=>",$3; i=0} else {if (i==1) print ll; i=1}; ll=$0; ln=$2; lv=$3}END{if (i==1) print ll}')
  
  CHANGED_USE=$(\
          echo "${RSYNC_PACKAGE_USE}" \
    |grep '^.fc.*/IUSE$' \
    |sed 's#^........... ##')
  
  
  UNTRACKED_PACKAGES=$(echo "${RSYNC_PACKAGE}" | grep '^- [^=]\+$' |sed -e 's#^- ##' -e 's/ /-/')
  MISSING_PACKAGES=$(echo "${RSYNC_PACKAGE}"  |grep '^+ [^=]\+$' |sed -e 's#^+ ##' -e 's/ /-/')
  UPGRADE_PACKAGES=$(echo "${RSYNC_PACKAGE}"  |grep '^+ .\+=' |sed 's#^+ ##')
  DOWNGRADE_PACKAGES=$(echo "${RSYNC_PACKAGE}"  |grep '^- .\+=' |sed 's#^- ##')
  
  echo 'PACKAGES:'
  
  print_block 'UNTRACKED PACKAGES' "${UNTRACKED_PACKAGES}" E
  print_block 'MISSING PACKAGES' "${MISSING_PACKAGES}" e
  
  print_block 'UPGRADE PACKAGES' "${UPGRADE_PACKAGES}" x
  print_block 'DOWNGRADE PACKAGES' "${DOWNGRADE_PACKAGES}" b
  
  print_block 'CHANGED USE FLAGS' "${CHANGED_USE}" u
fi
