#!/bin/bash
#
# Script (ssdtGen.sh) to create SSDTs for Mac OS.
#
# Version 0.1.6beta - Copyright (c) 2017 by M.F.C.
#
# Introduction:
#     - ssdtGen is an automated bash script that attempts to build and
#        compile SSDTs for X99/Z170 systems running Mac OS!
#     - Simply run the commands in the README to download and execute the
#        ssdtGen.sh file from your Desktop.
#
#
# Bugs:
#     - Bug reports can be filed at: https://github.com/mattcarlotta/ssdtGen/issues
#        Please provide clear steps to reproduce the bug and the output of the
#        script. Thank you!
#

#===============================================================================##
## GLOBAL VARIABLES #
##==============================================================================##

# Debug output path
dPath="$HOME/Desktop/debug_output.txt"

# User's home dir
gPath="$HOME/Desktop"

#DSDT external device path
gExtDSDTPath='_SB_.PCI0'

#SSDT's standard device path
gSSDTPath='_SB.PCI0'

#SSDT being built/compile set by printHeader
gSSDT=""

#SSDT's Table ID set by printHeader
gSSDTID=""

#Currently logged in user
gUSER=$(stat -f%Su /dev/console)

#IASL root compiler directory
gIaslRootDir="/usr/bin/iasl"

#IASL local directory
gUsrLocalDir="/usr/local/bin"

#IASL local compiler directory
gIaslLocalDir="/usr/local/bin/iasl"

#Github IASL download
gIaslGithub="https://raw.githubusercontent.com/mattcarlotta/ssdtGen/master/tools/iasl"

#Count to cycle thru arrays
gCount=0

export TERM=dumb
#SSDT Table-ID array
gTableID=""

#Motherboad ID array
gMoboID=('X99' 'Z170' 'MAXIMUS')

#carriage return
cr=`echo $'\n.'`
cr=${cr%.}

#===============================================================================##
## USER ABORTS SCRIPT #
##==============================================================================##
function _clean_up()
{
  clear
  echo "Cleaning up any left-overs"
  # remove any left over .dsl files
  rm "${gPath}"/*.dsl 2> /dev/null
  clear
  echo "Script was aborted!"
  exit -0
}

#===============================================================================##
## CHECK DEVICE PROPERTY SEARCH RESULTS #
##==============================================================================##
function _checkDevice_Prop()
{
  #DEVICE SEARCH RESULT
  SSDT_VALUE=$1
  #DEVICE
  SSDT_DEVICE=$2
  #DEVICE PROPERTY
  SSDT_PROP=$3

  #if device search result is empty, display not found error
  if [ -z "$SSDT_VALUE" ]
    then
      echo "*—-ERROR—-* There was a problem locating $SSDT_DEVICE's $SSDT_PROP property!"
      echo "Please run this script in debug mode to generate a debug text file."
  fi
}

#===============================================================================##
## E.O.F. BRACKETS #
##==============================================================================##
function _close_Brackets()
{
  #more (closing) brackets (MB)
  local MB=$1

  if [ "$MB" = true ];
    then
    echo '        }'                                                                      >> "$gSSDT"
    echo '    }'                                                                          >> "$gSSDT"
   #if BRIDGEADDRESS is not empty, add one more closing bracket
    if [ ! -z "$BRIDGEADDRESS" ];
      then
        echo '    }'                                                                      >> "$gSSDT"
    fi
  else
    echo '            })'                                                                 >> "$gSSDT"
    echo '        }'                                                                      >> "$gSSDT"
    echo '    }'                                                                          >> "$gSSDT"
  fi
}

#===============================================================================##
## SET DEVICE PROPERTIES WITH A 0 VALUE #
##==============================================================================##
function _setDevice_ValueZero()
{
  echo '                Buffer() { 0x00 },'                                               >> "$gSSDT"
}

#===============================================================================##
## SET DEVICE PROPERTIES W/O BUFFER #
##==============================================================================##
function _setDevice_NoBuffer()
{
  #DEVICE PROPERTY
  PROP=$1
  #DEVICE VALUE
  VALUE=$2

  echo '                '$PROP','                                                         >> "$gSSDT"
  echo '                '$VALUE','                                                        >> "$gSSDT"
}

#===============================================================================##
## SET DEVICE PROPERTIES #
##==============================================================================##
function _setDeviceProp()
{
  #DEVICE PROPERTY
  PROP=$1
  #DEVICE VALUE
  VALUE=$2

  echo '                '$PROP', Buffer() {'$VALUE'},'                                    >> "$gSSDT"

}

#===============================================================================##
## FIND DEVICE PROPERTIES #
##==============================================================================##
function _findDeviceProp()
{
  #DEVICE PROPERTY (compatible/deviceid/name/model/subsystem-id/subsystem-vendor-id/)
  PROP=$1
  #DEVICE PROPERTY RELATED TO PROP 1 (compatible=>IOName or device-id=>AUDIO)
  local PROP2=$2

  #if PROP2 isn't empty...
  if [ ! -z "$PROP2" ];
    then
      #check if PROP2 is AUDIO...
      if [[ "$PROP2" == 'AUDIO' ]];
        then
          #if AUDIO find device-id...
          SSDT_VALUE=$(ioreg -lw0 -p IODeviceTree -n $PCISLOT -r | grep $PROP | tail -n 1 | sed -e 's/ *[",|=:/_@<>]//g; s/'$PROP'//g')
        else
          #if not AUDIO find IOName...
          SSDT_VALUE=$(ioreg -p IODeviceTree -n "$DEVICE" -k $PROP2 | grep $PROP2 |  sed -e 's/ *["|=:/_@]//g; s/'$PROP2'//g')
      fi
    else
      #if PROP2 is empty, look for device property (PROP1)
      SSDT_VALUE=$(ioreg -p IODeviceTree -n "$DEVICE" -k $PROP | grep $PROP |  sed -e 's/ *["|=<A-Z>:/_@]//g; s/'$PROP'//g')
  fi

  #make sure the return SSDT_VALUE isn't empty
  _checkDevice_Prop "${SSDT_VALUE}" "$DEVICE" "$PROP"

  echo '                "'$PROP'", Buffer() {'                                            >> "$gSSDT"

  #set value based upon found device property
  if [[ "$PROP" == 'compatible' ]];
    then
      echo '                    "'$SSDT_VALUE'"'                                          >> "$gSSDT"
    elif [[ "$PROP" == 'device-id' ]] || [[ "$PROP" == 'subsystem-vendor-id' ]];
    then
      echo '                    0x'${SSDT_VALUE:0:2}', 0x'${SSDT_VALUE:2:2}', 0x00, 0x00' >> "$gSSDT"
    else
      echo '                    0x00, 0x'${SSDT_VALUE:2:2}', 0x00, 0x00'                  >> "$gSSDT"
  fi
  echo '                },'                                                               >> "$gSSDT"
}

#===============================================================================##
## SET GPU DEVICE STATUS #
##==============================================================================##
function _setGPUDevice_Status()
{
  if [[ "$moboID" = "X99" ]];
    then
      #search for any D0xx devices located within device tree
      D0XX=$(ioreg -p IODeviceTree -n ${PCISLOT} -r | grep D0 | sed -e 's/ *["+|=<a-z>:/_@-]//g; s/^ *//g')
      D0XX=${D0XX:0:4}

      #make sure the return D0XX isn't empty
      _checkDevice_Prop "${D0XX}" "$PCISLOT" "D0XX device"

      #remove previous GPU and AUDIO devices
      echo '    Name ('${gSSDTPath}'.'${PCISLOT}'.'${GPU}'._STA, Zero)'                   >> "$gSSDT"
      echo '    Name ('${gSSDTPath}'.'${PCISLOT}'.'${AUDIO}'._STA, Zero)'                 >> "$gSSDT"
      #if D0xx isn't empty, then remove device
      if [ ! -z "${D0XX}" ];
        then
          echo '    Name ('${gSSDTPath}'.'${PCISLOT}'.'${D0XX}'._STA, Zero)'              >> "$gSSDT"
      fi
      echo '}'                                                                            >> "$gSSDT"
    else
      #if the mobo isn't X99, just remove the GPU device
      echo '    Name ('${gSSDTPath}'.'${PCISLOT}'.'${GPU}'._STA, Zero)'                   >> "$gSSDT"
      echo '}'                                                                            >> "$gSSDT"
  fi
}

