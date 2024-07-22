#!/usr/bin/env bash

SCRIPTNAME=$0
function usage() {
	echo "usage: $SCRIPTNAME [-h] [--duration DURATION] [--tool TOOL] [--dumptype DUMPTYPE]"
	echo "  -h | --help   display this help message"
	echo "  --tool        <dotnet-trace|dotnet-dump> Required."
	echo "  --duration    specified for trace. In minutes, 00 to 59. Defaults to 05."
	echo "  --dumptype    <Full|Heap|Mini|Triage> Only specified for dotnet-dump. Defaults to Full"
}

# This block canonicalizes user-provided command line options and exits the
# script if they supplied something unrecognized (e.g --somethingdumb)
VALIDARGS=$(getopt -o h --long help,duration:,tool:,dumptype: \
	-n "decisions_dotnet_tool.sh" -- "$@")
if [ $? != 0 ]; then
	echo "Invalid arguments / options,see ${SCRIPTNAME} -h for help.." >&2
	exit 1
fi
eval set -- "$VALIDARGS"

# Set defaults
DURATION="05"
DUMPTYPE="Full"

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
	--tool)
		TOOL="$2"
		shift 2
		;;
	--dumptype)
		DUMPTYPE="$2"
		shift 2
		;;
	--)
		shift
		break
		;;
	*) break ;;
	esac
done

case "${DUMPTYPE}" in
Full | Heap | Mini | Triage) ;;
*)
	echo "Invalid dumptype ${DUMPTYPE} specified, exiting.." >&2
	exit 1
	;;
esac

case "${TOOL}" in
dotnet-trace | dotnet-dump) ;;
'')
	usage
	exit 1
	;;
*)
	echo "Invalid tool ${TOOL} specified, exiting.." >&2
	exit 1
	;;
esac

if ! [[ "$DURATION" =~ ^[0-5][0-9]$ ]]; then
	echo "Invalid duration ${DURATION}. Please specify a number 01-59." >&2
	echo "Exiting.." >&2
	exit 1
fi

# This might fail if container can't connect to the internet.
if [[ ! -f /root/.dotnet/tools/${TOOL} ]]; then
	echo "Attempting to install ${TOOL}.."
	dotnet tool install --global "${TOOL}" >/dev/null || {
		echo "failed to install ${TOOL}"
		exit 2
	}
	echo "Install successful!"
fi

mkdir -p "${DECISIONS_FILESTORAGELOCATION}/dotnet/${TOOL}-data"

case "${TOOL}" in
dotnet-trace)
	/root/.dotnet/tools/"${TOOL}" collect \
		--process-id 1 \
		--profile "cpu-sampling" \
		--output "${DECISIONS_FILESTORAGELOCATION}/dotnet/${TOOL}-data/$(date +"%Y-%m-%d_%H.%M.%S").nettrace" \
		--duration 00:00:"${DURATION}":00
	;;
dotnet-dump)
	/root/.dotnet/tools/"${TOOL}" collect \
		--process-id 1 \
		--type "${DUMPTYPE}" \
		--output "${DECISIONS_FILESTORAGELOCATION}/dotnet/${TOOL}-data/$(date +"%Y-%m-%d_%H.%M.%S").nettrace"
	;;
*) exit 1 ;;
esac
