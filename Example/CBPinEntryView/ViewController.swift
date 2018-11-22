//
//  ViewController.swift
//  CBPinEntryView
//
//  Created by Chris Byatt on 03/18/2017.
//  Copyright (c) 2017 Chris Byatt. All rights reserved.
//

import UIKit
import CBPinEntryView

class ViewController: UIViewController {

    @IBOutlet var pinEntryView: CBPinEntryView! {
        didSet {
            pinEntryView.delegate = self
        }
    }
    @IBOutlet var stringOutputLabel: UILabel!

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if #available(iOS 12, *) {
            pinEntryView.textContentType = .oneTimeCode
        }
    }
    
    @IBAction func pressedGetCode(_ sender: UIButton) {
        stringOutputLabel.text = pinEntryView.getPinAsString()
        print(pinEntryView.getPinAsInt() ?? "Nothing entered")
        pinEntryView.resignFirstResponder()
    }

    @IBAction func toggleError(_ sender: UIButton) {
        if !pinEntryView.errorMode {
            pinEntryView.setError(isError: true)
        } else {
            pinEntryView.setError(isError: false)
        }
    }

    @IBAction func pressedClear(_ sender: UIButton) {
        pinEntryView.clearEntry()
    }
}

extension ViewController: CBPinEntryViewDelegate {
    func entryChanged(_ completed: Bool) {
        if completed {
            print(pinEntryView.getPinAsString())
        }
    }
}

