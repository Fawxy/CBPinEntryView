#
# Be sure to run `pod lib lint CBPinEntryView.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'CBPinEntryView'
  s.version          = '1.5.3'
  s.summary          = 'A view for entering arbitrary length numerical pins or codes written in Swift 4.0.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
This view allows a user to enter a pin or code (for security/mobile verification etc) of any length. It allows deletion, continuation, secure entry, and allows you to get the entire entered code as a single String or Int without having to join Strings from multiple text fields. It's fast, looks nice (I think) and is customisable! Requires iOS 9+.
                       DESC

  s.homepage         = 'https://github.com/Fawxy/CBPinEntryView'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Chris Byatt' => 'byatt.chris@gmail.com' }
  s.source           = { :git => 'https://github.com/Fawxy/CBPinEntryView.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/ChrisByatt'

  s.ios.deployment_target = '9.0'

  s.source_files = 'CBPinEntryView/Classes/**/*'
end
