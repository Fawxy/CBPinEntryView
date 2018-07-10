//
//  CBPinEntryView.swift
//  Pods
//
//  Created by Chris Byatt on 18/03/2017.
//
//

import UIKit

public protocol CBPinEntryViewDelegate: class {
    func entryChanged(_ completed: Bool)
}

@IBDesignable open class CBPinEntryView: UIView {

    @IBInspectable open var length: Int = CBPinEntryViewDefaults.length
    
    @IBInspectable open var spacing: CGFloat = CBPinEntryViewDefaults.spacing

    @IBInspectable open var entryCornerRadius: CGFloat = CBPinEntryViewDefaults.entryCornerRadius {
        didSet {
            if oldValue != entryCornerRadius {
                updateButtonStyles()
            }
        }
    }

    @IBInspectable open var entryBorderWidth: CGFloat = CBPinEntryViewDefaults.entryBorderWidth {
        didSet {
            if oldValue != entryBorderWidth {
                updateButtonStyles()
            }
        }
    }

    @IBInspectable open var entryDefaultBorderColour: UIColor = CBPinEntryViewDefaults.entryDefaultBorderColour {
        didSet {
            if oldValue != entryDefaultBorderColour {
                updateButtonStyles()
            }
        }
    }

    @IBInspectable open var entryBorderColour: UIColor = CBPinEntryViewDefaults.entryBorderColour {
        didSet {
            if oldValue != entryBorderColour {
                updateButtonStyles()
            }
        }
    }

    @IBInspectable open var entryErrorBorderColour: UIColor = CBPinEntryViewDefaults.entryErrorColour

    @IBInspectable open var entryBackgroundColour: UIColor = CBPinEntryViewDefaults.entryBackgroundColour {
        didSet {
            if oldValue != entryBackgroundColour {
                updateButtonStyles()
            }
        }
    }

    @IBInspectable open var entryTextColour: UIColor = CBPinEntryViewDefaults.entryTextColour {
        didSet {
            if oldValue != entryTextColour {
                updateButtonStyles()
            }
        }
    }

    @IBInspectable open var entryFont: UIFont = CBPinEntryViewDefaults.entryFont {
        didSet {
            if oldValue != entryFont {
                updateButtonStyles()
            }
        }
    }

    @IBInspectable open var isSecure: Bool = CBPinEntryViewDefaults.isSecure

    @IBInspectable open var secureCharacter: String = CBPinEntryViewDefaults.secureCharacter

    @IBInspectable open var keyboardType: Int = CBPinEntryViewDefaults.keyboardType

    private var stackView: UIStackView?
    private var textField: UITextField!

    fileprivate var errorMode: Bool = false

    fileprivate var entryButtons: [UIButton] = [UIButton]()

    public weak var delegate: CBPinEntryViewDelegate?

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
        stackView!.spacing = spacing
        stackView!.translatesAutoresizingMaskIntoConstraints = false
        
        self.addSubview(stackView!)
        
        stackView!.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0).isActive = true
        stackView!.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 0).isActive = true
        stackView!.topAnchor.constraint(equalTo: topAnchor, constant: 0).isActive = true
        stackView!.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0).isActive = true
    }

    private func setupTextField() {
        textField = UITextField(frame: bounds)
        textField.delegate = self
        textField.keyboardType = UIKeyboardType(rawValue: keyboardType) ?? .numberPad
        textField.addTarget(self, action: #selector(textfieldChanged(_:)), for: .editingChanged)

        self.addSubview(textField)

        textField.isHidden = true
    }

    private func createButtons() {
        for i in 0..<length {
            let button = UIButton()
            button.backgroundColor = entryBackgroundColour
            button.setTitleColor(entryTextColour, for: .normal)
            button.titleLabel?.font = entryFont

            button.layer.cornerRadius = entryCornerRadius
            button.layer.borderColor = entryDefaultBorderColour.cgColor
            button.layer.borderWidth = entryBorderWidth

            button.tag = i + 1

            button.addTarget(self, action: #selector(didPressCodeButton(_:)), for: .touchUpInside)

            entryButtons.append(button)
            stackView?.addArrangedSubview(button)
        }
    }

    private func updateButtonStyles() {
        for button in entryButtons {
            button.backgroundColor = entryBackgroundColour
            button.setTitleColor(entryTextColour, for: .normal)
            button.titleLabel?.font = entryFont

            button.layer.cornerRadius = entryCornerRadius
            button.layer.borderColor = entryDefaultBorderColour.cgColor
            button.layer.borderWidth = entryBorderWidth
        }
    }

    @objc private func didPressCodeButton(_ sender: UIButton) {
        errorMode = false
        
        let entryIndex = textField.text!.count + 1
        for button in entryButtons {
            button.layer.borderColor = entryBorderColour.cgColor

            if button.tag == entryIndex {
                button.layer.borderColor = entryBorderColour.cgColor
            } else {
                button.layer.borderColor = entryDefaultBorderColour.cgColor
            }
        }
        
        textField.becomeFirstResponder()
    }

    open func toggleError() {
        if !errorMode {
            for button in entryButtons {
                button.layer.borderColor = entryErrorBorderColour.cgColor
                button.layer.borderWidth = entryBorderWidth
            }
        } else {
            for button in entryButtons {
                button.layer.borderColor = entryBorderColour.cgColor
            }
        }

        errorMode = !errorMode
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
    
    @discardableResult open override func becomeFirstResponder() -> Bool {
        super.becomeFirstResponder()
        
        if let firstButton = entryButtons.first {
            didPressCodeButton(firstButton)
        }
        
        return true
    }
    
    @discardableResult open override func resignFirstResponder() -> Bool {
        super.resignFirstResponder()
        clearError()
        return textField.resignFirstResponder()
    }

    open func clearError() {
        errorMode = false
        entryButtons.forEach {
            $0.layer.borderColor = entryBorderColour.cgColor
        }
    }

    open func clear() {
        clearError()
        textField.text = ""
        entryButtons.forEach {
            $0.setTitle("", for: .normal)
        }
    }
}

extension CBPinEntryView: UITextFieldDelegate {
    @objc func textfieldChanged(_ textField: UITextField) {
        let complete: Bool = textField.text!.count == length
        delegate?.entryChanged(complete)
    }

    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        clearError()

        let deleting = (range.location == textField.text!.count - 1 && range.length == 1 && string == "")

        if string.count > 0 && !Scanner(string: string).scanInt(nil) {
            return false
        }

        let oldLength = textField.text!.count
        let replacementLength = string.count
        let rangeLength = range.length

        let newLength = oldLength - rangeLength + replacementLength

        if !deleting {
            for button in entryButtons {
                if button.tag == newLength {
                    button.layer.borderColor = entryDefaultBorderColour.cgColor
                    UIView.setAnimationsEnabled(false)
                    if !isSecure {
                        button.setTitle(string, for: .normal)
                    } else {
                        button.setTitle(secureCharacter, for: .normal)
                    }
                    UIView.setAnimationsEnabled(true)
                } else if button.tag == newLength + 1 {
                    button.layer.borderColor = entryBorderColour.cgColor
                } else {
                    button.layer.borderColor = entryDefaultBorderColour.cgColor
                }
            }
        } else {
            for button in entryButtons {
                if button.tag == oldLength {
                    button.layer.borderColor = entryBorderColour.cgColor
                    UIView.setAnimationsEnabled(false)
                    button.setTitle("", for: .normal)
                    UIView.setAnimationsEnabled(true)
                } else {
                    button.layer.borderColor = entryDefaultBorderColour.cgColor
                }
            }
        }

        return newLength <= length
    }
}
