//
//  ViewController.swift
//  OfflineDashboard
//
//  Created by Mamnun Bhuiyan on 20/02/2016.
//  Copyright © 2016 IMS Health. All rights reserved.
//

import UIKit
import Alamofire
import MBProgressHUD
import WebKit
import SSZipArchive

class ViewController: UIViewController {
    @IBOutlet weak var loadBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var webView: UIWebView!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func loadTapped(sender: UIBarButtonItem) {
        let alertController = UIAlertController(title: "Enter URL", message: nil, preferredStyle: UIAlertControllerStyle.Alert)
        alertController.addTextFieldWithConfigurationHandler(nil)
        let okAction = UIAlertAction(title: "Ok", style: UIAlertActionStyle.Default) { (action:UIAlertAction) -> Void in
            guard let urlString = alertController.textFields?.first?.text, url = NSURL(string: urlString)
                where self.validateURL(urlString) else {
                return
            }

            self.loadURL(url)
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Destructive) { (action:UIAlertAction) -> Void in
            alertController.dismissViewControllerAnimated(true, completion: nil)
        }

        alertController.addAction(cancelAction)
        alertController.addAction(okAction)

        self.presentViewController(alertController, animated: true, completion: nil)
    }

    private func loadURL(url:NSURL) {
//        let debugPath = "file:///Users/mamnun/Library/Developer/CoreSimulator/Devices/654C7542-563B-4449-8377-4A92B954877C/data/Containers/Data/Application/59556971-E333-4368-8D4E-5B00DA6F5272/Documents/new.zip"
//        unzipURL(NSURL(string: debugPath))
//        return

        let hud = MBProgressHUD.showHUDAddedTo(self.view, animated: true)
        hud.mode = MBProgressHUDMode.AnnularDeterminate

        var localPath: NSURL?
        Alamofire.download(.GET, url, destination: { (downloadedURL:NSURL, response:NSHTTPURLResponse) -> NSURL in
            let directoryURL = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)[0]
            let pathComponent = response.suggestedFilename

            localPath = directoryURL.URLByAppendingPathComponent(pathComponent!)
            return localPath!
        })
            .progress { bytesRead, totalBytesRead, totalBytesExpectedToRead in

                // This closure is NOT called on the main queue for performance
                // reasons. To update your ui, dispatch to the main queue.
                dispatch_async(dispatch_get_main_queue()) {
                    hud.progress = Float(totalBytesRead) / Float(totalBytesExpectedToRead)
                }
            }
            .response { (request:NSURLRequest?, response:NSHTTPURLResponse?, data:NSData?, error:NSError?) -> Void in
                hud.hide(true)
                self.unzipURL(localPath)
        }

    }

    private func unzipURL(localPath:NSURL?) {
        guard let localPath = localPath, directoryURL = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first else { return }
        let destination = directoryURL.URLByAppendingPathComponent(String(localPath.absoluteString.lowercaseString.hash), isDirectory: true)// + "/" + String(localPath.absoluteString.lowercaseString.hash)

        do {
            // lets create the folder
            try NSFileManager.defaultManager().createDirectoryAtPath(destination.path!, withIntermediateDirectories: true, attributes: nil)
            //now unzip
            if SSZipArchive.unzipFileAtPath(localPath.path, toDestination: destination.path) {
                // now the hardest path... recursively enumerate files until we find index.html file
                let enumerator = NSFileManager.defaultManager().enumeratorAtURL(destination, includingPropertiesForKeys: nil, options: NSDirectoryEnumerationOptions.SkipsHiddenFiles, errorHandler: nil)
                while let file =  enumerator?.nextObject() {
                    debugPrint(file)
                    if let fileURL = file as? NSURL where fileURL.absoluteString.hasSuffix("index.html") {
                        self.webView.loadRequest(NSURLRequest(URL: fileURL))
                        return
                    }
                }

            }
        } catch let error as NSError {
            //NOOP
            debugPrint(error)
        }




    }

    private func validateURL(urlString:String) -> Bool {
        let urlRegEx = "(http|https)://((\\w)*|([0-9]*)|([-|_])*)+([\\.|/]((\\w)*|([0-9]*)|([-|_])*))+"
        let urlTest = NSPredicate(format: "SELF MATCHES %@", urlRegEx)
        return urlTest.evaluateWithObject(urlString)
    }

}

