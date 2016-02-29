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

        alertController.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Destructive, handler: nil))
        alertController.addAction(okAction)

        self.presentViewController(alertController, animated: true, completion: nil)
    }

    private func loadURL(url:NSURL) {
        let hud = MBProgressHUD.showHUDAddedTo(self.view, animated: true)
        hud.mode = MBProgressHUDMode.AnnularDeterminate
        hud.labelText = "Downloading"

        var localPath: NSURL?
        Alamofire.download(.GET, url, destination: { (downloadedURL:NSURL, response:NSHTTPURLResponse) -> NSURL in
            let directoryURL = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)[0]
            let pathComponent = response.suggestedFilename

            localPath = directoryURL.URLByAppendingPathComponent(pathComponent!)
            return localPath!
        }).progress( { bytesRead, totalBytesRead, totalBytesExpectedToRead in
                // This closure is NOT called on the main queue for performance
                // reasons. To update your ui, dispatch to the main queue.
                dispatch_async(dispatch_get_main_queue()) {
                    hud.progress = Float(totalBytesRead) / Float(totalBytesExpectedToRead)
                }
        }).response { (request:NSURLRequest?, response:NSHTTPURLResponse?, data:NSData?, error:NSError?) -> Void in
                hud.hide(true)
                self.unzipURL(localPath, directory: String(url.absoluteString.lowercaseString.hash)) //this hash will guarantee a single url we always get same folder name
        }

    }

    private func unzipURL(localPath:NSURL?, directory:String) {
        guard let localPath = localPath, directoryURL = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first else { return }
        let destination = directoryURL.URLByAppendingPathComponent(directory, isDirectory: true)

        do {
            // lets create the folder if it doesnt exist
            try NSFileManager.defaultManager().createDirectoryAtPath(destination.path!, withIntermediateDirectories: true, attributes: nil)
            //now unzip
            if SSZipArchive.unzipFileAtPath(localPath.path, toDestination: destination.path) {
                // now the hardest path... recursively enumerate files until we find index.html file
                let enumerator = NSFileManager.defaultManager().enumeratorAtURL(destination, includingPropertiesForKeys: nil, options: NSDirectoryEnumerationOptions.SkipsHiddenFiles, errorHandler: nil)
                while let fileURL =  enumerator?.nextObject() as? NSURL {
                    if fileURL.absoluteString.hasSuffix("index.html") {
                        self.webView.loadRequest(NSURLRequest(URL: fileURL))
                        return
                    }
                }
            }
        } catch let error as NSError {
            debugPrint(error)
        }
    }

    private func validateURL(urlString:String) -> Bool {
        let urlRegEx = "(http|https)://((\\w)*|([0-9]*)|([-|_])*)+([\\.|/]((\\w)*|([0-9]*)|([-|_])*))+"
        let urlTest = NSPredicate(format: "SELF MATCHES %@", urlRegEx)
        return urlTest.evaluateWithObject(urlString)
    }

}

