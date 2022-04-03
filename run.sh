#!/bin/bash

print_help () {
  # Display Help
  echo "Process MetFrag parameter files with MetFragCLI and produce ranking summary. Mount a directory (PARAMETERFOLDER) that"
  echo "contains a folder named 'parameters' inside the Docker container. This 'parameters' folder contains MetFrag parameter"
  echo "files that need to be processed. After successful processing a 'results' and 'rankings' folder is created in the mounted"
  echo "directory."
  echo ""
  echo "Use absolute paths in your parameter files (e.g. for 'PeakListPath', 'LocalDatabasePath' etc.). This paths must exists inside"
  echo "the Docker container. Additional mounts (-v) might be required."
  echo ""
  echo "The run script in the Docker container will copy the parameter files and overwrite some settings such as 'MetFragCandidateWriter'."
  echo "This is necessary as the ranking function needs a particular format. The original parameters mounted in the container won't be "
  echo "modified."
  echo
  echo "Syntax: docker run -v 'PARAMETERFOLDER':'TARGET' metfragrank [-h] [-p TARGET]"
  echo "options:"
  echo "p     set absolute path to root folder containing a 'parameters' directory with MetFrag parameter files"
  echo "h     print this help"
  echo
}

#######
#
# Process MetFrag parameter file with MetFragCLI
#
run_metfrag () {
  parameter_file=$1
  java -jar MetFragCommandLine-2.4.8.jar \
	  "${parameter_file}"
}

#######
#
# Calculate rank of MetFrag result file
#for parameter_file in /tmp/parameters/*; do
#  rank_metfrag 'RESULT_FILE' 'INCHIKEY' 'RANKINGS_FOLDER' 'RANKINGS_SCORES'
#
# Example:
#
#  rank_metfrag "/metfrag/results/metfrag_result.psv" "BSYNRYMUTXBXSQ-UHFFFAOYSA-N" "/metfrag/rankings"
#
rank_metfrag () {
  result_file=$1
  inchikey=$2
  rankings_folder=$3
  #
  [ ! -f "${result_file}" ] && echo "result file ${result_file} not found. file will be skipped." && return 1
  [ ! -d "${rankings_folder}" ] && echo "rankings directory ${rankings_folder} not found" && return 1
  inchikey_1=$(echo $inchikey | cut -d"-" -f1)
  ranking_file=$(basename ${result_file} | sed "s/.psv$//").txt
  # calculate rank
  java -cp MetFragTools-2.4.8.jar:MetFragCommandLine-2.4.8.jar \
	  de.ipbhalle.metfrag.ranking.GetRankOfCandidatePSV \
	  "${result_file}" \
	  InChIKey1=${inchikey_1} \
	  Score=1.0 > "${rankings_folder}/${ranking_file}"
}

#######
#
# Process parameters in 'parameters folder'
#
process_parameters () {
  root_folder=$(echo $1 | sed 's/\/\s*$//')
  [ ! -d "${root_folder}" ] && echo "The directory ${root_folder} was not found inside the Docker container." && exit 1
  [ ! -d "${root_folder}/parameters" ] && echo "No 'parameters' directory found inside ${root_folder} directory." && exit 1
  [ -n "$(find ${root_folder}/parameters -prune -empty 2>/dev/null)" ] && echo "No parameter files found in ${root_folder}/parameters directory." && exit 1
  [ -d "${root_folder}/results" ] && echo "Found a 'results' directory in ${root_folder} directory. Please remove it." && exit 1
  [ -d "${root_folder}/rankings" ] && echo "Found a 'rankings' directory in ${root_folder} directory. Please remove it." && exit 1
  mkdir "${root_folder}/results" "${root_folder}/rankings"
  # copy parameters
  [ -d /tmp/parameters ] && rm -r /tmp/parameters
  cp -r ${root_folder}/parameters /tmp
  # remove parameters that will be set afterwards
  sed -i '/^ResultsPath/d' /tmp/parameters/*
  sed -i '/^MetFragCandidateWriter/d' /tmp/parameters/*
  sed -i "/^SampleName/d" /tmp/parameters/*
  # add parameters
  echo "ResultsPath = ${root_folder}/results" | tee -a /tmp/parameters/* > /dev/null
  echo "MetFragCandidateWriter = PSV" | tee -a /tmp/parameters/* > /dev/null
  ## add sample names and process files
  for parameter_file in /tmp/parameters/*; do
    filename=$(basename -- "${parameter_file}")
    extension="${filename##*.}"
    sample_name=$(echo ${filename} | sed "s/\.${extension}$//")
    echo "SampleName = ${sample_name}" | tee -a "${parameter_file}" > /dev/null
    # get and check InChIKey
    inchikey=$(grep -e "#\s*InChIKey\s*=" "${parameter_file}" | sed "s/.*=\s*//")
    [ -z "${inchikey}" ] && echo "parameter file ${filename} contains no valid '# InChIKey = ' line. file will be skipped." && continue
    # process file
    run_metfrag "${parameter_file}"
    if [ "$?" -eq "0" ]; then
      rank_metfrag "${root_folder}/results/${sample_name}.psv" "${inchikey}" "${root_folder}/rankings"
    else
      echo "parameter file ${filename} could not be processed correctly"
    fi
  done 
}

while getopts ':hp:' option; do
  case "$option" in
    h) print_help
       exit
       ;;
    p) folder=$OPTARG
       process_parameters "${folder}"
       ;;
    :) printf "missing argument for -%s\n\n" "$OPTARG" >&2
       print_help >&2
       exit 1
       ;;
   \?) printf "illegal option: -%s\n\n" "$OPTARG" >&2
       print_help >&2
       exit 1
       ;;
  esac
done

if [ $OPTIND -eq 1 ]; then
	printf "missing option\n\n"
	print_help >&2; 
fi
