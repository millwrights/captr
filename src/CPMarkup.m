// Captr — SPDX-License-Identifier: MIT OR Apache-2.0
#import "CPMarkup.h"

static NSRect CPRectBetween(NSPoint a, NSPoint b) {
    return NSMakeRect(MIN(a.x, b.x), MIN(a.y, b.y), fabs(a.x - b.x), fabs(a.y - b.y));
}

@implementation CPMarkup

+ (instancetype)annotationWithTool:(CPTool)tool color:(NSColor *)color stroke:(CGFloat)stroke {
    CPMarkup *a = [[CPMarkup alloc] init];
    a.tool = tool;
    a.color = color ?: [NSColor systemRedColor];
    a.strokeWidth = stroke > 0 ? stroke : 3.0;
    a.points = [NSMutableArray array];
    a.fontSize = 18.0;
    a.text = @"";
    return a;
}

- (id)copyWithZone:(NSZone *)zone {
    CPMarkup *c = [[CPMarkup allocWithZone:zone] init];
    c.tool = self.tool;
    c.points = [[NSMutableArray alloc] initWithArray:self.points copyItems:NO];
    c.color = self.color;
    c.strokeWidth = self.strokeWidth;
    c.text = [self.text copy];
    c.fontSize = self.fontSize;
    c.fontName = [self.fontName copy];
    c.number = self.number;
    return c;
}

- (NSFont *)fontOfSize:(CGFloat)size {
    NSFont *f = self.fontName ? [NSFont fontWithName:self.fontName size:size] : nil;
    return f ?: [NSFont systemFontOfSize:size weight:NSFontWeightSemibold];
}

#pragma mark - Geometry

- (NSPoint)startPoint { return self.points.count > 0 ? self.points[0].pointValue : NSZeroPoint; }
- (void)setStartPoint:(NSPoint)p {
    if (self.points.count == 0) [self.points addObject:[NSValue valueWithPoint:p]];
    else self.points[0] = [NSValue valueWithPoint:p];
}
- (NSPoint)endPoint { return self.points.count > 0 ? self.points.lastObject.pointValue : NSZeroPoint; }
- (void)setEndPoint:(NSPoint)p {
    if (self.points.count < 2) {
        while (self.points.count < 1) [self.points addObject:[NSValue valueWithPoint:p]];
        [self.points addObject:[NSValue valueWithPoint:p]];
    } else {
        self.points[self.points.count - 1] = [NSValue valueWithPoint:p];
    }
}
- (void)addPoint:(NSPoint)p { [self.points addObject:[NSValue valueWithPoint:p]]; }

- (NSRect)boundingRect {
    if (self.points.count == 0) return NSZeroRect;
    NSRect r;
    if (self.tool == CPToolPen || self.tool == CPToolHighlighter) {
        NSPoint p0 = self.points[0].pointValue;
        r = NSMakeRect(p0.x, p0.y, 0, 0);
        for (NSValue *v in self.points) r = NSUnionRect(r, NSMakeRect(v.pointValue.x, v.pointValue.y, 0, 0));
    } else if (self.tool == CPToolText) {
        NSSize sz = [(self.text.length ? self.text : @"Text") sizeWithAttributes:@{ NSFontAttributeName: [self fontOfSize:self.fontSize] }];
        NSPoint s = self.startPoint;
        r = NSMakeRect(s.x, s.y, sz.width, sz.height);
    } else if (self.tool == CPToolStep) {
        CGFloat rad = self.strokeWidth * 4 + 8;
        NSPoint s = self.startPoint;
        r = NSMakeRect(s.x - rad, s.y - rad, rad * 2, rad * 2);
        if (self.text.length) {
            NSSize sz = [self.text sizeWithAttributes:@{ NSFontAttributeName: [self fontOfSize:self.fontSize] }];
            r = NSUnionRect(r, NSMakeRect(s.x + rad + 6, s.y - sz.height / 2, sz.width, sz.height));
        }
    } else {
        r = CPRectBetween(self.startPoint, self.endPoint);
    }
    return NSInsetRect(r, -6, -6);
}

- (BOOL)containsPoint:(NSPoint)p { return NSPointInRect(p, [self boundingRect]); }

- (void)translateBy:(NSSize)delta {
    for (NSUInteger i = 0; i < self.points.count; i++) {
        NSPoint p = self.points[i].pointValue;
        p.x += delta.width; p.y += delta.height;
        self.points[i] = [NSValue valueWithPoint:p];
    }
}

- (BOOL)isCommittable {
    switch (self.tool) {
        case CPToolText: return YES;   // kept; removed later if left empty
        case CPToolStep: return YES;
        case CPToolPen:
        case CPToolHighlighter: return self.points.count >= 2;
        default: {
            NSRect r = CPRectBetween(self.startPoint, self.endPoint);
            return (r.size.width >= 3 || r.size.height >= 3);
        }
    }
}

#pragma mark - Drawing

