//
//  ViewController.swift
//  e-imzo
//
//  Created by Jakhongir Nematov on 11/02/21.
//

import Cocoa
import ShellOut

enum State : String {
    case install
    case select
    case run
}

class ViewController: NSViewController {
    @IBOutlet weak var installLabel: NSTextField!
    @IBOutlet weak var installImageButton: NSButton!
    @IBOutlet weak var installNumberLabel: NSTextField!
    @IBOutlet weak var selectLabel: NSTextField!
    @IBOutlet weak var selectImageButton: NSButton!
    @IBOutlet weak var selectNumberLabel: NSTextField!
    @IBOutlet weak var runLabel: NSTextField!
    @IBOutlet weak var runImageButton: NSButton!
    @IBOutlet weak var runNumberLabel: NSTextField!
    @IBOutlet weak var firstArrow: NSButton!
    @IBOutlet weak var secondArrow: NSButton!
    @IBOutlet weak var nextButton: NSButton!
    
    var macName : String?
    let dskeys = "DSKEYS"
    var currentState : State = .install {
        didSet {
            UserDefaults.standard.setValue(currentState.rawValue, forKey: "currentState")
            switch currentState {
            case .install:
                nextButton.title = "Install"
            case .select:
                installLabel.textColor = .green
                installImageButton.contentTintColor = .green
                installNumberLabel.textColor = .green
                firstArrow.contentTintColor = .green
                nextButton.title = "Select"
            case .run:
                installLabel.textColor = .green
                installImageButton.contentTintColor = .green
                installNumberLabel.textColor = .green
                firstArrow.contentTintColor = .green
                nextButton.title = "Select"
                selectLabel.textColor = .green
                selectImageButton.contentTintColor = .green
                selectNumberLabel.textColor = .green
                secondArrow.contentTintColor = .green
                nextButton.title = "Run"
            }
        }
    }
    
    var password : String? {
        didSet {
            if currentState == .install {
                installation()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        let domain = Bundle.main.bundleIdentifier!
//        UserDefaults.standard.removePersistentDomain(forName: domain)
//        UserDefaults.standard.synchronize()
        if let currentStateString = UserDefaults.standard.string(forKey: "currentState") {
            currentState = State(rawValue: currentStateString) ?? .install
        }
        
        if let password = UserDefaults.standard.string(forKey: "password") {
            self.password = password
        }
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        view.window?.isOpaque = false
        view.window?.backgroundColor = NSColor.black.withSystemEffect(.pressed).withAlphaComponent(0.8)
    }
    
    @IBAction func nextAction(_ sender: Any) {
        switch currentState {
        case .install:
            askForPassword()
        case .select:
            selectFile()
        case .run:
            run()
        }
    }
    
    func askForPassword() {
        let passwordText = getString(title: "Enter Your Mac Password", placeholderString: "Password")
        UserDefaults.standard.setValue(passwordText, forKey: "password")
        password = passwordText
    }
    
    func installation() {
        do {
            self.macName = try shellOut(to: "scutil --get ComputerName")
        } catch let error as NSError {
            print(error)
        }
        
        guard let macName = self.macName , let password = self.password else { return }
        do {
            try shellOut(to: ["echo '\(password)' | sudo -S mkdir '\(macName)'", "echo '\(password)' | sudo -S mkdir '\(macName)/\(self.dskeys)'"], at: "/Volumes")
        } catch let error as NSError {
            print(error)
        }
        
        if let bundleFile = Bundle.main.url(forResource: "E-IMZO", withExtension: "zip") {
            let savePanel = NSSavePanel()
            
            // this is a preferred method to get the desktop URL
            savePanel.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

            savePanel.message = "Save E-IMZO Files"
            savePanel.nameFieldStringValue = "E-IMZO.zip"
            savePanel.showsHiddenFiles = false
            savePanel.showsTagField = false
            savePanel.canCreateDirectories = true
            
            if let url = savePanel.url, savePanel.runModal().rawValue == NSApplication.ModalResponse.OK.rawValue {
                print("Now copying", bundleFile.path, "to", url.path)
                // Do the actual copy:
                do {
                    try FileManager().copyItem(at: bundleFile, to: url)
                    guard let directory = savePanel.directoryURL?.path else { return }
                    do {
                        try shellOut(to: ["mv 'untitled' 'E-IMZO.zip'"], at: directory)
                        try shellOut(to: "echo '\(password)' | sudo -S cp '\(directory)/E-IMZO.zip' '/Volumes/\(macName)'")
                        try shellOut(to: ["echo '\(password)' | sudo -S unzip 'E-IMZO.zip'"], at: "/Volumes/\(macName)")
                        try shellOut(to: ["echo '\(password)' | sudo -S rm 'E-IMZO.zip'"], at: "/Volumes/\(macName)")
                        currentState = .select
                    } catch let error as NSError {
                        print(error)
                    }
                } catch {
                    print(error.localizedDescription)
                }
            } else {
                print("canceled")
            }
        }
    }
    
    
    func selectFile() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.allowedFileTypes = ["pfx"]
        openPanel.directoryURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        openPanel.title = "Select"
        
        openPanel.beginSheetModal(for:self.view.window!) { (response) in
            if response == .OK {
                let selectedPath = openPanel.url!.path
                
                guard let macName = self.macName , let password = self.password else { return }
                do {
                    try shellOut(to: "echo '\(password)' | sudo -S cp '\(selectedPath)' '/Volumes/\(macName)/\(self.dskeys)'")
                    self.currentState = .run
                } catch let error as NSError {
                    print(error)
                }
            }
            openPanel.close()
        }
    }
    
    func run() {
        
        do {
            self.macName = try shellOut(to: "scutil --get ComputerName")
        } catch let error as NSError {
            print(error)
        }
        
        guard let macName = self.macName else { return }
        do {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                NSApp.terminate(self)
            }
            try shellOut(to: ["sh E-IMZO.sh"], at: "/Volumes/\(macName)/E-IMZO")
        } catch let error as NSError {
            print(error)
        }
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    func getString(title: String, placeholderString: String) -> String {
        let msg = NSAlert()
        msg.addButton(withTitle: "OK")      // 1st button
        msg.addButton(withTitle: "Cancel")  // 2nd button
        msg.messageText = title

        let txt = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 230, height: 24))
        txt.placeholderString = placeholderString
        

        msg.accessoryView = txt
        
        let response: NSApplication.ModalResponse = msg.runModal()

        if (response == NSApplication.ModalResponse.alertFirstButtonReturn) {
            return txt.stringValue
        } else {
            return ""
        }
    }
    
    
}

