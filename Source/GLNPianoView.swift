//
//  GLNPianoView.swift
//  GLNPianoView
//
//  Created by Gary Newby on 16/05/2016.
//  Copyright © 2016 Gary Newby. All rights reserved.
//

import UIKit

@objc public protocol GLNPianoViewDelegate: class {
    func pianoKeyUp(_ keyNumber: UInt8)
    func pianoKeyDown(_ keyNumber: UInt8)
}

@IBDesignable public class GLNPianoView: UIView {
    
    @IBInspectable var showNotes: Bool = true
    @objc public weak var delegate: GLNPianoViewDelegate?
    private var keyObjectsArray: [GLNPianoKey?] = []
    private var currentTouches = NSMutableSet(capacity: maxNumberOfKeys)
    private static let minNumberOfKeys = 12
    private static let maxNumberOfKeys = 61
    private var _octave: UInt8 = 60
    private var _numberOfKeys: Int = 24
    private var _blackKeyHeight: CGFloat = 0.60
    private var _blackKeyWidth: CGFloat = 0.80
    private var whiteKeyCount = 0
    private var keyCornerRadius: CGFloat = 0
    
    @IBInspectable public var numberOfKeys: Int {
        get {
            return _numberOfKeys
        }
        set {
            _numberOfKeys = newValue.clamp(min: GLNPianoView.minNumberOfKeys, max: GLNPianoView.maxNumberOfKeys)
            setNeedsLayout()
        }
    }
    
    @IBInspectable public var blackKeyHeight: CGFloat {
        get {
            return _blackKeyHeight
        }
        set {
            let value = newValue.clamp(min: 0, max: 10)
            _blackKeyHeight = (value.rounded() + 5) * 0.05
        }
    }
    
    @IBInspectable public var blackKeyWidth: CGFloat {
        get {
            return _blackKeyWidth
        }
        set {
            let value = newValue.clamp(min: 0, max: 8)
            _blackKeyWidth = (value.rounded() + 10) * 0.05
        }
    }
    
    public var octave: UInt8 {
        get {
            return _octave
        }
        set {
            _octave = newValue
            setNeedsLayout()
        }
    }
    
    @objc public func toggleShowNotes() {
        showNotes.toggle()
        setNeedsLayout()
    }
    
    @objc public func aKeyIsDown() -> Bool {
        var downKeyCount = 0
        for key in keyObjectsArray {
            if let k = key, k.isDown {
                downKeyCount += 1
            }
        }
        return (downKeyCount > 0)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        initKeys()
    }

    private func initKeys() {
        keyCornerRadius = _blackKeyWidth * 8.0
        whiteKeyCount = 0
        currentTouches = NSMutableSet()
        keyObjectsArray = [GLNPianoKey?](repeating: nil, count: (_numberOfKeys + 1))
        for index in 1 ..< _numberOfKeys + 1 {
            if index.isWhiteKey() {
                whiteKeyCount += 1
            }
        }
        isMultipleTouchEnabled = true
        layer.masksToBounds = true
        if let subLayers = layer.sublayers {
            for layer in subLayers {
                layer.removeFromSuperlayer()
            }
        }

        let rect: CGRect = bounds
        let whiteKeyHeight = rect.size.height
        let whiteKeyWidth = whiteKeyWidthForRect(rect)
        let blackKeyHeight = rect.size.height * _blackKeyHeight
        let blackKeyWidth = whiteKeyWidth * _blackKeyWidth
        let blackKeyOffset = blackKeyWidth / 2.0

        // White Keys
        var xPosition: CGFloat = 0
        for index in 0 ..< _numberOfKeys {
            if index.isWhiteKey() {
                let newX = (xPosition + 0.5)
                let newW = ((xPosition + whiteKeyWidth + 0.5) - newX)
                let keyRect = CGRect(x: newX, y: 0, width: newW, height: whiteKeyHeight - 1)
                let key = GLNPianoKey(color: UIColor.white, rect: keyRect, type: .white, cornerRadius: keyCornerRadius,
                                      showNotes: showNotes, noteNumber: (index + Int(octave)))
                keyObjectsArray[index] = key
                layer.addSublayer(key.layer)
                xPosition += whiteKeyWidth
            }
        }
        // Black Keys
        xPosition = 0.0
        for index in 0 ..< _numberOfKeys {
            if index.isWhiteKey() {
                xPosition += whiteKeyWidth
            } else {
                let keyRect = CGRect(x: (xPosition - blackKeyOffset), y: 0, width: blackKeyWidth, height: blackKeyHeight)
                let key = GLNPianoKey(color: UIColor.black, rect: keyRect, type: .black, cornerRadius: keyCornerRadius,
                                      showNotes: showNotes, noteNumber: (index + Int(octave)),
                                      blackKeyWidth: blackKeyWidth, blackKeyHeight: blackKeyHeight)
                keyObjectsArray[index] = key
                layer.addSublayer(key.layer)
            }
        }
    }
    
    private func whiteKeyWidthForRect(_ rect: CGRect) -> CGFloat {
        return (rect.size.width / CGFloat(whiteKeyCount))
    }
    
    private func updateKeys() {
        let touches = currentTouches.allObjects as Array
        var keyIsDownAt = [Bool](repeating: false, count: _numberOfKeys)
        
        for touchIndex in 0 ..< touches.count {
            let touch = touches[touchIndex]
            let point = (touch as AnyObject).location(in: self)
            let index = getKeyContaining(point)
            if index != NSNotFound {
                keyIsDownAt[index] = true
            }
        }
        
        for index in 0 ..< _numberOfKeys {
            if keyObjectsArray[index]?.isDown != keyIsDownAt[index] {
                if keyIsDownAt[index] {
                    delegate?.pianoKeyDown(UInt8(index))
                    keyObjectsArray[index]?.setImage(keyNum: index, isDown: true)
                } else {
                    delegate?.pianoKeyUp(UInt8(index))
                    keyObjectsArray[index]?.setImage(keyNum: index, isDown: false)
                }
                keyObjectsArray[index]?.isDown = keyIsDownAt[index]
            }
        }
        setNeedsDisplay()
    }
    
    private func getKeyContaining(_ point: CGPoint) -> Int {
        var keyNum = NSNotFound
        for index in 0 ..< _numberOfKeys {
            if let frame = keyObjectsArray[index]?.layer.frame, frame.contains(point) {
                keyNum = index
                if !index.isWhiteKey() {
                    break
                }
            }
        }
        return keyNum
    }

    public func highlightKeyWith(noteNumber: UInt8, down: Bool) {
        for (index, key) in keyObjectsArray.enumerated() {
            if let key = key  {
                if key.noteNumber == Int(noteNumber) {
                    key.isDown = down
                    key.setImage(keyNum: index, isDown: down)
                    setNeedsDisplay()
                }
            }
        }
    }
    
    public override func touchesBegan(_ touches: Set<UITouch>, with _: UIEvent?) {
        for touch in touches {
            currentTouches.add(touch)
        }
        updateKeys()
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with _: UIEvent?) {
        for touch in touches {
            currentTouches.add(touch)
        }
        updateKeys()
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with _: UIEvent?) {
        for touch in touches {
            currentTouches.remove(touch)
        }
        updateKeys()
    }
    
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            currentTouches.remove(touch)
        }
        updateKeys()
    }

}
