//
//  CBPinEntryView.swift
//  Pods
//
//  Created by Chris Byatt on 18/03/2017.
//
//

import UIKit

open class CBPinEntryView: UIView {

    @IBInspectable var length: Int = CBPinEntryViewDefaults.length

    @IBInspectable var entryCornerRadius: CGFloat = CBPinEntryViewDefaults.entryCornerRadius
    @IBInspectable var entryBorderColour: UIColor = CBPinEntryViewDefaults.entryBorderColour

    @IBInspectable var entryBackgroundColour: UIColor = CBPinEntryViewDefaults.entryBackgroundColour
    @IBInspectable var entryTextColour: UIColor = CBPinEntryViewDefaults.entryTextColour
    
    private var keyboardType: UIKeyboardType = .numberPad
    public var allowsSpaces = false

    @IBInspectable var entryFont: UIFont = CBPinEntryViewDefaults.entryFont {
        didSet {
            entryButtons.forEach {
                $0.titleLabel?.font = entryFont
            }
        }
    }
    
    var returnButtonAction: (()->Void)?
    
    private var stackView: UIStackView?
    var textField: UITextField!

    fileprivate var entryButtons: [UIButton] = [UIButton]()

    init(length: Int, keyboardType: UIKeyboardType) {
        self.length = length
        self.keyboardType = keyboardType
        super.init(frame: CGRect.zero)
        commonInit()
    }
    
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
        stackView!.spacing = 9

        self.addSubview(stackView!)
        stackView!.translatesAutoresizingMaskIntoConstraints = false
        stackView?.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        stackView?.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        stackView?.heightAnchor.constraint(equalTo: self.heightAnchor).isActive = true
        stackView?.widthAnchor.constraint(equalTo: self.widthAnchor).isActive = true
    }

    private func setupTextField() {
        textField = UITextField(frame: bounds)
        textField.delegate = self
        textField.keyboardType = keyboardType
        textField.autocapitalizationType = .none
        
        self.addSubview(textField)

        textField.isHidden = true
    }

    private func createButtons() {
        for i in 0..<length {
            let button = UIButton()
            button.backgroundColor = entryBackgroundColour
            button.setTitleColor(entryTextColour, for: .normal)
            button.titleLabel!.font = entryFont

            button.layer.cornerRadius = entryCornerRadius
            button.layer.borderColor = entryBorderColour.cgColor
            button.layer.borderWidth = 0.0

            button.tag = i + 1

            button.addTarget(self, action: #selector(didPressCodeButton(_:)), for: .touchUpInside)

            button.addBorder(side: .bottom, width: 1, color: UIColor.spGray)
            
            entryButtons.append(button)
            stackView?.addArrangedSubview(button)
        }
    }

    @objc func didPressCodeButton(_ sender: UIButton) {
        let entryIndex = textField.text!.count + 1

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
        let deleting = (range.location == textField.text!.count - 1 && range.length == 1 && string == "")

        let oldLength = textField.text!.count
        let replacementLength = string.count
        let rangeLength = range.length

        let newLength = oldLength - rangeLength + replacementLength

        if deleting {
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
        } else {
            guard string.count == 1 else {return false}
            if string.contains(" ") || string.contains("\n") { return false }
            
            guard let firstLetter = string.first else {return false}
            let trimmed = String(firstLetter).uppercased()
            
            for button in entryButtons {
                if button.tag == newLength {
                    button.layer.borderWidth = 0
                    UIView.setAnimationsEnabled(false)
                    button.setTitle(trimmed, for: .normal)
                    UIView.setAnimationsEnabled(true)
                } else if button.tag == newLength + 1 {
                    button.layer.borderWidth = 1
                } else {
                    button.layer.borderWidth = 0
                }
            }
        }

        // Uppercasing new string
        let change = newLength <= self.length
        if change, let uiTextRange = range.toTextRange(textInput: textField) {
            let uppercasedString = string.uppercased()
            textField.replace(uiTextRange, withText: uppercasedString)
        }
        
        return false
    }
    
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        returnButtonAction?()
        return false
    }
}

extension NSRange {
    func toTextRange(textInput:UITextInput) -> UITextRange? {
        if let rangeStart = textInput.position(from: textInput.beginningOfDocument, offset: location),
            let rangeEnd = textInput.position(from: rangeStart, offset: length) {
            return textInput.textRange(from: rangeStart, to: rangeEnd)
        }
        return nil
    }
}
