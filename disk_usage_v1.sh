#!/bin/bash

# declare required variables constants arrays
declare -A arr
declare -i cursor=0
declare -r du_op_file='/tmp/du_output.txt'
declare -r du_op_json='/tmp/du_output.json'
declare -x mnt_pt=$1
declare vars=''

# Check arugments function
arg_chk () {
                echo -e "\nERROR: Invalid parameter set, Mount point arg missing"
                exit 1
                }

# Cleanup function
cleanup () {
        rm -rf $du_op_file $du_op_json

        for i in $(env | awk -F"=" '{print $1}') ; do
                unset $i ; done
                }

# Check user function
usr_chk () {
        if (( $EUID != 0 )); then
                echo -e "\nWARNING: Not a root user. Fetching details for one or more directories or files may be skipped due to permissions"
        else
                echo -e "\nINFO: Running as root user"
        fi
                }

# Count and check passed arguments
if [ $# -lt 1 ]; then
        arg_chk
else
        echo -e "\nINFO: Space check to be performed on mount point $mnt_pt"
fi

usr_chk

# Check system sanity and write the output of disk usage command to a file
df_chk=$(timeout 5 df | grep $mnt_pt | wc -l)
if [[ $df_chk -ge 1 ]]; then
                du $mnt_pt > $du_op_file

                # read du output from temp file
                while read -r label number; do
                        arr[$cursor,0]="$label"; arr[$cursor,1]="$number"
                        cursor=cursor+1
                done < $du_op_file

#cat $du_op_file
#exit
                # Iterate and store values file and size in desire format
                for((i=0; i<${#arr[@]}/2; i++)); do
                        vars="${vars} ${arr[$i,1]},${arr[$i,0]}"
                done
#echo $vars
#exit
                # Populate json file with values files and size stored in array
                jq -n '{files: $ARGS.positional}' --args $vars > $du_op_json

                # update format to meet requirement
                sed -i -e 's/",/}/g' $du_op_json
                sed -i -e 's/"\//{"\//g' $du_op_json
                sed -i -e 's/,/", /g' $du_op_json
                sed -i -e 's/}/},/g' $du_op_json
                sed -i -e '$s/\,//g' $du_op_json
                sed -i -e 's/\(.*\)"/\1}/g' $du_op_json
                sed -i -e 's/"files}:/"files":/g' $du_op_json
                sed -i -e 's/}, /", /g' $du_op_json

                cat $du_op_json

                cleanup

                exit 0

else
        echo -e "\nERROR: Mount point is empty or DF command is talking too long or hanging. System restart needed."
        exit 1
fi
        