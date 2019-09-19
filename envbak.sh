#!/bin/bash
set -eux

help()
{
	echo -e "Name of config: store.conf\nInstallScript is tool for easier making up your userspace, when you want to save\nyour userspace from other system. If you want to save your utilities and their's\nconfig files, you can use implemented methods, or just create config file in\nscript folder in format:\n \nUtil:[NAME]\n[PathToConfig]\n[PathToConfig]\n...\n\nImplemented methods:\n-a or -add in format: -a [UtilityName] and optionaly -c [PathToConfig].\nYou can also set multiple paths separated by space.\n\n-d --delete [UtilityName] when you want remove all records about this utility\nand optionaly use -c [PathToConfig], to remove just one.\n\nWhen you've added all configs and utils, just use -b or --backup to make .tar\narchive in script folder. When you move .tar to new system, call\n--restore [PathToArchive]"
}

insertConfig()
{
for config in "${configs[@]}"
    do  
        if ! grep -q "^$config$" ./store.conf ; then # If config is not already in store.conf
           N=$(grep -n "$1" ./store.conf | cut -f 1 -d :) # Find line with utility name.
           sed -i "$($N + 1) i $config" ./store.conf # Insert config under utility name.
        fi    
    done 
}

appendConfig()
{
if [ "$manager" = "" ] ; then
	echo "Util:$1:" >> store.conf # Make record about utility.
else
	echo "Util:$1:$manager" >> store.conf # Make record about utility, with path to config file with install method.
fi

for config in "${configs[@]}"
    do  
        if ! grep -q "^$config$" ./store.conf ; then # Add config file under utility record ( Util:[NAME]:<PATH>)
           echo "$config" >> store.conf
        fi    
    done 
}

add()
{
	if [ -f "./store.conf" ]; then # If config file exists 
		if ! grep -q "^Util:$1:" ./store.conf ; then # If record about utility is not in store.conf
			appendConfig "$1"	
		else
			insertConfig "$1" 
		fi
	else
		appendConfig "$1"
	fi
}

delete()
{
	if [ -f "./store.conf" ]; then # If config file exist 
		if "$hasConfig" ; then # If command have setted exact config files to remove.
			for config in "${configs[@]}"
			do
				sed -i "$(grep -n "^$config$" ./store.conf | cut -f 1 -d :)d" ./store.conf # Remove exact configs
			done
		else # Remove whole record about utility with all configs
			if  grep -q "^Util:$1:" ./store.conf ; then # If record about utility is in store.conf
				startOfSec=$(grep -n "Util:$1:" ./store.conf| cut -f 1 -d :) # Line where is start of record (Util:[NAME]:<PATH>)
				endOfSec=$(cat ./store.conf | tail -n +"$(($startOfSec + 1 ))" | grep -n -m 1 "Util:"| cut -f 1 -d :) # Begin of next record
				if [ "$endOfSec" != 0 ]; then  # If the record is not last in conf
					sed -i "$startOfSec,$endOfSec d" ./store.conf # Remove lines in range
				else
					rm ./store.conf 
				fi
			fi
		fi 
	else
		echo "Config doesn't exists!"
		exit 1
	fi	
}

backup()
{
	if [ -f "./store.conf" ] || $2 ; then
		mkdir -p "$1/.storeConfig" # Create directory with archive name and hidden subdirectory .storeConfig for .conf file
		if $2 ; then # If user use config file created by his own.
			cp -iu "$3" "./$1/.storeConfig/" # $3 is path to config from user
		else
			cp -iu "./store.conf" "./$1/.storeConfig/" # Use default config created by this script in default folder (where script is used)
		fi

		input="./$1/.storeConfig/store.conf"
		while IFS= read -r line
		do
			if  echo "$line" | grep -q "^Util:" ; then # If line is start of util record 
				nameOfUtil=$(echo "$line" | cut -f 2 -d :) # Get util name 
				mkdir "$1/$nameOfUtil" # Create dir nammed by util
				installScript=$(echo "$line" | cut -f 3 -d :) # Path to installScript.sh

				if [ -n "$installScript" ] && [ -f "$installScript" ]; then # If path to installScript.sh is not default(empty) and exists.
					mkdir "$1/$nameOfUtil/.installScript" # Create dir to store installScript.sh
					cp  "$installScript" "$1/$nameOfUtil/.installScript/"
				fi
			else
				if [ -f "$line" ] || [ -d "$line" ]; then # Check if conf or dir witch confs exists
					cp -iur "$line" "$1/$nameOfUtil" 
				else
					echo "File or directory $line doesn't exists"
				fi
			fi
		done < "$input"
	        tar -cvf "$1.tar" "./$1" # Make .tar archive 
	        rm -rf "./$1" 
	else
		echo "No config file founded!"
	fi
}

