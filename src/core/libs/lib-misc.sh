#!/bin/bash


# run a process in the background, and log it's stdout and stderr to a specific logfile
# returncode is stored in $<identifier>_exitcode
# $1 identifier
# $2 command (will be eval'ed)
# $3 logfile
run_background ()
{
	[ -z "$1" ] && die_error "run_background: please specify an identifier to keep track of the command!"
	[ -z "$2" ] && die_error "run_background needs a command to execute!"
	[ -z "$3" ] && die_error "run_background needs a logfile to redirect output to!"

	debug 'MISC' "run_background called. identifier: $1, command: $2, logfile: $3"
	( \
		touch $RUNTIME_DIR/aif-$1-running
		debug 'MISC' "run_background starting $1: $2 >>$3 2>&1"
		[ -f $3 ] && echo -e "\n\n\n" >>$3
		echo "STARTING $1 . Executing $2 >>$3 2>&1\n" >> $3;
		var_exit=${1}_exitcode
		eval "$2" >>$3 2>&1
		read $var_exit <<< $? #TODO: bash complains about 'not a valid identifier'
		debug 'MISC' "run_background done with $1: exitcode (\$$1_exitcode): ${!var_exit} .Logfile $3" #TODO ${!var_exit} doesn't show anything --> maybe fixed now
		echo >> $3   
		rm -f $RUNTIME_DIR/aif-$1-running
	) &

	sleep 2
}


# wait until a process is done
# $1 identifier
wait_for ()
{
	[ -z "$1" ] && die_error "wait_for needs an identifier to known on which command to wait!"

	while [ -f $RUNTIME_DIR/aif-$1-running ]
	do
		#TODO: follow_progress dialog mode = nonblocking (so check and sleep is good), cli mode (tail -f )= blocking? (so check is probably not needed as it will be done)
		sleep 1
	done

	kill $(cat $ANSWER) #TODO: this may not work when mode = cli
}


# $1 set (array) haystack
# $2 needle
check_is_in ()
{
	[ -z "$1" ] && debug 'MISC' "check_is_in $1 $2" && die_error "check_is_in needs a non-empty needle as \$2 and a haystack as \$1!" # haystack can be empty though

	local pattern="$1" element
	shift
	for element
	do
		[[ $element = $pattern ]] && return 0
	done
	return 1
}


# cleans up file in the runtime directory who can be deleted, make dir first if needed
cleanup_runtime ()
{
	mkdir -p $RUNTIME_DIR || die_error "Cannot create $RUNTIME_DIR"
	rm -rf $RUNTIME_DIR/aif-dia* &>/dev/null
}


dohwclock() {
	infofy "Syncing hardwareclock to systemclock ..."
	if [ "$HARDWARECLOCK" = "UTC" ]; then
		HWCLOCK_PARAMS="$HWCLOCK_PARAMS --utc"
	else
		HWCLOCK_PARAMS="$HWCLOCK_PARAMS --localtime"
	fi

	[ ! -d /var/lib/hwclock ] && mkdir -p /var/lib/hwclock
	if [ ! -f /var/lib/hwclock/adjtime ]; then
		echo "0.0 0 0.0" > /var/lib/hwclock/adjtime # what the hell is this for???
	fi
	hwclock $HWCLOCK_PARAMS #tpowa does it without, but i would add --noadjtime here
}

