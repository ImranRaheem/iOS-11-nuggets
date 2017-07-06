//
//  ViewController.swift
//  BestChannelFinder
//
//  Created by imran on 16/6/17.
//  Copyright © 2017 Imran. All rights reserved.
//

import UIKit
import CoreMedia
import Vision

class ViewController: UIViewController {
    
    private var logo: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "logo")
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private var predictLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 60)
        label.textAlignment = .center
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private var previewView: UIView!
    
    // some properties used to control the app and store appropriate values
    
    let inceptionv3model = Inceptionv3()
    private var videoCapture: VideoCapture!
    private var requests = [VNRequest]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        previewView = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: view.bounds.size.height))
        previewView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(previewView)
        
        view.addSubview(logo)
        view.addSubview(predictLabel)
        
        NSLayoutConstraint.activate([
            previewView.leftAnchor.constraint(equalTo: view.leftAnchor),
            previewView.rightAnchor.constraint(equalTo: view.rightAnchor),
            previewView.topAnchor.constraint(equalTo: view.topAnchor),
            previewView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            logo.leftAnchor.constraint(equalTo: view.leftAnchor),
            logo.rightAnchor.constraint(equalTo: view.rightAnchor),
            logo.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            logo.widthAnchor.constraint(equalToConstant: 50),
            logo.heightAnchor.constraint(equalToConstant: 50),
            
            predictLabel.leftAnchor.constraint(equalTo: view.leftAnchor),
            predictLabel.rightAnchor.constraint(equalTo: view.rightAnchor),
            predictLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            predictLabel.heightAnchor.constraint(equalToConstant: 100)
        ])
        
        //setupVision()
        let spec = VideoSpec(fps: 5, size: CGSize(width: 299, height: 299))
        videoCapture = VideoCapture(cameraType: .back,
                                    preferredSpec: spec,
                                    previewContainer: previewView.layer)
        
        videoCapture.imageBufferHandler = {[unowned self] (imageBuffer) in
            self.handleImageBufferWithCoreML(imageBuffer: imageBuffer)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let videoCapture = videoCapture else {return}
        videoCapture.startCapture()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let videoCapture = videoCapture else {return}
        videoCapture.resizePreview()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        guard let videoCapture = videoCapture else {return}
        videoCapture.stopCapture()
        
        navigationController?.setNavigationBarHidden(false, animated: true)
        super.viewWillDisappear(animated)
    }
    
    // Magic function
    func handleImageBufferWithCoreML(imageBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(imageBuffer) else {
            return
        }
        do {
            let prediction = try self.inceptionv3model.prediction(image: self.resize(pixelBuffer: pixelBuffer)!)
            DispatchQueue.main.async {
                if let _ = prediction.classLabelProbs[prediction.classLabel] {
                    self.predictLabel.text = "\(self.emoji(for: prediction.classLabel).rawValue)"
                }
            }
        }
        catch let error as NSError {
            fatalError("Unexpected error ocurred: \(error.localizedDescription).")
        }
    }
    
    func setupVision() {
        guard let visionModel = try? VNCoreMLModel(for: inceptionv3model.model) else {
            fatalError("can't load Vision ML model")
        }
        let classificationRequest = VNCoreMLRequest(model: visionModel) { (request: VNRequest, error: Error?) in
            guard let observations = request.results else {
                print("no results:\(error!)")
                return
            }
            
            let classifications = observations[0...4]
                .flatMap({ $0 as? VNClassificationObservation })
                .filter({ $0.confidence > 0.2 })
                .map({ "\($0.identifier) \($0.confidence)" })
            DispatchQueue.main.async {
                self.predictLabel.text = classifications.joined(separator: "\n")
            }
        }
        classificationRequest.imageCropAndScaleOption = VNImageCropAndScaleOptionCenterCrop
        
        self.requests = [classificationRequest]
    }
    
    
    /// only support back camera
    var exifOrientationFromDeviceOrientation: Int32 {
        let exifOrientation: DeviceOrientation
        enum DeviceOrientation: Int32 {
            case top0ColLeft = 1
            case top0ColRight = 2
            case bottom0ColRight = 3
            case bottom0ColLeft = 4
            case left0ColTop = 5
            case right0ColTop = 6
            case right0ColBottom = 7
            case left0ColBottom = 8
        }
        switch UIDevice.current.orientation {
        case .portraitUpsideDown:
            exifOrientation = .left0ColBottom
        case .landscapeLeft:
            exifOrientation = .top0ColLeft
        case .landscapeRight:
            exifOrientation = .bottom0ColRight
        default:
            exifOrientation = .right0ColTop
        }
        return exifOrientation.rawValue
    }
    
    
    /// resize CVPixelBuffer
    ///
    /// - Parameter pixelBuffer: CVPixelBuffer by camera output
    /// - Returns: CVPixelBuffer with size (299, 299)
    func resize(pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        let imageSide = 299
        var ciImage = CIImage(cvPixelBuffer: pixelBuffer, options: nil)
        let transform = CGAffineTransform(scaleX: CGFloat(imageSide) / CGFloat(CVPixelBufferGetWidth(pixelBuffer)), y: CGFloat(imageSide) / CGFloat(CVPixelBufferGetHeight(pixelBuffer)))
        ciImage = ciImage.applying(transform).cropping(to: CGRect(x: 0, y: 0, width: imageSide, height: imageSide))
        let ciContext = CIContext()
        var resizeBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, imageSide, imageSide, CVPixelBufferGetPixelFormatType(pixelBuffer), nil, &resizeBuffer)
        ciContext.render(ciImage, to: resizeBuffer!)
        return resizeBuffer
    }
}

extension ViewController {
    private func emoji(for text: String) -> Emoji {
        print(text)
        if text == "computer keyboard, keypad" || text == "typewriter keyboard" {
            return Emoji.keyboard
        }
        else if text == "laptop, laptop computer" || text == "notebook, notebook computer" {
            return Emoji.laptop
        }
        else if text == "mouse, computer mouse" {
            return Emoji.mouse
        }
        else if text == "digital watch" || text == "stopwatch, stop watch" {
            return Emoji.watch
        }
        else if text == "cup" || text == "coffee mug" {
            return Emoji.mug
        }
        else if text == "wall clock" || text == "analog clock" || text == "digital clock" {
            return Emoji.clock
        }
        else if text == "studio couch, day bed" {
            return Emoji.couch
        }
        else if text == "sliding door" {
            return Emoji.door
        }
        else if text == "fountain pen" || text == "ballpoint, ballpoint pen, ballpen, Biro" {
            return Emoji.pencil
        }
        else if text == "television, television system" || text == "monitor" {
            return Emoji.television
        }
        else if text == "cellular telephone, cellular phone, cellphone, cell, mobile phone" || text == "dial telephone, dial phone" {
            return Emoji.mobilePhone
        }
        return Emoji.undefined
    }
}
