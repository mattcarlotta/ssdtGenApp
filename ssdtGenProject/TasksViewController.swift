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
  @IBOutlet var userInput: NSTextField!
  @IBOutlet var buildAllButton: NSButton!
  @IBOutlet var debugButton: NSButton!
  @IBOutlet var acpiCheckBox: NSButton!
  @IBOutlet var acpiTextInput: NSTextField!
  @IBOutlet var pcibridgeCheckBox: NSButton!
  @IBOutlet var pcibridgeTextInput: NSTextField!
  @IBOutlet var incompleteCheckBox: NSButton!
  @IBOutlet var incompleteTextInput: NSTextField!
  
  dynamic var isRunning = false
  var outputPipe:Pipe!
  var buildTask:Process!
  var debugScript = ""
  var buildSSDT = ""
  var choice3 = ""
  var choice4 = ""
  var choice5 = ""
 
  override func viewDidLoad() {
    self.view.wantsLayer = true
//    self.view.layer?.backgroundColor = CGColor(red: 0/255, green: 67/255, blue: 125/255, alpha: 1);
//    self.outputText.backgroundColor = NSColor(red: 170/255, green: 170/255, blue: 170/255, alpha: 1);
  }
//    @IBAction func checkBoxDebug(_ sender: Any) {
//        if ((sender as AnyObject).state == NSOnState) {
//            print("Checked")
//            print(acpiCheckBox.state)
//        }
//        else {
//           print("Unchecked")
//           print(acpiCheckBox.state)
//        }
//    }
  
  @IBAction func setDebugMode(_ sender: Any) {
    if ((sender as AnyObject).state == NSOnState) {
        debugScript = "debug"
        print(debugScript)
      } else {
        debugScript = ""
        print(debugScript)
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
    
  // BuildOne button action
  @IBAction func buildOne(_ sender:AnyObject) {
    
    if (userInput.stringValue).isEmpty {
      outputText.string = "*—-ERROR—-* Please add input before pressing build!"
    } else {
    
    // Clear output
    outputText.string = ""
      
    // Set Choice Option
    buildSSDT = ("build " + userInput.stringValue)
    
    // Set arguments to pass to script
    var arguments:[String] = []
    arguments.append(debugScript)
    arguments.append(buildSSDT)
    
    if (userInput.stringValue == "NVME") {
      
      // check to make sure either ACPI or Incomplete has been checked
      if (acpiCheckBox.state == 0 && incompleteCheckBox.state == 0 || acpiCheckBox.state == 1 &&  incompleteCheckBox.state == 1 ) {
        outputText.string = "*—-ERROR—-* You can only select either a complete ACPI Location or Incomplete ACPI location."
        return
      }
      
      // check to see if ACPI checkbox has been checked and is not empty
      if (acpiCheckBox.state == 1) {
        if ((acpiTextInput.stringValue).isEmpty) {
          outputText.string = "*—-ERROR—-* You must include the ACPI Location!"
          return
        } else {
          arguments.append(acpiTextInput.stringValue)
        }
      }
      
      // check to see if PCI Bridge checkbox has been checked and is not empty
      if (pcibridgeCheckBox.state == 1) {
        if ((pcibridgeTextInput.stringValue).isEmpty) {
          outputText.string = "*—-ERROR—-* You must include the PCI Bridge Location!"
          return
        } else {
          arguments.append(incompleteCheckBox.stringValue)
        }
      }
      
      // check to see if Incomplete ACPI checkbox has been checked and is not empty
      if (incompleteCheckBox.state == 1) {
        if ((incompleteTextInput.stringValue).isEmpty) {
          outputText.string = "*—-ERROR—-* You must include the Incomplete ACPI Location!"
          return
        } else {
          arguments.append(incompleteCheckBox.stringValue)
        }
      }
      

    }

    //6.
      
    runScript(arguments)
    }
  }
  
  @IBAction func stopTask(_ sender:AnyObject) {
    
      buildTask.terminate()
   
  }
    
  func runScript(_ arguments:[String]) {
    
    //1 - Reset text boxs while script is running
    acpiTextInput.stringValue = ""
    userInput.stringValue = ""
    
    //2 - Disable buttons while script is running
    acpiCheckBox.isEnabled = false
    buildButton.isEnabled = false
    buildAllButton.isEnabled = false
    debugButton.isEnabled = false
    spinner.startAnimation(self)
    
    isRunning = true
    
    let taskQueue = DispatchQueue.global(qos: DispatchQoS.QoSClass.background)
    
    //2.
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
      
      //3 - Enable buttons after output has terminated
      self.buildTask.terminationHandler = {
        
        task in
        DispatchQueue.main.async(execute: {
          self.acpiCheckBox.state = 0
          self.acpiCheckBox.isEnabled = true
          self.buildButton.isEnabled = true
          self.debugButton.isEnabled = true
          self.debugButton.state = 0
          self.buildAllButton.isEnabled = true
          self.spinner.stopAnimation(self)
          self.isRunning = false
        })
        
      }
      
      self.captureStandardOutputAndRouteToTextView(self.buildTask)
      
      //4.
      self.buildTask.launch()
      
      //5.
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
        self.outputText.backgroundColor = NSColor(red: 249/255, green: 250/255, blue: 215/255, alpha: 1);
        self.outputText.string = nextOutput
        
        let range = NSRange(location:nextOutput.characters.count,length:0)
        self.outputText.scrollRangeToVisible(range)
        
      })
      
      //6.
      self.outputPipe.fileHandleForReading.waitForDataInBackgroundAndNotify()
      
      
    }
    
  }
  
  
}