#===============================================================================##
## SET DEVICE STATUS TO 0 #
##==============================================================================##
function _setDevice_Status()
{
  #remove devices
  echo '    Name ('${gSSDTPath}'.'$SSDT'._STA, Zero)  // _STA: Status'                    >> "$gSSDT"
  echo '}'                                                                                >> "$gSSDT"
}

#===============================================================================##
## GRAB LEqual OR LNot COMPARE #
##==============================================================================##
function _getDSM()
{
  #LNot DSM
  local LNDSM=$1

  #if LNot is true, use LNot compare, otherwise use LEqual compare
  if [ "$LNDSM" = true ];
    then
      echo '            If (!Arg2) { Return (Buffer() { 0x03 } ) }'                       >> "$gSSDT"
    else
      echo '        Method (_DSM, 4, NotSerialized)'                                      >> "$gSSDT"
      echo '        {'                                                                    >> "$gSSDT"
      echo '            If (LEqual (Arg2, Zero)) { Return (Buffer() { 0x03 } ) }'         >> "$gSSDT"
  fi
  echo '            Return (Package ()'                                                   >> "$gSSDT"
  echo '            {'                                                                    >> "$gSSDT"
}

#===============================================================================##
## FIND AUDIO PROPERTIES #
##==============================================================================##
function _findAUDIO()
{
  if [[ "$moboID" = "X99" ]];
    then
      #TAKE GPU DEVICE (H000) and add 1 (H001)
      DEVICE="${DEVICE:0:3}1"

      #for debug purposes only
      #DEVICE="HDAU"
      #for debug purposes only

      #SET TO NEW VARIABLE FOR REMOVING DEVICE
      AUDIO=$DEVICE
  fi

  echo '    Device ('${gSSDTPath}'.'${PCISLOT}'.HDAU)'                                    >> "$gSSDT"
  echo '    {'                                                                            >> "$gSSDT"
  echo '        Name (_ADR, One)  // _ADR: Address'                                       >> "$gSSDT"
  _getDSM
}


#===============================================================================##
## FIND GPU PROPERTIES #
##==============================================================================##
function _findGPU()
{
  #search for a connected GPU
  PROP='attached-gpu-control-path'
  GPUPATH=$(ioreg -l | grep $PROP | sed -e 's/ *[",|=:<a-z>/_@-]//g; s/IOSAACPIPEPCI//g; s/AACPIPCI//g; s/IOPP//g' | cut -c3-6,8-11)
  PCISLOT=${GPUPATH:0:4} #BR3A / PEG0
  DEVICE=${GPUPATH:4:4} #H000 / PEGP
  GPU=$DEVICE

  #see if user is using a 17,1 SMBIOS, because it requires a subsystem-vendor-id property
  iMac171=$(ioreg -lw0 -p IODeviceTree | awk '/compatible/ {print $4}' | grep -o iMac17,1)

  #make sure the return GPU_PATH isn't empty
  _checkDevice_Prop "${GPUPATH}" "$SSDT" "$PROP"

  #set GPU device (SB.XXXX.XXXX)
  echo '    Device ('${gSSDTPath}'.'${PCISLOT}'.'${SSDT}')'                               >> "$gSSDT"
  echo '    {'                                                                            >> "$gSSDT"
  echo '        Name (_SUN, One) // _SUN: Slot User Number'                               >> "$gSSDT"
  echo '        Name (_ADR, Zero)  // _ADR: Address'                                      >> "$gSSDT"
  _getDSM
}

 #===============================================================================##
 ## GRAB WINDOWS OSI  #
 ##==============================================================================##
