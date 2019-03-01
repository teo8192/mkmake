#!/bin/sh

# © Teodor Dahl Knusten <teodor@dahlknutsen.no>
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# makes sure this file exist
exists="$(ls .targets 2> /dev/null)"
if [ ! "$exists" == ".targets" ]
then
	echo -e "You do not have a '.targets' file, aborting. For more information look at the README file"
	exit 1
fi

exists="$(ls Makefile 2> /dev/null)"
if [ "$exists" == "Makefile" ]
then
	echo -e "You already have a Makefile\nDo you want to continue? [y/n]"
	read answer
	if [ ! "$answer" == "y" ]
	then
		exit 1
	fi
fi

echo -e "# This makefile was generated on $(date) by mkmake.sh\n# See https://github.com/teo8192/mkmake.git for more details." > Makefile

awk '
/^target/ {
	print "EXECUTABLE" $2 "=bin/" $2 "\n" "DEBUG" $2 "=bin/" $2 "_debug"
}
' .targets >> Makefile

echo -e "\nCC=gcc\n" >> Makefile
echo -e "FLAGS=$(awk '
/^flags/ {
	for ( j = 2; j <= NF; ++j ) {
		printf "%s ", $j
	}
}
' .targets)\n" >> Makefile

objfol="objs"
binfol="bin"

source_dep=""
debug_source_dep=""
echo -e ".PHONY: all\nall: $binfol $objfol $(awk '
/^target/ {
	printf "$(EXECUTABLE%s) ", $2
}
' .targets)\n" >> Makefile

echo -e ".PHONY: debug\ndebug: $(awk '
/^target/ {
	printf "$(DEBUG%s) ", $2
}
' .targets)\n" >> Makefile
echo -e ".PHONY: clean\nclean:\n\t@rm -f $objfol/*.o $(awk '
/^target/ {
	printf "$(DEBUG%s) $(EXECUTABLE%s) ", $2, $2
}
/^clean/ {
	for (j = 2; j <= NF; ++j) {
		printf "%s ", $j
	}
}
' .targets)\n" >> Makefile

echo -e ".PHONY: dbclean\ndbclean:\n\t@rm -r objs/debug_[0-9a-zA-Z_]*.o $(awk '
/^target/ {
	printf "$(DEBUG%s) ", $2
}
' .targets)\n" >> Makefile

echo -e "$binfol:\n\t@[[ ! -d "$binfol" ]] && mkdir $binfol\n" >> Makefile
echo -e "$objfol:\n\t@[[ ! -d "$objfol" ]] && mkdir $objfol\n" >> Makefile



# finds header dependencies
header_dep=""
for i in `ls *.h`
do
	# use ripgrep and sed to extract dependencies from file
	# deps="$(rg --color never -o '#include *".*"' $i | sed 's/[0-9]*://g; s/"//g; s/#//g; s/include //g')"
	# use awk instead
	deps="$(awk '
	/^#include.*\"/ {
	gsub(/"/, "")
	print $2
	}
	' $i)"
	# remove newlines
	deps="$(echo $deps | tr -d '\n')"

	if [ "$header_dep" == "" ]
	then
		header_dep="$i $deps"
	else
		header_dep="$header_dep\n$i $deps"
	fi
done

# sourcefile dependencies
for i in `ls *.c`
do
	# Get filename without extension
	filename="$(echo $i | sed 's/\.[ch]$//g')"

	# use awk to extract dependencies from file
	deps="$(awk '
	/^#include.*\"/ {
	gsub(/"/, "")
	print $2
	}
	' $i)"
	d=""

	# get dependencies from header files
	for cdep in $deps
	do
		# Remove carrige return
		cdep="$(echo "$cdep" | tr -d "\r")"
		if [ "$d" == "" ]
		then
			d="$(echo -e "$header_dep" | grep "^$cdep" --color=never)"
		else
			d="$d $(echo -e "$header_dep" | grep "^$cdep" --color=never)"
		fi
	done

	# remove newlines
	d="$(echo $d | tr -d '\n')"
	d="$(echo $d | tr -d '\r')"
	cdep=""

	# remove duplicate dependencies
	for dep in $d
	do
		if [ "$(echo "$cdep" | grep "$dep" --color=never -o)" == "" ]
		then
			if [ "$cdep" == "" ]
			then
				cdep="$dep"
			else
				cdep="$cdep $dep"
			fi
		fi
	done

	# object file
	object="$objfol/$filename.o"
	if [ "$source_dep" == "" ]
	then
		source_dep="$object"
	else
		source_dep="$source_dep $object"
	fi

	debug_object="debug_$filename.o"
	if [ "$debug_source_dep" == "" ]
	then
		debug_source_dep="$debug_object"
	else
		debug_source_dep="$debug_source_dep $debug_object"
	fi

	# put it into file
	echo -e "$object: $i $cdep\n\t\$(CC) -c $i -O2\n\tmv $filename.o $objfol\n" >> Makefile
	echo -e "$objfol/$debug_object: $i $cdep\n\t\$(CC) -c $i -g -o $debug_object\n\tmv debug_$filename.o $objfol\n" >> Makefile
done

awk '
/^target/ {
	gsub(/\.c/, ".o")
	printf "$(EXECUTABLE%s): ", $2
	for ( j = 3; j <= NF; ++j ) {
		printf "objs/%s ", $j
	}
	printf "\n\t$(CC) -o $@ "
	for ( j = 3; j <= NF; ++j ) {
		printf "objs/%s ", $j
	}
	printf "$(FLAGS)\n\n"

	printf "$(DEBUG%s): ", $2
	for ( j = 3; j <= NF; ++j ) {
		printf "objs/debug_%s ", $j
	}
	printf "\n\t$(CC) -o $@ "
	for ( j = 3; j <= NF; ++j ) {
		printf "objs/debug_%s ", $j
	}
	printf "$(FLAGS)\n\n"
}
' .targets >> Makefile
