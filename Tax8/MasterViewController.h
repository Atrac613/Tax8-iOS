//
//  MasterViewController.h
//  Tax8
//
//  Created by Osamu Noguchi on 10/5/13.
//  Copyright (c) 2013 Osamu Noguchi. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <TesseractOCR/TesseractOCR.h>

@interface MasterViewController : UIViewController <AVCaptureVideoDataOutputSampleBufferDelegate> {
    IBOutlet UIView *previewView;
    IBOutlet UIImageView *previewImageView;
    
    AVCaptureVideoPreviewLayer *previewLayer;
    AVCaptureSession *session;
    
    UIImage *captureImage;
    
    NSTimer *timer;
    
    Tesseract *tesseract;
}

@end
