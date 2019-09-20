#!/bin/bash
set -x

help()
{
	echo -e "Name of config: store.conf\nInstallScript is tool for easier making up your userspace, when you want to save\nyour userspace from other system. If you want to save your utilities and their's\nconfig files, you can use implemented methods, or just create config file in\nscript folder in format:\n \nUtil:[NAME]\n[PathToConfig]\n[PathToConfig]\n...\n\nImplemented methods:\n-a or -add in format: -a [UtilityName] and optionaly -c [PathToConfig].\nYou can also set multiple paths separated by space.\n\n-d --delete [UtilityName] when you want remove all records about this utility\nand optionaly use -c [PathToConfig], to remove just one.\n\nWhen you've added all configs and utils, just use -b or --backup [NAME] \n<[YOURSCONFIG]> to make .tar archive in script folder.Your's config is path\nto other config then default.\n-m or --manager [PATHTOSHELLSCRIPT] when you want use your own way how to\ninstall utility.\n\n-b use as last.\n\n When you move .tar to new system, call\n-r or --restore [PathToArchive]\n-u or --update if you want update your system before restoring.\n-o or --owner [USER:NAME] or [GROUP:NAME] or both to change owner of configs\n-l or --log [NAME] creates log file \n-s or --silence to dont show progress."
}

insertConfig()
{
for config in "${configs[@]}"
    do
	echo "${configs[@]}"  
        if ! grep -q "^$config$" ./store.conf ; then # If config is not already in store.conf
           n=$(($(grep -n "^Util:$1:" ./store.conf | cut -f 1 -d :) + 1)) # Find line with utility name. 
	   makeLog "Adding $config under existing recod $1.."
	   sed -i "$n i $config" ./store.conf # Insert config under utility name. 
        fi    
    done 
}

appendConfig()
{
if [ "$manager" = "" ] ; then
	makeLog "Adding record about utility $1 with default installation.."
	echo "Util:$1:" >> store.conf # Make record about utility.
else
	makeLog "Adding record about utility $1 with installScript $manager.."
	echo "Util:$1:$manager" >> store.conf # Make record about utility, with path to config file with install method.
fi

for config in "${configs[@]}"
    do  
        #if ! grep -q "^$config$" ./store.conf ; then # Add config file under utility record ( Util:[NAME]:<PATH>)
	   makeLog "Adding $config to created record $1.." 
           echo "$config" >> store.conf
        #fi    
    done 
}

add()
{
	makeLog "Adding.."
	if [ -f "./store.conf" ]; then # If config file exists 
		if ! grep -q "^Util:$1:" ./store.conf ; then # If record about utility is not in store.conf
			appendConfig "$1"	
		else
			insertConfig "$1" 
		fi
	else
		appendConfig "$1"
	fi
	makeLog "Adding finished."
}

delete()
{
	makeLog "Deleting.."
	if [ -f "./store.conf" ]; then # If config file exist 
		if "$hasConfig" ; then # If command have setted exact config files to remove.
			for config in "${configs[@]}"
			do
				makeLog "Deleting $congif.."
				sed -i "$(grep -n "^$config$" ./store.conf | cut -f 1 -d :)d" ./store.conf # Remove exact configs
			done
		else # Remove whole record about utility with all configs
			if  grep -q "^Util:$1:" ./store.conf ; then # If record about utility is in store.conf
				startOfSec=$(grep -n "Util:$1:" ./store.conf| cut -f 1 -d :) # Line where is start of record (Util:[NAME]:<PATH>)
				endOfSec=$(cat ./store.conf | tail -n +"$(($startOfSec + 1 ))" | grep -n -m 1 "Util:"| cut -f 1 -d :) # Begin of next record
				if [ "$endOfSec" != "" ]; then  # If the record is not last in conf
					makeLog "Deleting $1 and all config files from line $startOfSec to $endOfSec.."
					sed -i "$startOfSec,$(($endOfSec + $startOfSec - 1)) d" ./store.conf # Remove lines in range
				else
					makeLog "Because this was last utility, deleting whole ./store.conf.." 
					rm ./store.conf 
				fi
			fi
		fi
		makeLog "Deleting finished." 
	else
		makeLog "Config doesn't exists!"
		exit 1
	fi	
}

