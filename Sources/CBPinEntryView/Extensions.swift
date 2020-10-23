//
//  Extensions.swift
//  FavoriteStart
//
//  Created by Rafael Machado on 2/9/15.
//  Copyright (c) 2015 Rafael Machado. All rights reserved.
//

import UIKit
import Foundation
import AVFoundation
//import MBProgressHUD
import MapKit
import Photos

extension UIImage {
    
    func filled(with color: UIColor) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        color.setFill()
        guard let context = UIGraphicsGetCurrentContext() else { return self }
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1.0, y: -1.0);
        context.setBlendMode(CGBlendMode.normal)
        let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        guard let mask = self.cgImage else { return self }
        context.clip(to: rect, mask: mask)
        context.fill(rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }
    
    static let pin = UIImage(named: "pin_big_circal")?.filled(with: .green)
    static let pin2 = UIImage(named: "pin_mediam_circal")?.filled(with: .green)
    static let me = UIImage(named: "pin_small_circal")?.filled(with: .blue)
    
}

extension UIColor {
    class var green: UIColor { return UIColor(red: 76 / 255, green: 217 / 255, blue: 100 / 255, alpha: 1) }
    class var blue: UIColor { return UIColor(red: 0, green: 122 / 255, blue: 1, alpha: 1) }
}

extension MKMapView {
    func annotationView<T: MKAnnotationView>(of type: T.Type, annotation: MKAnnotation?, reuseIdentifier: String) -> T {
        guard let annotationView = dequeueReusableAnnotationView(withIdentifier: reuseIdentifier) as? T else {
            return type.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        }
        annotationView.annotation = annotation
        return annotationView
    }
}

extension MKMapRect {
    init(minX: Double, minY: Double, maxX: Double, maxY: Double) {
        self.init(x: minX, y: minY, width: abs(maxX - minX), height: abs(maxY - minY))
    }
    init(x: Double, y: Double, width: Double, height: Double) {
        self.init(origin: MKMapPoint(x: x, y: y), size: MKMapSize(width: width, height: height))
    }
    func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        return self.contains(MKMapPoint(coordinate))
    }
}

let CLLocationCoordinate2DMax = CLLocationCoordinate2D(latitude: 90, longitude: 180)
let MKMapPointMax = MKMapPoint(CLLocationCoordinate2DMax)

//extension CLLocationCoordinate2D: Hashable {
//    public func hash(into hasher: inout Hasher) {
//        hasher.combine(latitude)
//        hasher.combine(longitude)
//    }
//}

public func ==(lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
    return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
}

extension Double {
    var zoomLevel: Double {
        let maxZoomLevel = log2(MKMapSize.world.width / 256) // 20
        let zoomLevel = floor(log2(self) + 0.5) // negative
        return max(0, maxZoomLevel + zoomLevel) // max - current
    }
}

public func milesToMeters(miles: Double) -> Double {
    // 1 mile is 1609.344 meters
    // source: http://www.google.com/search?q=1+mile+in+meters
    return 1609.344 * miles;
}

public func metersToMiles(meters: Double) -> Double {
    // 1 mile is 1609.344 meters
    // source: http://www.google.com/search?q=1+mile+in+meters
    return meters / 1609.344;
}

private let radiusOfEarth: Double = 6372797.6

extension CLLocationCoordinate2D {
    func coordinate(onBearingInRadians bearing: Double, atDistanceInMeters distance: Double) -> CLLocationCoordinate2D {
        let distRadians = distance / radiusOfEarth // earth radius in meters
        
        let lat1 = latitude * .pi / 180
        let lon1 = longitude * .pi / 180
        
        let lat2 = asin(sin(lat1) * cos(distRadians) + cos(lat1) * sin(distRadians) * cos(bearing))
        let lon2 = lon1 + atan2(sin(bearing) * sin(distRadians) * cos(lat1), cos(distRadians) - sin(lat1) * sin(lat2))
        
        return CLLocationCoordinate2D(latitude: lat2 * 180 / .pi, longitude: lon2 * 180 / .pi)
    }
    var location: CLLocation {
        return CLLocation(latitude: latitude, longitude: longitude)
    }
    func distance(from coordinate: CLLocationCoordinate2D) -> CLLocationDistance {
        return location.distance(from: coordinate.location)
    }
}

extension Array where Element: MKAnnotation {
    func subtracted(_ other: [Element]) -> [Element] {
        return filter { item in !other.contains { $0.isEqual(item) } }
    }
    mutating func subtract(_ other: [Element]) {
        self = self.subtracted(other)
    }
    mutating func add(_ other: [Element]) {
        self.append(contentsOf: other)
    }
    @discardableResult
    mutating func remove(_ item: Element) -> Element? {
        return firstIndex { $0.isEqual(item) }.map { remove(at: $0) }
    }
}

extension MKPolyline {
    convenience init(mapRect: MKMapRect) {
        let points = [
            MKMapPoint(x: mapRect.minX, y: mapRect.minY),
            MKMapPoint(x: mapRect.maxX, y: mapRect.minY),
            MKMapPoint(x: mapRect.maxX, y: mapRect.maxY),
            MKMapPoint(x: mapRect.minX, y: mapRect.maxY),
            MKMapPoint(x: mapRect.minX, y: mapRect.minY)
        ]
        self.init(points: points, count: points.count)
    }
}

extension OperationQueue {
    static var serial: OperationQueue {
        let queue = OperationQueue()
        queue.name = "com.cluster.serialQueue"
        queue.maxConcurrentOperationCount = 1
        return queue
    }
    func addBlockOperation(_ block: @escaping (BlockOperation) -> Void) {
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak operation] in
            guard let operation = operation else { return }
            block(operation)
        }
        self.addOperation(operation)
    }
}
//MARK: - Double

extension Float {
    
    var cleanValue: String {
        
        return self.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", self) : String(self)
    }
    
    /*
     func roundTo(_ decimalPlaces: Int) -> Float {
     var v = self
     var divisor = 1.0
     if decimalPlaces > 0 {
     for _ in 1 ... decimalPlaces {
     v *= 10.0
     divisor *= 0.1
     }
     }
     return (Float)(Darwin.round(v) * divisor)
     }
     */
}

//MARK: - StringProtocol

extension StringProtocol where Index == String.Index {
    func index(of string: Self, options: String.CompareOptions = []) -> Index? {
        return range(of: string, options: options)?.lowerBound
    }
}

//MARK: - UIColor

@objc extension UIColor {
    
    convenience init (r:CGFloat, g:CGFloat, b:CGFloat) {
        self.init(red: r/255.0, green: g/255.0, blue: b/255.0, alpha: 1.0)
    }
    
    convenience init (r:CGFloat, g:CGFloat, b:CGFloat, a:CGFloat) {
        self.init(red: r/255.0, green: g/255.0, blue: b/255.0, alpha: a)
    }
    
