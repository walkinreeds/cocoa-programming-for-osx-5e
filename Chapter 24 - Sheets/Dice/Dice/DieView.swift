//
//  DieView.swift
//  Dice
//
//  Created by Adam Preble on 8/22/14.
//  Copyright (c) 2014 Big Nerd Ranch. All rights reserved.
//

import Cocoa

class DieView: NSView, NSDraggingSource {
	
	var intValue: Int? = 1 {
		didSet {
			needsDisplay = true
		}
	}

	var pressed: Bool = false {
		didSet {
			needsDisplay = true
		}
	}

	var highlightForDragging: Bool = false {
		didSet {
			needsDisplay = true
		}
	}

    var color: NSColor = NSColor.whiteColor() {
        didSet {
            needsDisplay = true
        }
    }
    
    var numberOfTimesToRoll: Int = 10

	var mouseDownEvent: NSEvent?
	var rollsRemaining: Int = 0
	
	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
		commonInit()
	}
	required init?(coder: NSCoder) {
		super.init(coder: coder)
		commonInit()
	}
	
	func commonInit() {
		self.registerForDraggedTypes([NSPasteboardTypeString])
	}

	
	func roll() {
		rollsRemaining = numberOfTimesToRoll
		NSTimer.scheduledTimerWithTimeInterval(0.15, target: self, selector: Selector("rollTick:"), userInfo: nil, repeats: true)
		window?.makeFirstResponder(nil)
	}

	func rollTick(sender: NSTimer) {
		let lastIntValue = intValue
		while intValue == lastIntValue {
			randomize()
		}
		rollsRemaining--
		if rollsRemaining == 0 {
			sender.invalidate()
			window?.makeFirstResponder(self)
		}
	}

	func randomize() {
		intValue = Int(arc4random_uniform(5) + 1)
	}

	override var intrinsicContentSize: NSSize {
		return NSSize(width: 20, height: 20)
	}

	override func drawRect(dirtyRect: NSRect) {
		let backgroundColor = NSColor.lightGrayColor()
		backgroundColor.set()
		NSBezierPath.fillRect(bounds)
		
		if highlightForDragging {
			let gradient = NSGradient(startingColor: color, endingColor: backgroundColor)!
			gradient.drawInRect(bounds, relativeCenterPosition: NSZeroPoint)
		}
		else {
			drawDieWithSize(bounds.size)
		}
	}
	
	func metricsForSize(size: CGSize) -> (edgeLength: CGFloat, dieFrame: CGRect) {
		let edgeLength = min(size.width, size.height)
		let padding = edgeLength/10.0
		let drawingBounds = CGRect(x: 0, y: 0, width: edgeLength, height: edgeLength)
		var dieFrame = drawingBounds.insetBy(dx: padding, dy: padding)
		if pressed {
			dieFrame = dieFrame.offsetBy(dx: 0, dy: -edgeLength/40)
		}
		return (edgeLength, dieFrame)
	}
	
	func drawDieWithSize(size: CGSize) {
		if let intValue = intValue {
			let (edgeLength, dieFrame) = metricsForSize(size)
			let cornerRadius:CGFloat = edgeLength/5.0
			let dotRadius = edgeLength/12.0
			let dotFrame = dieFrame.insetBy(dx: dotRadius * 2.5, dy: dotRadius * 2.5)
			
			NSGraphicsContext.saveGraphicsState()
			
			let shadow = NSShadow()
			shadow.shadowOffset = NSSize(width: 0, height: -1)
			shadow.shadowBlurRadius = (pressed ? edgeLength/100 : edgeLength/20)
			shadow.set()
			
			color.set()
			NSBezierPath(roundedRect: dieFrame, xRadius: cornerRadius, yRadius: cornerRadius).fill()
			
			NSGraphicsContext.restoreGraphicsState()
			
			NSColor.blackColor().set()
			
			func drawDot(u: CGFloat, _ v: CGFloat) {
				let dotOrigin = CGPoint(x: dotFrame.minX + dotFrame.width * u,
										y: dotFrame.minY + dotFrame.height * v)
				let dotRect = CGRect(origin: dotOrigin, size: CGSizeZero)
					.insetBy(dx: -dotRadius, dy: -dotRadius)
				NSBezierPath(ovalInRect: dotRect).fill()
			}
			
			if (1...6).indexOf(intValue) != nil {
				// Draw Dots
				if [1, 3, 5].indexOf(intValue) != nil {
					drawDot(0.5, 0.5) // center dot
				}
				if (2...6).indexOf(intValue) != nil {
					drawDot(0, 1) // upper left
					drawDot(1, 0) // lower right
				}
				if (4...6).indexOf(intValue) != nil {
					drawDot(1, 1) // upper right
					drawDot(0, 0) // lower left
				}
				if intValue == 6 {
					drawDot(0, 0.5) // mid left/right
					drawDot(1, 0.5)
				}
			}
			else {
				let paraStyle = NSParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
				paraStyle.alignment = .Center
				let font = NSFont.systemFontOfSize(edgeLength * 0.6)
				let attrs = [
					NSForegroundColorAttributeName: NSColor.blackColor(),
							   NSFontAttributeName: font,
					 NSParagraphStyleAttributeName: paraStyle ]
				let string = "\(intValue)" as NSString
				string.drawCenteredInRect(dieFrame, attributes: attrs)
			}
		}
	}
	
	@IBAction func savePDF(sender: AnyObject!) {
		let savePanel = NSSavePanel()
		savePanel.allowedFileTypes = ["pdf"]
        savePanel.beginSheetModalForWindow(window!) {
            [unowned savePanel] (result) in
            if result == NSModalResponseOK {
                let data = self.dataWithPDFInsideRect(self.bounds)
                do {
                    try data.writeToURL(savePanel.URL!,
                        options: NSDataWritingOptions.DataWritingAtomic)
                } catch let error as NSError {
                    let alert = NSAlert(error: error)
                    alert.runModal()
                } catch {
                    fatalError("unknown error")
                }
            }
        }
	}

	// MARK: - Mouse Events
	
	override func mouseDown(theEvent: NSEvent) {
		Swift.print("mouseDown")
		mouseDownEvent = theEvent
		
		let dieFrame = metricsForSize(bounds.size).dieFrame
		let pointInView = convertPoint(theEvent.locationInWindow, fromView: nil)
		pressed = dieFrame.contains(pointInView)
	}
	override func mouseDragged(theEvent: NSEvent) {
		Swift.print("mouseDragged location: \(theEvent.locationInWindow)")

		let downPoint = mouseDownEvent!.locationInWindow
		let dragPoint = theEvent.locationInWindow
		
		let distanceDragged = hypot(downPoint.x - dragPoint.x, downPoint.y - dragPoint.y)
		if distanceDragged < 3 {
			return
		}
		
		pressed = false
		
		if let intValue = intValue {
			let imageSize = bounds.size
			let image = NSImage(size: imageSize, flipped: false) { (imageBounds) in
				self.drawDieWithSize(imageBounds.size)
				return true
			}
			
			let draggingFrameOrigin = convertPoint(downPoint, fromView: nil)
			let draggingFrame = NSRect(origin: draggingFrameOrigin, size: imageSize).offsetBy(dx: -imageSize.width/2, dy: -imageSize.height/2)
			
			let item = NSDraggingItem(pasteboardWriter: "\(intValue)")
			item.draggingFrame = draggingFrame
			item.imageComponentsProvider = {
				let component = NSDraggingImageComponent(key: NSDraggingImageComponentIconKey)
				component.contents = image
				component.frame = NSRect(origin: NSPoint(), size: imageSize)
				return [component]
			}
			
			beginDraggingSessionWithItems([item], event:mouseDownEvent!, source: self)
		}
	}
	override func mouseUp(theEvent: NSEvent) {
		Swift.print("mouseUp clickCount: \(theEvent.clickCount)")
		if theEvent.clickCount == 2 && pressed {
			roll()
		}
		pressed = false
	}
	
	// MARK: - Drag Source

	func draggingSession(session: NSDraggingSession, sourceOperationMaskForDraggingContext context: NSDraggingContext) -> NSDragOperation {
		return [.Copy, .Delete]
	}
	
	func draggingSession(session: NSDraggingSession, endedAtPoint screenPoint: NSPoint, operation: NSDragOperation) {
		if operation == .Delete {
			intValue = nil
		}
	}

	// MARK: - Drag Destination

	override func draggingEntered(sender: NSDraggingInfo) -> NSDragOperation {
		if sender.draggingSource() === self {
			return .None
		}
		highlightForDragging = true
		return sender.draggingSourceOperationMask()
	}

	override func draggingExited(sender: NSDraggingInfo?) {
		highlightForDragging = false
	}
	
	override func prepareForDragOperation(sender: NSDraggingInfo) -> Bool {
		return true
	}
	
	override func performDragOperation(sender: NSDraggingInfo) -> Bool {
		let ok = readFromPasteboard(sender.draggingPasteboard())
		return ok
	}
	
	override func concludeDragOperation(sender: NSDraggingInfo?) {
		highlightForDragging = false
	}
	

	// MARK: - First Responder
	
	override var acceptsFirstResponder: Bool { return true  }
	
	override func becomeFirstResponder() -> Bool {
		return true
	}
	
	override func resignFirstResponder() -> Bool {
		return true
	}
	
	override func drawFocusRingMask() {
		// Try this:
		//drawDieWithSize(bounds.size)
		NSBezierPath.fillRect(bounds)
	}
	override var focusRingMaskBounds: NSRect {
		return bounds
	}
	
	// MARK: Keyboard Events
	
	override func keyDown(theEvent: NSEvent) {
		interpretKeyEvents([theEvent])
	}
	
	override func insertText(insertString: AnyObject) {
		let text = insertString as! String
		if let number = Int(text) {
			intValue = number
		}
	}

	override func insertTab(sender: AnyObject?) {
		window?.selectNextKeyView(sender)
	}
	override func insertBacktab(sender: AnyObject?) {
		window?.selectPreviousKeyView(sender)
	}

	// MARK: - Pasteboard
	
	func writeToPasteboard(pasteboard: NSPasteboard) {
		if let intValue = intValue {
			pasteboard.clearContents()
			pasteboard.writeObjects(["\(intValue)"])
		}
	}
	
	func readFromPasteboard(pasteboard: NSPasteboard) -> Bool {
		let objects = pasteboard.readObjectsForClasses([NSString.self], options: [:]) as! [String]
		if let str = objects.first {
			intValue = Int(str)
			return true
		}
		return false
	}
	
	@IBAction func cut(sender: AnyObject?) {
		writeToPasteboard(NSPasteboard.generalPasteboard())
		intValue = nil
	}
	@IBAction func copy(sender: AnyObject?) {
		writeToPasteboard(NSPasteboard.generalPasteboard())
	}
	@IBAction func paste(sender: AnyObject?) {
		readFromPasteboard(NSPasteboard.generalPasteboard())
	}

}