backup()
{
	makeLog "Saving.."
	if [ -f "./store.conf" ] || $2 ; then
		makeLog "Creating archive dir $1.."
		mkdir -p "$1/.storeConfig" # Create directory with archive name and hidden subdirectory .storeConfig for .conf file
		
		if $2 ; then # If user use config file created by his own.
			makeLog "Copying $3 cofig to archive subdir .storeConfig.."
			cp -iu "$3" "./$1/.storeConfig/" # $3 is path to config from user
		else
			makeLog "Copying defaul config to archive subdir .storeConfig.."
			cp -iu "./store.conf" "./$1/.storeConfig/" # Use default config created by this script in default folder (where script is used)
		fi

		input="./$1/.storeConfig/store.conf"
		while IFS= read -r line
		do
			if  echo "$line" | grep -q "^Util:" ; then # If line is start of util record 
				nameOfUtil=$(echo "$line" | cut -f 2 -d :) # Get util name 
				makeLog "Creating dir $nameOfUtil for $nameOfUtil's configs.."
				mkdir "$1/$nameOfUtil" # Create dir nammed by util
				installScript=$(echo "$line" | cut -f 3 -d :) # Path to installScript.sh

				if [ -n "$installScript" ] && [ -f "$installScript" ]; then # If path to installScript.sh is not default(empty) and exists.
					mkdir "$1/$nameOfUtil/.installScript" # Create dir to store installScript.sh
					makeLog "Copying $installScript install script to $1/$nameOfUtil/.installScript/.."
					cp  "$installScript" "$1/$nameOfUtil/.installScript/"
				fi
			else
				if [ -f "$line" ] || [ -d "$line" ]; then # Check if conf or dir witch confs exists
					makeLog "Copying $line config to $1/$nameOfUtil.."
					cp -a "$line" "$1/$nameOfUtil" 
				else
					makeLog "File or directory $line doesn't exist!"
				fi
			fi
		done < "$input"
		makeLog "Making $1.tar archive.."
	        tar -cvf "$1.tar" "./$1" # Make .tar archive
		makeLog "Removing temporary archive.." 
	        rm -rf "./$1"
		makeLog "Backup finished, created $1.tar archive." 
	else
		makeLog "No config file founded!"
	fi
}

copy()
{
	makeLog "Copying $2 to $3.."
	if $preserve; then
		if [ -z $group ] ; then
			makeLog "Changing owner user:$user group:$group.."
			chown "$user:$group" "$3"
		else
			makeLog "Changing owner user:$user.."
			chown "$user" "$3"
		fi
	fi
	cp -iuar "./$1/$2" "$3" 
}

restore()
{	
	makeLog "Restoring.." 
	IsNoError=true
	if $updateSys ; then
		sudo pacman -Syu # Update system
	fi
	makeLog "Unpaking $1 archive.." 
	tar -xvf "$1" # Untar archive with stored configs to actual dir
	
	nameOfArchive=$(echo "$1" | awk -F/ '{print $NF}') # Get name of archive from path
	nameOfUntaredArchive="./$(echo "$nameOfArchive" | cut -f 1 -d .)" # Get name of untar archive
	cd "$nameOfUntaredArchive"
	find . -type f -print0 | xargs -0 sed -i "s|^/home/.*/|/home/$user/|" # Change name of user in paths of configs.

	while IFS= read -r line
	do
		        if echo "$line" | grep -q "^Util:" ; then # If line is begin of util record
				IsNoError=true
                                nameOfUtil=$(echo "$line" | cut -f 2 -d :) 
				pathToInstallMethod=$(echo "$line" | cut -f 3 -d :) # Try to get path to installScript
					
				if [ -z "$pathToInstallMethod" ] ; then # If path to installScript is null, use default way to install utility
					makeLog "Using pacman for $nameOfUtil installation.."
					sudo pacman -S "$nameOfUtil" || IsNoError=false  #If pacman can't install util, skip all configs for this util.
				else
					nameOfInstallMethod=$(echo "$pathToInstallMethod" | awk -F/ '{print $NF}') # Use own way to install util in installScript
					makeLog "Using $nameOfInstallMethod for $nameOfUtil installation.. "
					sudo sh "./$nameOfUtil/.installScript/$nameOfInstallMethod" "$nameOfUtil"
				fi
                        elif $IsNoError ; then # If the util where succesfully installed
				nameOfFile=$(echo "$line" | awk -F/ '{print $NF}')
				copy $nameOfUtil $nameOfFile $line
                        fi

	done < "./.storeConfig/store.conf"
	cd ..
	makeLog "Removing temporary archive.."
	rm -r "$nameOfUntaredArchive"
	makeLog "Restoring finished."
}

