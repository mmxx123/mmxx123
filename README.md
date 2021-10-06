## git clean>>>
sudo git clean -fdx && git checkout -- .
sudo git reset --hard HEAD

## git fetch remote branch>>
git fetch origin BR_H12AST2600_20210531_001083

## git config>>
git config user.name "maxt"
git commit --amend --author="Maxt <Maxt@supermicro.com.tw>"
git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.ci commit
git config --global alias.st status

## create patch>>
git format-patch -1 -o ../
git diff .... > patch_name

## import patch>>
git am Patch
patch -p1 < Patch
git apply yourcoworkers.diff

## tmux>>
tmux kill-session -t max
tmux new -s max
tmux attach -t max

## master write-read>>
./SMCIPMITool 192.168.0.22 ADMIN ADMIN ipmi raw 06 52 07 80 02 7e  # page 80, read 2 byte, offset 0x7eh
	07>>	0000 0111	> channel=0 (0000) bus id=3=011 private bus=1
	80>>	1000 0000	> slave address=80	read

## compile ipmitool>>
https://github.com/ipmitool/ipmitool/blob/master/INSTALL
autoreconf --install
./bootstrap && ./configure && make && sudo make install

## installed pkg>>
apt list --installed

## i2c utility>>
i2cdetect -ya 2
i2cset -y 2 0x38 0x00 0x45
i2cget -fy 2 0x38 1
i2cset -y 2 0x54 0x00 0x48
i2cdump -f -y 2 0x70

## scp>>
scp -r guest_hw2@10.148.21.5:/home/guest_hw2/max/x12/images/out_kernel.bin /home/maxt/tftpboot/

## check nic selection
cmd 20 c0 70 0c 0
00: dedicated nic
01: shared nic
## set to dedicated nic
cmd 20 c0 70 0c 1 0
## set to failover nic
cmd 20 c0 70 0c 1 2

## nfs>>
showmount -e
vim /etc/export
mount -t nfs -o nolock 10.181.90.67:/home/eric/Work/nfs /tmp/test
mount -t nfs -o nolock 10.181.90.201:/home/maxt /tmp/test/

## dw_HWInfo1 & dw_HWInfo2>>
	0x94,   // PLX2 Temp
	0x12B24500 | TEMPERATURE_SENSOR,
	  1-------	GET_MUX_INFO_MASK
	   2------	GET_PHYSICAL_BUS_NO_MASK
	    B2----	GET_DEVICE_ADDRESS_MASK
		  00--	GET_DATA_ADDRESS_MASK		*I2C OFFSET
		    00	GET_SENSOR_TYPE_MASK
		
	0xA8510000 | (SENSOR_SCAN_INTERVAL_ONE_SECOND * 3),
	  A8------	GET_SOFTWARE_OFFSET_MASK		GET_MUX1_SLAVE_MASK
		51----	GET_SENSOR_MODULE_NUMBER_MASK	GET_MUX1_VALUE_MASK
		  0000	GET_AOC_TYPE_MASK

