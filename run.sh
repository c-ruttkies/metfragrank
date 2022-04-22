#!/bin/bash

print_help () {
  # Display Help
  echo "Process MetFrag parameter files with MetFragCLI and produce ranking summary. Mount a directory (PARAMETERFOLDER) that"
  echo "contains a folder named 'parameters' inside the Docker container. This 'parameters' folder contains MetFrag parameter"
  echo "files that will be processed. After successful processing a 'results' and 'rankings' folder is created in the mounted"
  echo "directory."
  echo ""
  echo "Use absolute paths in your parameter files (e.g. for 'PeakListPath', 'LocalDatabasePath' etc.). These paths must exist inside"
  echo "the Docker container. Additional mounts (-v) might be required."
  echo ""
  echo "The run script in the Docker container will copy the parameter files and overwrite some settings such as 'MetFragCandidateWriter'."
  echo "This is necessary as the ranking function needs a particular format. The original parameters mounted in the container won't be "
  echo "modified."
  echo
  echo "Syntax: docker run -v 'PARAMETERFOLDER':'TARGET' metfragrank [-h] [-p TARGET]"
  echo "options:"
  echo "p     set absolute path to root folder containing a 'parameters' directory with MetFrag parameter files"
  echo "t     number of parameter files to process in parallel (default: 1)"
  echo "h     print this help"
  echo
}

#######
#
# Process MetFrag parameter file with MetFragCLI
#
run_metfrag () {
  parameter_file=$1
  echo "processing $(basename -- ${parameter_file})"
  java -jar MetFragCommandLine.jar \
	  "${parameter_file}" >> /dev/null
}

export -f run_metfrag

#######
#
# Calculate rank of MetFrag result file
#
#  rank_metfrag 'RESULT_FILE' 'INCHIKEY' 'RANKINGS_FOLDER' 'RANKINGS_SCORES'
#
# Example:
#
#  rank_metfrag "/metfrag/results/metfrag_result.csv" "BSYNRYMUTXBXSQ-UHFFFAOYSA-N" "/metfrag/rankings"
#
rank_metfrag () {
  result_file=$1
  inchikey=$2
  rankings_folder=$3
  #
  [ ! -f "${result_file}" ] && echo "result file ${result_file} not found. file will be skipped." && return 1
  [ ! -d "${rankings_folder}" ] && echo "rankings directory ${rankings_folder} not found" && return 1
  inchikey_1=$(echo $inchikey | cut -d"-" -f1)
  ranking_file=$(basename ${result_file} | sed "s/.csv$//").txt
  # calculate rank
  java -cp MetFragTools.jar:MetFragCommandLine.jar \
	  de.ipbhalle.metfrag.ranking.GetRankOfCandidateCSV \
	  "${result_file}" \
	  InChIKey1=${inchikey_1} \
	  Score=1.0 > "${rankings_folder}/${ranking_file}"
}

export -f rank_metfrag

#######
#
# Prepare and process a single parameter file
#
process_single_parameter_file () {
  parameter_file=$1
  root_folder=$2
  # add sample name to parameter file
  filename=$(basename -- "${parameter_file}")
  extension="${filename##*.}"
  sample_name=$(echo ${filename} | sed "s/\.${extension}$//")
  echo "SampleName = ${sample_name}" | tee -a "${parameter_file}" > /dev/null
  # get and check InChIKey
  inchikey=$(grep -e "#\s*InChIKey\s*=" "${parameter_file}" | sed "s/.*=\s*//")
  [ -z "${inchikey}" ] && echo "parameter file ${filename} contains no valid '# InChIKey = ' line. file will be skipped." && continue
  # process file
  starting_time=$(date +%s)
  run_metfrag "${parameter_file}"
  if [ "$?" -eq "0" ]; then
    rank_metfrag "${root_folder}/results/${sample_name}.csv" "${inchikey}" "${root_folder}/rankings"
    ending_time=$(date +%s)
    echo "processing $(basename -- ${parameter_file}) finished in $(echo "${ending_time} - ${starting_time}" | bc) s"
  else
    echo "parameter file ${filename} could not be processed correctly"
  fi
}

export -f process_single_parameter_file

