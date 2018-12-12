#!/bin/bash


# TODO: make more efficient

# rename directories (replace space with underscore)
find $1 -name "* *" -type d -print0 | \
while read -d $'\0' f; do mv -v "$f" "${f// /_}"; done


# rename files (replace space with underscore)
find $1 -name "* *" -type f -print0 | \
while read -d $'\0' f; do mv -v "$f" "${f// /_}"; done

# rename files (replace double-underscore with single-underscore)
find $1 -name "*-_*" -type f -print0 | \
while read -d $'\0' f; do mv -v "$f" "${f/-_/_}"; done


# rename files (replace double-underscore with single-underscore)
find $1 -name "*_-*" -type f -print0 | \
while read -d $'\0' f; do mv -v "$f" "${f/_-/_}"; done


# rename files (replace double-underscore with single-underscore)
find $1 -name "*__*" -type f -print0 | \
while read -d $'\0' f; do mv -v "$f" "${f/__/_}"; done
