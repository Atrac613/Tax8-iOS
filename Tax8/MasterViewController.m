//
//  MasterViewController.m
//  Tax8
//
//  Created by Osamu Noguchi on 10/5/13.
//  Copyright (c) 2013 Osamu Noguchi. All rights reserved.
//

#import "MasterViewController.h"
#import <QuartzCore/QuartzCore.h>

@interface MasterViewController () {
    
}
@end

@implementation MasterViewController

- (void)awakeFromNib
{
    [super awakeFromNib];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    tesseract = [[Tesseract alloc] initWithDataPath:@"tessdata" language:@"eng"];
    [tesseract setVariableValue:@"0123456789" forKey:@"tessedit_char_whitelist"];
    
    [self configureView];
    
    [self addTimer];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)configureView {
    [self.navigationItem setTitle:@"Tax8"];
    
    if (TARGET_IPHONE_SIMULATOR) {
        [self setupTestAVCapture];
    } else {
        [self setupAVCapture];
    }
    
    CALayer *borderLayer = [CALayer layer];
    [borderLayer setBorderColor:[UIColor redColor].CGColor];
    [borderLayer setBorderWidth:1.f];
    [borderLayer setFrame:CGRectMake(10, 125, 300, 70)];
    [previewView.layer addSublayer:borderLayer];
}

#pragma mark - Timer

- (void)addTimer {
    timer = [NSTimer scheduledTimerWithTimeInterval:1
                                             target:self
                                           selector:@selector(getNumber)
                                           userInfo:nil
                                            repeats:YES];
}

- (void)removeTimer {
    [timer invalidate];
    timer = nil;
}

#pragma mark - AVCapture

