#!/usr/bin/env bash

# To be used later in output statements

RED="\e[31m"
GREEN="\e[32m"
BLUE="\e[34m"
YELLOW="\e[33m"
NC="\e[0m" # NC for "No Color"

SCRIPTNAME=$0
function usage() {
	echo -e
	echo -e "${GREEN}USAGE${NC}"
	echo -e "${BLUE}  $SCRIPTNAME [tool]${NC}"
	echo -e
	echo -e "${GREEN}ARGUMENTS${NC}"
	echo -e "${BLUE}  [tool]${NC}"
	echo -e "${BLUE}  required. either of <dotnet-dump|dotnet-trace>${NC}"
	echo -e
	echo -e "${GREEN}OPTIONS${NC}"
	echo -e "${BLUE}  -h | --help   display this help message${NC}"
	echo -e "${BLUE}  --duration    specified for trace. In minutes, 00 to 59. Defaults to 05.${NC}"
	echo -e "${BLUE}  --output      absolute path to output directory. must exist.${NC}"
	echo -e "${BLUE}  --pid     the PID of the process to trace / memory dump. Defaults to 1${NC}"
	echo -e "${BLUE}  --dumptype    <Full|Heap|Mini|Triage> Only specified for dotnet-dump. Defaults to Full${NC}"
}

# This block canonicalizes user-provided command line options and exits the
# script if they supplied something unrecognized (e.g --somethingdumb)
VALIDARGS=$(getopt -o h --long help,duration:,dumptype:,output:,pid: \
	-n "decisions_dotnet_tool.sh" -- "$@")
if [ $? != 0 ]; then
	echo -e "\n${RED}Invalid arguments / options,see ${SCRIPTNAME} -h for help..${NC}" >&2
	exit 1
fi
eval set -- "$VALIDARGS"

# Set defaults
DURATION="05"
DUMPTYPE="Full"
OUTPUT="${DECISIONS_FILESTORAGELOCATION}"
# Fallback to /tmp if FILESTORAGELOCATION not set
if [[ -z "${DECISIONS_FILESTORAGELOCATION}" ]]; then
	OUTPUT="/tmp"
fi

# Parse canonicalized options and set corresponding script variables.
while true; do
	case "$1" in
	-h | --help)
		usage
		exit 1
		;;
	--duration)
		DURATION="$2"
		shift 2
		;;
	--dumptype)
		DUMPTYPE="$2"
		shift 2
		;;
	--output)
		OUTPUT="$2"
		shift 2
		;;
	--pid)
		PID="$2"
		shift 2
		;;
	--)
		shift
		break
		;;
	*) break ;;
	esac
done

TOOL=$1

case "${DUMPTYPE}" in
Full | Heap | Mini | Triage) ;;
*)
	echo -e "\n${RED}Invalid dumptype ${DUMPTYPE} specified, exiting..${NC}" >&2
	exit 1
	;;
esac

case "${TOOL}" in
dotnet-trace | dotnet-dump) ;;
'')
	echo -e "\n${RED}No tool specified. Exiting...${NC}" >&2
	exit 1
	;;
*)
	echo -e "\n${RED}Invalid tool ${TOOL} specified, exiting..${NC}" >&2
	exit 1
	;;
esac

if ! [[ "$DURATION" =~ ^[0-5][0-9]$ ]]; then
	echo -e "\n${RED}Invalid duration ${DURATION}. Please specify a number 01-59.${NC}" >&2
	echo -e "  ${RED}Exiting..${NC}" >&2
	exit 1
fi

# Used ls /proc strategy here because `procps` isn't installed on our
# containers by default so can't rely on `pgrep`.
if ! ls /proc/*/exe | grep -e "/proc/${PID}/"; then
	echo -e "${RED}ERROR: PID ${PID} was not found.${NC}"
	echo -e "${RED}Possibly you forgot to set this with --pid flag and script used default value.${NC}"
	exit 1
fi

# This might fail if container can't connect to the internet.
if [[ ! -f /root/.dotnet/tools/${TOOL} ]]; then
	echo -e "\n${YELLOW}Attempting to install ${TOOL}..${NC}"
	dotnet tool install --global "${TOOL}" >/dev/null || {
		echo -e "  ${RED}failed to install ${TOOL}${NC}. Exiting..." >&2
		exit 2
	}
	echo -e "${GREEN}Install successful!${NC}"
else
	echo -e "\n${GREEN}${TOOL} already installed, proceeding..${NC}"
fi

if [[ ! -d "${OUTPUT}" ]]; then
	echo -e "${RED}Specified output directory ${OUTPUT} does not exist.${NC}. Exiting..." >&2
	exit 2
fi

mkdir -p "${OUTPUT}/dotnet/${TOOL}-data"
OUTFILE="${OUTPUT}/dotnet/${TOOL}-data/$(date +"%Y-%m-%d_%H.%M.%S")"

case "${TOOL}" in
dotnet-trace)
	echo -e "\n${YELLOW}Beginning trace for ${DURATION} minutes..${NC}"
	echo -e "  ${BLUE}Note: pressing <ENTER> or <CTRL-C> will end the trace early."
	/root/.dotnet/tools/"${TOOL}" collect \
		--process-id "${PID}" \
		--profile "cpu-sampling" \
		--output "${OUTFILE}.nettrace" \
		--duration 00:00:"${DURATION}":00 &>/dev/null
	echo -e "\n${GREEN}Trace complete!${NC}"
	echo -e "  ${GREEN}Wrote output to ${OUTFILE}.nettrace${NC}"
	echo "---"
	;;
dotnet-dump)
	echo -e "\n${YELLOW}Writing dump...${NC}"
	/root/.dotnet/tools/"${TOOL}" collect \
		--process-id ${PID} \
		--type "${DUMPTYPE}" \
		--output "${OUTFILE}" \
		&>/dev/null
	echo -e "\n${GREEN}Dump complete!${NC}"
	echo -e "  ${GREEN}Wrote output to ${OUTFILE}${NC}"
	echo "---"
	;;
*) exit 1 ;;
esac
