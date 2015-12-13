#!/bin/bash

USERS='Arnoldn Bonnstet Broderse Carrotsoup Duh Dvolz Forsterj Goldencave Jungj Kilbo Knightflight377 Kosieram Lalonde Lecam Magnusow Mattk Nooney Pejaustin Piersonv Rives Rowley Turnblad'
OUTFILE=$(mktemp)

rm -f "$OUTFILE"
for user in $USERS; do
	{
		echo "__USER: $user"
		curl --silent https://www.stolaf.edu/people/olaf/capstone15/"$user".html
		printf "\n\n"
	} >> "$OUTFILE"
done
cat "$OUTFILE"
