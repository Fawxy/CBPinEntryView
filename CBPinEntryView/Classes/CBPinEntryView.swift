//
//  CBPinEntryView.swift
//  Pods
//
//  Created by Chris Byatt on 18/03/2017.
//
//

import UIKit

@IBDesignable open class CBPinEntryView: UIView {

    @IBInspectable var length: Int = CBPinEntryViewDefaults.length

    @IBInspectable var entryCornerRadius: CGFloat = CBPinEntryViewDefaults.entryCornerRadius
    @IBInspectable var entryBorderColour: UIColor = CBPinEntryViewDefaults.entryBorderColour

    @IBInspectable var entryBackgroundColour: UIColor = CBPinEntryViewDefaults.entryBackgroundColour
    @IBInspectable var entryTextColour: UIColor = CBPinEntryViewDefaults.entryTextColour

    @IBInspectable var entryFont: UIFont = CBPinEntryViewDefaults.entryFont

    private var stackView: UIStackView?
    private var textField: UITextField!

    fileprivate var entryButtons: [UIButton] = [UIButton]()

    override public init(frame: CGRect) {
        super.init(frame: frame)

        commonInit()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override open func awakeFromNib() {
        super.awakeFromNib()

        commonInit()
    }

    override open func prepareForInterfaceBuilder() {
        commonInit()
    }


    private func commonInit() {
        setupStackView()
        setupTextField()

        createButtons()
    }

    private func setupStackView() {
        stackView = UIStackView(frame: bounds)
        stackView!.alignment = .fill
        stackView!.axis = .horizontal
        stackView!.distribution = .fillEqually
        stackView!.spacing = 10

        self.addSubview(stackView!)
    }

    private func setupTextField() {
        textField = UITextField(frame: bounds)
        textField.delegate = self
        textField.keyboardType = .numberPad

        self.addSubview(textField)

        textField.isHidden = true
    }

    private func createButtons() {
        for i in 0..<length {
            let button = UIButton()
            button.backgroundColor = UIColor.white
            button.setTitleColor(entryTextColour, for: .normal)
            button.titleLabel!.font = entryFont

            button.layer.cornerRadius = entryCornerRadius
            button.layer.borderColor = entryBorderColour.cgColor
            button.layer.borderWidth = 0.0

            button.tag = i + 1

            button.addTarget(self, action: #selector(didPressCodeButton(_:)), for: .touchUpInside)

            entryButtons.append(button)
            stackView?.addArrangedSubview(button)
        }
    }

    @objc func didPressCodeButton(_ sender: UIButton) {
        let entryIndex = textField.text!.characters.count + 1

        for button in entryButtons {
            if button.tag == entryIndex {
                button.layer.borderWidth = 1
            } else {
                button.layer.borderWidth = 0
            }
        }
        
        textField.becomeFirstResponder()
    }

    open func getPinAsInt() -> Int? {
        if let intOutput = Int(textField.text!) {
            return intOutput
        }

        return nil
    }

    open func getPinAsString() -> String {
        return textField.text!
    }
}

extension CBPinEntryView: UITextFieldDelegate {
    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let deleting = (range.location == textField.text!.characters.count - 1 && range.length == 1 && string == "")

        if string.characters.count > 0 && !Scanner(string: string).scanInt(nil) {
            return false
        }

        let oldLength = textField.text!.characters.count
        let replacementLength = string.characters.count
        let rangeLength = range.length

        let newLength = oldLength - rangeLength + replacementLength

        if !deleting {
            for button in entryButtons {
                if button.tag == newLength {
                    button.layer.borderWidth = 0
                    UIView.setAnimationsEnabled(false)
                    button.setTitle(string, for: .normal)
                    UIView.setAnimationsEnabled(true)
                } else if button.tag == newLength + 1 {
                    button.layer.borderWidth = 1
                } else {
                    button.layer.borderWidth = 0
                }
            }
        } else {
            for button in entryButtons {
                if button.tag == oldLength {
                    button.layer.borderWidth = 1
                    UIView.setAnimationsEnabled(false)
                    button.setTitle("", for: .normal)
                    UIView.setAnimationsEnabled(true)
                } else {
                    button.layer.borderWidth = 0
                }
            }
        }

        return newLength <= 5
    }
}