function _getWindows_OSI()
{
  echo '    Method (XOSI, 1)'                                                             >> "$gSSDT"
  echo '    {'                                                                            >> "$gSSDT"
  echo '        Store(Package()'                                                          >> "$gSSDT"
  echo '        {'                                                                        >> "$gSSDT"
  echo '            "Windows",                // generic Windows query'                   >> "$gSSDT"
  echo '            "Windows 2001",           // Windows XP'                              >> "$gSSDT"
  echo '            "Windows 2001 SP2",       // Windows XP SP2'                          >> "$gSSDT"
  echo '             //"Windows 2001.1",      // Windows Server 2003'                     >> "$gSSDT"
  echo '            //"Windows 2001.1 SP1",   // Windows Server 2003 SP1'                 >> "$gSSDT"
  echo '            "Windows 2006",           // Windows Vista'                           >> "$gSSDT"
  echo '            "Windows 2006 SP1",       // Windows Vista SP1'                       >> "$gSSDT"
  echo '            //"Windows 2006.1",       // Windows Server 2008'                     >> "$gSSDT"
  echo '            "Windows 2009",           // Windows 7/Windows Server 2008 R2'        >> "$gSSDT"
  echo '            "Windows 2012",           // Windows 8/Windows Server 2012'           >> "$gSSDT"
  echo '            //"Windows 2013",         // Windows 8.1/Windows Server 2012 R2'      >> "$gSSDT"
  echo '            "Windows 2015",           // Windows 10/Windows Server TP'            >> "$gSSDT"
  echo '        }, Local0)'                                                               >> "$gSSDT"
  echo '       Return (Ones != Match(Local0, MEQ, Arg0, MTR, 0, 0))'                      >> "$gSSDT"
  echo '    }'                                                                            >> "$gSSDT"
  echo '}'                                                                                >> "$gSSDT"
}

