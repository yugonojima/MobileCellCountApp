//
//  ViewController.swift
//  CoreMLPlayground
//
//  Created by Shuichi Tsutsumi on 2018/06/14.
//  Copyright © 2018 Shuichi Tsutsumi. All rights reserved.
//

import UIKit
import CoreML
import Vision

class ViewController: UIViewController ,UIGestureRecognizerDelegate{

    private var videoCapture: VideoCapture!
    private let serialQueue = DispatchQueue(label: "com.shu223.coremlplayground.serialqueue")
    
    private let videoSize = CGSize(width: 1280, height: 720)
    private let preferredFps: Int32 = 2
    private var touched:Bool = false
    
    private var modelUrls: [URL]!
    private var selectedVNModel: VNCoreMLModel?
    private var selectedModel: MLModel?

    private var cropAndScaleOption: VNImageCropAndScaleOption = .scaleFit
    
    @IBOutlet private weak var previewView: UIView! //@IBOutlet : storyboardと紐づけるための宣言
    @IBOutlet private weak var modelLabel: UILabel!
    @IBOutlet private weak var resultView: UIView!
    @IBOutlet private weak var resultLabel: UILabel!
    @IBOutlet private weak var othersLabel: UILabel!
    @IBOutlet private weak var bbView: BoundingBoxView!
//    @IBOutlet weak var cropAndScaleOptionSelector: UISegmentedControl!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
           
        //UIGestureのデリゲート
        tapGesture.delegate = self
           
        //viewに追加
        self.view.addGestureRecognizer(tapGesture)

        let spec = VideoSpec(fps: preferredFps, size: videoSize)
        let frameInterval = 1.0 / Double(preferredFps)
        
        videoCapture = VideoCapture(cameraType: .back,
                                    preferredSpec: spec,
                                    previewContainer: previewView.layer)
    
        videoCapture.imageBufferHandler = {[unowned self] (imageBuffer, timestamp, outputBuffer) in
            let delay = CACurrentMediaTime() - timestamp.seconds
            if delay > frameInterval {
                return
            }
            
            self.serialQueue.async {
                if (self.touched == false) {
                    self.runModel(imageBuffer: imageBuffer)
                } else if (self.touched == true) {
                    return
                }
                
            }
        }
        
       
        
        let modelPaths = Bundle.main.paths(forResourcesOfType: "mlmodel", inDirectory: "models")
        
        modelUrls = []
        for modelPath in modelPaths {
            let url = URL(fileURLWithPath: modelPath)
            let compiledUrl = try! MLModel.compileModel(at: url)
            modelUrls.append(compiledUrl)
        }
        
        selectModel(url: modelUrls.first!)

        
        // scaleFill
//        cropAndScaleOptionSelector.selectedSegmentIndex = 0 //最初に何番目の項目が選択されている状態にするか
//        updateCropAndScaleOption()
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
        // TODO: Should be dynamically determined
        self.bbView.updateSize(for: CGSize(width: videoSize.height, height: videoSize.width))
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        guard let videoCapture = videoCapture else {return}
        videoCapture.stopCapture()
        super.viewWillDisappear(animated)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - Private
    
    private func showActionSheet() {
        let alert = UIAlertController(title: "Models", message: "Choose a model", preferredStyle: .actionSheet)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alert.addAction(cancelAction)
        
        for modelUrl in modelUrls {
            let action = UIAlertAction(title: modelUrl.modelName, style: .default) { (action) in
                self.selectModel(url: modelUrl)
            }
            alert.addAction(action)
        }
        present(alert, animated: true, completion: nil)
    }
    
    private func selectModel(url: URL) {
        selectedModel = try! MLModel(contentsOf: url)
        do {
            selectedVNModel = try VNCoreMLModel(for: selectedModel!)
            modelLabel.text = url.modelName
        }
        catch {
            fatalError("Could not create VNCoreMLModel instance from \(url). error: \(error).")
        }
    }
    
