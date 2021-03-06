//
//  TCBlobDownloadManager.swift
//  TCBlobDownloadSwift
//
//  Created by Thibault Charbonnier on 30/12/14.
//  Copyright (c) 2014 thibaultcha. All rights reserved.
//

import Foundation

public let kTCBlobDownloadSessionIdentifier = "tcblobdownloadmanager_downloads"

public let kTCBlobDownloadErrorDomain = "com.tcblobdownloadswift.error"
public let kTCBlobDownloadErrorDescriptionKey = "TCBlobDownloadErrorDescriptionKey"
public let kTCBlobDownloadErrorHTTPStatusKey = "TCBlobDownloadErrorHTTPStatusKey"
public let kTCBlobDownloadErrorFailingURLKey = "TCBlobDownloadFailingURLKey"

public enum TCBlobDownloadError: Int {
    case TCBlobDownloadHTTPError = 1
}

public class TCBlobDownloadManager {
    // Instance of the underlying class implementing NSURLSessionDownloadDelegate
    private let delegate: DownloadDelegate

    // If true, downloads will start immediatly after being created
    public var startImmediatly = true

    // The underlying NSURLSession
    public let session: NSURLSession

    /**
        A shared instance of TCBlobDownloadManager
    */
    public class var sharedInstance: TCBlobDownloadManager {
        struct Singleton {
            static let instance = TCBlobDownloadManager()
        }
        
        return Singleton.instance
    }

    /**
        Initializer for custom NSURLSession configuration
    */
    public init(config: NSURLSessionConfiguration) {
        self.delegate = DownloadDelegate()
        self.session = NSURLSession(configuration: config, delegate: self.delegate, delegateQueue: nil)
        self.session.sessionDescription = "TCBlobDownloadManger session"
    }

    /**
        Initializer with auto NSURLSession configuration
    */
    public convenience init() {
        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
        //config.HTTPMaximumConnectionsPerHost = 1
        self.init(config: config)
    }

    /**
        Base method to start a download, called by other download methods.
        Not public.
    */
    func downloadWithDownload(download: TCBlobDownload) -> TCBlobDownload {
        self.delegate.downloads[download.downloadTask.taskIdentifier] = download

        if self.startImmediatly {
            download.downloadTask.resume()
        }

        return download
    }

    /**
        Start a download at given URL
    */
    public func downloadFileAtURL(url: NSURL, toDirectory directory: NSURL?, withName name: String?, andDelegate delegate: TCBlobDownloadDelegate?) -> TCBlobDownload {
        let downloadTask = self.session.downloadTaskWithURL(url)
        let download = TCBlobDownload(downloadTask: downloadTask, toDirectory: directory, fileName: name, delegate: delegate)

        return self.downloadWithDownload(download)
    }

    /**
        Start a download with given resumeData
    */
    public func downloadFileWithResumeData(resumeData: NSData, toDirectory directory: NSURL?, withName name: String?, andDelegate delegate: TCBlobDownloadDelegate?) -> TCBlobDownload {
        let downloadTask = self.session.downloadTaskWithResumeData(resumeData)
        let download = TCBlobDownload(downloadTask: downloadTask, toDirectory: directory, fileName: name, delegate: delegate)

        return self.downloadWithDownload(download)
    }

    public func currentDownloadsFilteredByState(state: NSURLSessionTaskState?) -> [TCBlobDownload] {
        var downloads = [TCBlobDownload]()

        // Should be functional as soon as Dictionary supports reduce/filter
        for download in self.delegate.downloads.values {
            if state == nil || download.downloadTask.state == state {
                downloads.append(download)
            }
        }

        return downloads
    }

    /**
        NSURLSessionTask Delegate
    */
    class DownloadDelegate: NSObject, NSURLSessionDownloadDelegate {
        var downloads: [Int: TCBlobDownload] = [:]
        let acceptableStatusCodes: Range<Int> = 200...299
        
        func validateResponse(response: NSHTTPURLResponse) -> Bool {
            return contains(self.acceptableStatusCodes, response.statusCode)
        }
        
        // MARK: NSURLSessionDownloadDelegate
        
        func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
            println("Resume at offset: \(fileOffset) total expected: \(expectedTotalBytes)")
        }
        
        func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
            let download = self.downloads[downloadTask.taskIdentifier]!
            let progress = totalBytesExpectedToWrite == NSURLSessionTransferSizeUnknown ? -1 : Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)

            download.progress = progress

            dispatch_async(dispatch_get_main_queue()) {
                download.delegate?.download(download, didProgress: progress, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
                return
            }
        }
        
        func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL location: NSURL) {
            let download = self.downloads[downloadTask.taskIdentifier]!
            var fileError: NSError?
            var resultingURL: NSURL?
            
            if NSFileManager.defaultManager().replaceItemAtURL(download.destinationURL, withItemAtURL: location, backupItemName: nil, options: nil, resultingItemURL: &resultingURL, error: &fileError) {
                download.resultingURL = resultingURL
            } else {
                download.error = fileError
            }
        }
        
        func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError sessionError: NSError?) {
            let download = self.downloads[task.taskIdentifier]!
            var error: NSError? = sessionError ?? download.error

            // Handle possible HTTP errors
            if let response = task.response as? NSHTTPURLResponse {
                // NSURLErrorDomain errors are not supposed to be reported by this delegate
                // according to https://developer.apple.com/library/ios/documentation/Cocoa/Conceptual/URLLoadingSystem/NSURLSessionConcepts/NSURLSessionConcepts.html
                // so let's ignore them as they sometimes appear there for now. (But WTF?)
                if !validateResponse(response) && (error == nil || error!.domain == NSURLErrorDomain) {
                    //let userInfo: [NSString: AnyObject] = [NSString(string: kTCBlobDownloadErrorDescriptionKey): "Erroneous HTTP status code: \(response.statusCode)", NSString(string: kTCBlobDownloadErrorFailingURLKey): task.originalRequest.URL, NSString(string: kTCBlobDownloadErrorHTTPStatusKey): response.statusCode]
                    error = NSError(domain: kTCBlobDownloadErrorDomain,
                                      code: TCBlobDownloadError.TCBlobDownloadHTTPError.rawValue,
                        userInfo: nil)
                }
            }

            // Remove reference to the download
            self.downloads.removeValueForKey(task.taskIdentifier)

            dispatch_async(dispatch_get_main_queue()) {
                download.delegate?.download(download, didFinishWithError: error, atLocation: download.resultingURL)
                return
            }
        }
    }
}

// MARK: TCBlobDownloadDelegate

public protocol TCBlobDownloadDelegate: class {
    func download(download: TCBlobDownload, didProgress progress: Float, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64)
    func download(download: TCBlobDownload, didFinishWithError: NSError?, atLocation location: NSURL?)
}