#######
#
# Calculates ranking summary for a set of rankings files
#
calculate_rankings_summary () {
  rankings_folder=$1
  [ ! -d "${rankings_folder}" ] && echo "rankings directory ${rankings_folder} not found in" && return 1
  # count ranking files
  number_files=$(ls "${rankings_folder}" | wc -l)
  [ "${number_files}" -eq "0" ] && echo "No rankings files found in ${rankings_folder} directory." && exit 1
  # count ranking files for which inchi key has not been found
  inchikey_not_found=$(head -n 1 ${rankings_folder}/* | grep -c "not found in")
  number_files_used_for_ranking=$(expr ${number_files} - ${inchikey_not_found})
  echo "Number files: ${number_files}"
  echo "Number files missing correct candidate: ${inchikey_not_found}"
  echo "Number files used for ranking: ${number_files_used_for_ranking}"
  if [ "${number_files}" -eq "${inchikey_not_found}" ]; then
    echo "Top1:  NA"
    echo "Top5:  NA"
    echo "Top10: NA"
    echo "Mean:  NA"
  else
    echo "Top1:  $(grep -L 'not found in' ${rankings_folder}/* | xargs cut -d " " -f3 | grep -c -E '^1$')"
    echo "Top5:  $(grep -L 'not found in' ${rankings_folder}/* | xargs cut -d " " -f3 | grep -c -E '^1$|^2$|^3$|^4$|^5$')"
    echo "Top10: $(grep -L 'not found in' ${rankings_folder}/* | xargs cut -d " " -f3 | grep -c -E '^1$|^2$|^3$|^4$|^5$|^6$|^7$|^8$|^9$|^10$')"
    echo "Mean:  $(echo "($(grep -L 'not found in' ${rankings_folder}/* | xargs cut -d " " -f3 | paste -sd+ | bc))/${number_files_used_for_ranking}" | bc)"
  fi
}

#######
#
# Process parameters in 'parameters folder'
#
process_parameters () {
  root_folder=$(echo $1 | sed 's/\/\s*$//')
  threads=$2
  # some checks
  [ ! -d "${root_folder}" ] && echo "The directory ${root_folder} was not found inside the Docker container." && exit 1
  [ ! -d "${root_folder}/parameters" ] && echo "No 'parameters' directory found inside ${root_folder} directory." && exit 1
  [ -n "$(find ${root_folder}/parameters -prune -empty 2>/dev/null)" ] && echo "No parameter files found in ${root_folder}/parameters directory." && exit 1
  [ -d "${root_folder}/results" ] && echo "Found a 'results' directory in ${root_folder} directory. Please remove it." && exit 1
  [ -d "${root_folder}/rankings" ] && echo "Found a 'rankings' directory in ${root_folder} directory. Please remove it." && exit 1
  echo "$(find "${root_folder}/parameters" -maxdepth 1 -type f | wc -l) parameter file(s) will be processed"
  mkdir "${root_folder}/results" "${root_folder}/rankings"
  # copy parameters
  [ -d /tmp/parameters ] && rm -r /tmp/parameters
  cp -r ${root_folder}/parameters /tmp
  # remove parameters that will be set afterwards
  sed -i '/^ResultsPath\s*=/d' /tmp/parameters/*
  sed -i '/^MetFragCandidateWriter\s*=/d' /tmp/parameters/*
  sed -i "/^SampleName\s*=/d" /tmp/parameters/*
  sed -i "/^NumberThreads\s*=/d" /tmp/parameters/*
  # add parameters
  echo "ResultsPath = ${root_folder}/results" | tee -a /tmp/parameters/* > /dev/null
  echo "MetFragCandidateWriter = CSV" | tee -a /tmp/parameters/* > /dev/null
  echo "NumberThreads = 1" | tee -a /tmp/parameters/* > /dev/null
  # process parameter files
  find /tmp/parameters/ -maxdepth 1 -type f | parallel -I% -u --max-args 1 -j "${threads}" process_single_parameter_file % "${root_folder}"
  # calculate ranking summary
  calculate_rankings_summary "${root_folder}/rankings"
}

folder=""
number_threads=1
while getopts ':hp:t:' option; do
  case "$option" in
    h) print_help
       exit
       ;;
    p) folder="${OPTARG}"
       ;;
    t) number_threads="${OPTARG}"
       ;;
    :) printf "missing argument for -%s\n\n" "${OPTARG}" >&2
       print_help >&2
       exit 1
       ;;
   \?) printf "illegal option: -%s\n\n" "${OPTARG}" >&2
       print_help >&2
       exit 1
       ;;
  esac
done

if [ $OPTIND -eq 1 ]; then
	printf "missing option\n\n"
	print_help >&2;
fi

[ -z ${folder} ] && echo "No directory defined" && exit 1

! [[ "${number_threads}" =~ ^[0-9]+$ ]] && "Parameter for '-t' is not a number" && exit 1
[ "1" -gt "${number_threads}" ] && "Parameter for '-t' must be greater than zero"

export SHELL=$(type -p bash)

process_parameters "${folder}" "${number_threads}"
