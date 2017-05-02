# CBPinEntryView

[![Version](https://img.shields.io/cocoapods/v/CBPinEntryView.svg?style=flat)](http://cocoapods.org/pods/CBPinEntryView)
[![License](https://img.shields.io/cocoapods/l/CBPinEntryView.svg?style=flat)](http://cocoapods.org/pods/CBPinEntryView)
[![Platform](https://img.shields.io/cocoapods/p/CBPinEntryView.svg?style=flat)](http://cocoapods.org/pods/CBPinEntryView)

CBPinEntryView is a view written in Swift to allow easy and slick entry of pins or codes. It allows backspacing, dismissal of keyboard and continuation, the whole code is given as a single String or Int and the view is very easily customisable in code or the storyboard.

<img src='http://i.imgur.com/dAdUVkp.gif' alt='Showing easy entry and deletion' width='350'>

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Installation

CBPinEntryView is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "CBPinEntryView"
```
Put a view into your storyboard or xib and set it's class to `CBPinEntryView`. Create an outlet in your file and customise either with the IBInspectable properties or in your code.

Get the code with either `entryView.getPinAsString()` or `entryView.getPinAsInt()`.

There is now also an error mode which can be toggled with `entryView.toggleError()`. It is automatically removed if the user taps on the field or starts typing again.

## Author

Chris Byatt, byatt.chris@gmail.com

## License

CBPinEntryView is available under the MIT license. See the LICENSE file for more info.
