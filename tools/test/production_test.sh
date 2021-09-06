#!/bin/bash

red=`tput setaf 1`
green=`tput setaf 2`
reset=`tput sgr0`

IP_ADDR="0"
clear
TOF_TEST=0;
RGB_TEST=0;
ETHERNET_TEST=0;
ETHERNET_USB_TEST=0;
WIFI_TEST=0;

ssh_cmd() {
    local USER=analog
    local CLIENT=$IP_ADDR
    local PASS=analog
    local CMD="$1"

    sshpass -p ${PASS} ssh -q -t -oConnectTimeout=10 -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oCheckHostIP=no "$USER"@"$CLIENT" "$CMD" > /dev/null
}

ssh_cmd_ethernet() {
    local USER=analog
    local CLIENT="$2"
    local PASS=analog
    local CMD="$1"

    sshpass -p ${PASS} ssh -q -t -oConnectTimeout=10 -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oCheckHostIP=no "$USER"@"$CLIENT" "$CMD" 
}

ssh_cmd_with_response()
{
    local USER="analog"
    local CLIENT=$IP_ADDR
    local PASS="analog"
    local CMD="$1"
    sshpass -p ${PASS} ssh -q -t -oConnectTimeout=10 -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oCheckHostIP=no "$USER"@"$CLIENT" "$CMD"
   
}

ssh_cmd_wifi() {
    local USER=analog
    local CLIENT="172.16.1.1"
    local PASS=analog
    local CMD="$1"

    sshpass -p ${PASS} ssh -q -t -oConnectTimeout=10 -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oCheckHostIP=no "$USER"@"$CLIENT" "$CMD"
}

tof_test(){
    echo -e "\nToF camera test ..."
    if ssh_cmd_with_response "./Workspace/aditof_sdk/build/examples/camera-test/camera-test 'depth_only'" | grep -q "Test passed";
    then
        echo -e "${green}ToF camera test successfull! ${reset}"
        TOF_TEST='1'
    else
        echo -e "${red}ToF camera test unsuccessfull ${reset}"
    fi
}

rgb_test(){
    echo -e "\nRGB camera test ...";
    ssh_cmd "echo '1' |  sudo -S tee -a /sys/module/ov2735/parameters/test_mode" 
    ssh_cmd "rm frame.raw"
    VIDEO_PATH=$(ssh_cmd_with_response "v4l2-ctl --list-devices | grep ov2735 -A 2 | sed '1d' | sed 's/^[[:space:]]*//g' | sed '2d' | tr '\n' ' ' ")
    if echo $VIDEO_PATH | grep -q "not found";
    then
        echo -e "${red}\nNo device found for RGB camera!${reset}"
    else
        ssh_cmd "v4l2-ctl --device ${VIDEO_PATH} --stream-mmap=1 --stream-to=frame.raw --stream-count=1"
        if ssh_cmd_with_response "cmp frame.raw reference_frame.raw"
        then
           echo -e "${green}RGB camera test successfull!${reset}"
           RGB_TEST=1;
        else
            echo -e "${red}Wrong obtained image!${reset}";
        fi
    fi
}

ethernet_over_usb_test()
{
    echo -e "\nEthernet over usb test ...";
    pkill iperf3
    ssh_cmd 'pkill iperf3';
    ssh_cmd "iperf3 -s -1 &" & > /dev/null
    echo -e "${green}Results: ${reset}";
    sleep 4;
    if iperf3 -u -c 192.168.55.1 -b 1000M -t 4 | grep Mbits/sec;
    then
        echo -e "${green}End of ethernet test!${reset}";
        ETHERNET_USB_TEST=1;
    else
        echo -e "${red}Problem with connection!${reset}";
    fi
    ssh_cmd 'pkill iperf3';

}