    convenience init (hex:String) {
        var cString:String = hex.trim().uppercased()
        
        if (cString.hasPrefix("#")) {
            cString = (cString as NSString).substring(from: 1)
        }
        
        if (cString.count != 6) {
            self.init()
            return
        }
        
        let rString = (cString as NSString).substring(to: 2)
        let gString = ((cString as NSString).substring(from: 2) as NSString).substring(to: 2)
        let bString = ((cString as NSString).substring(from: 4) as NSString).substring(to: 2)
        
        var r:CUnsignedInt = 0, g:CUnsignedInt = 0, b:CUnsignedInt = 0;
        
        Scanner(string: rString).scanHexInt32(&r)
        Scanner(string: gString).scanHexInt32(&g)
        Scanner(string: bString).scanHexInt32(&b)
        
        self.init(red: CGFloat(r) / 255.0, green: CGFloat(g) / 255.0, blue: CGFloat(b) / 255.0, alpha: CGFloat(1))
    }
    
    /// Social: Brand identity color of popular social media platform.
    struct Social {
        // https://www.lockedowndesign.com/social-media-colors/
        private init() {}
        
        /// red: 59, green: 89, blue: 152
        public static let facebook = UIColor(r: 59, g: 89, b: 152)
        
        /// red: 0, green: 182, blue: 241
        public static let twitter = UIColor(r: 0, g: 182, b: 241)
        
        /// red: 223, green: 74, blue: 50
        public static let googlePlus = UIColor(r: 223, g: 74, b: 50)
        
        /// red: 0, green: 123, blue: 182
        public static let linkedIn = UIColor(r: 0, g: 123, b: 182)
        
        /// red: 69, green: 187, blue: 255
        public static let vimeo = UIColor(r: 69, g: 187, b: 255)
        
        /// red: 179, green: 18, blue: 23
        public static let youtube = UIColor(r: 179, g: 18, b: 23)
        
        /// red: 195, green: 42, blue: 163
        public static let instagram = UIColor(r: 195, g: 42, b: 163)
        
        /// red: 203, green: 32, blue: 39
        public static let pinterest = UIColor(r: 203, g: 32, b: 39)
        
        /// red: 244, green: 0, blue: 131
        public static let flickr = UIColor(r: 244, g: 0, b: 131)
        
        /// red: 67, green: 2, blue: 151
        public static let yahoo = UIColor(r: 67, g: 2, b: 151)
        
        /// red: 67, green: 2, blue: 151
        public static let soundCloud = UIColor(r: 67, g: 2, b: 151)
        
        /// red: 44, green: 71, blue: 98
        public static let tumblr = UIColor(r: 44, g: 71, b: 98)
        
        /// red: 252, green: 69, blue: 117
        public static let foursquare = UIColor(r: 252, g: 69, b: 117)
        
        /// red: 255, green: 176, blue: 0
        public static let swarm = UIColor(r: 255, g: 176, b: 0)
        
        /// red: 234, green: 76, blue: 137
        public static let dribbble = UIColor(r: 234, g: 76, b: 137)
        
        /// red: 255, green: 87, blue: 0
        public static let reddit = UIColor(r: 255, g: 87, b: 0)
        
        /// red: 74, green: 93, blue: 78
        public static let devianArt = UIColor(r: 74, g: 93, b: 78)
        
        /// red: 238, green: 64, blue: 86
        public static let pocket = UIColor(r: 238, g: 64, b: 86)
        
        /// red: 170, green: 34, blue: 182
        public static let quora = UIColor(r: 170, g: 34, b: 182)
        
        /// red: 247, green: 146, blue: 30
        public static let slideShare = UIColor(r: 247, g: 146, b: 30)
        
        /// red: 0, green: 153, blue: 229
        public static let px500 = UIColor(r: 0, g: 153, b: 229)
        
        /// red: 223, green: 109, blue: 70
        public static let listly = UIColor(r: 223, g: 109, b: 70)
        
        /// red: 0, green: 180, blue: 137
        public static let vine = UIColor(r: 0, g: 180, b: 137)
        
        /// red: 0, green: 175, blue: 240
        public static let skype = UIColor(r: 0, g: 175, b: 240)
        
        /// red: 235, green: 73, blue: 36
        public static let stumbleUpon = UIColor(r: 235, g: 73, b: 36)
        
        /// red: 255, green: 252, blue: 0
        public static let snapchat = UIColor(r: 255, g: 252, b: 0)
        
        /// red: 37, green: 211, blue: 102
        public static let whatsApp = UIColor(r: 37, g: 211, b: 102)
    }
}

//MARK: - UIButton

extension UIButton {
    private var states: [UIControl.State] {
        return [.normal, .selected, .highlighted, .disabled]
    }
    
    func setTitle(_ title: String?) {
        states.forEach { setTitle(title, for: $0) }
    }
    
    func setTitle(_ title: String?, withAnimation options: UIView.AnimationOptions) {
        self.layer.add(CATransition(), forKey: "fadeAnimation")
        self.states.forEach { self.setTitle(title, for: $0) }
    }
    
    func setImage(_ image: UIImage?) {
        states.forEach { setImage(image, for: $0) }
    }
}

extension CALayer {
    
    func addGradientBorder(colors:[UIColor],width:CGFloat = 3, cornerRadius: CGFloat = 0.0) {
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame =  CGRect(origin: CGPoint.zero, size: self.bounds.size)
        
        gradientLayer.startPoint = CGPoint(x:0.5, y:0)
        gradientLayer.endPoint = CGPoint(x:0.5,y:1)
        
        /* Gradient Effect
        // ******
        //gradientLayer.colors = colors.map({$0.cgColor})
        // ****** */
        
        
        /* Step Effect */
        // ******
        var colorsArray: [CGColor] = []
        var locationsArray: [NSNumber] = []
        for (index, color) in colors.enumerated() {
            // append same color twice
            colorsArray.append(color.cgColor)
            colorsArray.append(color.cgColor)
            locationsArray.append(NSNumber(value: (1.0 / Double(colors.count)) * Double(index)))
            locationsArray.append(NSNumber(value: (1.0 / Double(colors.count)) * Double(index + 1)))
        }
        gradientLayer.colors = colorsArray
        gradientLayer.locations = locationsArray
        // ******
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.lineWidth = width
        shapeLayer.path = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
        shapeLayer.fillColor = nil
        shapeLayer.strokeColor = UIColor.red.cgColor
        gradientLayer.mask = shapeLayer
        
        self.addSublayer(gradientLayer)
    }
    
    func addMultipleBorder(colors:[UIColor], width:CGFloat = 5, cornerRadius: CGFloat = 0.0) {
        
        for (index,color) in colors.enumerated() {
            
            let shapeLayer = CAShapeLayer()
            shapeLayer.lineWidth = CGFloat((colors.count - index)) * width
            shapeLayer.path = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
            shapeLayer.fillColor = nil
            shapeLayer.strokeColor = color.cgColor
            
            self.addSublayer(shapeLayer)
        }
    }
}

//MARK: - UIView

extension UIView {
    
    // MARK: - Properties
    
    /// Border color of view; also inspectable from Storyboard.
    @IBInspectable var borderColor: UIColor? {
        get {
            guard let color = layer.borderColor else { return nil }
            return UIColor(cgColor: color)
        }
        set {
            guard let color = newValue else {
                layer.borderColor = nil
                return
            }
            // Fix React-Native conflict issue
            guard String(describing: type(of: color)) != "__NSCFType" else { return }
            layer.borderColor = color.cgColor
        }
    }
    