#===============================================================================##
## FIND SMBS DEVICE  #
##==============================================================================##
function _findDevice_Address()
{
  DEVICE=$1 #SMBS or SBUS
  DEVICE2=$2 # SBUS or SMBS
  PROP='acpi-path'
  SSDTADR=$(ioreg -p IODeviceTree -n "$DEVICE" -k $PROP | grep $PROP |  sed -e 's/ *["|=<A-Z>:/_@-]//g; s/acpipathlane//g; y/abcdefghijklmnopqrstuvwxyz/ABCDEFGHIJKLMNOPQRSTUVWXYZ/')

  #make sure the return SSDT_VALUE isn't empty
  _checkDevice_Prop "${SSDTADR}" "$DEVICE" "$PROP"

  #set-up SBUS/SMBS Mikey driver
  echo '    External (_SB_.PCI0, DeviceObj)'                                              >> "$gSSDT"
  echo '    External (_SB_.PCI0.'${DEVICE}', DeviceObj)'                                  >> "$gSSDT"
  echo '    Scope (\_SB.PCI0.'${DEVICE}') {Name (_STA, Zero)}'                            >> "$gSSDT"
  echo '    OperationRegion (GPIO, SystemIO, 0x0500, 0x3C)'                               >> "$gSSDT"
  echo '    Field (GPIO, ByteAcc, NoLock, Preserve)'                                      >> "$gSSDT"
  echo '    {'                                                                            >> "$gSSDT"
  echo '        Offset (0x0C),'                                                           >> "$gSSDT"
  echo '        GL00,   8,'                                                               >> "$gSSDT"
  echo '        Offset (0x2C),'                                                           >> "$gSSDT"
  echo '            ,   1,'                                                               >> "$gSSDT"
  echo '        GI01,   1,'                                                               >> "$gSSDT"
  echo '            ,   1,'                                                               >> "$gSSDT"
  echo '        GI06,   1,'                                                               >> "$gSSDT"
  echo '        Offset (0x2D),'                                                           >> "$gSSDT"
  echo '        GL04,   8'                                                                >> "$gSSDT"
  echo '    }'                                                                            >> "$gSSDT"
  echo '    Device ('${gSSDTPath}'.'${DEVICE2}')'                                         >> "$gSSDT"
  echo '    {'                                                                            >> "$gSSDT"
  echo '        Name (_ADR, 0x'${SSDTADR}')  // _ADR: Address'                            >> "$gSSDT"
  echo '        Device (BUS0)'                                                            >> "$gSSDT"
  echo '        {'                                                                        >> "$gSSDT"
  echo '            Name (_CID, "smbus") // _CID: Compatible ID'                          >> "$gSSDT"
  echo '            Name (_ADR, Zero)'                                                    >> "$gSSDT"
  echo '            Device (MKY0)'                                                        >> "$gSSDT"
  echo '            {'                                                                    >> "$gSSDT"
  echo '                   Name (_ADR, Zero)'                                             >> "$gSSDT"
  echo '                   Name (_CID, "mikey")'                                          >> "$gSSDT"
  _getDSM
  echo '                          "refnum",'                                              >> "$gSSDT"
  echo '                          Zero,'                                                  >> "$gSSDT"
  echo '                          "address",'                                             >> "$gSSDT"
  echo '                          0x39,'                                                  >> "$gSSDT"
  echo '                          "device-id",'                                           >> "$gSSDT"
  echo '                          0x0CCB,'                                                >> "$gSSDT"
  _setDevice_ValueZero
  echo '                      })'                                                         >> "$gSSDT"
  echo '                   }'                                                             >> "$gSSDT"
  echo '                   Method (H1EN, 1, Serialized)'                                  >> "$gSSDT"
  echo '                   {'                                                             >> "$gSSDT"
  echo '                        If (LLessEqual (Arg0, One))'                              >> "$gSSDT"
  echo '                        {'                                                        >> "$gSSDT"
  echo '                            If (LEqual (Arg0, One)) { Or (GL04, 0x04, GL04) }'    >> "$gSSDT"
  echo '                            Else { And (GL04, 0xFB, GL04) }'                      >> "$gSSDT"
  echo '                        }'                                                        >> "$gSSDT"
  echo '                   }'                                                             >> "$gSSDT"
  echo '                   Method (H1IL, 0, Serialized)'                                  >> "$gSSDT"
  echo '                   {'                                                             >> "$gSSDT"
  echo '                        ShiftRight (And (GL00, 0x02), One, Local0)'               >> "$gSSDT"
  echo '                        Return (Local0)'                                          >> "$gSSDT"
  echo '                   }'                                                             >> "$gSSDT"
  echo '                   Method (H1IP, 1, Serialized)'                                  >> "$gSSDT"
  echo '                   {'                                                             >> "$gSSDT"
  echo '                        If (LLessEqual (Arg0, One))'                              >> "$gSSDT"
  echo '                        {'                                                        >> "$gSSDT"
  echo '                            Not (Arg0, Arg0)'                                     >> "$gSSDT"
  echo '                            Store (Arg0, GI01)'                                   >> "$gSSDT"
  echo '                        }'                                                        >> "$gSSDT"
  echo '                   }'                                                             >> "$gSSDT"
  echo '                   Name (H1IN, 0x11)'                                             >> "$gSSDT"
  echo '                   Scope (\_GPE)'                                                 >> "$gSSDT"
  echo '                   {'                                                             >> "$gSSDT"
  echo '                        Method (_L11, 0, NotSerialized)'                          >> "$gSSDT"
  echo '                        {'                                                        >> "$gSSDT"
  echo '                            Notify (\_SB.PCI0.'${DEVICE2}'.BUS0.MKY0, 0x80)'      >> "$gSSDT"
  echo '                        }'                                                        >> "$gSSDT"
  echo '                   }'                                                             >> "$gSSDT"
  echo '                   Method (P1IL, 0, Serialized)'                                  >> "$gSSDT"
  echo '                   {'                                                             >> "$gSSDT"
  echo '                        ShiftRight (And (GL00, 0x40), 0x06, Local0)'              >> "$gSSDT"
  echo '                        Return (Local0)'                                          >> "$gSSDT"
  echo '                   }'                                                             >> "$gSSDT"
  echo '                   Method (P1IP, 1, Serialized)'                                  >> "$gSSDT"
  echo '                   {'                                                             >> "$gSSDT"
  echo '                        If (LLessEqual (Arg0, One))'                              >> "$gSSDT"
  echo '                        {'                                                        >> "$gSSDT"
  echo '                            Not (Arg0, Arg0)'                                     >> "$gSSDT"
  echo '                            Store (Arg0, GI06)'                                   >> "$gSSDT"
  echo '                        }'                                                        >> "$gSSDT"
  echo '                   }'                                                             >> "$gSSDT"
  echo '                   Name (P1IN, 0x16)'                                             >> "$gSSDT"
  echo '                   Scope (\_GPE)'                                                 >> "$gSSDT"
  echo '                   {'                                                             >> "$gSSDT"
  if [[ "$moboID" = "X99" ]];
    then
      echo '                        Method (_L16, 0, NotSerialized)'                      >> "$gSSDT"
    else
      echo '                        Method (_L14, 0, NotSerialized)'                      >> "$gSSDT"
  fi
  echo '                        {'                                                        >> "$gSSDT"
  echo '                            XOr (GI06, One, GI06)'                                >> "$gSSDT"
  echo '                            Notify (\_SB.PCI0.'${DEVICE2}'.BUS0.MKY0, 0x80)'      >> "$gSSDT"
  echo '                        }'                                                        >> "$gSSDT"
  echo '                   }'                                                             >> "$gSSDT"
  echo '            }'                                                                    >> "$gSSDT"
  echo '            Device (DVL0)'                                                        >> "$gSSDT"
  echo '            {'                                                                    >> "$gSSDT"
  echo '                Name (_ADR, 0x57)'                                                >> "$gSSDT"
  echo '                Name (_CID, "diagsvault")'                                        >> "$gSSDT"
  _getDSM
  echo '                        "address",'                                               >> "$gSSDT"
  echo '                        0x57,'                                                    >> "$gSSDT"
  _setDevice_ValueZero
  _close_Brackets
  echo '            Device (BLC0)'                                                        >> "$gSSDT"
  echo '            {'                                                                    >> "$gSSDT"
  echo '                Name (_ADR, Zero)'                                                >> "$gSSDT"
  echo '                Name (_CID, "smbus-blc")'                                         >> "$gSSDT"
  _getDSM
  echo '                        "refnum",'                                                >> "$gSSDT"
  echo '                        Zero,'                                                    >> "$gSSDT"
  echo '                        "version",'                                               >> "$gSSDT"
  echo '                        0x02,'                                                    >> "$gSSDT"
  echo '                        "fault-off",'                                             >> "$gSSDT"
  echo '                        0x03,'                                                    >> "$gSSDT"
  echo '                        "fault-len",'                                             >> "$gSSDT"
  echo '                        0x04,'                                                    >> "$gSSDT"
  echo '                        "skey",'                                                  >> "$gSSDT"
  echo '                        0x4C445342,'                                              >> "$gSSDT"
  echo '                        "type",'                                                  >> "$gSSDT"
  echo '                        0x49324300,'                                              >> "$gSSDT"
  echo '                        "smask",'                                                 >> "$gSSDT"
  echo '                        0xFF,'                                                    >> "$gSSDT"
  _close_Brackets
  echo '        }'                                                                        >> "$gSSDT"
  echo '        Device (BUS1)'                                                            >> "$gSSDT"
  echo '        {'                                                                        >> "$gSSDT"
  echo '            Name (_CID, "smbus")'                                                 >> "$gSSDT"
  echo '            Name (_ADR, One)'                                                     >> "$gSSDT"
  echo '        }'                                                                        >> "$gSSDT"
  echo '    }'                                                                            >> "$gSSDT"
  echo '}'                                                                                >> "$gSSDT"
}