ethernet_test()
{
    echo -e "\nEthernet test ...";
    CAMERA_IP=$(ssh_cmd_with_response "hostname -I | cut -f1 -d' ' | tr '\n' ' ' ");
    if echo -q ${CAMERA_IP} | grep -q "172.16.1.1" 
    then
        echo -e "${red}Not connected to the same LAN network!${reset}"
    else
        ssh_cmd "iperf3 -s -1 &" &

        echo -e "${green}Results: ${reset}";
        sleep 4;
        if iperf3 -u -c $CAMERA_IP -b 1000M -t 4 | grep bits/sec;
        then
            echo -e "${green}End of ethernet test!${reset}";
            ETHERNET_TEST=1;
        else
            echo -e "${red}Problem with connection!${reset}";
        fi
    fi
}

wifi_test()
{
    echo -e "\nWireless connection test ..."
    #nmcli nm wifi on
    nmcli device wifi rescan
    sleep 2;
    if nmcli -a d wifi connect ADI_Smart_Camera password ADI_Smart_Camera | grep "successfully activated";
    then
        ssh_cmd_wifi "iperf3 -s -1 &" &
        echo -e "${green}Results: ${reset}";
        sleep 4;
        if iperf3 -u -c 172.16.1.1 -b 1000M -t 4 | grep Mbits/sec;
        then
            echo -e "${green}End of wireless test!${reset}";
            sleep 2
            IP_ADDR=$(ssh_cmd_wifi "hostname -I | cut -f1 -d' ' | tr '\n' ' ' ")
            IP_ADDR=${IP_ADDR::-1}
            WIFI_TEST=1;
        else
            echo -e "${red}Problem with connection!${reset}";
        fi
        ssh_cmd_wifi 'pkill iperf3';
    else
        sleep 2;
        if nmcli -a d wifi connect ADI_Smart_Camera password ADI_Smart_Camera | grep "successfully activated";
        then
            ssh_cmd_wifi "iperf3 -s -1 &" &
            echo -e "${green}Results: ${reset}";
            sleep 4;
            if iperf3 -u -c 172.16.1.1 -b 1000M -t 4 | grep Mbits/sec;
            then
                echo -e "${green}End of wireless test!${reset}";
                sleep 2
                IP_ADDR=$(ssh_cmd_wifi "hostname -I | cut -f1 -d' ' | tr '\n' ' ' ")
                IP_ADDR=${IP_ADDR::-1}
                WIFI_TEST=1;
            else
                echo -e "${red}Problem with connection!${reset}";
            fi
            ssh_cmd_wifi 'pkill iperf3';
        else
            echo -e "\n${red}Could not connect to the Camera via Wifi!${reset}";
        fi
    fi
    echo $IP_ADDR
}

ping_test()
{
    if ping -c 1 $IP_ADDR &> /dev/null;
    then
        echo -e "${green}Connection successfull! ${reset}"
        successfull_connection
    else
        echo -e "${red}Connection unsuccessfull ${reset}"
    fi
}

successfull_connection() {

    echo -e "After connecting the camera please wait for an extra 40 seconds to start the test, in order to boot every program and start the wifi module\nConnection test ... "
    wifi_test
    if echo "${IP_ADDR}" | grep -q "172.16.1.1"
    then
        echo -e "${red}Camera not on the same LAN network${reset}"
    else
        tof_test
        rgb_test
        ethernet_test

        if echo "${TOF_TEST}" | grep -q 1 && echo "${RGB_TEST}" | grep -q 1 && echo "${ETHERNET_TEST}" | grep -q 1 && echo "${WIFI_TEST}" | grep -q 1 
        then
            echo -e "${green}ALL TESTS PASSED SUCESSFULLY!${reset}";
        else
            echo -e "${red}Something went wrong!${reset}";
        fi
        
    fi

}

connection_test()
{
    successfull_connection;
}

program()
{
    echo -q password | sudo ./flash.sh -r jetson-nano-emmc mmcblk0p1
}

while :
do
	# show menu
	#clear
    echo -e "\n\n"
	echo "--------------------------------------"
	echo "	     M A I N - M E N U"
	echo "--------------------------------------"
	echo "1. Flash image on camera"
	echo "2. Test camera"
	echo "3. Exit"
	echo "---------------------------------"
	read -r -p "Enter your choice [1-3] : " c
	# take action
	case $c in
		1) program;;
		2) connection_test;;
		3) break;;
		*) Pause "Select between 1 to 3 only"
	esac
done