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

    @IBInspectable open var entryBorderColour: UIColor = CBPinEntryViewDefaults.entryBorderColour {
        didSet {
            if oldValue != entryBorderColour {
                updateButtonStyles()
            }
        }
    }

    @IBInspectable open var entryBackgroundColour: UIColor = CBPinEntryViewDefaults.entryBackgroundColour {
        didSet {
            if oldValue != entryBackgroundColour {
                updateButtonStyles()
            }
        }
    }

    @IBInspectable open var entryEditingBorderColour: UIColor = CBPinEntryViewDefaults.entryEditingBorderColour {
        didSet {
            if oldValue != entryEditingBorderColour {
                updateButtonStyles()
            }
        }
    }

    @IBInspectable open var entryEditingBackgroundColour: UIColor = CBPinEntryViewDefaults.entryEditingBackgroundColour {
        didSet {
            if oldValue != entryEditingBackgroundColour {
                updateButtonStyles()
            }
        }
    }

    @IBInspectable open var entryErrorBorderColour: UIColor = CBPinEntryViewDefaults.entryErrorColour

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

    open var textContentType: UITextContentType? {
        didSet {
            if #available(iOS 10, *) {
                if let contentType = textContentType {
                    textField.textContentType = contentType
                }
            }
        }
    }

    open var textFieldCapitalization: UITextAutocapitalizationType? {
        didSet {
            if let capitalization = textFieldCapitalization {
                textField.autocapitalizationType = capitalization
            }
        }
    }

    public enum AllowedEntryTypes: String {
        case any, numerical, alphanumeric, letters
    }

    open var allowedEntryTypes: AllowedEntryTypes = .numerical


    private var stackView: UIStackView?
    public private(set) var textField: PinEntryTextField!

    open var errorMode: Bool = false

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
        super.prepareForInterfaceBuilder()

        commonInit()
    }


    private func commonInit() {
        setupStackView()
        setupTextField()

        createButtons()
        configurePaste()
    }

    private func setupStackView() {
        stackView?.removeFromSuperview()

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
        textField = PinEntryTextField(frame: bounds)
        textField.delegate = self
        textField.keyboardType = UIKeyboardType(rawValue: keyboardType) ?? .numberPad
        textField.addTarget(self, action: #selector(textfieldChanged(_:)), for: .editingChanged)

        self.addSubview(textField)

        textField.isHidden = true
    }

    private func createButtons() {
        entryButtons.removeAll()

        for _ in 0..<length {
            let button = UIButton()
            button.backgroundColor = entryBackgroundColour
            button.setTitleColor(entryTextColour, for: .normal)
            button.titleLabel?.font = entryFont

            button.layer.cornerRadius = entryCornerRadius
            button.layer.borderColor = entryBorderColour.cgColor
            button.layer.borderWidth = entryBorderWidth

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
            button.layer.borderColor = entryBorderColour.cgColor
            button.layer.borderWidth = entryBorderWidth
        }
    }

    @objc private func didPressCodeButton(_ sender: UIButton) {
        errorMode = false

        let entryIndex = textField.text!.count
        if entryIndex < length {
            let button = entryButtons[entryIndex]
            button.layer.borderColor = entryEditingBorderColour.cgColor
            button.backgroundColor = entryEditingBackgroundColour
        }

        textField.becomeFirstResponder()
    }

    open func setError(isError: Bool) {
        if isError {
            errorMode = true
            for button in entryButtons {
                button.layer.borderColor = entryErrorBorderColour.cgColor
                button.layer.borderWidth = entryBorderWidth
            }
        } else {
            errorMode = false
            for button in entryButtons {
                button.layer.borderColor = entryBorderColour.cgColor
                button.backgroundColor = entryBackgroundColour
            }
        }
    }

    open func clearEntry() {
        setError(isError: false)
        textField.text = ""
        for button in entryButtons {
            button.setTitle("", for: .normal)
        }

        if let firstButton = entryButtons.first {
            didPressCodeButton(firstButton)
        }
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
        let willBecomeFirstResponder = super.becomeFirstResponder()
        if !willBecomeFirstResponder {
            if let firstButton = entryButtons.first {
                didPressCodeButton(firstButton)
            }
        }
        return willBecomeFirstResponder
    }

    @discardableResult open override func resignFirstResponder() -> Bool {
        let willResignFirstResponder = super.resignFirstResponder()
        if !willResignFirstResponder {
            setError(isError: false)
            textField.resignFirstResponder()
        }
        return willResignFirstResponder
    }
}

