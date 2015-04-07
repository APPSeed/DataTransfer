
//
//  ViewController.swift
//  DataTransfer
//
//  Created by hengyu on 15/4/7.
//  Copyright (c) 2015年 hengyu. All rights reserved.
//

import UIKit

class ViewController: UIViewController, JSImagePickerViewControllerDelegate {
    private(set) var viewPointer: AnyObject?
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var statusBtn: UIBarButtonItem!
    @IBOutlet weak var processBtn: UIBarButtonItem!
    @IBOutlet weak var uploadBtn: UIBarButtonItem!
    let statusLab: UILabel = {
        let lab = UILabel(frame: CGRectMake(0, 0, 180, 34))
        lab.textAlignment = .Center
        lab.adjustsFontSizeToFitWidth = true
        return lab
    }()
    private(set) var image: UIImage?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        imageView.layer.cornerRadius = 5.0
        imageView.layer.masksToBounds = true
        statusBtn.customView = statusLab
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    @IBAction func imageViewTapped(sender: UITapGestureRecognizer) {
        if sender.state == .Ended {
            viewPointer = sender.view
            let imagePicker = JSImagePickerViewController()
            imagePicker.delegate = self
            imagePicker.showImagePickerInController(self, animated: true)
        }
    }
    
    @IBAction func processBtnClicked(sender: AnyObject) {
        statusLab.text = "Processing"
        //NSTimer.scheduledTimerWithTimeInterval(3, target: self, selector: "process", userInfo: nil, repeats: false)
    }
    
    func process() {
        //statusLab.text = "Process Done!"
    }
    
    @IBAction func uploadBtnClicked(sender: AnyObject) {
        if let img = self.image {
            let urlStr = "http://freeshell.ustc.edu.cn:59438/upload"
            let url = NSURL(string: urlStr)!
            let req = NSMutableURLRequest(URL: url)
            
            let boundaryStr = "AaB03x"
            let startboundary = "--" + boundaryStr
            let endboundary = startboundary + "--"
        
            let startStr = startboundary + "\r\n" + "Content-Disposition: form-data; name=\"file\"; fileName=\"test.png\"" + "\r\n" + "Content-Type: image/png" + "\r\n"
            let startData = startStr.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)!
            let endStr = "\r\n\(endboundary)"
            let endData = endStr.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)!
            let imgData = UIImagePNGRepresentation(img)!
        
            var postData = NSMutableData()
            postData.appendData(startData)
            postData.appendData(imgData)
            postData.appendData(endData)
            
            let content = "multipart/form-data; boundary=\(startboundary)"
            req.setValue(content, forHTTPHeaderField: "Content-Type")
            //req.setValue("\(postData.length)", forHTTPHeaderField: "Content-Length")
            req.HTTPMethod = "POST"
            req.HTTPBody = postData
        
            statusLab.text = "Uploading"
                NSURLConnection.sendAsynchronousRequest(req, queue: NSOperationQueue.mainQueue(), completionHandler: {response, data, error in
                    println("Response: \(response)")
                    if error == nil {
                        self.statusLab.text = "Upload Succeed!"
                        println("Upload Succeed")
                    }
                    else {
                        self.statusLab.text = error.localizedDescription
                        println("Upload Failed: \(error.localizedDescription)")
                    }
                })
        }
    }
    
    // MARK: - JSImagePickerViewControllerDelegate
    
    func imagePickerDidSelectImage(image: UIImage!) {
        if let imgView = viewPointer as? UIImageView {
            imgView.image = image
            self.image = image
        }
    }
    
}

