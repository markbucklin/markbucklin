#!/bin/bash

# Translate the Markdown files into LaTex

pandoc -f markdown -t latex ./Executive.md -o Executive.tex
pandoc -f markdown -t latex ./Abbreviations.md -o Abbreviations.tex
pandoc -f markdown -t latex ./Body.md -o Body.tex
pandoc -f markdown -t latex ./Integrity.md -o Integrity.tex
pandoc -f markdown -t latex ./Appendix.md -o Appendix.tex

# Concatenate all LaTeX files into one big file

cat ./header.tex > output.tex
cat ./Executive.tex >> output.tex
cat ./Figures.tex >> output.tex
cat ./Abbreviations.tex >> output.tex
cat ./TOC.tex >> output.tex
cat ./Body.tex >> output.tex
cat ./Literature.tex >> output.tex
cat ./Appendix.tex >> output.tex
cat ./Integrity.tex >> output.tex
cat ./footer.tex >> output.tex


# Typeset the LaTeX thingie and build a nice pdf

pdflatex output
bibtex output
pdflatex output

# Check command line arguments and commit/push to git repo

if [ $# -eq 2 ]
        then
                if [ "$1" = "push" ]
                        then
                                /usr/bin/git add *
                                /usr/bin/git commit  -m "$2"
                                /usr/bin/git push
                        else
                                echo "If you want to push to git, please say so... "
                fi
	else
        	echo "Not pushed to git repo!"
fi

# cleanup

rm Executive.tex
rm Abbreviations.tex
rm Body.tex
rm Integrity.tex
rm Appendix.tex
