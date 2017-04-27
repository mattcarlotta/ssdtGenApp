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
  
  dynamic var isRunning = false
  var outputPipe:Pipe!
  var buildTask:Process!
  
  
  override func viewDidLoad() {
    self.view.wantsLayer = true
    self.view.layer?.backgroundColor = CGColor(red: 0/255, green: 67/255, blue: 125/255, alpha: 1);
    self.outputText.backgroundColor = NSColor(red: 170/255, green: 170/255, blue: 170/255, alpha: 1);
  }
  // Help button action
  @IBAction func helpButton(_ sender: Any) {
    //1.
    outputText.string = ""
    
    //2
    let helpDialogue = "help"
    
    //3
    var arguments:[String] = []
    arguments.append(helpDialogue)
    
    //6
    runScript(arguments)
  }
  
  // BuildAll button action
  @IBAction func buildAllSSDT(_ sender: AnyObject) {
    
    //1.
    outputText.string = ""
    
    //2
    let buildAll = "buildall"
    
    //3
    var arguments:[String] = []
    arguments.append(buildAll)
    
    //6.
    buildButton.isEnabled = false
    buildAllButton.isEnabled = false
    spinner.startAnimation(self)
    
    runScript(arguments)

  }
  
  // BuildOne button action
  @IBAction func buildOne(_ sender:AnyObject) {
    
    if (userInput.stringValue).isEmpty {
      outputText.string = "Please add input before pressing build!"
    } else {
    //1.
    outputText.string = ""
    
    //3
    var arguments:[String] = []
    arguments.append("build " + userInput.stringValue)
    
    //6.
    userInput.stringValue = ""
    buildButton.isEnabled = false
    buildAllButton.isEnabled = false
    spinner.startAnimation(self)
      
    runScript(arguments)
    }
  }
  
  @IBAction func stopTask(_ sender:AnyObject) {
    
      buildTask.terminate()
   
  }
  
  func runScript(_ arguments:[String]) {
    
    //1.
    isRunning = true
    
    let taskQueue = DispatchQueue.global(qos: DispatchQoS.QoSClass.background)
    
    //2.
    taskQueue.async {
      
      //1.
      guard let path = Bundle.main.path(forResource: "ssdtGen",ofType:"command") else {
        print("Unable to locate ssdtGen.command")
        return
      }
      
      //2.
      self.buildTask = Process()
      self.buildTask.launchPath = path
      self.buildTask.arguments = arguments
      
      //3.
      self.buildTask.terminationHandler = {
        
        task in
        DispatchQueue.main.async(execute: {
          self.buildButton.isEnabled = true
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