    /// Border width of view; also inspectable from Storyboard.
    @IBInspectable var borderWidth: CGFloat {
        get {
            return layer.borderWidth
        }
        set {
            layer.borderWidth = newValue
        }
    }
    
    /// Corner radius of view; also inspectable from Storyboard.
    @IBInspectable var radiusByHeight: Bool {
        get {
            return layer.cornerRadius == self.frame.size.height / 2
        }
        set {
            //layer.masksToBounds = true
            layer.cornerRadius = self.frame.size.height / 2
        }
    }
    
    /// Corner radius of view; also inspectable from Storyboard.
    @IBInspectable var cornerRadiuss: CGFloat {
        get {
            return layer.cornerRadius
        }
        set {
            //layer.masksToBounds = true
            layer.cornerRadius = abs(CGFloat(Int(newValue * 100)) / 100)
        }
    }
    
    /// SwifterSwift: Shadow color of view; also inspectable from Storyboard.
    @IBInspectable var sshadowColor: UIColor? {
        get {
            guard let color = layer.shadowColor else { return nil }
            return UIColor(cgColor: color)
        }
        set {
            //layer.masksToBounds = false
            layer.shadowColor = newValue?.cgColor
        }
    }
    
    /// SwifterSwift: Shadow offset of view; also inspectable from Storyboard.
    @IBInspectable var sshadowOffset: CGSize {
        get {
            return layer.shadowOffset
        }
        set {
            //layer.masksToBounds = false
            layer.shadowOffset = newValue
        }
    }
    
    /// SwifterSwift: Shadow opacity of view; also inspectable from Storyboard.
    @IBInspectable var sshadowOpacity: Float {
        get {
            return layer.shadowOpacity
        }
        set {
            //layer.masksToBounds = false
            layer.shadowOpacity = newValue
        }
    }
    
    /// SwifterSwift: Shadow radius of view; also inspectable from Storyboard.
    @IBInspectable var sshadowRadius: CGFloat {
        get {
            return layer.shadowRadius
        }
        set {
            layer.shadowRadius = newValue
        }
    }
    
    /// SwifterSwift: Size of view.
    var size: CGSize {
        get {
            return frame.size
        }
        set {
            width = newValue.width
            height = newValue.height
        }
    }
    
    /// Height of view.
    var height: CGFloat {
        get {
            return frame.size.height
        }
        set {
            frame.size.height = newValue
        }
    }
    
    /// Width of view.
    var width: CGFloat {
        get {
            return frame.size.width
        }
        set {
            frame.size.width = newValue
        }
    }
    
    /// x origin of view.
    var x: CGFloat {
        get {
            return frame.origin.x
        }
        set {
            frame.origin.x = newValue
        }
    }
    
    /// y origin of view.
    var y: CGFloat {
        get {
            return frame.origin.y
        }
        set {
            frame.origin.y = newValue
        }
    }
    
    /// Take screenshot of view (if applicable).
    var screenshot: UIImage? {
        UIGraphicsBeginImageContextWithOptions(layer.frame.size, false, 0)
        defer {
            UIGraphicsEndImageContext()
        }
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        layer.render(in: context)
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    func disbleMultiTap() {
        self.isUserInteractionEnabled = false
        DispatchQueue.main.asyncAfter(deadline:.now() + 0.25) {
            self.isUserInteractionEnabled = true
        }
    }
    
    func zoomOutWith(scale: CGFloat = 0.9, duration: TimeInterval, onCompletion: (()->())?) {
        UIView.animate(
            withDuration: max((duration / 2),0.1),
            animations: {
                self.transform = CGAffineTransform.init(scaleX: scale, y: scale)
        }) { _ in
            UIView.animate(
                withDuration: max((duration / 2),0.1),
                animations: {
                    self.transform = CGAffineTransform.identity
                    if onCompletion != nil {
                        onCompletion!()
                    }
            })
        }
    }
    
    //MARK: - Method
    
    @discardableResult
    func showHUD() -> MBProgressHUD {
        
        /* Show Progress Dialog */
        return MBProgressHUD.showAdded(to: UIApplication.shared.keyWindow!, animated: true)
    }
    
    func hideHUD() {
        
        /* Hide Progress Dialog */
        MBProgressHUD.hide(for: UIApplication.shared.keyWindow!, animated: true)
    }
    
    /// Remove all subviews in view.
    func removeAllSubviews() {
        
        self.subviews.forEach({ $0.removeFromSuperview() }) // this gets things done
        //self.subviews.map({ $0.removeFromSuperview() }) // this returns modified array
    }
    
    /// Remove all gesture recognizers from view.
    func removeGestureRecognizers() {
        gestureRecognizers?.forEach(removeGestureRecognizer)
    }
    
    // Tap Gesture Event
    func didOnTap(target: Any?, action: Selector?) {
        self.isUserInteractionEnabled = true
        let tapEvent = UITapGestureRecognizer(target: target, action: action)
        self.addGestureRecognizer(tapEvent)
    }
    
    /// Set some or all corners radiuses of view.
    ///
    /// - Parameters:
    ///   - corners: array of corners to change (example: [.bottomLeft, .topRight]).
    ///   - radius: radius for selected corners.
    func roundCorners(_ corners: UIRectCorner, radius: CGFloat) {
        let maskPath = UIBezierPath(
            roundedRect: bounds,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius))
        
        let shape = CAShapeLayer()
        shape.path = maskPath.cgPath
        layer.mask = shape
    }
    
    func loadViewFromNib() -> UIView? {
        let bundle = Bundle(for: type(of: self))
        let nib = UINib(nibName: String(describing: Self.self), bundle: bundle)
        return nib.instantiate(withOwner: self, options: nil).first as? UIView
    }
    
