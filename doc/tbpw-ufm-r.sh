#!/bin/bash
SUT_IPMI_IP=$1 ##"10.1.51.1"
IPMI_CMD="ipmitool -I lanplus -H $SUT_IPMI_IP -U ADMIN -P ADMIN i2c bus=6 "	# Linus: Bus=6, 0x86 removed, 0x80 --> 0x64 
JED_SOURCE=$2

rm JED_EXTRACT.tmp temp.txt CFG_flash.log *.hex

##function
function countdown()
{
  input=$1
  while [ 1 -ne $input ];
  do
    echo -ne " $input \r"
    let input-=1
    sleep 1
  done
}

##Check parameter
if [ $# -ne 2 ]
then
	echo "Command usage: ./BPNIO_CPLD_update.sh IPMI_IP CPLD_JED"
	exit 1
fi

##Check power status
ipmitool -I lanplus -H $SUT_IPMI_IP -U ADMIN -P ADMIN power status 
#if [ $? -ne 0 ] ; then
#	echo "System should be OFF when accessing CPLD flash"
#	exit
#fi

##Get CPLD Device ID
# $IPMI_CMD 0x86 1 0x3c		# Linus Disable
$IPMI_CMD 0x64 0 0x70 0x26	> /dev/null
sleep 0.1
$IPMI_CMD 0x64 0 0x71 0xE0 0x0 	> /dev/null
$IPMI_CMD 0x64 0 0x71 0x00 0x0 	> /dev/null
echo "****************"
echo "*CPLD Device ID*"
echo "****************"
DEVICE_ID=$($IPMI_CMD 0x64 4 0x73 | head -n1)
$IPMI_CMD 0x64 0 0x70 0xA6 > /dev/null
echo "$DEVICE_ID"
if [ "$DEVICE_ID" == " 01 2b a0 43" ] 
then
	echo "CPLD is XO2-1200"
	grep -rnw $JED_SOURCE -e "LCMXO2-1200HC" > /dev/null
	if [ $? -ne 0 ] 
	then
		echo "$JED_SOURCE is NOT for XO2-1200!!!"
		exit 1
	else
		echo "Device and JED match."
		let stx_count=2;
		let end_count=4;
	fi
elif [ "$DEVICE_ID" == " 01 2b 90 43" ] 
then
	echo "CPLD is XO2-640"
	grep -rnw $JED_SOURCE -e "LCMXO2-640HC" > /dev/null
	if [ $? -ne 0 ] 
	then
		echo "$JED_SOURCE is NOT for XO2-640!!!"
		exit 1
	else
		echo "Device and JED match."
		let stx_count=2;
		let end_count=3;
	fi
elif [ "$DEVICE_ID" == " 61 2b b0 43" ] 
then
	echo "CPLD is XO3LF-2100C"
	grep -rnw $JED_SOURCE -e "LCMXO3LF-2100C" > /dev/null
	if [ $? -ne 0 ] 
	then
		echo "$JED_SOURCE is NOT for LCMXO3LF-2100C!!!"
		exit 1
	else
		echo "Device and JED match."
		let stx_count=2;
		let end_count=4;
	fi	
else
	echo "Device Not Recognize!!!"
#	exit 1
fi


	echo "***************************************"
	echo "* Linus: SKIP Program, and Read check *"
	echo "***************************************"

if false; then		## Linus: To Disable Programming


##Reading JED, convert to HEX format
HEX_SOURCE="$JED_SOURCE.hex"
[ -f $HEX_SOURCE ] > /dev/null 
if [ $? -ne 0 ] 
then
	JED_EXTRACT="JED_EXTRACT.tmp"

	##Remove existing extrat temp files
	[ -f $JED_EXTRACT ] > /dev/null 
	if [ $? == 0 ] 
	then
		rm -f $JED_EXTRACT
	fi

	##Get config data size
	let JED_CONF_STX=$(grep -rnw $JED_SOURCE -e "L000000" | head -c $stx_count)+1
	let JED_CONF_END=$(grep -rnw $JED_SOURCE -e "NOTE END CONFIG DATA" | head -c $end_count )-2
	let JED_PAGE=$JED_CONF_END-$JED_CONF_STX+1

	echo "************************************"
	echo "* Converting Binary JED to HEX JED *"
	echo "************************************"
	echo "JED Config DATA Start Line: $JED_CONF_STX"
	echo "JED Config DATA End Line: $JED_CONF_END"

	##Extract config data from JED
	echo "JED Total Page" 2>&1 | tee -a $JED_EXTRACT 
	echo "$JED_PAGE" 2>&1 | tee -a $JED_EXTRACT
	head -n $JED_CONF_END $JED_SOURCE | tail -n $JED_PAGE >> $JED_EXTRACT

	pcount=1
	for flash_page in $(tail -n $JED_PAGE $JED_EXTRACT)
	do
	  rm -f temp.txt
	  echo "$flash_page" > temp.txt
	  for i in $(seq 1 16)
	  do
		let count=i*8
		line=$(head -c $count temp.txt | tail -c 8)
		printf '0x%.2x ' "$((2#$line))" >> $HEX_SOURCE
	  done

	  printf '\n' >> $HEX_SOURCE
	  echo -ne "extracting page $pcount\r"
	  let pcount=pcount+1
	done
	echo "Done! HEX file $HEX_SOURCE"
	
#	rm $JED_EXTRACT		# Linus: Disable
	sleep 2
	clear
else
	echo "$HEX_SOURCE found, using for updating directly."
fi

FLASH_PAGE=$(wc -l < $HEX_SOURCE)

##Flash operation
run_start=$(date +%s)
RERUN=1
SYS_ON=0

while [ "$RERUN" == "1" ] 
do


	echo "***********************"
	echo "* Enable Flash Access *"
	echo "***********************"
#    $IPMI_CMD 0x86 1 0x3c	# Linus: Disable
	$IPMI_CMD 0x64 0 0x70 0x26 > /dev/null
	$IPMI_CMD 0x64 0 0x71 0x74 0x8 0x0 0x0 > /dev/null
	$IPMI_CMD 0x64 0 0x70 0xA6 > /dev/null

	echo "*******************"
	echo "* Erase CFG Flash *"
	echo "*******************"
	$IPMI_CMD 0x64 0 0x70 0x26 > /dev/null
	$IPMI_CMD 0x64 0 0x71 0x0E 0x4 0x0 0x0 > /dev/null
	$IPMI_CMD 0x64 0 0x70 0xA6 > /dev/null
	echo "Waiting for erase to complete ..."
	countdown 5

	echo "*********************"
	echo "* Set to CFG page 0 *"
	echo "*********************"
	$IPMI_CMD 0x64 0 0x70 0x26 > /dev/null
	$IPMI_CMD 0x64 0 0x71 0x46 0x0 0x0 0x0 > /dev/null
	$IPMI_CMD 0x64 0 0x70 0xA6 > /dev/null

	echo "******************"
	echo "* Write CFG Data *"
	echo "******************"
	echo "JED total page: $FLASH_PAGE"
	i=1
	for i in $(seq 1 $FLASH_PAGE)
	do
	  data=$(head -n $i $HEX_SOURCE | tail -n 1)
	  $IPMI_CMD 0x64 0 0x70 0x26 > /dev/null
	  $IPMI_CMD 0x64 0 0x71 0x70 0x0 0x0 0x1 $data > /dev/null
	  $IPMI_CMD 0x64 0 0x70 0xA6 > /dev/null
	  echo -ne "Writing page $i\r"
	  sleep 0.001
	  let i=i+1      
	done

	echo "**************************"
	echo "* Set CFG Flash DONE bit *"
	echo "**************************"
	$IPMI_CMD 0x64 0 0x70 0x26 > /dev/null
	$IPMI_CMD 0x64 0 0x71 0x5E 0x0 0x0 0x0 > /dev/null
	$IPMI_CMD 0x64 0 0x70 0xA6 > /dev/null
	
	echo "************************"
	echo "* Disable Flash Access *"
	echo "************************"
	$IPMI_CMD 0x64 0 0x70 0x26 > /dev/null
	$IPMI_CMD 0x64 0 0x71 0x26 0x0 0x0 0xff > /dev/null
	$IPMI_CMD 0x64 0 0x70 0xA6 > /dev/null

   
	echo "*****************"
	echo "* Checking CFG  *"
	echo "*****************"

	##Deleting old log file before comparing
	CFG_FLASH_LOG="CFG_flash.log"
	[ -f $CFG_FLASH_LOG ] > /dev/null 
	if [ $? == 0 ] 
	then
		rm -f $CFG_FLASH_LOG
	fi

	##Check Flash
	$IPMI_CMD 0x64 0 0x70 0x26 > /dev/null
	$IPMI_CMD 0x64 0 0x71 0x74 0x8 0x0 0x0 > /dev/null
	$IPMI_CMD 0x64 0 0x70 0xA6> /dev/null

	$IPMI_CMD 0x64 0 0x70 0x26 > /dev/null
	$IPMI_CMD 0x64 0 0x71 0xB4 0x0 0x0 0x0 0x0 0x0 0x0 0x0 > /dev/null
	$IPMI_CMD 0x64 0 0x70 0xA6 > /dev/null

	echo "CFG Total Config Page: $FLASH_PAGE" 
	$IPMI_CMD 0x64 0 0x70 0x26 > /dev/null
	$IPMI_CMD 0x64 0 0x71 0x73 0x10 0x20 > /dev/null
	$IPMI_CMD 0x64 16 0x73 > /dev/null ##extra line, ignore
	cfg_count=1
	for cfg_count in $(seq 1 $FLASH_PAGE)		
	do
		$IPMI_CMD 0x64 16 0x73 >> $CFG_FLASH_LOG
		echo -ne "Reading page $cfg_count\r"
	done
	$IPMI_CMD 0x64 0 0x70 0xA6 > /dev/null

	$IPMI_CMD 0x64 0 0x70 0x26 > /dev/null
	$IPMI_CMD 0x64 0 0x71 0x26 0x0 0x0 0xff > /dev/null
	$IPMI_CMD 0x64 0 0x70 0xA6 > /dev/null
#    $IPMI_CMD 0x86 0 0x3C 0x80 > /dev/null	# Linus: Disable

	##Deleting old tmp file before comparing
	[ -f temp1.tmp ] > /dev/null 
	if [ $? == 0 ] 
	then
		rm -f temp1.tmp
	fi

	cat $HEX_SOURCE | sed 's/0x//g' > temp1.tmp
	echo "Comparing CFG with JED"
	diff -qw CFG_flash.log temp1.tmp > /dev/null

	CFG_COMP=$?
	if [ "$CFG_COMP" -ne "0" ] ; then
		echo "Mismatch found!!!"
		echo "Re-start programming process in 5 seconds ..."
		#rm temp1.tmp
		let RERUN=1
		countdown 5
		clear
		let RERUN=0	# Linus: Add
	else
		echo "Match and contiue ..."
		echo ""
#		rm $CFG_FLASH_LOG
#		rm temp1.tmp
		echo "****************"
		echo "* CPLD REFRESH *"
		echo "****************"
		$IPMI_CMD 0x64 0 0x70 0x26 		> /dev/null
		$IPMI_CMD 0x64 0 0x71 0x79 0x0 0x0 	> /dev/null	# Linus: NAK
		$IPMI_CMD 0x64 0 0x70 0xA6 		> /dev/null
		echo "CPLD updating process complete."
				
		let RERUN=0
	fi
	
	run_end=$(date +%s)
	run_time=$(( $run_end - $run_start ))
	echo "CFG update done!!! Total running $run_time seconds."	

done  ## end of RERUN while loop 

fi	## Linus: End of skipping programming 


	echo "********************"
	echo "* Linus: READ UFM  *"
	echo "********************"

	echo "***********************"
	echo "* Enable Flash Access *"
	echo "***********************"
	$IPMI_CMD 0x64 0 0x70 0x26 > /dev/null
	$IPMI_CMD 0x64 0 0x71 0x74 0x8 0x0 0x0 > /dev/null
	$IPMI_CMD 0x64 0 0x70 0xA6 > /dev/null


	echo "***********************"
	echo "* READ UFM 16Bytes x4 *"
	echo "***********************"
	$IPMI_CMD 0x64 0 0x70 0x26 > /dev/null
	$IPMI_CMD 0x64 0 0x71 0xB4 0x0 0x0 0x0 0x40 0x0 0x0 0x0 > /dev/null
	$IPMI_CMD 0x64 0 0x70 0xA6 > /dev/null

	$IPMI_CMD 0x64 0 0x70 0x26 > /dev/null
	$IPMI_CMD 0x64 0 0x71 0xCA 0x10 0x3F 0xFF > /dev/null
	$IPMI_CMD 0x64 16 0x73 
	$IPMI_CMD 0x64 16 0x73 
	$IPMI_CMD 0x64 16 0x73 
	$IPMI_CMD 0x64 16 0x73 
	$IPMI_CMD 0x64 16 0x73 
	$IPMI_CMD 0x64 0 0x70 0xA6 > /dev/null
	
	echo "************************"
	echo "* Disable Flash Access *"
	echo "************************"
	$IPMI_CMD 0x64 0 0x70 0x26 > /dev/null
	$IPMI_CMD 0x64 0 0x71 0x26 0x0 0x0 0xff > /dev/null
	$IPMI_CMD 0x64 0 0x70 0xA6 > /dev/null



