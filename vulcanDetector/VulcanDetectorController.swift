//
//  ViewController.swift
//  vulcanDetector
//
//  Created by Park Seyoung on 11/09/16.
//  Copyright © 2016 Park Seyoung. All rights reserved.
//

import UIKit
import CoreMotion
import CoreLocation
import MapKit
import Alamofire
import SwiftyJSON

class VulcanDetectorController: UIViewController, CLLocationManagerDelegate {
    
    var locationManager: CLLocationManager?
    
    lazy var motionManager = CMMotionManager()
    
    var accelerationDataHolder: CMAcceleration?
    
    var magnitudeLabel: UILabel!
    var faceView: UIImageView!
    var faceStatus = VibrationStatus.Steady
    var timeIntervalAtEarthquake: NSTimeInterval?
    var magnitudeState = EarthquakeMagnitude.Steady {
        didSet(old) {
            guard old != magnitudeState else { return }
            sendToServer()
        }
    }
    
    private func didShake(old: CMAcceleration?, new: CMAcceleration) -> (Bool, Double) {
        guard let old = old else {
            accelerationDataHolder = new
            return (false, 0) }
        let diff = abs(old.x - new.x) + abs(old.y - new.y) + abs(old.z - new.z)
        return (diff > Constants.didShakeThreshold, diff)
    }
    
    private func isFaceUpdatableBackToSteady() -> Bool {
        guard let old = timeIntervalAtEarthquake else { return true }
        let new = NSDate().timeIntervalSince1970
        let diff = new - old
        return diff > 1
    }
    
    private func updateFace(status: VibrationStatus) {
        guard faceStatus != status else { return }
        print("New image! \t \(status.rawValue)")
        let image = UIImage(named: status.rawValue)
        faceView.image = image
        faceStatus = status
        //        sendToServer()
    }
    
    private func getMagnitudeState(diff: Double) -> EarthquakeMagnitude {
        switch diff {
        case 0..<Constants.didShakeThreshold: return .Steady
        case Constants.didShakeThreshold..<0.6: return .Mild
        case 0.6..<1.0: return .Medium
        default: return .Strong
        }
    }
    
    private func sendToServer() {
        guard let coord = userCoordinate else { return }
        
        let params = [
            "longitude":String(coord.longitude),
            "latitude":String(coord.latitude),
            "magnitude": magnitudeState.rawValue
        ]
        
        Alamofire.request(.PUT, Constants.serverURL, parameters: params)
            .responseJSON { response in
                guard response.result.error == nil else {
                    // got an error in getting the data, need to handle it
                    print("error calling POST on /todos/1")
                    print(response.result.error!)
                    return
                }
                
                if let value = response.result.value {
                    let todo = JSON(value)
                    print("The todo is: " + todo.description)
                }
        }
        
    }
    
    private func printAcceleration(data: CMAcceleration){
        let (didShakeBool, diff) = didShake(accelerationDataHolder, new: data)
        if didShakeBool == true {
            
            timeIntervalAtEarthquake = NSDate().timeIntervalSince1970
            print("X = \(data.x)\t Y = \(data.y)\t Z = \(data.z)")
            updateFace(.Earthquake)
        } else if isFaceUpdatableBackToSteady() {
            //            print("updateFace(.Steady)")
            updateFace(.Steady)
        }
        accelerationDataHolder = data
        updateMagnitudeLabelText(String(diff))
        magnitudeState = getMagnitudeState(diff)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        loadLocationManager()
    }
    
    override func viewDidAppear(animated: Bool) {
        loadFaceImage()
        loadMagnitudeLabel("0.0")
        loadMotionManager()
        
    }
    
    private func loadLocationManager() {
        // Ask for Authorisation from the User.
        if (CLLocationManager.locationServicesEnabled()) {
            locationManager = CLLocationManager()
            locationManager!.delegate = self
            locationManager!.requestAlwaysAuthorization()
            locationManager!.desiredAccuracy = kCLLocationAccuracyBest
            locationManager!.startUpdatingLocation()
        }
    }
    
    var userCoordinate: CLLocationCoordinate2D? {
        didSet {
            guard let coord = userCoordinate else { return }
            print(coord)
        }
    }
    
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = manager.location else { return }
        userCoordinate = location.coordinate
    }
    
    func locationManager(manager: CLLocationManager!, didFailWithError error: NSError!) {
        print("Failed to get location")
        print(error)
    }
    
    private func loadMotionManager() {
        motionManager.accelerometerUpdateInterval = 1.0 / 4
        
        if motionManager.accelerometerAvailable{
            /// UI elements can be only updated in main queue
            /// Recommend: let queue = NSOperationQueue()
            let queue = NSOperationQueue.mainQueue()
            
            /// Load queue
            motionManager.startAccelerometerUpdatesToQueue(queue, withHandler:
                {data, error in
                    
                    guard let data = data else{
                        return
                    }
                    
                    self.printAcceleration(data.acceleration)
                    
                }
            )
        } else {
            print("Accelerometer is not available")
        }
    }
    
    private func updateMagnitudeLabelText(text: String) {
        magnitudeLabel.text = text
    }
    
    private func loadMagnitudeLabel(text: String) {
        magnitudeLabel = UILabel()
        magnitudeLabel.frame = CGRectMake(
            faceView.frame.midX,
            faceView.frame.maxY + 10, 100, 40)
        magnitudeLabel.backgroundColor = UIColor.clearColor()
        magnitudeLabel.textColor = UIColor.whiteColor()
        magnitudeLabel.textAlignment = NSTextAlignment.Center
        magnitudeLabel.text = text
        self.view.addSubview(magnitudeLabel)
    }
    
    private func loadFaceImage() {
        let faceImage = UIImage(named: VibrationStatus.Steady.rawValue)
        let x = (view.bounds.width - faceImage!.size.width) / 2
        let y = (view.bounds.height - faceImage!.size.height) / 2
        let frame = CGRectMake(
            x, y, faceImage!.size.width, faceImage!.size.height)
        faceView = UIImageView(image: faceImage)
        faceView.frame = frame
        
        view.addSubview(faceView)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
}