    private func runModel(imageBuffer: CVPixelBuffer) {
        guard let model = selectedVNModel else { return }
        let handler = VNImageRequestHandler(cvPixelBuffer: imageBuffer)
        
        let request = VNCoreMLRequest(model: model, completionHandler: { (request, error) in
            if let results = request.results as? [VNClassificationObservation] {
                self.processClassificationObservations(results)
            } else if #available(iOS 12.0, *), let results = request.results as? [VNRecognizedObjectObservation] {
                self.processObjectDetectionObservations(results)
            }
        })
        
        request.preferBackgroundProcessing = true
        request.imageCropAndScaleOption = cropAndScaleOption
        
        do {
            try handler.perform([request])
        } catch {
            print("failed to perform")
        }
    }
    
    @objc func tapped(_ sender: UITapGestureRecognizer) {
        //タップ直後に中身を実行
                if sender.state == .ended {
                    if (touched == false) {
                        touched = true
                    } else if (touched == true) {
                        touched = false
                    }
                    
                }
    }

    @available(iOS 12.0, *)
    private func processObjectDetectionObservations(_ results: //モデルから検出結果を受け取り、描画を行う
        [VNRecognizedObjectObservation]) {
        bbView.observations = results
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.resultView.isHidden = true
            self.bbView.isHidden = false
            self.bbView.setNeedsDisplay()
        }
    }

    private func processClassificationObservations(_ results: [VNClassificationObservation]) {
        var firstResult = ""
        var others = ""
        for i in 0...10 {
            guard i < results.count else { break }
            let result = results[i]
            let confidence = String(format: "%.2f", result.confidence * 100)
            if i==0 {
                firstResult = "\(result.identifier) \(confidence)"
            } else {
                others += "\(result.identifier) \(confidence)\n"
            }
        }
        DispatchQueue.main.async(execute: {
            self.bbView.isHidden = true
            self.resultView.isHidden = false
            self.resultLabel.text = firstResult
            self.othersLabel.text = others
        })
    }

//    private func updateCropAndScaleOption() {
//        let selectedIndex = cropAndScaleOptionSelector.selectedSegmentIndex
//        cropAndScaleOption = VNImageCropAndScaleOption(rawValue: UInt(selectedIndex))!
//    }
//
    
    
    // MARK: - Actions
    
    //Changeのボタンが押されると行われる描画
    @IBAction func modelBtnTapped(_ sender: UIButton) {
        showActionSheet()
    }
    
//    @IBAction func cropAndScaleOptionChanged(_ sender: UISegmentedControl) {
//        updateCropAndScaleOption()
//    }
    
    
//    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
//
//        UIGraphicsBeginImageContextWithOptions(view.frame.size, false, 0.0);
//        view.drawHierarchy(in: view.frame, afterScreenUpdates: true)
//        let screenShotImage:UIImage = UIGraphicsGetImageFromCurrentImageContext()!  //スリーンショットがUIImage型で取得できる
//        UIGraphicsEndImageContext()
//        let imageView = UIImageView(image:screenShotImage)
//        self.view.addSubview(imageView)
//
//     }
//    //タッチ操作をした際の処理
//    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
//        let imageView = UIImageView(image:screenShotImage)
//        imageView.removeFromSuperview()
//    }
}

extension ViewController: UIPopoverPresentationControllerDelegate {
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "popover" {
            let vc = segue.destination
            vc.modalPresentationStyle = UIModalPresentationStyle.popover
            vc.popoverPresentationController!.delegate = self
        }
        
        if let modelDescriptionVC = segue.destination as? ModelDescriptionViewController, let model = selectedModel {
            modelDescriptionVC.modelDescription = model.modelDescription
        }
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
}

extension URL {
    var modelName: String {
        return lastPathComponent.replacingOccurrences(of: ".mlmodelc", with: "")
    }
}