- (void)drawWithBase:(NSImage *)base
           pixelated:(NSImage *)pixelated
             blurred:(NSImage *)blurred
          canvasRect:(NSRect)canvasRect {
    NSColor *color = self.color;
    CGFloat w = self.strokeWidth;

    switch (self.tool) {
        case CPToolRectangle: {
            [color setStroke];
            NSBezierPath *path = [NSBezierPath bezierPathWithRect:CPRectBetween(self.startPoint, self.endPoint)];
            path.lineWidth = w; [path stroke];
            break;
        }
        case CPToolEllipse: {
            [color setStroke];
            NSBezierPath *path = [NSBezierPath bezierPathWithOvalInRect:CPRectBetween(self.startPoint, self.endPoint)];
            path.lineWidth = w; [path stroke];
            break;
        }
        case CPToolRedact: {
            [[NSColor blackColor] setFill];
            NSRectFill(CPRectBetween(self.startPoint, self.endPoint));
            break;
        }
        case CPToolLine: {
            [color setStroke];
            NSBezierPath *path = [NSBezierPath bezierPath];
            path.lineWidth = w; path.lineCapStyle = NSLineCapStyleRound;
            [path moveToPoint:self.startPoint]; [path lineToPoint:self.endPoint];
            [path stroke];
            break;
        }
        case CPToolArrow:  [self drawArrow:color width:w]; break;
        case CPToolPen:    [self drawFreehandWithColor:color width:w alpha:1.0]; break;
        case CPToolHighlighter: {
            NSColor *hl = [color colorWithAlphaComponent:0.35];
            [self drawFreehandWithColor:hl width:MAX(w * 4, 14) alpha:0.35];
            break;
        }
        case CPToolText:   [self drawText:color]; break;
        case CPToolStep:   [self drawStep:color]; break;
        case CPToolPixelate: [self drawRegionImage:pixelated canvasRect:canvasRect nearest:YES]; break;
        case CPToolBlur:     [self drawRegionImage:blurred   canvasRect:canvasRect nearest:NO];  break;
        case CPToolSelect:
        case CPToolCount: break;
    }
}

- (void)drawArrow:(NSColor *)color width:(CGFloat)w {
    NSPoint s = self.startPoint, e = self.endPoint;
    [color setStroke]; [color setFill];
    NSBezierPath *shaft = [NSBezierPath bezierPath];
    shaft.lineWidth = w; shaft.lineCapStyle = NSLineCapStyleRound;
    [shaft moveToPoint:s]; [shaft lineToPoint:e]; [shaft stroke];

    CGFloat angle = atan2(e.y - s.y, e.x - s.x);
    CGFloat head = MAX(w * 3.0, 12.0);
    CGFloat spread = M_PI / 7.0;
    NSPoint p1 = NSMakePoint(e.x - head * cos(angle - spread), e.y - head * sin(angle - spread));
    NSPoint p2 = NSMakePoint(e.x - head * cos(angle + spread), e.y - head * sin(angle + spread));
    NSBezierPath *tip = [NSBezierPath bezierPath];
    [tip moveToPoint:e]; [tip lineToPoint:p1]; [tip lineToPoint:p2]; [tip closePath];
    [tip fill];
}

- (void)drawFreehandWithColor:(NSColor *)color width:(CGFloat)w alpha:(CGFloat)alpha {
    if (self.points.count < 2) return;
    [color setStroke];
    NSBezierPath *path = [NSBezierPath bezierPath];
    path.lineWidth = w; path.lineJoinStyle = NSLineJoinStyleRound; path.lineCapStyle = NSLineCapStyleRound;
    [path moveToPoint:self.points[0].pointValue];
    for (NSUInteger i = 1; i < self.points.count; i++) [path lineToPoint:self.points[i].pointValue];
    [path stroke];
}

- (void)drawText:(NSColor *)color {
    NSString *s = self.text.length ? self.text : @"";
    if (!s.length) return;
    NSDictionary *attrs = @{
        NSFontAttributeName: [self fontOfSize:self.fontSize],
        NSForegroundColorAttributeName: color,
    };
    [s drawAtPoint:self.startPoint withAttributes:attrs];
}

- (void)drawStep:(NSColor *)color {
    CGFloat rad = self.strokeWidth * 4 + 8;
    NSPoint c = self.startPoint;
    NSRect circle = NSMakeRect(c.x - rad, c.y - rad, rad * 2, rad * 2);
    [color setFill];
    [[NSBezierPath bezierPathWithOvalInRect:circle] fill];

    NSString *num = [NSString stringWithFormat:@"%ld", (long)self.number];
    NSDictionary *numAttrs = @{
        NSFontAttributeName: [NSFont boldSystemFontOfSize:rad],
        NSForegroundColorAttributeName: [NSColor whiteColor],
    };
    NSSize numSize = [num sizeWithAttributes:numAttrs];
    [num drawAtPoint:NSMakePoint(c.x - numSize.width / 2, c.y - numSize.height / 2) withAttributes:numAttrs];

    // Optional explanation label to the right of the badge.
    if (self.text.length) {
        NSDictionary *labelAttrs = @{
            NSFontAttributeName: [self fontOfSize:self.fontSize],
            NSForegroundColorAttributeName: color,
        };
        NSSize sz = [self.text sizeWithAttributes:labelAttrs];
        [self.text drawAtPoint:NSMakePoint(c.x + rad + 6, c.y - sz.height / 2) withAttributes:labelAttrs];
    }
}

// Draw a full-canvas processed image (pixelated/blurred) clipped to this
// annotation's rect, so only the region is obscured.
- (void)drawRegionImage:(NSImage *)image canvasRect:(NSRect)canvasRect nearest:(BOOL)nearest {
    if (!image) return;
    NSRect region = CPRectBetween(self.startPoint, self.endPoint);
    if (NSIsEmptyRect(region)) return;
    [NSGraphicsContext saveGraphicsState];
    NSBezierPath *clip = [NSBezierPath bezierPathWithRect:region];
    [clip addClip];
    if (nearest) [NSGraphicsContext currentContext].imageInterpolation = NSImageInterpolationNone;
    [image drawInRect:canvasRect fromRect:NSZeroRect
            operation:NSCompositingOperationSourceOver fraction:1.0
       respectFlipped:YES hints:nil];
    [NSGraphicsContext restoreGraphicsState];
}

@end
