#!/bin/bash

# Exit immediately if a pipeline, which may consist of a single simple command, a list,
#or a compound command returns a non-zero status: If errors are not handled by user
set -e
#set -x

#=============================================================
# HEADER
#=============================================================

#INSTITUTION:ISCIII
#CENTRE:BU-ISCIII
#AUTHOR: Pedro J. Sola
VERSION=1.0
#CREATED: 13 April 2018
#REVISION:
#DESCRIPTION:build_karyotype script that creates karyotype file for CIRCOS either for summary and individual image

#================================================================
# END_OF_HEADER
#================================================================

#SHORT USAGE RULES
#LONG USAGE FUNCTION
usage() {
	cat << EOF

build_karyotype script that creates karyotype file for CIRCOS either for summary and individual image

usage : $0 <-i inputfile(coverage)> [-o <directory>] [-f <file_name>] [-g <group_name>] <-k int(0-100)> <-K int(0-100)> [-v] [-h]

	-i input file
	-o output directory (optional). By default the file is replaced in the same location
	-f file name for identification
	-g group name for identification
	-R Reconstruct
	-K percentage value to display plasmids covered >= in summary image
	-k percentage value to display plasmids covered >= in individual image
	-v version
	-h display usage message

example: build_karyotype.sh -i ecoli.coverage -K 80 -k 50

EOF
}

#================================================================
# OPTION_PROCESSING
#================================================================
#Make sure the script is executed with arguments
if [ $# = 0 ] ; then
 usage >&2
 exit 1
fi


# Error handling
error(){
  local parent_lineno="$1"
  local script="$2"
  local message="$3"
  local code="${4:-1}"

	RED='\033[0;31m'
	NC='\033[0m'

  if [[ -n "$message" ]] ; then
    echo -e "\n---------------------------------------\n"
    echo -e "${RED}ERROR${NC} in Script $script on or near line ${parent_lineno}; exiting with status ${code}"
    echo -e "MESSAGE:\n"
    echo -e "$message"
    echo -e "\n---------------------------------------\n"
  else
    echo -e "\n---------------------------------------\n"
    echo -e "${RED}ERROR${NC} in Script $script on or near line ${parent_lineno}; exiting with status ${code}"
    echo -e "\n---------------------------------------\n"
  fi

  exit "${code}"
}

#DECLARE FLAGS AND VARIABLES
cwd="$(pwd)"
input_file="Input_file"
coverage_cutoff_input=100
reconstruct=false

#PARSE VARIABLE ARGUMENTS WITH getops
#common example with letters, for long options check longopts2getopts.sh
options=":i:o:f:g:K:k:Rvh"
while getopts $options opt; do
	case $opt in
		i )
			input_file=$OPTARG
			;;
		o )
			output_dir=$OPTARG
			;;
		f ) file_name=$OPTARG
			;;
		g ) group_name=$OPTARG
			;;
		R ) reconstruct=true
			;;
		K )
			if [ $OPTARG -lt 0 ] || [ $OPTARG -gt 100 ]; then
				echo "please, provide a summary percentage between 0 and 100"
				usage
				exit 1
			else
				coverage_cutoff_summary_percentage=$OPTARG
			fi
			;;
		k )
			if [ $OPTARG -lt 0 ] || [ $OPTARG -gt 100 ]; then
				echo "please, provide an individual percentage between 0 and 100"
				usage
				exit 1
			else
				coverage_cutoff_individual_percentage=$OPTARG
			fi
			;;
		h )
		  	usage
		  	exit 1
		  	;;
		v )
		  	echo $VERSION
		  	exit 1
		  	;;
		\?)
			echo "Invalid Option: -$OPTARG" 1>&2
			usage
			exit 1
			;;
		: )
      		echo "Option -$OPTARG requires an argument." >&2
      		exit 1
      		;;
      	* )
			echo "Unimplemented option: -$OPTARG" >&2;
			exit 1
			;;

	esac
done
shift $((OPTIND-1))

#================================================================
# MAIN_BODY
#================================================================
##CHECK DEPENDENCIES, MANDATORY FIELDS, FOLDERS AND ARGUMENTS

echo -e "\n#Executing" $0 "\n"

check_mandatory_files.sh $input_file

coverage_cutoff_summary=$(echo "(1 - ($coverage_cutoff_summary_percentage/100))" | bc -l)
coverage_cutoff_individual=$(echo "(1 - ($coverage_cutoff_individual_percentage/100))" | bc -l)


if [ ! $output_dir ]; then
	output_dir=$(dirname $input_file)
	#echo "Default output directory is" $output_dir
	mkdir -p $output_dir
else
	#echo "Output directory is" $output_dir
	mkdir -p $output_dir
fi


if [ ! $file_name ]; then
	file_name=$(basename $input_file | cut -d. -f1)
fi

echo "FILE NAME" $file_name

echo "$(date)"
echo "Obtain list of cromosomes (idiogram) for CIRCOS karyotype file"
echo "Generating summary karyotype file with plasmids that mapped more than" $coverage_cutoff_summary_percentage"%"
if [ $reconstruct = true ];then

	awk '{print "chr -", $1, $1, "0", $2, "id="$1}' $input_file \
	>$output_dir/$file_name".karyotype_summary.txt" || error ${LINENO} $(basename $0) "Awk command for karyotype summary in $file_name\".karyotype_summary.txt\" creation. See $output_dir/logs for more information"

	awk '{print "chr -", $1, $1, "0", $2, "id="$1}' $input_file \
	>$output_dir/$file_name".karyotype_individual.txt" || error ${LINENO} $(basename $0) "Awk command for karyotype individual in $file_name\".karyotype_individual.txt\" creation. See $output_dir/logs for more information."

else
	awk '
		{if ($2 == 0 && $5 < '"${coverage_cutoff_summary}"')
			{print "chr -", $1, $1, "0", $4, "id="$1}
		}
		' $input_file \
		> $output_dir/$file_name".karyotype_summary.txt" || error ${LINENO} $(basename $0) "Awk command for karyotype summary in $file_name\".karyotype_summary.txt\" creation. See $output_dir/logs for more information."


	echo "Generating individual karyotype file with plasmids that mapped more than" $coverage_cutoff_individual_percentage"%"

	awk '
		{if ($2 == 0 && $5 < '"${coverage_cutoff_individual}"')
			{print "chr -", $1, $1, "0", $4, "id="$1}
		}
		' $input_file \
		> $output_dir/$file_name".karyotype_individual.txt" || error ${LINENO} $(basename $0) "Awk command for karyotype individual in $file_name\".karyotype_individual.txt\" creation. See $output_dir/logs for more information"

fi

echo "$(date)"
echo "Done Obtain list of cromosomes (idiogram) for CIRCOS karyotype file"
echo "Files can be found at" $output_dir
echo $(cat $output_dir/$file_name".karyotype_summary.txt" | wc -l) "sequences will be displayed on summary image"
echo -e $(cat $output_dir/$file_name".karyotype_individual.txt" | wc -l) "images will be created individually" "\n"