    func showShadow() {
        
        for subView in self.superview!.subviews {
            subView.layer.zPosition = 0
        }
        self.layer.zPosition = 1
        self.zoomOutWith(scale:1.05, duration: 1.0, onCompletion: nil)
        
        let shadowPath = UIBezierPath(roundedRect: self.bounds, cornerRadius: CGFloat(self.cornerRadiuss))
        
        self.layer.masksToBounds = false
        self.layer.shadowColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1).cgColor
        self.layer.shadowOffset = CGSize(width: 0.0, height: 0.0)
        self.layer.shadowOpacity = 0.3
        self.layer.shadowRadius = 5
        self.layer.shadowPath = shadowPath.cgPath
    }
    
    func hideShadow() {
        self.layer.shadowOpacity = 0
        self.layer.masksToBounds = true
    }
    
    //MARK: - Animation Effect
    func openWithBounceEffect(parentView:UIView? = UIApplication.shared.keyWindow)
    {
        self.transform = CGAffineTransform(scaleX: 0.001, y: 0.001)
        
        parentView?.addSubview(self);
        
        UIView.animate(withDuration: 0.3/1.5, animations: {
            self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1);
        }, completion:{ (finish) in
            
            UIView.animate(withDuration: 0.3/2, animations: {
                self.transform = CGAffineTransform(scaleX: 0.9, y: 0.9);
            }, completion: { (finish) in
                
                UIView.animate(withDuration:0.3/2, animations: {
                    
                    self.transform = CGAffineTransform.identity;
                }, completion: { (finished) in
                    
                })
            })
        })
    }
    
    func openWithAnimation()
    {
        self.transform = CGAffineTransform(scaleX: 1.3, y: 1.3);
        self.alpha = 0;
        
        UIView.animate(withDuration: 0.35, animations: {
            self.alpha = 1;
            self.transform = CGAffineTransform(scaleX: 1, y: 1);
        })
    }
    
    func openFromBottom(_ bgColor: UIColor?, duration: TimeInterval = 0.35, completion: ((Bool) -> Void)? = nil) {
        
        self.frame = CGRect(x: 0, y: SCREEN_HEIGHT, width: SCREEN_WIDTH, height: self.frame.size.height)
        UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 5, options: [.curveEaseInOut, .allowUserInteraction],
                       /*UIView.animate(withDuration: duration,*/ animations: {
                        
                        self.frame = CGRect(x: 0, y: SCREEN_HEIGHT - self.frame.size.height, width: SCREEN_WIDTH, height: self.frame.size.height)
                        self.layoutIfNeeded()
                        
                       },completion:{ status in
                        if bgColor != nil { self.backgroundColor = bgColor }
                        if completion != nil {
                            completion!(status)
                        }
                       })
    }
    
    func closeToBottom(_ bgColor: UIColor?, duration: TimeInterval = 0.35)
    {
        self.frame = CGRect(x: 0, y: self.frame.origin.y, width: SCREEN_WIDTH, height: self.frame.size.height)
        
        if bgColor != nil { self.backgroundColor = bgColor }
        UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 5, options: [.curveEaseInOut, .allowUserInteraction],
                       /*UIView.animate(withDuration: duration, */animations: {
                        
                        self.frame = CGRect(x: 0, y: SCREEN_HEIGHT, width: SCREEN_WIDTH, height: self.frame.size.height)
                        self.layoutIfNeeded()
                       })
    }
    
    func closeToTop(_ bgColor: UIColor?)
    {
        
        if bgColor != nil { self.backgroundColor = bgColor }
        
        UIView.animate(withDuration: 0.35, animations: {
            
            self.frame = CGRect(x: 0, y: -SCREEN_HEIGHT + 10, width: SCREEN_WIDTH, height: self.frame.size.height)
            self.layoutIfNeeded()
        })
    }
    
    func openFromLeftWithBounce(_ bgColor: UIColor?) {
        self.frame = CGRect(x: SCREEN_WIDTH, y: self.frame.origin.y, width: SCREEN_WIDTH, height: self.frame.size.height)
        
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 1, options: .curveEaseInOut, animations: {
            self.frame = CGRect(x: 0, y: self.frame.origin.y, width: SCREEN_WIDTH, height: self.frame.size.height)
            self.layoutIfNeeded()
        }) { _ in
            if bgColor != nil { self.backgroundColor = bgColor }
        }
    }
    
    func openFromLeft(_ bgColor: UIColor?, duration: TimeInterval = 0.35, delay: TimeInterval = 0, completion: ((Bool) -> Void)? = nil) {
        
        self.frame = CGRect(x: SCREEN_WIDTH, y: self.frame.origin.y, width: SCREEN_WIDTH, height: self.frame.size.height)
        self.layoutIfNeeded()
        UIView.animate(withDuration: duration, delay: delay, animations: {
            
            self.frame = CGRect(x: 0, y: self.frame.origin.y, width: SCREEN_WIDTH, height: self.frame.size.height)
            self.layoutIfNeeded()
            
        },completion:{ status in
            if bgColor != nil { self.backgroundColor = bgColor }
            if completion != nil {
                completion!(status)
            }
        })
    }
    
    func closeToRight(_ bgColor: UIColor?)
    {
        self.frame = CGRect(x: self.frame.origin.x, y: self.frame.origin.y, width: self.frame.size.width, height: self.frame.size.height)
        
        if bgColor != nil { self.backgroundColor = bgColor }
        
        UIView.animate(withDuration: 0.35, animations: {
            
            self.frame = CGRect(x: SCREEN_WIDTH, y: self.frame.origin.y, width: self.frame.size.width, height: self.frame.size.height)
            self.layoutIfNeeded()
        })
    }
    
    
    func closeWithAnimation()
    {
        UIView.animate(withDuration: 0.35, animations: {
            
            self.transform = CGAffineTransform(scaleX: 1.3, y: 1.3);
            self.alpha = 0.0;
        },
                       completion:{ (finished) in
                        
                        if (finished) {
                            self.removeFromSuperview()
                        }
        })
    }
    
    
    func resizeByHeight(text:String, font:UIFont) {
        
        height = max(self.frame.size.height, text.heightWithConstrainedWidth(width: self.frame.size.width, font: font) + 2)
    }
    
    /// Get view's parent view controller
    @objc var topViewController: UIViewController? {
        
        var responder: UIResponder? = self
        while !(responder is UIViewController) {
            responder = responder?.next
            if nil == responder {
                break
            }
        }
        return (responder as? UIViewController)!
        
        /*
         var parentResponder: UIResponder? = self.superview
         while parentResponder != nil {
         parentResponder = parentResponder!.next
         if let viewController = parentResponder as? UIViewController {
         return viewController
         }
         }
         return nil
         */
    }
    
    func changeConstrainValue(identifier:String, constant:Float) {
        
        for costrain in self.constraints {
            if costrain.isKind(of: NSLayoutConstraint.self) {
                if costrain.identifier == identifier {
                    costrain.constant = CGFloat(constant)
                }
            }
        }
    }
    
    /*
     class func loadNib<T: UIView>(viewType: T.Type) -> T {
     let className = String.className(viewType)
     return NSBundle(forClass: viewType).loadNibNamed(className, owner: nil, options: nil).first as! T
     }
     
     class func loadNib() -> Self {
     return loadNib(self)
     }
     */
    
    public func setGradientBorder(_ colors: [UIColor]) {
        self.clipsToBounds = true
        self.layer.addGradientBorder(colors: colors, width: 6.0, cornerRadius: self.layer.cornerRadius)
        //self.layer.addMultipleBorder(colors: colors, cornerRadius: self.layer.cornerRadius)
    }
    
    @discardableResult
    func applyGradient(colours: [UIColor]) -> CAGradientLayer {
        return self.applyGradient(colours: colours, locations: nil)
    }

    @discardableResult
    func applyGradient(colours: [UIColor], locations: [NSNumber]?) -> CAGradientLayer {
        
        if let layers = self.layer.sublayers {
            layers.forEach {
                if let label = $0.accessibilityLabel, label == "gradient.layer" {
                    $0.removeFromSuperlayer()
                }
            }
        }
        
        let gradient: CAGradientLayer = CAGradientLayer()
        gradient.accessibilityLabel = "gradient.layer"
        gradient.frame = self.bounds
        gradient.cornerRadius = self.cornerRadiuss
        gradient.colors = colours.map { $0.cgColor }
        gradient.startPoint = CGPoint(x: 0.0, y: 0.5)
        gradient.endPoint = CGPoint(x: 0.5, y: 0.5)
        gradient.locations = locations
        self.layer.insertSublayer(gradient, at: 0)
        return gradient
    }
}