- (void)setupAVCapture
{
    session = [AVCaptureSession new];
    [session setSessionPreset:AVCaptureSessionPresetLow];
    
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];
    
    if ([session canAddInput:deviceInput]) {
        [session addInput:deviceInput];
    }
    
    NSMutableDictionary *settings = [NSMutableDictionary dictionary];
    [settings setObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA]
                 forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    AVCaptureVideoDataOutput *dataOutput = [[AVCaptureVideoDataOutput alloc] init];
    dataOutput.videoSettings = settings;
    [dataOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    [session addOutput:dataOutput];
    
    previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
    [previewLayer setBackgroundColor:[[UIColor blackColor] CGColor]];
    [previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    
    CALayer *rootLayer = [previewView layer];
    [rootLayer setMasksToBounds:YES];
    [previewLayer setFrame:[rootLayer bounds]];
    [rootLayer addSublayer:previewLayer];
    [session startRunning];
}

- (void)setupTestAVCapture {
    UIImage *image = [UIImage imageNamed:@"test.png"];
    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
    [imageView setContentMode:UIViewContentModeScaleAspectFill];
    [previewView addSubview:imageView];
    
    CGRect screenRect = CGRectMake(0, 0, imageView.frame.size.width, imageView.frame.size.height);
    UIGraphicsBeginImageContext(screenRect.size);
    
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    [[UIColor clearColor] set];
    CGContextFillRect(ctx, screenRect);
    
    [imageView.layer renderInContext:ctx];
    
    UIImage *previewImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    captureImage = previewImage;
}

#pragma mark - Recognize

- (void)getNumber {
    [self getNumberWithImage:captureImage];
}

- (void)getNumberWithImage:(UIImage*)image {
    [tesseract setImage:image];
    [tesseract recognize];
    
    NSString *recognizedString = [tesseract recognizedText];
    [self configureTaxView:recognizedString];
    
    [tesseract clear];
    
    previewImageView.image = [UIImage imageWithCGImage:image.CGImage];
}

- (void)configureTaxView:(NSString*)recognizedString {
    NSArray *prices = [recognizedString componentsSeparatedByString:@"\n"];
    NSString *rawString = [prices objectAtIndex:0];
    NSString *currentPriceString = [rawString stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    NSLog(@"Recognized String: %@", recognizedString);
    
    NSNumberFormatter *format = [[NSNumberFormatter alloc] init];
    [format setNumberStyle:NSNumberFormatterDecimalStyle];
    [format setGroupingSeparator:@","];
    [format setGroupingSize:3];
    [format setMinimumFractionDigits:0];
    
    NSNumber *currentPriceNumber = [NSNumber numberWithInt:[currentPriceString intValue]];
    [currentPriceLabel setText:[format stringFromNumber:currentPriceNumber]];
    
    NSNumber *tax5PriceNumber = [NSNumber numberWithInt:round([currentPriceNumber intValue] * 1.05f)];
    [tax5PriceLabel setText:[format stringFromNumber: tax5PriceNumber]];
    
    NSNumber *tax8PriceNumber = [NSNumber numberWithInt:round([currentPriceNumber intValue] * 1.08f)];
    [tax8PriceLabel setText:[format stringFromNumber: tax8PriceNumber]];
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput*)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection*)connection {
    CVImageBufferRef buffer;
    buffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    CVPixelBufferLockBaseAddress(buffer, 0);
    
    uint8_t *base;
    size_t width, height, bytesPerRow;
    base = CVPixelBufferGetBaseAddress(buffer);
    width = CVPixelBufferGetWidth(buffer);
    height = CVPixelBufferGetHeight(buffer);
    bytesPerRow = CVPixelBufferGetBytesPerRow(buffer);
    
    CGColorSpaceRef colorSpace;
    CGContextRef cgContext;
    colorSpace = CGColorSpaceCreateDeviceRGB();
    cgContext = CGBitmapContextCreate(
                                      base, width, height, 8, bytesPerRow, colorSpace,
                                      kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGColorSpaceRelease(colorSpace);
    
    CGImageRef cgImage = CGBitmapContextCreateImage(cgContext);
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    
    CGImageRelease(cgImage);
    CGContextRelease(cgContext);
    
    CVPixelBufferUnlockBaseAddress(buffer, 0);
    
    image = [self convertToGrayScale:image];
    image = [self scaleAndRotateImage:image];
    captureImage = [self imageByCropping:image toRect:CGRectMake(0, 90, image.size.width, 35)];
}

#pragma mark - Others

- (UIImage *)scaleAndRotateImage:(UIImage *)image {
    CGImageRef imgRef = image.CGImage;
    
    CGFloat width = CGImageGetWidth(imgRef);
    CGFloat height = CGImageGetHeight(imgRef);
    
    CGAffineTransform transform = CGAffineTransformIdentity;
    CGRect bounds = CGRectMake(0, 0, width, height);
    
    CGFloat boundHeight;
    
    boundHeight = bounds.size.height;
    bounds.size.height = bounds.size.width;
    bounds.size.width = boundHeight;
    transform = CGAffineTransformMakeScale(-1.0, 1.0);
    transform = CGAffineTransformRotate(transform, M_PI / 2.0);
    
    UIGraphicsBeginImageContext(bounds.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextConcatCTM(context, transform);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imgRef);
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return result;
}

- (UIImage*)convertToGrayScale:(UIImage*)image {
    CIImage *ciImage = [[CIImage alloc] initWithImage:image];
    
    CIFilter *ciFilter = [CIFilter filterWithName:@"CIPhotoEffectNoir" keysAndValues:kCIInputImageKey, ciImage, nil];
    
    CIContext *ciContext = [CIContext contextWithOptions:nil];
    CGImageRef cgImage = [ciContext createCGImage:[ciFilter outputImage] fromRect:[[ciFilter outputImage] extent]];
    UIImage *result = [UIImage imageWithCGImage:cgImage scale:1.0f orientation:UIImageOrientationUp];
    CGImageRelease(cgImage);
    
    return result;
}

- (UIImage*)imageByCropping:(UIImage *)image toRect:(CGRect)rect {
    CGImageRef imageRef = CGImageCreateWithImageInRect([image CGImage], rect);
    UIImage *result = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    
    return result;
}

@end