#===============================================================================##
## GET EXTERNAL NVME DEVICE #
##==============================================================================##
function _getExtDevice_NVME
{
  #user speccified NVMEDEVICE (BR1B,PEG0,RP04,etc)
  echo '    External ('${gExtDSDTPath}'.'${NVMEDEVICE}', DeviceObj)'                      >> "$gSSDT"

  #search for any D0xx devices located within NVMEDEVICE's tree
  FOUNDD0xx=$(ioreg -p IODeviceTree -n "$NVMEDEVICE" -r | grep D0 | sed -e 's/ *["+|=<a-z>:/_@-]//g; s/^ *//g' | cut -c1-4 | sed '$!N;s/\n/ /')

  #if INCOMPLETENVMEPATH is empty...
  if [ -z "$INCOMPLETENVMEPATH" ];
    then
      #combine BR1B.H000, BR1B.D075, BR1B.D081 for removal
      extDEVICES=($NVMELEAFNODE $FOUNDD0xx)
    else
      #otherwise, only D0xx devices will be removed
      extDEVICES=($FOUNDD0xx)
  fi

  #loop through extDEVICES, set an External reference, then remove it
  for((i=0;i<${#extDEVICES[@]};i++))
  do
    echo '    External ('${gExtDSDTPath}'.'${NVMEDEVICE}'.'${extDEVICES[$i]}', DeviceObj)'>> "$gSSDT"
    echo '    Scope ('${gExtDSDTPath}'.'${NVMEDEVICE}'.'${extDEVICES[$i]}')'              >> "$gSSDT"
    echo '    {Name (_STA, Zero)}'                                                        >> "$gSSDT"
  done

  #set NVME device scope (SB.PCI0.XXXX) and then NVME device
  echo '    Scope ('${gExtDSDTPath}'.'${NVMEDEVICE}')'                                    >> "$gSSDT"
  echo '    {'                                                                            >> "$gSSDT"
  echo '        Device (NVME)'                                                            >> "$gSSDT"
  echo '        {'                                                                        >> "$gSSDT"

  #if user specified INCOMPLETENVMEPATH is empty, set 0 address, otherwise set incomplete address
  if [ -z "$INCOMPLETENVMEPATH" ];
    then
      #NVME HAS A COMPLETE ACPI
      echo '            Name (_ADR, Zero)'                                                >> "$gSSDT"
    else
      #NVME HAS AN INCOMPLETE ACPI
      echo '            Name (_ADR, '$NVME_ACPI_ADRESSS')'                                >> "$gSSDT"
  fi

  #if user specified BRIDGEADDRESS is not empty, create a new PCIB device w/ address
  if [ ! -z "$BRIDGEADDRESS" ]
    then
    echo '        Device (PCIB)'                                                          >> "$gSSDT"
    echo '        {'                                                                      >> "$gSSDT"
    echo '            Name (_ADR, '$BRIDGEADDRESS')'                                      >> "$gSSDT"
  fi

  #use LEqual operand
  _getDSM
}

#===============================================================================##
## GRAB EXTERNAL DEVICE ADDRESS #
##==============================================================================##
function _getExtDevice_Address()
{
  #only add DSM to pre-existing device (EVSS, LPC0/B)
  DEVICE=$1

  echo '    External ('${gExtDSDTPath}'.'${DEVICE}', DeviceObj)'                          >> "$gSSDT"
  echo '    Method ('${gSSDTPath}'.'${DEVICE}'._DSM, 4, NotSerialized)'                   >> "$gSSDT"
  echo '    {'                                                                            >> "$gSSDT"

  #use LNot operand
  _getDSM true
}

#===============================================================================##
## GRAB DEVICE ADDRESS #
##==============================================================================##
function _getDevice_ACPI_Path()
{
  #ALZA/HDAS, HECI
  DEVICE=$1
  #HDEF, IMEI
  NEWDEVICE=$2
  #DEVICE PROPERTY
  PROP='acpi-path'
  #FIND DEVICE ADDRESS
  SSDTADR=$(ioreg -p IODeviceTree -n "$DEVICE" -k $PROP | grep $PROP |  sed -e 's/ *["|=<A-Z>:/_@-]//g; s/acpipathlane//g; y/abcdefghijklmnopqrstuvwxyz/ABCDEFGHIJKLMNOPQRSTUVWXYZ/')

  #make sure the return SSDTADR isn't empty
  _checkDevice_Prop "${SSDTADR}" "$DEVICE" "$PROP"

  #if NEWDEVICE is not empty, set a new device, otherwise use existing device
  if [ ! -z "$NEWDEVICE" ];
    then
      echo '    Device ('${gSSDTPath}'.'${NEWDEVICE}')'                                   >> "$gSSDT"
    else
      echo '    Device ('${gSSDTPath}'.'${DEVICE}')'                                      >> "$gSSDT"
  fi
  echo '    {'                                                                            >> "$gSSDT"
  echo '        Name (_ADR, 0x'${SSDTADR}')  // _ADR: Address'                            >> "$gSSDT"

  #use LEqual operand
  _getDSM
}

#===============================================================================##
## ATTEMPTS TO BUILD SSDTS FOR DEVICES #
##==============================================================================##
function _buildSSDT()
{
  SSDT=$1

  if [ "$SSDT" == "ALZA" ] || [ "$SSDT" == "HDAS" ];
    then
      # for debug only
      #_getDevice_ACPI_Path "HDEF"
      # for debug only
      _getDevice_ACPI_Path "${SSDT}" "HDEF"
      _setDeviceProp '"AAPL,slot-name"' '"Built In"'
      _setDeviceProp '"device_type"' '"Audio Controller"'
      _setDeviceProp '"built-in"' '0x00'
      _setDeviceProp '"model"' '"Realtek Audio Controller"'
      _setDeviceProp '"hda-gfx"' '"onboard-1"'
      _setDeviceProp '"layout-id"' '0x01, 0x00, 0x00, 0x00'
      _setDeviceProp '"PinConfigurations"' '0x00'
      _findDeviceProp 'compatible' 'IOName'
      _close_Brackets
      _setDevice_Status
  fi

  if [[ "$SSDT" == "EVSS" ]];
    then
      _getExtDevice_Address $SSDT
      _setDeviceProp '"AAPL,slot-name"' '"Built In"'
      _setDeviceProp '"built-in"' '0x00'
      _setDeviceProp '"name"' '"Intel sSata Controller"'
      _setDeviceProp '"model"' '"Intel 99 Series Chipset Family sSATA Controller"'
      _setDeviceProp '"device_type"' '"AHCI Controller"'
      _findDeviceProp 'compatible' 'IOName'
      _findDeviceProp 'device-id'
      _close_Brackets
  fi

  if [[ "$SSDT" == "GFX1" ]];
    then
      _findGPU
      _setDeviceProp '"AAPL,slot-name"' '"Built In"'
      _setDeviceProp '"hda-gfx"' '"onboard-2"'
      if [ ! -z "$iMac171" ];
        then
          _findDeviceProp 'subsystem-vendor-id'
      fi
      _setDeviceProp '"@0,connector-type"' '0x00, 0x08, 0x00, 0x00'
      _setDeviceProp '"@1,connector-type"' '0x00, 0x08, 0x00, 0x00'
      _setDeviceProp '"@2,connector-type"' '0x00, 0x08, 0x00, 0x00'
      _setDeviceProp '"@3,connector-type"' '0x00, 0x08, 0x00, 0x00'
      _setDeviceProp '"@4,connector-type"' '0x00, 0x08, 0x00, 0x00'
      _setDeviceProp '"@5,connector-type"' '0x00, 0x08, 0x00, 0x00'
      _close_Brackets
      _findAUDIO
      _setDeviceProp '"hda-gfx"' '"onboard-2"'
      _setDeviceProp '"PinConfigurations"' '0xe0, 0x00, 0x56, 0x28'
      _findDeviceProp 'device-id' 'AUDIO'
      _close_Brackets
      _setGPUDevice_Status
  fi

  if [[ "$SSDT" == "GLAN" ]];
    then
      _getExtDevice_Address $SSDT
      _setDeviceProp '"AAPL,slot-name"' '"Built In"'
      if [[ "$moboID" = "Z170" ]];
        then
          _setDeviceProp '"model"' '"Intel i219V"'
        else
          _setDeviceProp '"model"' '"Intel i218V"'
      fi
      _setDeviceProp '"name"' '"Ethernet Controller"'
      _setDeviceProp '"built-in"' '0x00'
      _findDeviceProp 'device-id'
      _findDeviceProp 'subsystem-id'
      _findDeviceProp 'subsystem-vendor-id'
      _close_Brackets
  fi

  if [[ "$SSDT" == "HECI" ]];
    then
      # for debug only
      #_getDevice_ACPI_Path "IMEI"
      # for debug only
      _getDevice_ACPI_Path "${SSDT}" "IMEI"
      _setDeviceProp '"AAPL,slot-name"' '"Built In"'
      _setDeviceProp '"name"' '"IMEI Controller"'
      _setDeviceProp '"model"' '"IMEI Controller"'
      _setDeviceProp '"built-in"' '0x00'
      _setDeviceProp '"compatible"' '"pci8086,1e3a"'
      _setDeviceProp '"device-id"' '0x3A, 0x1E, 0x00, 0x00'
      _close_Brackets
      _setDevice_Status
  fi

  if [[ "$SSDT" == "NVME" ]];
    then
      _getExtDevice_NVME "${NVME_ACPI_PATH}"
      _setDeviceProp '"AAPL,slot-name"' '"Built In"'
      _setDeviceProp '"name"' '"NVMe Controller"'
      _setDeviceProp '"model"' '"NVMe Controller"'
      _setDeviceProp '"class-code"' '0xFF, 0x08, 0x01, 0x00'
      _setDeviceProp '"built-in"' '0x00'
      _close_Brackets
      _close_Brackets true
  fi

  if [ "$SSDT" == "LPC0" ] || [ "$SSDT" == "LPCB" ];
    then
      _getExtDevice_Address $SSDT
      if [[ "$moboID" = "Z170" ]];
        then
          _setDeviceProp '"compatible"' '"pci8086,9cc1"'
        else
          _setDeviceProp '"compatible"' '"pci8086,9c43"'
      fi
      _close_Brackets
  fi

  if [ "$SSDT" == "SAT1" ] || [ "$SSDT" == "SAT0" ];
    then
      _getExtDevice_Address $SSDT
      _setDeviceProp '"AAPL,slot-name"' '"Built In"'
      _setDeviceProp '"built-in"' '0x00'
      _setDeviceProp '"device-type"' '"AHCI Controller"'
      _setDeviceProp '"name"' '"Intel AHCI Controller"'
      if [[ "$moboID" = "Z170" ]];
        then
          _setDeviceProp '"model"' '"Intel 10 Series Chipset Family SATA Controller"'
        else
          _setDeviceProp '"model"' '"Intel 99 Series Chipset Family SATA Controller"'
      fi

      _findDeviceProp 'compatible' 'IOName'
      _findDeviceProp 'device-id'
      _close_Brackets
  fi

  if [ "$SSDT" == "SMBS" ] || [ "$SSDT" == "SBUS" ];
    then
      if [[ "$moboID" = "Z170" ]];
        then
          _findDevice_Address "${SSDT}" "SMBS"
        else
          # for debug only
          #_findDevice_Address SBUS "SBUS"
          # for debug only
          _findDevice_Address "${SSDT}" "SBUS"
      fi
      #_setDevice_Status
  fi

  if [[ "$SSDT" == "XHC" ]];
    then
      _getExtDevice_Address $SSDT
      _setDeviceProp '"AAPL,slot-name"' '"Built In"'
      _setDeviceProp '"name"' '"Intel XHC Controller"'
      if [[ "$moboID" = "Z170" ]];
        then
          _setDeviceProp '"model"' '"Intel 10 Series Chipset Family USB xHC Host Controller"'
        else
          _setDeviceProp '"model"' '"Intel 99 Series Chipset Family USB xHC Host Controller"'
      fi
      _setDevice_NoBuffer '"AAPL,current-available"' '0x0834'
      _setDevice_NoBuffer '"AAPL,current-extra"' '0x0A8C'
      _setDevice_NoBuffer '"AAPL,current-in-sleep"' '0x0A8C'
      _setDevice_NoBuffer '"AAPL,max-port-current-in-sleep"' '0x0834'
      _setDevice_NoBuffer '"AAPL,device-internal"' '0x00'
      _setDevice_ValueZero
      _setDeviceProp '"AAPL,clock-id"' '0x01'
      _findDeviceProp 'device-id'
      _close_Brackets
  fi

  if [[ "$SSDT" == "XOSI" ]];
    then
      _getWindows_OSI
  fi
}

##===============================================================================##
# COMPILE SSDTs AND CLEAN UP #
##===============================================================================##
function _compileSSDT
{
  #increase SSDT array counter
  ((gCount++))
  #give user ownership over gen'd SSDTs
  chown $gUSER $gSSDT
  echo "Attemping to compile: ${gSSDTID}.dsl"
  #attempt to compile gen'd SSDTs
  iasl -G "$gSSDT"
  echo "Removing: ${gSSDTID}.dsl"
  echo ''
  echo '------------------------------------------------------------------------------------------------------------------------------------------'
  #printf '\n'
  #remove gen'd SSDT-XXXX.dsl files
  rm "$gSSDT"

  #exit script if user only wanted to build one SSDT
  if [ ! -z "$buildOne" ];
    then
      echo "User only wanted to build ${buildOne}" > /dev/null 2>&1
      exit 0
  fi

  #otherwise build all SSDTs
  if (( $gCount < ${#gTableID[@]}-1 ));
   then
      echo 'Attempting to build all SSDTs...' > /dev/null 2>&1
     _printHeader
  fi
}

##===============================================================================##
# PRINT TO FILE HEADER #
##===============================================================================##
function _printHeader()
{
  #set SSDTs based upon moboID
  gSSDTID="SSDT-${gTableID[$gCount]}"
  echo 'Creating: '${gSSDTID}'.dsl'
  #set a new SSDT-XXXX.dsl directory
  gSSDT="${gPath}/${gSSDTID}.dsl"

  echo 'DefinitionBlock ("", "SSDT", 1, "mfc88", "'${gTableID[$gCount]}'", 0x00000000)'   > "$gSSDT"
  echo '{'                                                                                >> "$gSSDT"

  #build and compile 0-9 SSDTs
  _buildSSDT ${gTableID[$gCount]}
  _compileSSDT
}

##===============================================================================##
# CHECK USER'S INPUT TO LOCAL IOREG #
##===============================================================================##
function _checkIf_PATH_Exists()
{
  #check and make sure user specified a valid device/leafnode
  if [ ! -z "$INCOMPLETENVMEPATH" ];
    then
      IOREGPATH=$(ioreg -p IODeviceTree -n "$NVMEDEVICE" -r)
    else
      IOREGPATH=$(ioreg -p IODeviceTree -n "$NVMEDEVICE" -r | grep -o $NVMELEAFNODE)
  fi

  #if IOREG is empty...
  if [ -z "$IOREGPATH" ];
    then
      #check if INCOMPLETENVMEPATH was not activated, if so, display NVMEPATH error
      if [ -z "$INCOMPLETENVMEPATH" ];
        then
          echo ''
          echo "*—-ERROR—-*There was a problem locating $NVMEDEVICE's leafnode ($NVMELEAFNODE)!"
          echo "Please make sure the ACPI path submitted is correct!"
          exit 0
      else
        #otherwise, display INCOMPLETENVMEPATH error
        echo ''
        echo "*—-ERROR—-* There was a problem locating $INCOMPLETENVMEPATH!"
        echo "Please make sure the ACPI path submitted is correct!"
        exit 0
    fi
  fi
}

##===============================================================================##
# CHECK IF USER SPECIFIED ADDRESSES ARE IN CORRECT FORMAT #
##===============================================================================##
function _checkIf_VALIDADDRESS()
{
  #USER SPECIFIED BRIDGE ADDRESSS
  BR=$1

  if [ "$BR" == true ];
    then
      #if BRIDGEADDRESS is less than or equal to 2, then show error, then send back to prompt
      if [[ "${#BRIDGEADDRESS}" -le 2 ]] ;
        then
        echo ''
        echo "*—-ERROR—-* You must include a valid PCI Bridge address! Try again"
        exit 0
      fi
    else
      #if NVME_ACPI_ADRESSS is not at least "0x" or is <= 2, then show error, then send back to prompt
      if [[ "$NVME_ACPI_ADRESSS" != 0x* ]] || [[ "${#NVME_ACPI_ADRESSS}" -le 2 ]];
        then
        echo ''
        echo "*—-ERROR—-* You must include a valid ACPI address! Try again"
        exit 0
      fi
  fi
}

##===============================================================================##
# ASK USER IF NVME IS BEHIND PCI BRIDGE #
##===============================================================================##
function _askfor_PCIBRIDGE()
{
  echo ''
  while true; do
  read -p "Is the NVME behind a PCI bridge? If so, write the PCI bridge address ${bold}0x0000${normal}, otherwise write ${bold}no${normal}. $cr--> " choice
    case "$choice" in
      #user wants to exit script
      exit|EXIT )
      _clean_up
      break
      ;;
      no|NO )
      #NVME isn't behind a PCI bridge
      echo 'NVME isn/t behind a PCI bridge!' > /dev/null 2>&1
      break
      ;;
      #NVME is behind a PCI bridge
      0x*|0X* )
      BRIDGEADDRESS=${choice:0:8}
      #check if PCI bridge address is in the correct syntax
      _checkIf_VALIDADDRESS true
      break
      ;;
      #user input invalid choice
      * )
      echo ''
      echo "*—-ERROR—-* Sorry, but $choice is not a valid option! Try again"
      echo ''
      ;;
    esac
  done
}

##===============================================================================##
# ASK USER WHERE NVME IS LOCATED #
##===============================================================================##
function _askfor_NVMEPATH()
{
  echo ''
  read -p "What is the NVME's ACPI path? For example, write ${bold}BR1B.H000${normal}, or ${bold}RP04.PSXS${normal}, or ${bold}PEG0.PEGP${normal}, and so on. $cr--> " choice
    case "$choice" in
      #user wants to exit script
      exit|EXIT )
      _clean_up
      ;;
      #user specified a device and leafnode
      * )
      NVME_ACPI_PATH=$choice #full ACPI path
      NVMEDEVICE=${choice:0:4} #device path (BR1B)
      NVMELEAFNODE=${choice:5:4} #leafnode (H000)
      #make sure the ACPI path exists
      _checkIf_PATH_Exists
      #if it does exist, send them to PCI bridge prompt
      _askfor_PCIBRIDGE
      echo ''
      #if no PCI bridge, set gCount according to found SSDT (10)
      gCount=$i
      #attempt to build and compile SSDT
      _printHeader
      ;;
  esac
}