// MARK: - UIScrollView
public extension UIScrollView {
    
    /// SwifterSwift: Takes a snapshot of an entire ScrollView
    ///
    ///    AnySubclassOfUIScroolView().snapshot
    ///    UITableView().snapshot
    ///
    /// - Returns: Snapshot as UIimage for rendered ScrollView
    var snapshot: UIImage? {
        // Original Source: https://gist.github.com/thestoics/1204051
        UIGraphicsBeginImageContextWithOptions(contentSize, false, 0)
        defer {
            UIGraphicsEndImageContext()
        }
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        let previousFrame = frame
        frame = CGRect(origin: frame.origin, size: contentSize)
        layer.render(in: context)
        frame = previousFrame
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
}

//MARK: - UIResponder

extension UIResponder {
    func owningViewController() -> UIViewController? {
        var nextResponser = self
        while let next = nextResponser.next {
            nextResponser = next
            if let vc = nextResponser as? UIViewController {
                return vc
            }
        }
        return nil
    }
}

//MARK: - UIApplication

extension UIApplication {
    
    class func getDelegate() -> AppDelegate {
        return self.shared.delegate as! AppDelegate;
    }
    
    class func topViewController(base: UIViewController? = UIApplication.shared.keyWindow?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            if let selected = tab.selectedViewController {
                return topViewController(base: selected)
            }
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
    
    var statusBarView: UIView? {
        if responds(to: Selector(("statusBar"))) {
            return value(forKey: "statusBar") as? UIView
        }
        return nil
    }
}

//MARK: - UIWindow

public extension UIWindow {
    
    /// Switch current root view controller with a new view controller.
    ///
    /// - Parameters:
    ///   - viewController: new view controller.
    ///   - animated: set to true to animate view controller change _(default is true)_.
    ///   - duration: animation duration in seconds _(default is 0.5)_.
    ///   - options: animataion options _(default is .transitionFlipFromRight)_.
    ///   - completion: optional completion handler called when view controller is changed.
    func setRootViewController(to viewController: UIViewController, animated: Bool, duration: TimeInterval = 0.5, options: UIView.AnimationOptions = .transitionFlipFromRight, _ completion: (() -> Void)? = nil) {
        
        guard animated else {
            rootViewController = viewController
            completion?()
            return
        }
        
        UIView.transition(with: self, duration: duration, options: options, animations: {
            let oldState = UIView.areAnimationsEnabled
            UIView.setAnimationsEnabled(false)
            self.rootViewController = viewController
            UIView.setAnimationsEnabled(oldState)
        }, completion: { _ in
            completion?()
        })
    }
    
}

//MARK: - UINavigationController

extension UINavigationController {
    
    //    @objc override open var preferredStatusBarStyle: UIStatusBarStyle {
    //        return .lightContent
    //    }
    
    func isExist(viewController: AnyClass) -> UIViewController?
    {
        let allViewControllers = self.viewControllers
        
        for objVC in allViewControllers {
            if objVC.isKind(of: viewController) {
                return objVC
            }
        }
        
        return nil
    }
}

extension UILabel {
    //    func indexOfAttributedTextCharacterAtPoint(point: CGPoint) -> Int {
    //        assert(self.attributedText != nil, "This method is developed for attributed string")
    //        let textStorage = NSTextStorage(attributedString: self.attributedText!)
    //        let layoutManager = NSLayoutManager()
    //        textStorage.addLayoutManager(layoutManager)
    //        let textContainer = NSTextContainer(size: self.frame.size)
    //        textContainer.lineFragmentPadding = 0
    //        textContainer.maximumNumberOfLines = self.numberOfLines
    //        textContainer.lineBreakMode = self.lineBreakMode
    //        layoutManager.addTextContainer(textContainer)
    //
    //        let index = layoutManager.characterIndex(for: point, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
    //        return index
    //    }
    
    var isTruncated: Bool {

        guard let labelText = text else {
            return false
        }

        let labelTextSize = (labelText as NSString).boundingRect(
            with: CGSize(width: frame.size.width, height: .greatestFiniteMagnitude),
            options: .usesLineFragmentOrigin,
            attributes: [.font: font!],
            context: nil).size

        return labelTextSize.height > bounds.size.height
    }
}


//MARK: - UIViewController

extension UIViewController {
    
    /// SwifterSwift: Check if ViewController is onscreen and not hidden.
    var isVisible: Bool {
        // http://stackoverflow.com/questions/2777438/how-to-tell-if-uiviewcontrollers-view-is-visible
        return isViewLoaded && view.window != nil
    }
    
    @discardableResult
    func showHUD() -> MBProgressHUD {
        
        /* Show Progress Dialog */
        return MBProgressHUD.showAdded(to: UIApplication.shared.keyWindow!, animated: true)
    }
    
    func hideHUD() {
        
        /* Hide Progress Dialog */
        MBProgressHUD.hide(for: UIApplication.shared.keyWindow!, animated: true)
    }
    
    func removeFrom(navigationController:UINavigationController)
    {
        var allViewControllers = navigationController.viewControllers
        
        for objVC in allViewControllers
        {
            if objVC.isKind(of: self.classForCoder)
            {
                objVC.removeFromParent();
                allViewControllers.remove(object: objVC);
                break;
            }
        }
        
        navigationController.viewControllers = allViewControllers;
    }
    
    /// Assign as listener to notification.
    ///
    /// - Parameters:
    ///   - name: notification name.
    ///   - selector: selector to run with notified.
    func addNotificationObserver(name: Notification.Name, selector: Selector) {
        NotificationCenter.default.addObserver(self, selector: selector, name: name, object: nil)
    }
    
    /// Unassign as listener to notification.
    ///
    /// - Parameter name: notification name.
    func removeNotificationObserver(name: Notification.Name) {
        NotificationCenter.default.removeObserver(self, name: name, object: nil)
    }
    
    /// Unassign as listener from all notifications.
    func removeNotificationsObserver() {
        NotificationCenter.default.removeObserver(self)
    }
    
    /// Helper method to add a UIViewController as a childViewController.
    ///
    /// - Parameters:
    ///   - child: the view controller to add as a child
    ///   - containerView: the containerView for the child viewcontroller's root view.
    func addChildViewController(_ child: UIViewController, toContainerView containerView: UIView) {
        addChild(child)
        containerView.addSubview(child.view)
        child.didMove(toParent: self)
    }
    
    /// Helper method to remove a UIViewController from its parent.
    func removeViewAndControllerFromParentViewController() {
        guard parent != nil else { return }
        
        willMove(toParent: nil)
        removeFromParent()
        view.removeFromSuperview()
    }
    
