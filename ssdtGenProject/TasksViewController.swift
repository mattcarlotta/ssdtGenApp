/*
 * Copyright (c) 2015 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import Cocoa

class TasksViewController: NSViewController {
  
  //Controller Outlets
  @IBOutlet var outputText:NSTextView!
  @IBOutlet var spinner:NSProgressIndicator!
  @IBOutlet var buildButton:NSButton!
  @IBOutlet var buildAllButton: NSButton!
  @IBOutlet var debugButton: NSButton!
  @IBOutlet var completeCheckBox: NSButton!
  @IBOutlet var completeTextInput: NSTextField!
  @IBOutlet var pcibridgeCheckBox: NSButton!
  @IBOutlet var pcibridgeTextInput: NSTextField!
  @IBOutlet var incompleteCheckBox: NSButton!
  @IBOutlet var incompleteTextInput: NSTextField!
  @IBOutlet var terminateButton: NSButton!
  @IBOutlet var ssdtList: NSPopUpButton!
  @IBOutlet var exitButton: NSButton!
  @IBOutlet var nvmeOptions: NSImageView!
  @IBOutlet var nvmeBox: NSBox!
  @IBOutlet var completeacpiImage: NSImageView!
  @IBOutlet var pcibridgeImage: NSImageView!
  @IBOutlet var incompleteacpiImage: NSImageView!
  
  // Set up default variables
  dynamic var isRunning = false
  var outputPipe:Pipe!
  var buildTask:Process!
  var debugScript = ""
  var buildSSDT = ""
  var incompleteACPI = ""
  var completeACPI = ""
  var pciBridge = ""
  var textError = ""
  var SSDTs = ["ALZA", "EVSS", "GFX1", "GLAN", "HDAS", "HECI", "LPC0", "LPCB", "NVME", "SAT0", "SAT1", "SBUS", "SMBS", "XHC", "XOSI"]
  var userSelectedSSDT = ""

  // Toggles NVME Options on/off
  func toggleNVMEBox(_ boolState: Bool ) {
    completeacpiImage.isEnabled = boolState
    completeCheckBox.isEnabled = boolState
    completeTextInput.isEnabled = boolState
    incompleteCheckBox.isEnabled = boolState
    incompleteacpiImage.isEnabled = boolState
    incompleteTextInput.isEnabled = boolState
    pcibridgeImage.isEnabled = boolState
    pcibridgeCheckBox.isEnabled = boolState
    pcibridgeTextInput.isEnabled = boolState
    nvmeOptions.isEnabled = boolState
  }
  
  // Sets a borderless window and allows it to be moveable
  override func viewDidAppear() {
    super.viewDidAppear()

    self.view.window?.styleMask.insert(.fullSizeContentView)   
    self.view.window?.titleVisibility = NSWindowTitleVisibility.hidden;
    self.view.window?.titlebarAppearsTransparent = true;
    //self.view.window?.isMovableByWindowBackground = true;
  }
  
  // Set up pop up button with list
  override func viewDidLoad() {
    ssdtList.removeAllItems()
    ssdtList.addItems(withTitles: SSDTs)
    ssdtList.selectItem(at: 0)
    userSelectedSSDT = SSDTs[ssdtList.indexOfSelectedItem]
    toggleNVMEBox(false)
  }
  
  // Set buildOne SSDT and toggle NVME options on/off
  @IBAction func selectedSSDT(_ sender: Any) {
    userSelectedSSDT = SSDTs[ssdtList.indexOfSelectedItem]
    
    if (userSelectedSSDT == "NVME") {
      toggleNVMEBox(true)
    } else {
      toggleNVMEBox(false)
    }
  }
  
  // Set debug mode on/off
  @IBAction func toggleDebugMode(_ sender: Any) {
    if ((sender as AnyObject).state == NSOnState) {
      debugScript = "debug"
    } else {
      debugScript = ""
    }

  }

  // BuildAll button action
  @IBAction func buildAllSSDT(_ sender: AnyObject) {
    
    //1 - Clear output
    outputText.string = ""
    
    //2 - Prepare args
    buildSSDT = "buildall"
    
    //3 - Set args
    var arguments:[String] = []
    arguments.append(debugScript)
    arguments.append(buildSSDT)
    
    //4 - Pass args to runScript
    runScript(arguments)

  }
  
  // Reset Build button to inactive if error
  func resetBuildButtonState () {
    self.buildButton.state = 0
  }
  
  // Pop up Error alert
  func dialogOKCancel(_ textError: String) -> Bool {
    let myPopup: NSAlert = NSAlert()
    myPopup.messageText = "Error"
    myPopup.informativeText = textError
    myPopup.alertStyle = NSAlertStyle.warning
    myPopup.addButton(withTitle: "OK")
    return myPopup.runModal() == NSAlertFirstButtonReturn
  }
    
  // BuildOne button action
  @IBAction func buildOne(_ sender:AnyObject) {
    
    if (userSelectedSSDT.isEmpty) {
      outputText.string = "*—-ERROR—-* Please add input before pressing build!"
    } else {
    
    //1 - Clear output
    outputText.string = ""
      
    //2 - Set Choice Option
    buildSSDT = ("build " + userSelectedSSDT)
    
    //3 - Set arguments to pass to script
    var arguments:[String] = []
    arguments.append(debugScript)
    arguments.append(buildSSDT)
    
    //4 - Check if NVME was selected
    if (userSelectedSSDT == "NVME") {
      
      //1 - Check to make sure either ACPI or Incomplete has been checked
      if (completeCheckBox.state == 0 && incompleteCheckBox.state == 0 || completeCheckBox.state == 1 &&  incompleteCheckBox.state == 1 ) {
        textError = "You must select either a complete NVME ACPI Location or an Incomplete NVME ACPI location."
        _ = dialogOKCancel(textError)
        resetBuildButtonState()
        return
      }
      
      //2 - Check to see if Incomplete ACPI checkbox has been checked and is not empty
      if (incompleteCheckBox.state == 1) {
        if ((incompleteTextInput.stringValue).isEmpty) {
          textError = "You must include the Incomplete NVME ACPI Location!"
          _ = dialogOKCancel(textError)
          resetBuildButtonState()
          return
        } else {
          incompleteACPI = incompleteTextInput.stringValue
          }
      }
      arguments.append(incompleteACPI)
        
      
      //3 - Check to see if ACPI checkbox has been checked and is not empty
      if (completeCheckBox.state == 1) {
        if ((completeTextInput.stringValue).isEmpty) {
          textError = "You must include the ACPI NVME Location!"
          _ = dialogOKCancel(textError)
          resetBuildButtonState()
          return
        } else {
          completeACPI = completeTextInput.stringValue
        }
      }
      arguments.append(completeACPI)
      
      //4 - Check to see if PCI Bridge checkbox has been checked and is not empty
      if (pcibridgeCheckBox.state == 1) {
        if ((pcibridgeTextInput.stringValue).isEmpty) {
          textError = "You must include the PCI Bridge address location!"
          _ = dialogOKCancel(textError)
          resetBuildButtonState()
          return
        } else {
          pciBridge = pcibridgeTextInput.stringValue
        }
      }
      arguments.append(pciBridge)
      
    }
    //5 - Pass all args to script  
    runScript(arguments)
    }
  }
  
  // End script/exit app
  @IBAction func stopTask(_ sender:AnyObject) {
      buildTask.terminate()
  }
  
  // Run ssdtGen.command script
  func runScript(_ arguments:[String]) {
    
    //1 - Reset input boxes while script is running
    completeTextInput.stringValue = ""
    debugScript = ""
    incompleteTextInput.stringValue = ""
    pcibridgeTextInput.stringValue = ""
    
    //2 - Disable buttons while script is running
    buildButton.isEnabled = false
    buildAllButton.isEnabled = false
    debugButton.isEnabled = false
    ssdtList.isEnabled = false
    exitButton.isEnabled = false
    spinner.startAnimation(self)
    toggleNVMEBox(false)
    
    isRunning = true
    
    let taskQueue = DispatchQueue.global(qos: DispatchQoS.QoSClass.background)
    
    //2 - Start async task output
    taskQueue.async {
      
      //1 - Attempt to locate script
      guard let path = Bundle.main.path(forResource: "ssdtGen",ofType:"command") else {
        print("*—-ERROR—-* Unable to locate ssdtGen.command")
        return
      }
      
      //2 - Set up process with destination and args
      self.buildTask = Process()
      self.buildTask.launchPath = path
      self.buildTask.arguments = arguments
      
      //3 - Enable or disable buttons after output has terminated
      self.buildTask.terminationHandler = {
        
        task in
        DispatchQueue.main.async(execute: {
          self.completeCheckBox.state = 0
          self.incompleteCheckBox.state = 0
          self.pcibridgeCheckBox.state = 0
          self.buildButton.state = 0
          self.buildButton.isEnabled = true
          self.debugButton.state = 0
          self.debugButton.isEnabled = true
          self.buildAllButton.state = 0
          self.buildAllButton.isEnabled = true
          self.ssdtList.isEnabled = true
          self.exitButton.isEnabled = true
          self.ssdtList.selectItem(at: 0)
          self.spinner.stopAnimation(self)
          self.isRunning = false
        })
        
      }
      
      //4 - Capture output
      self.captureStandardOutputAndRouteToTextView(self.buildTask)
      
      //5 - Launch command script
      self.buildTask.launch()
      
      //6 - Wait until script file has ended
      self.buildTask.waitUntilExit()

    }
    
  }
  
  
  func captureStandardOutputAndRouteToTextView(_ task:Process) {
    
    //1.
    outputPipe = Pipe()
    task.standardOutput = outputPipe
    
    //2.
    outputPipe.fileHandleForReading.waitForDataInBackgroundAndNotify()
    
    //3.
    NotificationCenter.default.addObserver(forName: NSNotification.Name.NSFileHandleDataAvailable, object: outputPipe.fileHandleForReading , queue: nil) {
      notification in
      
      //4.
      let output = self.outputPipe.fileHandleForReading.availableData
      let outputString = String(data: output, encoding: String.Encoding.utf8) ?? ""
      
      //5.
      DispatchQueue.main.async(execute: {
        let previousOutput = self.outputText.string ?? ""
        let nextOutput = previousOutput + "\n" + outputString
        self.outputText.backgroundColor = NSColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1);
        self.outputText.string = nextOutput
        
        let range = NSRange(location:nextOutput.characters.count,length:0)
        self.outputText.scrollRangeToVisible(range)
        
      })
      
      //6.
      self.outputPipe.fileHandleForReading.waitForDataInBackgroundAndNotify()
      
      
    }
    
  }
  
  
}
