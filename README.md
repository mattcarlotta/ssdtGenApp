# ssdtGenApp 0.2.1beta

Introduction

ssdtGen is an app that attempts to build and compile custom SSDTs for X99/Z170 systems (see first note below) running Mac OS. Specifically, it will inject properties into your ACPI tables for: on-board sound, an external GPU/HDMI audio, sSata Contoller, ethernet, IMEI controller, LPC support, NVMe devices, Sata Controller, SBUS controller, XHC usb power options, and XOSI support.

Note 1: Regardless of motherboard, you can build a custom NVME SSDT that'll work in conjunction with Rehabman's spoofed <a href="http://www.insanelymac.com/forum/topic/312803-patch-for-using-nvme-under-macos-sierra-is-ready/page-55#entry2405345">HackrNVMeFamily-10_xx_x.kext</a>. If you're unfamiliar with how NVME injection works and what is required, please read one or both of the guides in footnote 2 (††) in the "Limitation Notes" below.

Note 2: Please note that some of the devices will still need "drivers" (kexts) to be fully functional:
* <a href="http://www.insanelymac.com/forum/files/file/436-ahciportinjectorkext/">AHCIPortInjector.kext</a> for HDD/SSD devices (EVSS and SAT0/SAT1)
* <a href="http://www.insanelymac.com/forum/topic/304235-intelmausiethernetkext-for-intel-onboard-lan/#entry2107186">IntelMausiEthernet.kext</a> for ethernet (GLAN)
* Custom AppleHDA-ALCXXXX.kext OR <a href="http://www.insanelymac.com/forum/topic/311293-applealc-%E2%80%94-dynamic-applehda-patching/#entry2221652">AppleALC.kext</a> + <a href="https://bitbucket.org/RehabMan/os-x-eapd-codec-commander">CodecCommander.kext</a> OR <a href="http://www.insanelymac.com/forum/topic/308387-el-capitan-realtek-alc-applehda-audio/#entry2172944">RealtekALC.kext</a> for on-board and HDMI/DP sound (HDAU and HDEF)
* <a href="http://www.insanelymac.com/forum/topic/312525-nvidia-web-driver-updates-for-macos-sierra-update-03272017/">Nvidia Web Drivers</a> for GPU recognition

You can download the latest version of ssdtGen to your Desktop by entering the following commands in a terminal window:
```
cd ~/desktop && curl -OL https://github.com/mattcarlotta/ssdtGenApp/raw/master/ssdtGen.zip && unzip -qu ssdtGen.zip && rm -rf __MACOSX && rm -rf ssdtGen.zip
```

You must initially run the ssdtGen as a ROOT user otherwise you may receive an error when attempting to install IASL (after IASL has been installed, double clicking the ssdtGen.app will suffice). Enter the following command in a terminal window to run ssdtGen.app as a ROOT user:
```
sudo $HOME/Desktop/ssdtGen.app/Contents/MacOS/ssdtGen
```

Go here for more support: <a href="http://www.insanelymac.com/forum/topic/322811-ssdtgen-custom-generated-ssdts-x99z170-systems/">ssdtGen - custom generated SSDTs (x99/z170 systems)</a>

--------------------------------------------------------------------------------------------------------------

**Limitation Notes

* DSDT ACPI tables must be vanilla(†). If any devices are renamed, forget about it. Won't work.
* Clover DSDT "fixes" (like addHDMI/fixSBUS) will interfere with SSDT injection. Do not use.
* This app will install IASL to the usr/bin directory if it's missing (requires ROOT privileges)
* Piker-Alpha's <a href="https://github.com/Piker-Alpha/ssdtPRGen.sh">ssdtPRgen</a> is still required if you wish to have CPU power management
* This app currently only supports 1 connected (external) GPU. If you have or are using the IGPU (Intel's
internal GPU located on the CPU die), then GPU injection won't work. Also, if you have multiple external
GPU's attached, only the first one will be injected.
* A generated SSDT-NVME.aml requires a spoofed HackrNVMeFamily-10_xx_x.kext to be loaded††
* If a SSDT-xxxx.aml fails to compile, then it won't be saved. Check the terminal output for errors.

† If you're using a custom DSDT.aml, it may conflict with the SSDTs if it already has DSMs injected at the device. Also, XHCI must be named XHC via config.plist DSDT patch (recommended to install USBInjectAll.kext + XHCI-x99-injector.kext with a custom SSDT-UAIC.aml):
- <a href="https://www.tonymacx86.com/threads/guide-creating-a-custom-ssdt-for-usbinjectall-kext.211311/">Rehabman's Guide for Creating a Custom SSDT for USBInjectAll.kext</a>
- <a href="http://www.insanelymac.com/forum/topic/313296-guide-mac-osx-1012-with-x99-broadwell-e-family-and-haswell-e-family/page-53#entry2354822"> My Guide for using UsbInjectAll.kext with a Custom SSDT-UIAC.aml</a>

†† In order to generate a spoofed HackrNVMeFamily-10_xx_x.kext to work with SSDT-NVME.aml, please follow:
* <a href="https://www.tonymacx86.com/threads/guide-hackrnvmefamily-co-existence-with-ionvmefamily-using-class-code-spoof.210316/">HackrNVMeFamily co-existence with IONVMeFamily using class-code spoof<a/>
* <a href="http://www.insanelymac.com/forum/topic/312803-patch-for-using-nvme-under-macos-sierra-is-ready/page-37#entry2343228">Generic HackrNVMeFamily guide<a/> (skip steps 9-11, as this app will generate one for you)

**Note: This app is in beta testing. Therefore, expect some bugs/issues to occur.
