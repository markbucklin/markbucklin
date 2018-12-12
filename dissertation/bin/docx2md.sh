#!/bin/bash


# TODO: fix to handle files with spaces

if [ "$1" == '' ]; then
	DOCFILES="$(find ${PWD} -type f -name "*.docx" | fzf -m)"
else
	DOCFILES="$*"
fi

for docfile in ${DOCFILES} ; do 
	mdfile="${docfile%.docx}.md"
	pandoc --output="${mdfile}" --from=docx --atx-headers --biblatex --wrap=none "${docfile}"
done