##===============================================================================##
# ASK USER IF NVME PATH IS INCOMPLETE #
##===============================================================================##
function _set_INCOMPLETENVMEDETAILS()
{
  #user specified device and address
  NVME_ACPI_PATH=${choice3:0:4} #device (BR1B)
  NVME_ACPI_ADRESSS=${choice3:5:10} #address (0x8000)
  INCOMPLETENVMEPATH=$NVME_ACPI_PATH #device (BR1B) used for checking against
  NVMEDEVICE=$NVME_ACPI_PATH #device (BR1B) used for checking against
  #check if NVME device address is in the correct syntax
  _checkIf_VALIDADDRESS
  #make sure the ACPI path exists
  _checkIf_PATH_Exists
  #if path exists and address is in the correct syntax, set gCount according to found SSDT (10)
  gCount=$i
  #attempt to build and compile SSDT
  _printHeader
}

##===============================================================================##
# CHECK USER CHOICES TO SSDT LIST #
##===============================================================================##
function _checkIf_SSDT_Exists()
{
  #loop through SSDT array to find user specfied buildOne SSDT
  for((i=0;i<${#gTableID[@]};i++))
  do
    if [[ "${buildOne}" == "${gTableID[$i]}" ]];
      then
        #set gCount according to found SSDT (0-9)
        gCount=$i
        #attempt to build and compile SSDT
        _printHeader
        break
    fi
  done

  echo "*—-ERROR—-* $buildOne is not a SSDT! Please try again!"
}

#===============================================================================##
## FIND USER'S MOTHERBOARD #
##==============================================================================##
function _findMoboID()
{
  #moboID=$(ioreg -n FakeSMCKeyStore -k product-name | grep product-name | sed -e 's/ *["|=:/_@-]//g; s/productname//g' | grep -o $mobo)

  #find user's motherboard
  moboID=$(ioreg -lw0 -p IODeviceTree | awk '/OEMBoard/ {print $4}' | grep -o ${gMoboID[$i]})
}

#===============================================================================##
## CHECK TO SEE IF USER'S MOTHERBOARD IS SUPPORTED #
##==============================================================================##
function _checkBoard
{
  #loop through MoboID array list (X99, Z170, MAXIMUS)
  for((i=0;i<${#gMoboID[@]};i++))
  do
    _findMoboID
    if [ ! -z "$moboID" ];
      then
        #if mobo was found, break loop
        echo "User has a $moboID board!"  > /dev/null 2>&1
        break
    fi
  done

  #check to see if moboID matches X99, Z170 or MAXIMUS
  if [[ "$moboID" = "X99" ]];
    then
      gTableID=('ALZA' 'EVSS' 'GFX1' 'GLAN' 'HECI' 'LPC0' 'SAT1' 'SMBS' 'XHC' 'XOSI' 'NVME')
    elif [[ "$moboID" = "Z170" ]] || [[ "$moboID" = "MAXIMUS" ]];
      then
      gTableID=('GLAN' 'GFX1' 'HDAS' 'HECI' 'LPCB' 'SAT0' 'SBUS' 'XHC' 'XOSI' 'NVME')
  else
    #if moboID doesn't match, display error, exit script
    echo ""
    echo "*—-ERROR—-*This script only supports X99/Z170 motherboards at the moment!"
    echo ""
    exit 0
  fi
}

##===============================================================================##
# GIVE USER CHOICES ON WHAT TO DO #
##===============================================================================##
function _user_choices()
{
  choice=$choice1
  case "$choice" in
    # attempt to build all SSDTs
    buildall|BUILDALL )
    _checkBoard
    _printHeader
    exit 0
    ;;
    # attempt to build one SSDT
    build* | BUILD*)
    buildOne=${choice:6:9}
    #if NVME was selected, send them to INCOMPLETENVMEDETAILS prompt
    if [[ "$buildOne" == "NVME" ]];
      then
      echo 'User selected NVME!'
      gCount=0
      gTableID='NVME'
      if [ ! -z "$choice3" ];
        then
          echo 'User selected incomplete NVME!'
          _set_INCOMPLETENVMEDETAILS
        else
          echo 'Choice3 is empty'
          exit 0
          _checkBoard
          _checkIf_SSDT_Exists
      fi
    fi
    exit 0
    ;;
    # debug mode
    debug|DEBUG )
    set -x
    #main true 2>&1 | tee "$dPath"
    echo "Now running in debug mode!"
    choice1=$choice2
    echo "choice2: $userSelected"
    _user_choices 2>&1 | tee "$dPath"
    ioreg -lw0 -p IODeviceTree >> "$dPath"
    set +x
    exit 0
    ;;
    # display help instructions
    help|HELP )
    display_instructions
    ;;
    # kill the script
    exit|EXIT )
    _clean_up
    ;;
    # oops - user made a mistake, show display instructions
    * )
    echo ""
    echo "*—-ERROR—-* That was not a valid option! Please try again!"
    echo ""
    exit 0
    ;;
  esac
}

