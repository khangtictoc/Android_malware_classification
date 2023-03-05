#!/bin/bash

# Store the path to the directory in a variable
src_folder=$1
des_folder=$2
temp_path=$3

# Global variable
NUM_FILE_SUCCESS=0

#################### DEFINE FUNCTION ###################

## HELP MENU
Help()
{
   # Display Help
   echo "Usage: AndroPy_autorun [SOURCE_FILE] [DESTINATION_FILE] [TEMP_FILE]"
   echo
   echo "Parameters:"
   echo "SOURCE_FILE     	Folder contains APK files"
   echo "DESTINATION_FILE	Folder stores our output"
   echo "TEMP_FILE		Folder for processing. This one is not stable, only for running this script, nothing more"
   echo "-h    			Print this Help."
   echo "Note1: You have running the script as root if your 'docker' is used with administrative privilege"
   echo "Note2: You should specify ABSOLUTE path for properly executing"
   echo "Note3: No trailing slash '/' when specifying PATH"
}

## File intro
initLog()
{
  echo "///////////////////////////////////////////////////////////////" > "$file_log"
  echo "//////////////// FILE ANALYSIS PROCESS CHECKER ////////////////" >> "$file_log"
  echo -e "///////////////////////////////////////////////////////////////\n\n" >> "$file_log"
  echo "WORKING DIRECTORY: $src_folder" >> "$file_log"
  echo "OUTPUT DIRECTORY: $des_folder" >> "$file_log"
  echo -e "\n\n" >> "$file_log"
}

## Check VirusTotal API Status
# Check quotas parameters - limits - remaining requests

checkQuotasVT()
{

 vt_api_key=$1
 user_id=$1
 echo "Checking your current key: $1 ............"
 curl --request GET \
     --url "https://www.virustotal.com/api/v3/users/$user_id/overall_quotas" \
     --header "accept: application/json" \
     --header "x-apikey: $vt_api_key" | jq '.data.api_requests_daily' > vt_api_quotas.txt

  # Show status dialog
   allowed_req=$(cat vt_api_quotas.txt | jq '.user.allowed')
   used_req=$(cat vt_api_quotas.txt | jq '.user.used')
   

   rem_req=$( echo "$allowed_req-$used_req" | bc) 
   echo "################## VIRUSTOTAL QUOTAS STATUS ##################"
   echo "Used requests: $used_req"
   echo "Remaining requests: $rem_req"
   
   rm -f vt_api_quotas.txt
   
   # Check condition whether to input new API_KEY
   if [[ $rem_req -eq 0 ]]
   then
     read -p "New VirusTotal API key (Make sure enter key with available quotas): " vt_api_key
     if [[ -z $vt_api_key ]] 
     then 
       echo "Your VT key must be valid (Your key's length is 0)"
       exit 0
     fi
   fi
   echo "Your newly assigned API_KEY: $vt_api_key"
   
}

################### MAIN FUNCTION ###################

# Get the options (if it has)
while getopts ":h" option; do
   case $option in
      h) # display Help
         Help
         exit ;;
      ?)
         echo "Invalid using"
         echo "Use -h for more help"
         exit ;;
   esac
done


# Pre-check
# Check whether 3 needed parameters exist?
if [[ -z $1 || -z $2 || -z $3 ]] 
then
  echo "Not enought parameters. Please check HELP"
  Help
  exit 0
fi

# Print general information
echo "Source file: ${src_folder^^}"
echo "Destination file: ${des_folder^^}"



# VIRUS TOTAL key option

echo -e "\n\n@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo "@@ !!! VIRUS TOTAL API KEY ONLY HAS A QUOTAS IN A MINUS/DAY !!! @@"
echo -e "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@\n\n"

read -p "Use default API key (hardcoded) [YES/NO]? " option

shopt -s nocasematch

if [[ $option =~ YES|Y ]] 
then 
  vt_api_key="a54d394ab2062917d31a22e60db6c43a3484aeefe423a0a842b49daaece136db"
elif [[ $option =~ NO|N ]]
then
  read -p "Your customized VirusTotal API key: " vt_api_key
  if [[ -z $vt_api_key ]] 
  then
    echo "Your VT key must be valid (Your key's length is 0)"
    exit 0
  fi
else
  echo "Choice only match with 'yes(y)' or 'no(n)' !!!"
  exit 0
fi

# Use the built-in `readarray` command to store the list of files in an array
readarray -t files < <(find "$src_folder" -maxdepth 1 -type f)


echo "========== PREPROCESSING ==========="

