#!/bin/bash
#
# This script create the project's config file.
# It define all the needed variables and store them in the XXXX file,
# wich can be add in the .gitignore file, for securing password and 
# private data.
#
# Usage: ./init.sh
#           will create a .cfg file if this file does not exists
#           backup previous file if exists and create a new one
#           based on the sticonfig.init file

STI_CONFIG_FILE='./sticonfig.cfg'

# To create the config.init file from all the *.sh script
# find . -name "*.sh" -exec grep -hr ^: {} \;  | cut -c 5-  | sed 's/.$//' > test.cfg 

tempVarName=""
    tempVal=""

# Create or backup the previous config file
if [ -f $STI_CONFIG_FILE ]; then
    mv $STI_CONFIG_FILE $STI_CONFIG_FILE.$(date +%Y%m%d_%H%M%S)
else
    echo "No config file found, create $STI_CONFIG_FILE"
    touch $STI_CONFIG_FILE
fi

echo -e "######################################################################\n# STI Foreman config file \n# Generated on $(date)\n######################################################################" > ./sticonfig.cfg
while read -r line ; do
    # http://stackoverflow.com/questions/10586153/bash-split-string-into-array
    IFS='\:=' read -a array <<< "$line"
    tempVarName=""
    tempVal=""
    tempInput=""
    for index in "${!array[@]}"
    do
        if [ $index -eq 0 ]; then 
            tempVarName=${array[index]} 
        fi
        if [ $index -eq 2 ]; then
            # http://stackoverflow.com/questions/9651746/bash-read-inside-a-loop-reading-a-file
            tempVal=${array[index]}
            read -u 3 -p "Enter ${tempVarName} (Default : ${tempVal}): " tempInput
            tempInput=${tempInput:-$tempVal}
            echo $tempInput
            # Write it to sticonfig.cfg
            echo ": \${${tempVarName}:=$tempInput}" >> $STI_CONFIG_FILE
        fi
    done
done 3<&0 < <(grep -hr ^: sticonfig.init  | cut -c 5-  | sed 's/.$//')

echo "Print the result:"
cat $STI_CONFIG_FILE
echo ".... end ...."
echo "Be sure to add .config in your .gitignore file"

#echo "http://stackoverflow.com/questions/2642585/read-a-variable-in-bash-with-a-default-value"
