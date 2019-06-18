# CBPinEntryView

[![Version](https://img.shields.io/cocoapods/v/CBPinEntryView.svg?style=flat)](http://cocoapods.org/pods/CBPinEntryView)
[![License](https://img.shields.io/cocoapods/l/CBPinEntryView.svg?style=flat)](http://cocoapods.org/pods/CBPinEntryView)
[![Platform](https://img.shields.io/cocoapods/p/CBPinEntryView.svg?style=flat)](http://cocoapods.org/pods/CBPinEntryView)

CBPinEntryView is a view written in Swift to allow easy and slick entry of pins, codes or passwords. It allows backspacing, dismissal of keyboard and continuing where you left off, the whole code is given as a single String or Int and the view is very easily customisable in code or the storyboard.

## Preview



| Enter pins easily! | Communicate user error | Clear the text field to retry | Secure entry mode |
|:------------------:|:----------------------:|:-----------------------------:|:-----------------:|
| ![](http://i.imgur.com/75oYhG5.gif) | ![](http://i.imgur.com/UU5Xm7X.gif) | ![](http://i.imgur.com/ABZH0Ea.gif) | ![](http://i.imgur.com/zAhXL7O.gif) |

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Installation

CBPinEntryView is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "CBPinEntryView"
```
Put a view into your storyboard or xib and set it's class to `CBPinEntryView`. Create an outlet in your file and customise either with the IBInspectable properties or in your code.

### Get the code

Get the code with either `entryView.getPinAsString()` or `entryView.getPinAsInt()`.

### Entry callbacks

There are two delegate methods `entryChanged(_ completed: Bool)` and `entryCompleted(with entry: String?)`. The first will let you know each time the entry is changed, and whether they have completed the entry. The second function will get called when the user fills out the entry to completion and the entered pin will be passed.

### Secure entry

Secure entry with customisable secure character (change from ● to ✱ or any other character). Enable `isSecure`.
Change the secure entry character by setting the `secureCharacter` property.

### Display errors

There is an error mode which can be enabled with `pinEntryView.setError(isError: true)` and disabled with `pinEntryView.setError(isError: false)`. Whether error mode is enabled can be checked with `pinEntryView.errorMode`. Calling `pinEntryView.resignFirstResponder()` will hide the keyboard and disable the error mode.

### Allow or restrict characters

Set `allowedEntryTypes` and choose between `any`, `numerical`, `alphanumeric`, `letters` to enable or restrict characters. Set `textFieldCapitalization` to choose what kind of capitalisation you would like on the text field.

### Customise keyboard type!

The keyboard types are an enum with int raw values. Options are as follows:

```
0: default // Default type for the current input method.
1: asciiCapable // Displays a keyboard which can enter ASCII characters
2: numbersAndPunctuation // Numbers and assorted punctuation.
3: URL // A type optimized for URL entry (shows . / .com prominently).
4: numberPad // A number pad with locale-appropriate digits (0-9, ۰-۹, ०-९, etc.). Suitable for PIN entry.
5: phonePad // A phone pad (1-9, *, 0, #, with letters under the numbers).
6: namePhonePad // A type optimized for entering a person's name or phone number.
7: emailAddress // A type optimized for multiple email address entry (shows space @ . prominently).
8: decimalPad // A number pad with a decimal point.
9: twitter // A type optimized for twitter text entry (easy access to @ #)
```

## License

CBPinEntryView is available under the MIT license. See the LICENSE file for more info.