# Create destination folder if it does not exist
if [[ -d "$des_folder" ]]
then
  echo "Destination folder found!!!"
else
  mkdir -p "$des_folder"
  echo ">>>>>>>> Create resulting folder successfully !!!"
fi


file_log="$des_folder/status_checker_$(date +'%Y-%m-%d_%H:%M:%S').log"

# Add an output checker file
if [[ -e "$des_folder/status_checker_$(date +'%Y-%m-%d_%H:%M:%S').log" ]]
then
  initLog
else
  echo ">>>>>>>>> FILE LOG CREATED !!!"
  initLog

fi

# Create TEMP folder for each processing loop 

if [[ -d "$temp_path" ]] 
then
  echo "TEMP folder found!!!"
  rm -dRf  $temp_path/*
else
  mkdir -p "$temp_path"
  echo ">>>>>>>> Create TEMP folder successfully !!!"
fi

# Make folder for destination path

mkdir -p $des_folder/DroidBox_outputs/
mkdir -p $des_folder/Dynamic/Droidbox/
mkdir -p $des_folder/Dynamic/Strace/
mkdir -p $des_folder/Features_files/
mkdir -p $des_folder/FlowDroid_outputs/
mkdir -p $des_folder/FlowDroid_processed/
mkdir -p $des_folder/samples/BW/
mkdir -p $des_folder/samples/MW/
mkdir -p $des_folder/invalid_apks/
mkdir -p $des_folder/VT_analysis/


# Loop from 0 to the length of the array


echo "============== START EVALUATE ================"

for i in $(seq 0 $((${#files[@]} - 1))); do

  # Clear the container stored in the system
  echo "Y" | docker system prune

  # Remove all output and start new files
  echo "REMOVING ALL OUTPUT (IF TRUE)..."

  rm -dRf  $temp_path/*
  
  cp "${files[i]}" "$temp_path"
  
  # Check VirusTotal API_KEY Quotas
  checkQuotasVT $vt_api_key
  
  # Start AndroPy
  echo "PROCESSING WITH ANDROPY ... ${file[i]}"
  docker run --volume=$temp_path:/apks alexmyg/andropytool -s /apks/ -vt $vt_api_key -all

  # Check the condition
  if [[ -d  "$temp_path/DroidBox_outputs" && -d  "$temp_path/Dynamic" && -d  "$temp_path/Features_files" && -d  "$temp_path/FlowDroid_outputs" && -d  "$temp_path/FlowDroid_processed" && -d  "$temp_path/VT_analysis" ]]
  then
    if [[ -z $(ls -A "$temp_path/DroidBox_outputs") || -z $(ls -A "$temp_path/Dynamic") || -z $(ls -A "$temp_path/Features_files") || -z $(ls -A "$temp_path/FlowDroid_outputs") || -z $(ls -A "$temp_path/FlowDroid_processed") || -z $(ls -A "$temp_path/VT_analysis") ]]
    then 
      echo "${files[i]}: FAILED - Empty folder detected !!!" >> "$file_log"
    else
    
    # If successful, save the result to destination folder
    
      echo "${files[i]}: SUCCESSFUL !!!" >> "$file_log"
      cp -f $temp_path/DroidBox_outputs/* $des_folder/DroidBox_outputs/
      cp -f $temp_path/Dynamic/Droidbox/* $des_folder/Dynamic/Droidbox/
      cp -f $temp_path/Dynamic/Strace/* $des_folder/Dynamic/Strace/
      cp -f $temp_path/Features_files/* $des_folder/Features_files/
      cp -f $temp_path/FlowDroid_outputs/* $des_folder/FlowDroid_outputs/
      cp -f $temp_path/FlowDroid_processed/* $des_folder/FlowDroid_processed/
      cp -f $temp_path/VT_analysis/* $des_folder/VT_analysis/
      cp -f $temp_path/samples/BW/* $des_folder/samples/BW/
      cp -f $temp_path/samples/MW/* $des_folder/samples/MW/
      cp -f $temp_path/invalid_apks/* $des_folder/invalid_apks/  
      NUM_FILE_SUCCESS=$(($NUM_FILE_SUCCESS+1))
    fi
  else
    echo "${files[i]}: FAILED - No folder detected !!!" >> "$file_log"
  fi
   

done

# Report to LOG file


echo -e "\n\n" >> "$file_log" 
echo "Number of file successed: $NUM_FILE_SUCCESS" >> "$file_log" 
echo "Number of file failed: $((${#files[@]} - $NUM_FILE_SUCCESS))" >> "$file_log" 

echo "============== FINISH EVALUATE ================"