    /// Helper method to present a UIViewController as a popover.
    ///
    /// - Parameters:
    ///   - popoverContent: the view controller to add as a popover.
    ///   - sourcePoint: the point in which to anchor the popover.
    ///   - size: the size of the popover. Default uses the popover preferredContentSize.
    ///   - delegate: the popover's presentationController delegate. Default is nil.
    ///   - animated: Pass true to animate the presentation; otherwise, pass false.
    ///   - completion: The block to execute after the presentation finishes. Default is nil.
    func presentPopover(_ popoverContent: UIViewController, sourcePoint: CGPoint, size: CGSize? = nil, delegate: UIPopoverPresentationControllerDelegate? = nil, animated: Bool = true, completion: (() -> Void)? = nil) {
        popoverContent.modalPresentationStyle = .popover
        
        if let size = size {
            popoverContent.preferredContentSize = size
        }
        
        if let popoverPresentationVC = popoverContent.popoverPresentationController {
            popoverPresentationVC.sourceView = view
            popoverPresentationVC.sourceRect = CGRect(origin: sourcePoint, size: .zero)
            popoverPresentationVC.delegate = delegate
        }
        
        present(popoverContent, animated: animated, completion: completion)
    }
}

//MARK: - NSMutableAttributedString

public extension NSMutableAttributedString {
    
    func addColor(color:UIColor?, substring:String) {
        let range = self.string.range(of: substring, options: .caseInsensitive)
        if (range != nil && color != nil) {
            self.addAttribute(NSAttributedString.Key.foregroundColor, value: color!, range: self.string.nsRange(from: range!))
        }
    }
    
    func addBackgroundColor(color:UIColor?, substring:String) {
        let range = self.string.range(of: substring, options: .caseInsensitive)
        if (range != nil && color != nil) {
            self.addAttribute(NSAttributedString.Key.backgroundColor, value: color!, range: self.string.nsRange(from: range!))
        }
    }
    
    func addUnderlineForSubstring(substring:String) {
        let range = self.string.range(of: substring, options: .caseInsensitive)
        if (range != nil) {
            self.addAttribute(NSAttributedString.Key.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: self.string.nsRange(from: range!))
        }
    }
    
    func addStrikeThrough(thickness:Int, substring:String) {
        let range = self.string.range(of: substring, options: .caseInsensitive)
        if (range != nil) {
            self.addAttribute(NSAttributedString.Key.strikethroughStyle, value: thickness, range: self.string.nsRange(from: range!))
        }
    }
    
    func addShadowColor(color:UIColor?, width:CGFloat, height:CGFloat, radius:CGFloat, substring:String) {
        let range = self.string.range(of: substring, options: .caseInsensitive)
        if (range != nil && color != nil) {
            
            let shadow:NSShadow  = NSShadow();
            shadow.shadowColor = color!;
            shadow.shadowOffset = CGSize(width: width, height: height)
            shadow.shadowBlurRadius = radius;
            
            self.addAttribute(NSAttributedString.Key.shadow, value: shadow, range: self.string.nsRange(from: range!))
        }
    }
    
    func addFontWithName(fontName:String?, fontSize:CGFloat, substring:String) {
        let range = self.string.range(of: substring, options: .caseInsensitive)
        if (range != nil && fontName != nil) {
            
            let font:UIFont = UIFont(name: fontName!, size: fontSize)!;
            
            self.addAttribute(NSAttributedString.Key.font, value: font, range: self.string.nsRange(from: range!))
        }
    }
    
    func addFont(font:UIFont?, substring:String) {
        let range = self.string.range(of: substring, options: .caseInsensitive)
        if (range != nil && font != nil) {
            
            self.addAttribute(NSAttributedString.Key.font, value: font!, range: self.string.nsRange(from: range!))
        }
    }
    
    func addAlignment(alignment:NSTextAlignment, substring:String) {
        let range = self.string.range(of: substring, options: .caseInsensitive)
        if (range != nil) {
            
            let style:NSMutableParagraphStyle = NSMutableParagraphStyle();
            style.alignment = alignment;
            
            self.addAttribute(NSAttributedString.Key.font, value: style, range: self.string.nsRange(from: range!))
        }
    }
    
    func addColorToRussianText(color:UIColor?) {
        
        if (color == nil) {
            return
        }
        
        let set:CharacterSet = CharacterSet(charactersIn: "абвгдеёжзийклмнопрстуфхцчшщъыьэюяАБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ")
        
        var searchRange:NSRange = NSMakeRange(0, self.string.count);
        var foundRange:NSRange!;
        
        while (searchRange.location < self.string.count) {
            searchRange.length = self.string.count - searchRange.location;
            
            foundRange = (self.string as NSString).rangeOfCharacter(from: set, options: .caseInsensitive, range: searchRange)
            if (foundRange.location != NSNotFound) {
                
                self.addAttribute(NSAttributedString.Key.foregroundColor, value: color!, range: foundRange)
                
                searchRange.location = foundRange.location + 1;
                
            } else {
                // no more substring to find
                break;
            }
        }
        
    }
    
    func addStrokeColor(color:UIColor?, thickness:Int, substring:String) {
        let range = self.string.range(of: substring, options: .caseInsensitive)
        if (range != nil && color != nil) {
            
            self.addAttribute(NSAttributedString.Key.strokeColor, value: color!, range: self.string.nsRange(from: range!))
            
            self.addAttribute(NSAttributedString.Key.strokeWidth, value: thickness, range: self.string.nsRange(from: range!))
        }
    }
    
    func addVerticalGlyph(glyph:Bool, substring:String) {
        let range = self.string.range(of: substring, options: .caseInsensitive)
        if (range != nil) {
            
            self.addAttribute(NSAttributedString.Key.foregroundColor, value: glyph, range: self.string.nsRange(from: range!))
        }
    }
    
    func addLineSpacing(lineSpacing:CGFloat, substring:String) {
        let range = self.string.range(of: substring, options: .caseInsensitive)
        if (range != nil) {
            
            let paragraphStyle:NSMutableParagraphStyle = NSMutableParagraphStyle();
            paragraphStyle.lineSpacing = lineSpacing;
            paragraphStyle.alignment = NSTextAlignment.right;
            
            self.addAttribute(NSAttributedString.Key.paragraphStyle, value: paragraphStyle, range: self.string.nsRange(from: range!))
        }
    }
    
    func heightWithConstrainedWidth(width: CGFloat) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = self.boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, context: nil)
        
        return boundingBox.height
    }
    
    func widthWithConstrainedHeight(height: CGFloat) -> CGFloat {
        let constraintRect = CGSize(width: .greatestFiniteMagnitude, height: height)
        let boundingBox = self.boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, context: nil)
        
        return boundingBox.width
    }
    
}

//MARK: - Array

extension Array where Element: Equatable
{
    mutating func remove(object: Element) {
        
        if let index = firstIndex(of: object) {
            remove(at: index)
        }
    }
    
    /*mutating func groupList(UsingKey key: String) {
     
     var objGroupList: [JSON] = [JSON]()
     
     for objTemp in self as! [JSON] {
     
     var templist = objGroupList.filter{$0[key].stringValue == objTemp[key].stringValue}
     
     if templist.count > 0 {
     
     var list = templist[0]["list"].arrayValue
     list.append(objTemp)
     let position = objGroupList.firstIndex(of: templist[0])!
     templist[0]["list"] = JSON(list)
     objGroupList[position]["list"] = JSON(list)
     
     } else {
     
     objGroupList.append([
     key:objTemp[key].stringValue,
     "isopen":"0",
     "list":[objTemp]
     ])
     }
     }
     
     self = objGroupList as! Array<Element>
     }*/
    
