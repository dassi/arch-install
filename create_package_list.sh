#!/bin/sh

FILE="packages.csv"

# packages from standard repos
pacman --quiet -Qen | while read -r pkg
do 
  pacman -Qi "$pkg" | grep -E 'Name|Description' | awk 'BEGIN {FS=" : "; print "PAC"} {print "\"" $2 "\""}' | paste -d ',' - - - 
done > $FILE

# packages from AUR (or potential other) repos
pacman --quiet -Qem | while read -r pkg
do 
  pacman -Qi "$pkg" | grep -E 'Name|Description' | awk 'BEGIN {FS=" : "; print "AUR"} {print "\"" $2 "\""}' | paste -d ',' - - - 
done >> $FILE
