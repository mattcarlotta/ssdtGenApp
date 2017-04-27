//
//  HelpController.swift
//  ssdtGen
//
//  Created by m6d on 4/26/17.
//  Copyright © 2017 Ray Wenderlich. All rights reserved.
//

import Cocoa

class HelpController: NSViewController {

  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
    @IBAction func dismiss(_ sender: Any) {
        self.dismissViewController(self)
    }
    
    override func viewDidLoad() {
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = CGColor(red: 0/255, green: 67/255, blue: 125/255, alpha: 1);
    }
    
}