    mutating func groupList(UsingKey key: String, Tiles: [String]) {
        
        var objGroupList: [JSON] = [JSON]()
        
        for title in Tiles {
            
            let templist = (self as! [JSON]).filter{$0[key].stringValue == title}
            
            objGroupList.append([
                key:title,
                "isopen":"0",
                "list":templist
            ])
        }
        
        self = objGroupList as! Array<Element>
    }
}

//MARK: - UITableView

extension UITableView {
    
    /// Reload data with a completion handler.
    ///
    /// - Parameter completion: completion handler to run after reloadData finishes.
    func reloadData(_ completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0, animations: {
            self.reloadData()
        }, completion: { _ in
            completion()
        })
    }
    
    /// Scroll to bottom of TableView.
    ///
    /// - Parameter animated: set true to animate scroll (default is true).
    func scrollToBottom(animated: Bool = true) {
        let bottomOffset = CGPoint(x: 0, y: contentSize.height - bounds.size.height)
        setContentOffset(bottomOffset, animated: animated)
    }
    
    /// Scroll to top of TableView.
    ///
    /// - Parameter animated: set true to animate scroll (default is true).
    func scrollToTop(animated: Bool = true) {
        setContentOffset(CGPoint.zero, animated: animated)
    }
}

//MARK: - UITableViewCell

extension UITableViewCell {
    
    func addSeparatorLine(){
        
        let line = UIView(frame: CGRect(x: 0, y: bounds.size.height - 1, width: bounds.size.width, height: 1))
        line.backgroundColor = UIColor(r: 79, g: 99, b: 102)
        addSubview(line)
    }
}




//MARK: - UIImage

extension UIImage {
    
    /* Resize Image */
    func resizeImage(_ withMaxSize: CGFloat = 700) -> UIImage
    {
        var actualHeight: CGFloat = self.size.height;
        var actualWidth: CGFloat = self.size.width;
        let maxHeight: CGFloat = withMaxSize;
        let maxWidth: CGFloat = withMaxSize;
        var imgRatio = CGFloat(actualWidth/actualHeight);
        let maxRatio = CGFloat(maxWidth/maxHeight);
        //float compressionQuality = 1;//50 percent compression
        
        if (actualHeight > maxHeight || actualWidth > maxWidth)
        {
            if(imgRatio < maxRatio)
            {
                //adjust width according to maxHeight
                imgRatio = maxHeight / actualHeight;
                actualWidth = imgRatio * actualWidth;
                actualHeight = maxHeight;
            }
            else if(imgRatio > maxRatio)
            {
                //adjust height according to maxWidth
                imgRatio = maxWidth / actualWidth;
                actualHeight = imgRatio * actualHeight;
                actualWidth = maxWidth;
            }
            else
            {
                actualHeight = maxHeight;
                actualWidth = maxWidth;
            }
        }
        
        
        
        let rect = CGRect(x: 0, y: 0, width: actualWidth, height: actualHeight)
        UIGraphicsBeginImageContext(rect.size)
        self.draw(in: rect)
        let img = UIGraphicsGetImageFromCurrentImageContext();
        //NSData *imageData = UIImageJPEGRepresentation(img, compressionQuality);
        UIGraphicsEndImageContext();
        
        // Save To Gallery
        //UIImageWriteToSavedPhotosAlbum([UIImage imageWithData:imageData], nil, nil, nil);
        
        return img!;//[UIImage imageWithData:imageData];
    }
    
    public class func gifImageWithData(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            print("image doesn't exist")
            return nil
        }
        
        return UIImage.animatedImageWithSource(source)
    }
    
    public class func gifImageWithURL(_ gifUrl:String) -> UIImage? {
        guard let bundleURL:URL = URL(string: gifUrl)
        else {
            print("image named \"\(gifUrl)\" doesn't exist")
            return nil
        }
        guard let imageData = try? Data(contentsOf: bundleURL) else {
            print("image named \"\(gifUrl)\" into NSData")
            return nil
        }
        
        return gifImageWithData(imageData)
    }
    
    public class func gifImageWithName(_ name: String) -> UIImage? {
        guard let bundleURL = Bundle.main
                .url(forResource: name, withExtension: "gif") else {
            print("SwiftGif: This image named \"\(name)\" does not exist")
            return nil
        }
        guard let imageData = try? Data(contentsOf: bundleURL) else {
            print("SwiftGif: Cannot turn image named \"\(name)\" into NSData")
            return nil
        }
        
        return gifImageWithData(imageData)
    }
    
    class func delayForImageAtIndex(_ index: Int, source: CGImageSource!) -> Double {
        var delay = 0.1
        
        let cfProperties = CGImageSourceCopyPropertiesAtIndex(source, index, nil)
        let gifProperties: CFDictionary = unsafeBitCast(
            CFDictionaryGetValue(cfProperties,
                                 Unmanaged.passUnretained(kCGImagePropertyGIFDictionary).toOpaque()),
            to: CFDictionary.self)
        
        var delayObject: AnyObject = unsafeBitCast(
            CFDictionaryGetValue(gifProperties,
                                 Unmanaged.passUnretained(kCGImagePropertyGIFUnclampedDelayTime).toOpaque()),
            to: AnyObject.self)
        if delayObject.doubleValue == 0 {
            delayObject = unsafeBitCast(CFDictionaryGetValue(gifProperties,
                                                             Unmanaged.passUnretained(kCGImagePropertyGIFDelayTime).toOpaque()), to: AnyObject.self)
        }
        
        delay = delayObject as! Double
        
        if delay < 0.1 {
            delay = 0.1
        }
        
        return delay
    }
    
    class func gcdForPair(_ a: Int?, _ b: Int?) -> Int {
        var a = a
        var b = b
        if b == nil || a == nil {
            if b != nil {
                return b!
            } else if a != nil {
                return a!
            } else {
                return 0
            }
        }
        
        if a < b {
            let c = a
            a = b
            b = c
        }
        
        var rest: Int
        while true {
            rest = a! % b!
            
            if rest == 0 {
                return b!
            } else {
                a = b
                b = rest
            }
        }
    }
    
    class func gcdForArray(_ array: Array<Int>) -> Int {
        if array.isEmpty {
            return 1
        }
        
        var gcd = array[0]
        
        for val in array {
            gcd = UIImage.gcdForPair(val, gcd)
        }
        
        return gcd
    }
    
    class func animatedImageWithSource(_ source: CGImageSource) -> UIImage? {
        let count = CGImageSourceGetCount(source)
        var images = [CGImage]()
        var delays = [Int]()
        
        for i in 0..<count {
            if let image = CGImageSourceCreateImageAtIndex(source, i, nil) {
                images.append(image)
            }
            
            let delaySeconds = UIImage.delayForImageAtIndex(Int(i),
                                                            source: source)
            delays.append(Int(delaySeconds * 1000.0)) // Seconds to ms
        }
        
        let duration: Int = {
            var sum = 0
            
            for val: Int in delays {
                sum += val
            }
            
            return sum
        }()
        
        let gcd = gcdForArray(delays)
        var frames = [UIImage]()
        
        var frame: UIImage
        var frameCount: Int
        for i in 0..<count {
            frame = UIImage(cgImage: images[Int(i)])
            frameCount = Int(delays[Int(i)] / gcd)
            
            for _ in 0..<frameCount {
                frames.append(frame)
            }
        }
        
        let animation = UIImage.animatedImage(with: frames,
                                              duration: Double(duration) / 1000.0)
        
        return animation
    }
}

fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
        case let (l?, r?):
            return l < r
        case (nil, _?):
            return true
        default:
            return false
    }
}

// MARK: - UITextField
public extension UITextField {
    
    /// Return text with no spaces or new lines in beginning and end.
    var trimmedText: String? {
        return text?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Check if textFields text is a valid email format.
    ///
    /// textField.text = "john@doe.com"
    /// textField.hasValidEmail -> true
    ///
    /// textField.text = "swifterswift"
    /// textField.hasValidEmail -> false
    ///
    var hasValidEmail: Bool {
        // http://stackoverflow.com/questions/25471114/how-to-validate-an-e-mail-address-in-swift
        return text!.range(of: "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}",
                           options: String.CompareOptions.regularExpression,
                           range: nil, locale: nil) != nil
        
        //NSPredicate(format: "SELF MATCHES %@", "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,4}").evaluate(with: text!)
    }
    
    func setPlaceHolderTextColor(_ color: UIColor) {
        guard let holder = placeholder, !holder.isEmpty else { return }
        attributedPlaceholder = NSAttributedString(string: holder, attributes: [.foregroundColor: color])
    }
    
    /// - Parameters:
    ///   - image: left image
    ///   - padding: amount of padding between icon and the left of textfield
    func addPaddingLeftIcon(_ image: UIImage, padding: CGFloat) {
        let imageView = UIImageView(image: image)
        imageView.contentMode = .center
        leftView = imageView
        leftView?.frame.size = CGSize(width: image.size.width + padding, height: image.size.height)
        leftViewMode = .always
    }
    
    func addPaddingRightIcon(_ image: UIImage, padding: CGFloat) {
        let imageView = UIImageView(image: image)
        imageView.contentMode = .center
        rightView = imageView
        rightView?.frame.size = CGSize(width: image.size.width + padding, height: image.size.height)
        rightViewMode = .always
    }
    
    func addPrefix(_ strPrefix: String) {
        
        let prefix = UILabel()
        prefix.font = self.font
        prefix.text = "  " + strPrefix + "  "
        prefix.sizeToFit()

        self.leftView = prefix
        self.leftViewMode = .always // .whileEditing
    }
    
//    Added by Aalok for payment view design
    enum Direction {
        case Left
        case Right
    }
    
    func withImage(direction: Direction, image: UIImage, colorSeparator: UIColor, colorBorder: UIColor, imageContentMode: UIView.ContentMode = .center){
        let mainView = UIView(frame: CGRect(x: 0, y: 2, width: 30, height: self.frame.height - 4))
        mainView.layer.cornerRadius = 5
        
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 30, height: mainView.frame.height))
        view.backgroundColor = .white
        view.clipsToBounds = true
        view.layer.cornerRadius = 5
        view.layer.borderWidth = CGFloat(0.5)
        view.layer.borderColor = colorBorder.cgColor
        mainView.addSubview(view)
        
        let imageView = UIImageView(image: image)
        imageView.contentMode = imageContentMode//.scaleAspectFit
        imageView.frame = CGRect(x: 0, y: 5, width: 20, height: view.frame.height - 10)
        view.addSubview(imageView)
        
        let seperatorView = UIView()
        seperatorView.backgroundColor = colorSeparator
        mainView.addSubview(seperatorView)
        
        if(Direction.Left == direction){ // image left
            seperatorView.frame = CGRect(x: 30, y: 0, width: 1, height: mainView.frame.height)
            self.leftViewMode = .always
            self.leftView = mainView
        } else { // image right
            seperatorView.frame = CGRect(x: 0, y: 0, width: 1, height: mainView.frame.height)
            self.rightViewMode = .always
            self.rightView = mainView
        }
        
        self.layer.borderColor = colorBorder.cgColor
        self.layer.borderWidth = CGFloat(0.5)
        self.layer.cornerRadius = 5
    }
}

//MARK: - URL

extension URL {
    
    func thumbnail() -> UIImage? {
        
        let asset = AVAsset(url: self)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 1, preferredTimescale: 1)
        
        do {
            let imageRef = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            return UIImage(cgImage: imageRef)
        } catch {
            print(error)
            return nil
        }
    }
}

extension PHAsset {
    
    func image(targetSize: CGSize = PHImageManagerMaximumSize) -> UIImage {
        var thumbnail = UIImage()
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.deliveryMode = .opportunistic
        imageManager.requestImage(for: self, targetSize: targetSize, contentMode: .aspectFill, options: options, resultHandler: { image, _ in
            thumbnail = image!
        })
        return thumbnail
    }
}

import GoogleMaps

extension GMSCircle {
    func bounds () -> GMSCoordinateBounds {
        func locationMinMax(_ positive : Bool) -> CLLocationCoordinate2D {
            let sign: Double = positive ? 1 : -1
            let dx = sign * self.radius  / 6378000 * (180 / .pi)
            let lat = position.latitude + dx
            let lon = position.longitude + dx / cos(position.latitude * .pi / 180)
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }

        return GMSCoordinateBounds(coordinate: locationMinMax(true),
                               coordinate: locationMinMax(false))
    }
}


//MARK: - UITableView

extension GMSMapView {
    
    func drawCircle(position: CLLocationCoordinate2D, miles: Double,  fillColor: UIColor, strokeWidth: CGFloat, strokeColor: UIColor) {
        
        DispatchQueue.main.async {
            
            let circle = GMSCircle(position: position, radius:milesToMeters(miles: miles))
            circle.fillColor = fillColor
            circle.strokeWidth = strokeWidth
            circle.strokeColor = strokeColor
            circle.map = self
            
            let marker = GMSMarker(position: position)
            marker.icon = UIImage(named: "pin")
            //marker.title = ""
            marker.map = self
            
            let update = GMSCameraUpdate.fit(circle.bounds())
            self.animate(with: update)
        }
    }
    
    func getCenterCoordinate() -> CLLocationCoordinate2D {
        let centerPoint = self.center
        let centerCoordinate = self.projection.coordinate(for: centerPoint)
        return centerCoordinate
    }

    func getTopCenterCoordinate() -> CLLocationCoordinate2D {
        // to get coordinate from CGPoint of your map
        let topCenterCoor = self.convert(CGPoint(x: self.frame.size.width / 2.0, y: 0), from: self)
        let point = self.projection.coordinate(for: topCenterCoor)
        return point
    }

    func getRadius() -> CLLocationDistance {

        let centerCoordinate = getCenterCoordinate()
        // init center location from center coordinate
        let centerLocation = CLLocation(latitude: centerCoordinate.latitude, longitude: centerCoordinate.longitude)
        let topCenterCoordinate = self.getTopCenterCoordinate()
        let topCenterLocation = CLLocation(latitude: topCenterCoordinate.latitude, longitude: topCenterCoordinate.longitude)

        let radius = CLLocationDistance(centerLocation.distance(from: topCenterLocation))

        return round(radius)
    }
}
