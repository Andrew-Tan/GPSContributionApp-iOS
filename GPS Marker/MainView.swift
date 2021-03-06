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
import SwiftyJSON
import Alamofire

class MainView: UIViewController, CLLocationManagerDelegate {
    
    // Button stack
    @IBOutlet weak var buttonStack: UIStackView!
    
    // Label
    @IBOutlet weak var longLabel: UILabel!
    @IBOutlet weak var latLabel: UILabel!
    @IBOutlet weak var altLabel: UILabel!
    @IBOutlet weak var horizontalAccuracy: UILabel!
    @IBOutlet weak var verticalAccuracy: UILabel!
    
    // Location Service
    let locationManager = CLLocationManager()
    var currentDroppedPin: MKPointAnnotation?
    var updateTimer: NSTimer!
    
    // Activity Indicator
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    // GeoJSON file location
    var fileManager: NSFileManager?
    let sidewalkFilePath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] + "/sidewalk-collection.json"
    let curbrampFilePath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] + "/curbramp-collection.json"
    let crossingFilePath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] + "/crossing-collection.json"
    let userCredentialFilePath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] + "/user-credential.json"
    
    // Network Temprary Server
    let serverURL = "http://52.34.168.220:3000/wines"
    
    /**
     Intiate properties that only need to be done once when the scene is initiated
     */
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "OpenSidewalks"
        // navigationController?.navigationBar.barTintColor = UIColor.yellowColor()
        // navigationController?.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: UIColor.blackColor()]
        
        // Location manager configuration
        locationManager.delegate = self
        locationManager.requestAlwaysAuthorization()
        
        // Define Buttons on the navigation bar
        let loginButton = UIBarButtonItem(title: "Login", style: .Plain, target: self, action: #selector(buttonClicked))
        loginButton.tag = 5
        let uploadButton = UIBarButtonItem(title: "Upload", style: .Plain, target: self, action: #selector(buttonClicked))
        uploadButton.tag = 3
        navigationItem.leftBarButtonItem = loginButton
        navigationItem.rightBarButtonItem = uploadButton
        
    }
    
    /**
     Intiate properties that only need to be done every time when this scene appear
     */
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        // Start timer: Update GPS info periodcally
        updateGPSInfo()
        updateTimer = NSTimer.scheduledTimerWithTimeInterval(2, target: self, selector: #selector(updateGPSInfo), userInfo: nil, repeats: true)
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        
        // Stop timer
        updateTimer.invalidate()
    }
    
    /**
     Get current GPS information from location manager and update displaying labels
     */
    func updateGPSInfo() {
        if let current = locationManager.location {
            let coordinate = current.coordinate
            longLabel.text = "Long: \(coordinate.longitude) degree"
            latLabel.text = "Lat: \(coordinate.latitude) degree"
            altLabel.text = "Alt: \(current.altitude) meters"
            horizontalAccuracy.text = "Horizontal: \(current.horizontalAccuracy) meters"
            verticalAccuracy.text = "Vertical: \(current.verticalAccuracy) meters"
        }
    }
    
    /**
     Display a message window
     */
    func displayMessage(title: String, message: String) {
        let alertController = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .Alert)
        let dismissAction = UIAlertAction(title: "Dismiss", style: .Cancel, handler: nil)
        alertController.addAction(dismissAction)
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
    /**
     Delete all cache stored on phone
     
     - parameter displayMsg: a switch indicate whether to give a prompt after procedure is completed (If the deleting process fails, a prompt will be given regardless of this parameter)
     
     - parameter removeMask: a mask which indicate which file to remove
     FOR NOW:
     000: Remove Nothing
     001: Remove crossing file ONLY
     010: Remove sidewalk file ONLY
     100: Remove curb ramp file ONLY
     111: Remove Everything
     */
    func invalidateCache(displayMsg: Bool, removeMask: Int) {
        // Lazy Initialization
        if fileManager == nil {
            fileManager = NSFileManager()
        }
        
        var deleteThings = 3
        
        if removeMask % (10 as Int) != 0 {
            // The last digit of the mask is not 0
            do {
                try fileManager!.removeItemAtPath(sidewalkFilePath)
            } catch {
                // Deleting error handling
                deleteThings -= 1
            }
        }
        
        if removeMask / (10 as Int) != 0 {
            // The first digit of the mask is not 0
            do {
                try fileManager!.removeItemAtPath(curbrampFilePath)
            } catch {
                // Deleting error handling
                deleteThings -= 1
            }
        }
        
        if removeMask / (100 as Int) != 0 {
            // The first digit of the mask is not 0
            do {
                try fileManager!.removeItemAtPath(crossingFilePath)
            } catch {
                // Deleting error handling
                deleteThings -= 1
            }
        }
        
        if displayMsg {
            if deleteThings > 0 {
                displayMessage("SUCCESS", message: "Cache is deleted")
            } else {
                displayMessage("Empty", message: "Nothing to delete")
            }
        }
    }
    
    /**
     Upload all recorded data to the cloud
     */
    func uploadData() {
        // Lazy Initialization
        if fileManager == nil {
            fileManager = NSFileManager()
        }
        
        if let header_Data = NSData(contentsOfFile: userCredentialFilePath) {
            let headerJSON = JSON(data: header_Data)
            
            let uploadCollection = ["Sidewalk": sidewalkFilePath, "Curb Ramp": curbrampFilePath, "Crossing": crossingFilePath]
            var errItem: [String] = []
            for (name, path) in uploadCollection {
                
                if !(fileManager!.fileExistsAtPath(path)) {
                    continue
                }
                
                if let path_Data = NSData(contentsOfFile: path) {
                    let path_JSON = addHeader(JSON(data: path_Data), headerJSON: headerJSON)
                    
                    // print("Data to be uploaded \(name):\n \(path_JSON.description)")
                    
                    Alamofire.request(.POST, serverURL, parameters: path_JSON.dictionaryObject, encoding: .JSON)
                        .validate()
                        .responseJSON { response in
                            switch response.result {
                            case .Success:
                                print("HTTP Request Success!")
                            case .Failure(let error):
                                errItem.append(name)
                                NSLog(error.localizedDescription)
                            }
                    }
                }
            }
            
            if errItem.count > 0 {
                displayMessage("ERROR", message: "\(errItem.description) failed to be uploaded")
            } else {
                displayMessage("SUCCESS", message: "Record uploaded, thank you for your contribution!")
                invalidateCache(false, removeMask: 111)
            }
        } else {
            let alertController = UIAlertController(
                title: "Credential Error",
                message: "Please login first",
                preferredStyle: .Alert)
            let dismissAction = UIAlertAction(title: "Dismiss", style: .Cancel, handler: nil)
            alertController.addAction(dismissAction)
            let loginAction = UIAlertAction(title: "Login", style: .Default, handler: {(alert: UIAlertAction!) in self.performSegueWithIdentifier("LoginSceneSegue", sender: nil)})
            alertController.addAction(loginAction)
            self.presentViewController(alertController, animated: true, completion: nil)
        }
    }
    
    /**
     Encode necessary device info into the JSON file
     
     - parameter targetJSON: the JSON data to be added info
     
     - return: the targetJSON with proper device info
     */
    func addHeader(targetJSON: JSON, headerJSON: JSON) -> JSON {
        var returnJSON = targetJSON
        returnJSON["properties"]["UserInfo"] = headerJSON
        
        return returnJSON
    }
    
    // MARK:- Action
    
    /**
     Handle button clicked action
     
     - parameter sender: the button object who triggered this action
     */
    @IBAction func buttonClicked(sender: UIButton) {
        switch sender.tag {
        case 0:
            // Sidewalk button get clicked
            performSegueWithIdentifier("sidewalkSceneSegue", sender: sender)
            break
        case 1:
            // Curbramp button get clicked
            performSegueWithIdentifier("curbrampSceneSegue", sender: sender)
            break
        case 2:
            // displayMessage("UNDER DEVELOPMENT", message: "Please check back later :)")
            performSegueWithIdentifier("crossingSceneSegue", sender: sender)
            break
        case 3:
            // Upload Data button get clicked
            // Upload data
            activityIndicator.startAnimating()
            uploadData()
            activityIndicator.stopAnimating()
            break
        case 4:
            // Clear Cache get clicked
            // Ask user again
            let alertController = UIAlertController(
                title: "DELETE CACHE",
                message: "Are you sure? Unuploaded entries will be deleted!",
                preferredStyle: .Alert)
            let dismissAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
            alertController.addAction(dismissAction)
            let confirmAction = UIAlertAction(title: "DELETE!", style: .Destructive, handler: {(alert: UIAlertAction!) in self.invalidateCache(true, removeMask: 111)})
            alertController.addAction(confirmAction)
            self.presentViewController(alertController, animated: true, completion: nil)
            break
        case 5:
            // Login button get clicked
            performSegueWithIdentifier("LoginSceneSegue", sender: sender)
        default:
            NSLog("Undefined Caller")
            break
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
        case .NotDetermined:
            buttonStack.hidden = true
            manager.requestWhenInUseAuthorization()
        case .Restricted, .Denied:
            buttonStack.hidden = true
            let alertController = UIAlertController(
                title: "Background Location Access Disabled",
                message: "In order to record location information you reported, please open this app's settings and set location access.",
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

