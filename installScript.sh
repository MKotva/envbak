#!/bin/bash
set -eux

help()
{
	echo -e "Name of config: install.conf\nInstallScript is tool for easier making up your userspace, when you want to save\nyour userspace from other system. If you want to save your utilities and their's\nconfig files, you can use implemented methods, or just create config file in\nscript folder in format:\n \nUtil:[NAME]\n[PathToConfig]\n[PathToConfig]\n...\n\nImplemented methods:\n-a or -add in format: -a [UtilityName] and optionaly -c [PathToConfig].\nYou can also set multiple paths separated by space.\n\n-r --remove [UtilityName] when you want remove all records about this utility\nand optionaly use -c [PathToConfig], to remove just one.\n\nWhen you've added all configs and utils, just use -s or --save to make .tar\narchive in script folder. When you move .tar to new system, call\n--restore [PathToArchive]"
}

insertConfig()
{
for config in "${configs[@]}"
    do  
        if ! grep -q "^$config$" ./install.conf ; then
           N=$(cat ./install.conf | grep -n $1 | cut -f 1 -d :) 
           sed -i "$(($N + 1)) i $config" ./install.conf
        fi    
    done 
}

appendConfig()
{
for config in "${configs[@]}"
    do  
        if ! grep -q "^$config$" ./install.conf ; then
           echo $config >> install.conf
        fi    
    done 
}

add()
{
	if [ -f "./install.conf" ]; then
		if ! grep -q "^Util:$1$" ./install.conf ; then
			echo Util:$1 >> install.conf
			appendConfig	
		else
			insertConfig $1 
		fi
	else
		echo Util:$1 >> install.conf
		appendConfig
	fi
}

remove()
{
	if [ -f "./install.conf" ]; then
		if $config ; then
			for config in "${configs[@]}"
			do
				sed -i "$(cat ./install.conf | grep -n "^$config$" | cut -f 1 -d :)d" ./install.conf 
			done
		else
			if  grep -q "^Util:$1$" ./install.conf ; then
				startOfSec=$(cat ./install.conf | grep -n "Util:$1"| cut -f 1 -d :)
				toTail=$(($(cat ./install.conf | wc -l) - $startOfSec))
				endOfSec=$(cat ./install.conf | tail $toTail | grep -n "Util:$1"| cut -f 1 -d :)
				if [ $endOfSec != 0 ]; then 
					sed -i "$lineOfStar,$endOfSec" ./install.conf
				else
					rm ./install.conf
				fi
			fi
		fi 
	fi	
}

save()
{
	if [ -f "./install.conf" ]; then
		mkdir "$1"
		cd "$1"
		mkdir .isntallConfig
		cd .installConfig 
		
		input="./install.conf"
		while IFS= read -r line
		do
			if grep -q "^Util:" $line ; then
				cd ..
				nameOfDir=$(echo $line | cut -f 2 -d :)
				mkdir "$nameOfDir"
				cd "./$nameOfDir"
			else
				cp "$line" ./
			fi
		done < "$input"
	else
		echo "No config file founded!"
	fi
}

#restore()

nameOfUtil=""
remove=false
add=false
config=false
configs=()

if [ $# == 1 ]; then
	help
	exit 1
fi

for arg in "$@"
do
	if $config; then
		configs+=($arg)
	else
        	case $arg in
           	-h |--help )
           	     help
           	     exit 1
           	     ;;
          	 -s |--save )
			shift
			save $1
        	        ;;
        	 -r |--remove )
			shift
			nameOfUtil=$1
			remove=true
        	        ;;
        	 -a |--add )
			shift
			nameOfUtil=$1
			add=true
        	        ;;
		 -c )
			config=true
			;;
        	 -restore)
			shift
        	        restore $1
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
	add $nameOfUtil
elif $remove; then
	remove $nameOfUtil
fi