extension CBPinEntryView: UITextFieldDelegate {
    @objc func textfieldChanged(_ textField: UITextField) {
        let complete: Bool = textField.text!.count == length
        delegate?.entryChanged(complete)
    }

    public func textFieldDidEndEditing(_ textField: UITextField) {
        setError(isError: false)
    }

    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        for button in entryButtons {
            button.layer.borderColor = entryBorderColour.cgColor
            button.backgroundColor = entryBackgroundColour
        }
        textField.resignFirstResponder()
        return true
    }

    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        errorMode = false

        if UIMenuController.shared.isMenuVisible {
            UIMenuController.shared.setMenuVisible(false, animated: true)
        }

        if string.count > 0 {
            var allowed = true
            switch allowedEntryTypes {
            case .numerical: allowed = Scanner(string: string).scanInt(nil)
            case .letters: allowed = Scanner(string: string).scanCharacters(from: CharacterSet.letters, into: nil)
            case .alphanumeric: allowed = Scanner(string: string).scanCharacters(from: CharacterSet.alphanumerics, into: nil)
            case .any: break
            }

            if !allowed {
                return false
            }
        }

        let oldLength = textField.text!.count
        let replacementLength = string.count
        let rangeLength = range.length

        let newLength = oldLength - rangeLength + replacementLength
        let deleting = (range.length > 0 && newLength < oldLength && string == "")

        guard newLength <= length else { return false }

        if !deleting {
            let zipped = zip(entryButtons[oldLength..<newLength], string)
            for (button, char) in zipped {
                button.layer.borderColor = entryBorderColour.cgColor
                button.backgroundColor = entryBackgroundColour
                UIView.setAnimationsEnabled(false)
                if !isSecure {
                    button.setTitle(String(char), for: .normal)
                } else {
                    button.setTitle(secureCharacter, for: .normal)
                }
                UIView.setAnimationsEnabled(true)
            }
            if newLength < length {
                let button = entryButtons[newLength]
                button.layer.borderColor = entryEditingBorderColour.cgColor
                button.backgroundColor = entryEditingBackgroundColour
            }
        } else {
            let upperBound = oldLength < length ? oldLength + 1 : oldLength
            for (i, button) in entryButtons[newLength..<upperBound].enumerated() {
                button.layer.borderColor = i == 0 ? entryEditingBorderColour.cgColor : entryBorderColour.cgColor
                button.backgroundColor = i == 0 ? entryEditingBackgroundColour : entryBackgroundColour
                UIView.setAnimationsEnabled(false)
                if !isSecure {
                    button.setTitle(string, for: .normal)
                } else {
                    button.setTitle(secureCharacter, for: .normal)
                }
                UIView.setAnimationsEnabled(true)
            }
        }

        return true
    }
}

extension CBPinEntryView {
    private func configurePaste() {
        isUserInteractionEnabled = true
        addGestureRecognizer(UILongPressGestureRecognizer(
            target: self,
            action: #selector(showPasteMenu(sender:))
        ))
    }

    @objc private func showPasteMenu(sender: Any?) {
        let menu = UIMenuController.shared
        textField.becomeFirstResponder()
        if !menu.isMenuVisible {
            let buttonIndex = self.textField.text!.count
            if buttonIndex < length {
                let button = entryButtons[buttonIndex]
                menu.setTargetRect(button.frame, in: self)
                menu.setMenuVisible(true, animated: true)
            }
        }
    }
}

public class PinEntryTextField: UITextField {
    override public func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return (action == #selector(paste(_:)))
    }
}
