#!/bin/bash
# Script to backup TrueNAS SCALE configuration file
# WARNING: DOES NOT CHECK IF A VALID BACKUP IS ACTUALLY CREATED
#

# # # # # # # # # # # # # # # #
# USER CONFIGURABLE VARIABLES #
# # # # # # # # # # # # # # # #

# TrueNAS Server IP or URL
trueNasServerURL=${TRUENAS_SERVER_URL}
ntfyServerUrl=${NTFY_SERVER_URL}

# Ntfy Server Address
ntfyServerUrl=${NTFY_SERVER_URL}

# TrueNAS API key
trueNasApiKey=${TRUENAS_API_KEY}

# Ntfy API key
ntfyApiKey=${NTFY_API_KEY}

# Include Secret Seed (true| false)
secSeed=true

# Path on server to store backups
backuploc="/home/jleon/backups/truenas"

# Backup directory in an external drive
externalHDDDirectory="/mnt/3TB_drive/backups/truenas"

# TrueNAS mount directory for latest config file
trueNasMntDirectory="/mnt/truenas_jleon/backups/truenas_config"

# Max number of backups to keep (set as 0 to never delete anything)
maxnrOfFiles=3

# # # # # # # # # # # # # # # # # #
# END USER CONFIGURABLE VARIABLES #
# # # # # # # # # # # # # # # # # #


echo
echo "Backing up current TrueNAS config"

# Check current TrueNAS version number
versiondir=$( curl --no-progress-meter \
-X 'GET' \
"${trueNasServerURL}/api/v2.0/system/version_short" \
-H "Authorization: Bearer ${trueNasApiKey}" )

# Set directory for backups to: 'path on server' / 'current version number'
# version contains quotes, remove them with 1:-1
backupMainDir="${backuploc}/${versiondir:1:-1}"
backupHDDDir="${externalHDDDirectory}/${versiondir:1:-1}"

# # Create directory for for backups (Location/Version)
mkdir -p "$backupMainDir"
mkdir -p "$backupHDDDir"

# # Use appropriate extention if we are exporting the secret seed
if [ $secSeed = true ]
then
    fileExt="tar"
    echo "Secret Seed will be included"
else
    fileExt="db"
    echo "Secret Seed will NOT be included"
fi

# # Generate file name
fileName=TrueNAS-$(date +%Y-%m-%d_%H%M%S).$fileExt

# # API call to backup config and include secret seed
curl --no-progress-meter \
-X 'POST' \
"${trueNasServerURL}/api/v2.0/config/save" \
-H "Authorization: Bearer ${trueNasApiKey}" \
-H "accept: */*" \
-H "Content-Type: application/json" \
-d '{"secretseed": '$secSeed'}' \
--output "${backupMainDir}/${fileName}"

if [ -d "$externalHDDDirectory" ]; then
  echo "Saving a copy in: $externalHDDDirectory "
  cp -v "${backupMainDir}/${fileName}" "${backupHDDDir}"
else
    echo "Directory $externalHDDDirectory not found, skipping saving file."
fi

# Push a copy to the server to create an RSync task and push it to Google Cloud
if [ -d "$trueNasMntDirectory" ]; then
  echo "Saving a copy in: ${trueNasMntDirectory} "
  cp -v "${backupMainDir}/${fileName}" "${trueNasMntDirectory}/latest_truenas_config.${fileExt}"
else
    echo "Directory ${trueNasMntDirectory} not found, skipping saving file."
fi


if [ $? -ne 0 ]
then
    echo "Error when saving configuration file!"

    # Send error to ntfy
    curl --no-progress-meter \
    -X 'POST' \
    "${ntfyServerUrl}/truenas_config" \
    -H "Authorization: Bearer ${ntfyApiKey}" \
    -H "accept: */*" \
    -H "Content-Type: application/json" \
    -H "Title: TrueNAS Configuration, " \
    -H "Tags: floppy_disk, red_circle, rotating_light" \
    -H "Actions: view, Open TrueNAS, ${trueNasServerURL}" \
    -d "An error ocurred saving the configuration file."

    exit 1
else
    echo "Config saved to ${backupMainDir}/${fileName}"
    echo " And to ${backupHDDDir}/${fileName}"
fi

# #
# # The next section checks for and deletes old backups.
# # Will not run if $maxnrOfFiles is set to zero.
# #

if [ ${maxnrOfFiles} -ne 0 ]
then
    echo
    echo "Checking for old backups to delete"
    echo "Number of files to keep: ${maxnrOfFiles}"

    # Get number of files in the backup directory
    nrOfFiles="$(ls -l ${backupMainDir} | grep -c "^-.*")"

    echo "Current number of files: ${nrOfFiles}"

    # Only do something if the current number of files is greater than $maxnrOfFiles
    if [ ${maxnrOfFiles} -lt "${nrOfFiles}" ]
    then
        nFileToRemove="$((nrOfFiles - maxnrOfFiles))"
        echo "Removing ${nFileToRemove} file(s)"
        while [ $nFileToRemove -gt 0 ]
        do
            fileToRemove="$(ls -t ${backupMainDir} | tail -1)"
            echo "Removing file ${fileToRemove}"
            nFileToRemove="$((nFileToRemove - 1))"
            rm "${backupMainDir}/${fileToRemove}"
            rm "${backupHDDDir}/${fileToRemove}"
            done
    fi
# Inform the user that no files will be deleded if $maxnrOfFiles is set to zero
else
    echo
    echo "NOT deleting old backups because '\$maxnrOfFiles' is set to 0"
fi

#All Done

echo
echo "DONE!"
echo

# API call to ntfy
curl --no-progress-meter \
-X 'POST' \
"${ntfyServerUrl}/truenas_config" \
-H "Authorization: Bearer ${ntfyApiKey}" \
-H "accept: */*" \
-H "Content-Type: application/json" \
-H "Title: TrueNAS Configuration" \
-H "Tags: floppy_disk, green_circle" \
-H "Actions: view, Open TrueNAS, ${trueNasServerURL}" \
-d "${fileName} successfully saved."
