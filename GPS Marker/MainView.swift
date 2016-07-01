//
//  ViewController.swift
//  GPS Marker
//
//  Created by Andrew Tan on 6/29/16.
//  Copyright © 2016 Taskar Center for Accessible Technology. All rights reserved.
//

import UIKit
import CoreLocation
import MapKit

class MainView: UIViewController, CLLocationManagerDelegate {
    // Map view
    @IBOutlet weak var mapView: MKMapView!
    
    // Button stack
    @IBOutlet weak var buttonStack: UIStackView!
    
    // Label
    @IBOutlet weak var longLabel: UILabel!
    @IBOutlet weak var latLabel: UILabel!
    @IBOutlet weak var horizontalAccuracy: UILabel!
    @IBOutlet weak var verticalAccuracy: UILabel!
    
    // Location Service
    let locationManager = CLLocationManager()
    var currentDroppedPin : MKPointAnnotation?
    
    // File stored
    let sidewalkFilePath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] + "/sidewalk-collection.json"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Location manager configuration
        locationManager.delegate = self
        locationManager.requestAlwaysAuthorization()
    }
    
    // MARK:- Action
    
    /**
        Handle button clicked action
        - parameter sender: the button object who triggered this action
    */
    @IBAction func buttonClicked(sender: UIButton) {
        if sender.tag == 0 {
            // Sidewalk get clicked
            performSegueWithIdentifier("sidewalkSceneSegue", sender: sender)
        }
        
        if sender.tag == 4 {
            // Clear Cache get clicked
            let fileManager = NSFileManager()
            do {
                try fileManager.removeItemAtPath(sidewalkFilePath)
            } catch {
                if fileManager.fileExistsAtPath(sidewalkFilePath) {
                    print("Remove file faliure!")
                } else {
                    print("Remove file success")
                }
            }
        }
    }
    
    //MARK:- CLLocationManagerDelegate methods
    
    /**
     Handle different cases when location authorization status changed
     
     - parameter manager: the CLLocationManager
     - parameter status: the current status of location authorization
     */
    func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        
        switch status {
        case .AuthorizedAlways, .AuthorizedWhenInUse:
            buttonStack.hidden = false
            mapView.userTrackingMode = .Follow
        case .NotDetermined:
            buttonStack.hidden = true
            mapView.userTrackingMode = .None
            manager.requestAlwaysAuthorization()
        case .Restricted, .Denied:
            buttonStack.hidden = true
            mapView.userTrackingMode = .None
            let alertController = UIAlertController(
                title: "Background Location Access Disabled",
                message: "In order to record location information you reported, please open this app's settings and set location access to 'Always'.",
                preferredStyle: .Alert)
            
            let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
            alertController.addAction(cancelAction)
            
            let openAction = UIAlertAction(title: "Open Settings", style: .Default) { (action) in
                if let url = NSURL(string:UIApplicationOpenSettingsURLString) {
                    UIApplication.sharedApplication().openURL(url)
                }
            }
            alertController.addAction(openAction)
            
            self.presentViewController(alertController, animated: true, completion: nil)
        }
    }
}