#===============================================================================##
## CHECK MACIASL AND IASL ARE INSTALLED #
##==============================================================================##
function _checkPreInstalled()
{
  #check to see if IASL is installed in usr/bin or usr/local/bin
  if [ -f "$gIaslRootDir" ] || [ -f "$gIaslLocalDir" ];
    then
      echo 'IASL64 is already installed!' > /dev/null 2>&1
    else
      echo "*—-ERROR—-*IASL64 isn't installed in the either $gIaslRootDir nor your $gIaslLocalDir directory!"
      echo ""
      echo "Attempting to download IASL from Github..."
      #check to see if usr/local/bin exists
      if [ ! -d "$gUsrLocalDir" ];
        then
          echo "$gUsrLocalDir doesn't exist. Creating directory!"
          mkdir -p $gUsrLocalDir
        else
          echo "$gUsrLocalDir already exists" > /dev/null 2>&1
      fi
      #download pre-compiled IASL if not installed
      curl -o $gIaslLocalDir $gIaslGithub
      if [[ $? -ne 0 ]];
        then
          echo ''
          echo "*—-ERROR—-*Make sure your network connection is active!"
          exit 1
      fi
      #change the IASL file to be executeable
      chmod +x $gIaslLocalDir
      echo ""
      echo "MaciASL has been installed!"
      echo ""
  fi
}

#===============================================================================##
## START PROGRAM #
##==============================================================================##
function main()
{
  _checkPreInstalled
  _user_choices
}

#Selected input mode
choice1=$1 #debug script

#Check to see if debug is active, if not replace choice1
if [ -z "$1" ]
  then
    #if empty, use $2
    choice1=$2
    echo "$choice1 - choice1 was set to option 1"
  else
    choice2=$2 #buildAll or build
    echo "$choice2 - choice2 was set to option 2"
fi

choice3=$3 #Incomplete ACPI
echo "$choice3 - choice3 was set to option 3"
choice4=$4
choice5=$5

main


#===============================================================================##
## END OF FILE #
##==============================================================================##