checkIfPathExist()
{
if [ ! -f "$1" ] && [ ! -d "$1" ]; then
    makeLog "Path doesn't exist!"
    exit 1
fi
}

makeLog()
{
	if "$silent" && "$makeLogfile"  ; then
		echo "$1" >> "$logFileName"
	elif "$makeLogfile" ; then
		echo "$1" | tee -a "$logFileName"
	elif ! "$silent" ; then
		echo "$1"
	fi  
}
encrease()
{
 if [ "$counter" = "0" ]; then
	counter=1
 else
	((counter++))
 fi
}

updateSys=false
silent=false
makeLogfile=false
logFileName=""
preserve=false
user=""
group=""
manager="" 
nameOfUtil=""
delete=false
add=false
pathToArchive=""
restore=false
hasConfig=false
configs=()

if [ $# == 1 ]; then
	help
	exit 1
fi

encrease "New operation:"
counter=0
args=("$@")
while [ $counter -ne $# ]
do
	if $hasConfig; then
		configs+=("${args[$counter]}")
	else
		arg="${args[$counter]}"
        	case "$arg" in
           		 -h |--help )
           		        help
           		        exit 1
           		        ;;
        	 
			 -a |--add )
				encrease
				nameOfUtil="${args[$counter]}"
				add=true
        		        ;;

			 -b |--backup )
				encrease
                	        if [ $(($# - $counter)) == 1 ]; then
                	                checkIfPathExist "${args[$($counter + 1)]}"
                	                backup "${args[$counter]}" true "${args[$($counter + 1)]}"
                	        else
                	                backup "${args[$counter]}" false
                	        fi
                	        break
                	        ;;
			 -c )
                	        hasConfig=true
                       	 	;;

		 	 -d |--delete )
				encrease
                        	nameOfUtil="${args[$counter]}"
                        	delete=true
                        	;;

		 	 -m |--manager )
				encrease
				manager="${args[$counter]}"
				checkIfPathExist "$manager"
				;;
	
	    	 	 -l |--log )
				encrease
				logFileName="${args[$counter]}"
				makeLogfile=true
		  		;;	

		 	 -o |--owner )
				encrease
				user="$(cut -f 2 -d : "${args[$counter]}")"
				if grep -q "GROUP:" "${args[$($counter + 1)]}" | cut -f 1 -d : ; then
					encrease
					group="$(cut -f 2 -d : ${args[$counter]})"
				fi
				preserve=true
				;;

			 -u |--update )
				updateSys=true
				;;
	
		 	 -s |--silence )
				silent=true
				;;
        
		 	 -r |--restore )
				encrease
				user=$USER
				pathToArchive="${args[$counter]}"
				checkIfPathExist "$pathToArchive"
				restore=true
        	        	;;
        	 	 *)
        	        	echo "Invalid option: $arg " 1>&2
          	    		exit 1
				;;
        	esac
	fi
encrease
done

if $add; then
	add "$nameOfUtil"
elif $delete; then
	delete "$nameOfUtil"
elif $restore; then
	restore $pathToArchive
fi