restore()
{
	IsNoError=true
	sudo pacman -Syu # Update system 
	tar -xvf "$1" # Untar archive with stored configs to actual dir
	
	nameOfArchive=$(echo "$1" | awk -F/ '{print $NF}') # Get name of archive from path
	cd "./$(echo "$nameOfArchive" | cut -f 1 -d .)" # Get name of untar archive
	find . -type f -print0 | xargs -0 sed -i "s|^/home/.*/|/home/$user/|" # Change name of user in paths of configs.

	while IFS= read -r line
	do
		        if echo "$line" | grep -q "^Util:" ; then # If line is begin of util record
				IsNoError=true
                                nameOfUtil=$(echo "$line" | cut -f 2 -d :) 
				pathToInstallMethod=$(echo "$line" | cut -f 3 -d :) # Try to get path to installScript
			
				if [ -z "$pathToInstallMethod" ] ; then # If path to installScript is null, use default way to install utility
					sudo pacman -S "$nameOfUtil" || IsNoError=false  #If pacman can't install util, skip all configs for this util.
				else
					nameOfInstallMethod=$(echo "$pathToInstallMethod" | awk -F/ '{print $NF}') # Use own way to install util in installScript
					sudo sh "./$nameOfUtil/.installScript/$nameOfInstallMethod" "$nameOfUtil"
				fi
                        elif $IsNoError ; then # If the util where succesfully installed
				nameOfFile=$(echo "$line" | awk -F/ '{print $NF}')
				cp -iur "./$nameOfUtil/$nameOfFile" "$line" 
                        fi

	done < "./.storeConfig/store.conf"
}

checkIfPathExist()
{
if [ ! -f "$1" ] && [ ! -d "$1" ]; then
    echo "Path doesn't exist!"
    exit 1
fi
}


manager="" 
nameOfUtil=""
delete=false
add=false
hasConfig=false
configs=()

if [ $# == 1 ]; then
	help
	exit 1
fi

for arg in "$@"
do
	if $hasConfig; then
		configs+=("$arg")
	else
        	case "$arg" in
           	-h |--help )
           	     help
           	     exit 1
           	     ;;
          	 -b |--backup )
			shift
			if [ $# == 3 ]; then
				checkIfPathExist "$2"
				backup "$1" true "$2"
			else
				backup "$1" false
			fi
			break
        	        ;;
        	 -d |--delete )
			shift
			nameOfUtil="$1"
			delete=true
        	        ;;
        	 -a |--add )
			shift
			nameOfUtil="$1"
			add=true
			shift
        	        ;;
		 -m |--manager )
			shift
			manager="$1"
			checkIfPathExist "$1"
			;;
		 -c )
			hasConfig=true
			;;
        	 -r |--restore )
			shift
			user=$USER
			checkIfPathExist "$1"
			restore "$1"
			break
        	        ;;
        	 \? )
        	        echo "Invalid option: $OPTARG" 1>&2
          	    	exit 1
             	   	;;
           	  : )
                	echo "Invalid option: $OPTARG requires an argument" 1>&2
               	 	exit 1
                	;;
        	esac
	fi
done

if $add; then
	add "$nameOfUtil"
elif $delete; then
	delete "$nameOfUtil"
fi
