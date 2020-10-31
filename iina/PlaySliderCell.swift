//
//  PlaySlider.swift
//  iina
//
//  Created by lhc on 25/7/16.
//  Copyright © 2016 lhc. All rights reserved.
//

import Cocoa

class PlaySliderCell: NSSliderCell {

  lazy var playerCore: PlayerCore = {
    let windowController = self.controlView!.window!.windowController
    if let mainWindowController = windowController as? MainWindowController {
      return mainWindowController.player
    }
    return (windowController as! MiniPlayerWindowController).player
  }()

  override var knobThickness: CGFloat {
    return knobWidth
  }

  let knobWidth: CGFloat = 3
  let knobHeight: CGFloat = 15
  let knobRadius: CGFloat = 1
  let barRadius: CGFloat = 1.5

  var isInDarkTheme: Bool = true

  private var knobColor: NSColor = {
    return NSColor(named: .mainSliderKnob)!
  }()
  private var knobActiveColor: NSColor = {
    return NSColor(named: .mainSliderKnobActive)!
  }()
  private var barColorLeft: NSColor = {
    return NSColor(named: .mainSliderBarLeft)!

  }()
  private var barColorRight: NSColor = {
    return NSColor(named: .mainSliderBarRight)!
  }()
  private var chapterStrokeColor: NSColor = {
    return NSColor(named: .mainSliderBarChapterStroke)!
  }()

  var drawChapters = Preference.bool(for: .showChapterPos)

  var isPausedBeforeSeeking = false

  override func awakeFromNib() {
    minValue = 0
    maxValue = 100
  }

  override func drawKnob(_ knobRect: NSRect) {
    // Round the X position for cleaner drawing
    let rect = NSMakeRect(round(knobRect.origin.x),
                          knobRect.origin.y + 0.5 * (knobRect.height - knobHeight),
                          knobRect.width,
                          knobHeight)
    let isLightTheme = !controlView!.window!.effectiveAppearance.isDark

    if #available(macOS 10.14, *), isLightTheme {
      NSGraphicsContext.saveGraphicsState()
      let shadow = NSShadow()
      shadow.shadowBlurRadius = 1
      shadow.shadowColor = .controlShadowColor
      shadow.shadowOffset = NSSize(width: 0, height: -0.5)
      shadow.set()
    }

    let path = NSBezierPath(roundedRect: rect, xRadius: knobRadius, yRadius: knobRadius)
    (isHighlighted ? knobActiveColor : knobColor).setFill()
    path.fill()

    if #available(macOS 10.14, *), isLightTheme {
      path.lineWidth = 0.4
      NSColor.controlShadowColor.setStroke()
      path.stroke()
      NSGraphicsContext.restoreGraphicsState()
    }
  }

  override func knobRect(flipped: Bool) -> NSRect {
    let slider = self.controlView as! NSSlider
    let bounds = super.barRect(flipped: flipped)
    let percentage = slider.doubleValue / (slider.maxValue - slider.minValue)
    let pos = min(CGFloat(percentage) * bounds.width, bounds.width - 1);
    let rect = super.knobRect(flipped: flipped)
    let flippedMultiplier = flipped ? CGFloat(-1) : CGFloat(1)
    return NSMakeRect(pos - flippedMultiplier * 0.5 * knobWidth, rect.origin.y, knobWidth, rect.height)
  }

  override func drawBar(inside rect: NSRect, flipped: Bool) {
    let info = playerCore.info

    let slider = self.controlView as! NSSlider

    /// The position of the knob, rounded for cleaner drawing
    let knobPos : CGFloat = round(knobRect(flipped: flipped).origin.x);

    /// How far progressed the current video is, used for drawing the bar background
    var progress : CGFloat = 0;

    if info.isNetworkResource,
      info.cacheTime != 0,
      let duration = info.videoDuration,
      duration.second != 0 {
      let pos = Double(info.cacheTime) / Double(duration.second) * 100
      progress = round(rect.width * CGFloat(pos / (slider.maxValue - slider.minValue))) + 2;
    } else {
      progress = knobPos;
    }

    let barRect: NSRect
    if #available(macOS 10.16, *) {
      barRect = rect
    } else {
      barRect = NSMakeRect(rect.origin.x, rect.origin.y + 1, rect.width, rect.height - 2)
    }
    let path = NSBezierPath(roundedRect: barRect, xRadius: barRadius, yRadius: barRadius)

    // draw left
    let pathLeftRect : NSRect = NSMakeRect(barRect.origin.x, barRect.origin.y, progress, barRect.height)
    NSBezierPath(rect: pathLeftRect).addClip();

    if #available(macOS 10.14, *), !controlView!.window!.effectiveAppearance.isDark {
      // Draw knob shadow in 10.14+ light theme
    } else {
      // Clip 1px around the knob
      path.append(NSBezierPath(rect: NSRect(x: knobPos - 1, y: barRect.origin.y, width: knobWidth + 2, height: barRect.height)).reversed);
    }

    barColorLeft.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()

    // draw right
    NSGraphicsContext.saveGraphicsState()
    let pathRight = NSMakeRect(barRect.origin.x + progress, barRect.origin.y, barRect.width - progress, barRect.height)
    NSBezierPath(rect: pathRight).setClip()
    barColorRight.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()

    // draw chapters
    NSGraphicsContext.saveGraphicsState()
    if drawChapters {
      if let totalSec = info.videoDuration?.second {
        chapterStrokeColor.setStroke()
        var chapters = info.chapters
        if chapters.count > 0 {
          chapters.remove(at: 0)
          chapters.forEach { chapt in
            let chapPos = CGFloat(chapt.time.second) / CGFloat(totalSec) * barRect.width
            let linePath = NSBezierPath()
            linePath.move(to: NSPoint(x: chapPos, y: barRect.origin.y))
            linePath.line(to: NSPoint(x: chapPos, y: barRect.origin.y + barRect.height))
            linePath.stroke()
          }
        }
      }
    }
    NSGraphicsContext.restoreGraphicsState()
  }

  override func barRect(flipped: Bool) -> NSRect {
    let rect = super.barRect(flipped: flipped)
    return NSMakeRect(0, rect.origin.y, rect.width + rect.origin.x * 2, rect.height)
  }


  override func startTracking(at startPoint: NSPoint, in controlView: NSView) -> Bool {
    isPausedBeforeSeeking = playerCore.info.isPaused
    let result = super.startTracking(at: startPoint, in: controlView)
    if result {
      playerCore.pause()
      playerCore.mainWindow.thumbnailPeekView.isHidden = true
    }
    return result
  }

  override func stopTracking(last lastPoint: NSPoint, current stopPoint: NSPoint, in controlView: NSView, mouseIsUp flag: Bool) {
    if !isPausedBeforeSeeking {
      playerCore.resume()
    }
    super.stopTracking(last: lastPoint, current: stopPoint, in: controlView, mouseIsUp: flag)
  }

}
