//
//  GHContextOverlayView.m
//  GHContextMenu
//
//  Created by Tapasya on 27/01/14.
//  Copyright (c) 2014 Tapasya. All rights reserved.
//  Updated by Levi Nunnink on 2015
//

#import "GHContextMenuView.h"

#define GHShowAnimationID @"GHContextMenuViewRriseAnimationID"
#define GHDismissAnimationID @"GHContextMenuViewDismissAnimationID"
#define GHShowAllAnimationID @"GHShowAllAnimationID"
#define GHHideAllAnimationID @"GHHideAllAnimationID"

#define RAD2DEG(x) ((x) * 180 / M_PI)
#define DEGREES_TO_RADIANS(x) (M_PI * (x) / 180.0)

NSInteger const GHMainItemSize = 50;
NSInteger const GHMenuItemSize = 50;
NSInteger const GHBorderWidth  = 0;

CGFloat const   GHAnimationDuration = 0.25;
CGFloat const   GHAnimationDelay = GHAnimationDuration / 4;


@interface GHMenuItemLocation : NSObject

@property (nonatomic) CGPoint position;
@property (nonatomic) CGFloat angle;

@end

@implementation GHMenuItemLocation

@end


@interface GHContextMenuView ()<UIGestureRecognizerDelegate>
{
    CADisplayLink *displayLink;
}

@property (nonatomic, strong) UILongPressGestureRecognizer* longPressRecognizer;

@property (nonatomic, assign) BOOL isShowing;
@property (nonatomic, assign) BOOL isPanning;

@property (nonatomic) CGPoint longPressLocation;
@property (nonatomic) CGPoint currentLocation;

@property (nonatomic, strong) NSMutableArray* menuItems;
@property (nonatomic, strong) NSMutableArray* titles;
@property (nonatomic, strong) NSMutableArray* titleItems;

@property (nonatomic) CGFloat radius;
@property (nonatomic) CGFloat arcAngle;
@property (nonatomic) CGFloat angleBetweenItems;
@property (nonatomic, strong) NSMutableArray* itemLocations;
@property (nonatomic) NSInteger prevIndex;

@property (nonatomic,retain) id itemBGHighlightedColor;
@property (nonatomic,retain) id itemBGColor;

@property (nonatomic) CGFloat cachedStartAngle;

@property (nonatomic, weak) UIView *gestureRecognizerView;

@end

@implementation GHContextMenuView

- (id)init
{
    self = [super initWithFrame:UIScreen.mainScreen.bounds];
    if (self) {
        // Initialization code
        self.userInteractionEnabled = YES;
        self.backgroundColor  = [UIColor clearColor];
        _menuActionType = GHContextMenuActionTypePan;

        displayLink = [CADisplayLink displayLinkWithTarget:self
                                                  selector:@selector(highlightMenuItemForPoint)];
        
        [displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        
        _menuItems = [NSMutableArray array];
        _titleItems = [NSMutableArray array];
        _titles = [NSMutableArray array];
        _itemLocations = [NSMutableArray array];
        _arcAngle = M_PI_2;
        _radius = 70;
        
        self.itemBGColor = (id)[UIColor clearColor].CGColor;
        self.itemBGHighlightedColor = (id)[UIColor clearColor].CGColor;
        
    }
    return self;
}

#pragma mark -
#pragma mark Layer Touch Tracking
#pragma mark -

-(NSInteger)indexOfClosestMatchAtPoint:(CGPoint)point
{
    int i = 0;
    for(CALayer *menuItemLayer in self.menuItems) {
        if( CGRectContainsPoint( menuItemLayer.frame, point ) ) {
            return i;
        }
        i++;
    }
    return -1;
}


-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{

    CGPoint menuAtPoint = CGPointZero;

    if ([touches count] == 1) {

        UITouch *touch = (UITouch *)touches.anyObject;
        CGPoint touchPoint = [touch locationInView:self];

        NSInteger menuItemIndex = [self indexOfClosestMatchAtPoint:touchPoint];
        if( menuItemIndex > -1 ) {
            menuAtPoint = [(CALayer *)self.menuItems[(NSUInteger)menuItemIndex] position];
        }

        if( (self.prevIndex >= 0 && self.prevIndex != menuItemIndex)) {
            [self resetPreviousSelection];
        }
        self.prevIndex = menuItemIndex;
    }
	
	menuAtPoint = [self convertPoint:menuAtPoint toView:self.gestureRecognizerView];

    [self dismissWithSelectedIndexForMenuAtPoint: menuAtPoint];
}


#pragma mark -
#pragma mark LongPress handler
#pragma mark -

// Split this out of the longPressDetected so that we can reuse it with touchesBegan (above)
-(void)dismissWithSelectedIndexForMenuAtPoint:(CGPoint)point
{

    if(self.delegate && [self.delegate respondsToSelector:@selector(menuView:didSelectItemAtIndex:forMenuAtPoint:)] && self.prevIndex >= 0){
        [self.delegate menuView:self didSelectItemAtIndex:self.prevIndex forMenuAtPoint:point];
		
		CALayer *item = (CALayer *)self.menuItems[(NSUInteger)self.prevIndex];
		
		[self attachPopUpAnimationToLayer:item completion:^{
			[self hideMenu];
		}];
		
        self.prevIndex = -1;
	} else {
		[self hideMenu];
	}

}

- (void)longPressDetected:(UIGestureRecognizer*) gestureRecognizer
{
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        
        // Don't start when we have zero items.
        if(self.menuItems.count == 0) {
            return;
        }
        
        
        self.prevIndex = -1;
        
        CGPoint pointInView;
        
        // If the menu should be anchored to the center of the view, do so
        if (self.menuAnchor == GHContextMenuAnchorContainingView) {
            pointInView = gestureRecognizer.view.center;
        } else {
            // Otherwise anchor it to the touch by default
            pointInView = [gestureRecognizer locationInView:gestureRecognizer.view];
        }
        
        if (self.dataSource != nil && [self.dataSource respondsToSelector:@selector(menuView:shouldShowMenuAtPoint:)] && ![self.dataSource menuView:self shouldShowMenuAtPoint:pointInView]){
            return;
        }
        
        [[UIApplication sharedApplication].keyWindow addSubview:self];
        if (self.menuAnchor == GHContextMenuAnchorContainingView) {
			self.longPressLocation = CGPointMake(gestureRecognizer.view.frame.origin.x + (gestureRecognizer.view.frame.size.width / 2), gestureRecognizer.view.frame.origin.y + gestureRecognizer.view.layer.borderWidth);
		} else {
            CGPoint longPressLocation = [gestureRecognizer locationInView:self];
			
			if (longPressLocation.x - 110 <= 0) {
				longPressLocation.x = 110;
			} else if (longPressLocation.x + 100 >= self.frame.size.width) {
				longPressLocation.x = self.frame.size.width - 110;
			}
			
			if (longPressLocation.y - 100 <= 0) {
				longPressLocation.y = 110;
			} else if (longPressLocation.y + 100 >= self.frame.size.height) {
				longPressLocation.y = self.frame.size.height - 100;
			}
			
			
			self.longPressLocation = longPressLocation;
        }
        [self showMenu];
    }
    
    if (gestureRecognizer.state == UIGestureRecognizerStateChanged) {
        if (self.isShowing && (self.menuActionType == GHContextMenuActionTypePan || self.menuActionType == GHContextmenuActionTypePanAndTap)) {
            self.isPanning = YES;
            self.currentLocation =  [gestureRecognizer locationInView:self];
        }
    }
    
    // Only trigger if we're using the GHContextMenuActionTypePan (default)
    if((gestureRecognizer.state == UIGestureRecognizerStateEnded && self.menuActionType == GHContextMenuActionTypePan) || (gestureRecognizer.state == UIGestureRecognizerStateEnded && self.menuActionType == GHContextmenuActionTypePanAndTap && self.prevIndex >= 0)) {
        CGPoint menuAtPoint = [self convertPoint:self.longPressLocation toView:gestureRecognizer.view];
        [self dismissWithSelectedIndexForMenuAtPoint:menuAtPoint];
	} else {
		self.gestureRecognizerView = gestureRecognizer.view;
	}
}

- (void) showMenu
{
    self.frame = UIScreen.mainScreen.bounds;
    self.isShowing = YES;
    [self animateMenu:YES];
    [self setNeedsDisplay];
}

- (void) hideMenu
{
    if (self.isShowing) {
        [CATransaction begin];
        [CATransaction setCompletionBlock:^{
            [self removeFromSuperview];
        }];
        self.isShowing = NO;
        self.isPanning = NO;
        [self animateMenu:NO];
        [self setNeedsDisplay];
        [CATransaction commit];
    }
}

- (CALayer*) layerWithImage:(UIImage*) image
{
    CALayer* imageLayer = [CALayer layer];
    [imageLayer setContentsGravity:kCAGravityResizeAspect];
	imageLayer.contentsScale = [UIScreen mainScreen].scale;
    imageLayer.contents = (id) image.CGImage;
    imageLayer.bounds = CGRectMake(0, 0, GHMenuItemSize, GHMenuItemSize);
    imageLayer.position = CGPointMake(GHMenuItemSize / 2, GHMenuItemSize / 2);
	imageLayer.rasterizationScale = [UIScreen mainScreen].scale;

	return imageLayer;
}

-(CALayer *)layerWithTitle:(NSString *)title
{
    UIFont *font = [UIFont fontWithName:@"HelveticaNeue-Medium" size:14.0f];
    
    CGSize boundingSize = [title boundingRectWithSize:CGSizeMake(FLT_MAX, FLT_MAX) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName: font} context:nil].size;
    CATextLayer *textLayer = [CATextLayer layer];
    textLayer.zPosition = 10.0f;
    textLayer.cornerRadius = 3.0f;
    textLayer.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.9].CGColor;
    textLayer.font = (__bridge CFTypeRef)(font.fontName);
    textLayer.fontSize = font.pointSize;
    textLayer.frame = CGRectMake(0, 0, boundingSize.width + 10, boundingSize.height + 2);
    textLayer.alignmentMode = kCAAlignmentCenter;
    textLayer.foregroundColor = [UIColor whiteColor].CGColor;
    textLayer.string = title;
    textLayer.opacity = 0.0;
    textLayer.contentsScale = UIScreen.mainScreen.scale;
    
    return textLayer;
}

- (void) setDataSource:(id<GHContextOverlayViewDataSource>)dataSource
{
    _dataSource = dataSource;
    [self reloadData];

}

# pragma mark - menu item layout

- (void) reloadData
{
    [self.menuItems makeObjectsPerformSelector:@selector(removeFromSuperlayer)];
    [self.titleItems makeObjectsPerformSelector:@selector(removeFromSuperlayer)];
    
    [self.menuItems removeAllObjects];
    [self.titleItems removeAllObjects];
    [self.titles removeAllObjects];
    [self.itemLocations removeAllObjects];
    
    if (self.dataSource != nil) {
        NSInteger count = [self.dataSource numberOfMenuItemsForMenuView:self];
        for (int i = 0; i < count; i++) {
            UIImage* image = [self.dataSource menuView:self imageForItemAtIndex:i];
            CALayer *layer = [self layerWithImage:image];
            [self.layer addSublayer:layer];
            [self.menuItems addObject:layer];
			if ([self.dataSource respondsToSelector:@selector(menuView:titleForItemAtIndex:)]) {
				NSString *title = [self.dataSource menuView:self titleForItemAtIndex:i];
				CALayer *textLayer = [self layerWithTitle:title];
				[self.layer addSublayer:textLayer];
				[self.titleItems addObject:textLayer];
				[self.titles addObject:title];
			}
        }
		
		self.layer.shouldRasterize = YES;
		self.layer.rasterizationScale = UIScreen.mainScreen.scale;
    }
}

- (void)layoutMenuItems
{
    [self.itemLocations removeAllObjects];
    
    self.angleBetweenItems = M_PI / 2.5;
    self.arcAngle = MAX(self.menuItems.count - 1, 0) * _angleBetweenItems;
    
	self.cachedStartAngle =  -(_arcAngle / 2) - M_PI_2;
	
    for(int i = 0; i < self.menuItems.count; i++) {
        GHMenuItemLocation *location = [self locationForItemAtIndex:i];
        [self.itemLocations addObject:location];
    }
}

-(CGPoint)normalizeTitleFrameFor:(CGRect)layerFrame relativeTo:(CGPoint)otherPoint
{
    
    CGSize size = self.bounds.size;
    
    CGRect frame = CGRectZero;
    frame.size = layerFrame.size;
    frame.origin = CGPointMake(otherPoint.x - frame.size.width / 2, otherPoint.y - frame.size.height - 10 - GHMenuItemSize / 2);
    frame.origin.x = MAX(MIN(size.width - frame.size.width - 5, frame.origin.x), 5);
    frame.origin.y = MAX(MIN(size.height - frame.size.height - 5, frame.origin.y), 5);
    
    return CGPointMake(CGRectGetMidX(frame), CGRectGetMidY(frame));
}

- (GHMenuItemLocation*) locationForItemAtIndex:(NSUInteger) index
{
    
	CGFloat itemAngle = [self itemAngleAtIndex:index];
	CGPoint itemCenter = CGPointMake(self.longPressLocation.x + cosf(itemAngle) * self.radius,
									 self.longPressLocation.y + sinf(itemAngle) * self.radius);
    
    GHMenuItemLocation *location = [GHMenuItemLocation new];
    location.position = itemCenter;
    location.angle = itemAngle;
    
    return location;
}

-(CGFloat)currentStartAngle
{
    CGFloat itemRadius = GHMenuItemSize / 2;
    
    // We need to calculate the angle to the wall from each size.
    
    CGFloat perItemArc = asinf(itemRadius / 2 / _radius);
    CGFloat width = self.bounds.size.width;
    CGPoint currentPoint = self.longPressLocation;
    
    CGFloat centerX = width / 2;
    
    CGFloat distanceFromEdge;
    
    BOOL inverted = NO;
    
    if(currentPoint.x < centerX) {
        // We need to calculate to the left wall.
        distanceFromEdge = MAX(currentPoint.x, itemRadius);
        inverted = YES;
    } else {
        // We need to calculat to the right wall.
        distanceFromEdge = MAX(itemRadius, width - currentPoint.x);
    }
    
    CGFloat adjacent = distanceFromEdge - itemRadius;
    
    CGFloat angleUnderEdge = acosf(adjacent / _radius);
    
    // Now, for the given point, we need to calculate the actual height...
    
    CGFloat angleAdjustment = _arcAngle / 2;
    CGFloat ideal = -angleAdjustment;
    
    CGFloat startAngle;
    
    if(isnan(angleUnderEdge)) {
        startAngle = ideal;
        // If our menu is going to go over the top bounds of our app, we need to flip the start angle
        if (currentPoint.y - [self calculateRadius] <= 0) {
            startAngle += DEGREES_TO_RADIANS(180);            
        }
    } else if(inverted) {
        startAngle = MAX(-M_PI_2 + angleUnderEdge + perItemArc, ideal);
        // If our menu is going to go over the top bounds of our app, we need to rotate the start angle
        if (currentPoint.y - [self calculateRadius] <= 0) {
            startAngle += DEGREES_TO_RADIANS(90);
        }
    } else {
        startAngle = MIN(M_PI_2 - angleUnderEdge - _arcAngle - perItemArc, ideal);
        // If our menu is going to go over the top bounds of our app, we need to rotate the start angle
        if (currentPoint.y - [self calculateRadius] <= 0) {
            startAngle += DEGREES_TO_RADIANS(-90);
        }
    }
    
    // Rotate it back 90 degrees, since 0 radians is basically a vector (1, 0)
    // And we want to treat it as (0, 1).
    return startAngle - M_PI_2;
}

- (CGFloat) itemAngleAtIndex:(NSUInteger) index
{
    
	CGFloat itemAngle = _cachedStartAngle + (index * _angleBetweenItems);
    
    if (itemAngle > 2 *M_PI) {
        itemAngle -= 2*M_PI;
    }else if (itemAngle < 0){
        itemAngle += 2*M_PI;
    }

    return itemAngle;
}

# pragma mark - helper methods

- (CGFloat) calculateRadius
{
    CGSize mainSize = CGSizeMake(GHMainItemSize, GHMainItemSize);
    CGSize itemSize = CGSizeMake(GHMenuItemSize, GHMenuItemSize);
    CGFloat mainRadius = sqrt(pow(mainSize.width, 2) + pow(mainSize.height, 2)) / 2;
    CGFloat itemRadius = sqrt(pow(itemSize.width, 2) + pow(itemSize.height, 2)) / 2;
    
    CGFloat minRadius = (CGFloat)(mainRadius + itemRadius);
    CGFloat maxRadius = ((itemRadius * self.menuItems.count) / self.arcAngle) * 1.5;
    
	CGFloat radius = MAX(minRadius, maxRadius);

    return radius;
}

- (CGFloat)angleBeweenStartinPoint:(CGPoint) startingPoint endingPoint:(CGPoint) endingPoint
{
    CGPoint originPoint = CGPointMake(endingPoint.x - startingPoint.x, endingPoint.y - startingPoint.y);
    float bearingRadians = atan2f(originPoint.y, originPoint.x);
    
    bearingRadians = (bearingRadians > 0.0 ? bearingRadians : (M_PI*2 + bearingRadians));

    return bearingRadians;
}

# pragma mark - animation and selection

-  (void)highlightMenuItemForPoint
{
    if (self.isShowing && self.isPanning) {
        
        CGFloat angle = [self angleBeweenStartinPoint:self.longPressLocation endingPoint:self.currentLocation];
        NSInteger closeToIndex = -1;
        for (int i = 0; i < self.menuItems.count; i++) {
            GHMenuItemLocation* itemLocation = [self.itemLocations objectAtIndex:i];
            if (fabs(itemLocation.angle - angle) < self.angleBetweenItems / 2) {
                closeToIndex = i;
                break;
            }
        }
        
        if (closeToIndex >= 0 && closeToIndex < self.menuItems.count) {
            
            GHMenuItemLocation* itemLocation = [self.itemLocations objectAtIndex:closeToIndex];

            CGFloat distanceFromCenter = sqrt(pow(self.currentLocation.x - self.longPressLocation.x, 2)+ pow(self.currentLocation.y-self.longPressLocation.y, 2));
			
            CGFloat toleranceDistance = self.radius / 3;
            
            CGFloat distanceFromItem = fabsf(distanceFromCenter - self.radius) - GHMenuItemSize/(2*sqrt(2)) ;
            
            if (fabs(distanceFromItem) < toleranceDistance ) {
                CALayer *layer = [self.menuItems objectAtIndex:closeToIndex];
				CALayer *textLayer;
				if (self.titleItems.count) {
					 textLayer = [self.titleItems objectAtIndex:closeToIndex];
				}
                layer.backgroundColor = (__bridge CGColorRef)(self.itemBGHighlightedColor);
                
                CGFloat distanceFromItemBorder = fabs(distanceFromItem);

				CGFloat scaleFactor = 1.25;
                scaleFactor = MAX(scaleFactor, 1.0);
                
                // Scale
                CATransform3D scaleTransForm =  CATransform3DScale(CATransform3DIdentity, scaleFactor, scaleFactor, 1.0);
                
                CGFloat xtrans = cosf(itemLocation.angle);
                CGFloat ytrans = sinf(itemLocation.angle);
                
                CATransform3D transLate = CATransform3DTranslate(scaleTransForm, 5 * scaleFactor * xtrans, 5 * scaleFactor * ytrans, 0);
                layer.transform = transLate;

				if (self.titleItems.count) {
					textLayer.transform = CATransform3DTranslate(CATransform3DIdentity, 0, 20 * ytrans * scaleFactor, 0);
					textLayer.opacity = 1.0f;
				}
				
				
                if ( ( self.prevIndex >= 0 && self.prevIndex != closeToIndex)) {
                    [self resetPreviousSelection];
                }
                
                self.prevIndex = closeToIndex;
                
            } else if(self.prevIndex >= 0) {
                [self resetPreviousSelection];
            }
        } else {
            [self resetPreviousSelection];
        }
    }
}

- (void) resetPreviousSelection
{
    if (self.prevIndex >= 0) {
        CALayer *layer = self.menuItems[self.prevIndex];
		CALayer *textLayer;
		
		if (self.titleItems.count) {
			textLayer = self.titleItems[self.prevIndex];
		}
        GHMenuItemLocation* itemLocation = [self.itemLocations objectAtIndex:self.prevIndex];
        layer.position = itemLocation.position;
        layer.backgroundColor = (__bridge CGColorRef)self.itemBGColor;
        layer.transform = CATransform3DIdentity;
		if (self.titleItems.count) {
			textLayer.transform = CATransform3DIdentity;
			textLayer.opacity = 0.0f;
		}
        self.prevIndex = -1;
    }
}

- (void)animateMenu:(BOOL)isShowing
{
    if (isShowing) {
        [self layoutMenuItems];
    }
    
    CAMediaTimingFunction *timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.45f :1.2f :0.75f :1.0f];

    CGColorRef visibleColour = [UIColor colorWithWhite:0.1f alpha:.8f].CGColor;
    CGColorRef hiddenColour  = UIColor.clearColor.CGColor;
    self.layer.backgroundColor = (isShowing ?  visibleColour : hiddenColour);
    
    [_menuItems enumerateObjectsUsingBlock:^(CALayer *layer, NSUInteger index, BOOL *stop) {
		layer.opacity = isShowing ? 0 : 1;
        CGPoint fromPosition = self.longPressLocation;
		
        GHMenuItemLocation* location = [self.itemLocations objectAtIndex:index];
        CGPoint toPosition = location.position;
        
        double delayInSeconds = index * GHAnimationDelay;
        
        CABasicAnimation *positionAnimation;
        
        positionAnimation = [CABasicAnimation animationWithKeyPath:@"position"];
        positionAnimation.fromValue = [NSValue valueWithCGPoint:isShowing ? fromPosition : toPosition];
        positionAnimation.toValue = [NSValue valueWithCGPoint:isShowing ? toPosition : fromPosition];
        positionAnimation.timingFunction = timingFunction;
        positionAnimation.duration = GHAnimationDuration;
        positionAnimation.beginTime = [layer convertTime:CACurrentMediaTime() fromLayer:nil] + delayInSeconds;
        [positionAnimation setValue:[NSNumber numberWithUnsignedInteger:index] forKey:isShowing ? GHShowAnimationID : GHDismissAnimationID];
        positionAnimation.delegate = self;
        
        [layer addAnimation:positionAnimation forKey:@"riseAnimation"];
    }];
}

- (void)animationDidStart:(CAAnimation *)anim
{
    if([anim valueForKey:GHShowAnimationID]) {
        NSUInteger index = [[anim valueForKey:GHShowAnimationID] unsignedIntegerValue];
        CALayer *layer = self.menuItems[index];
		CALayer *titleLayer;
		if (self.titleItems.count) {
			titleLayer = self.titleItems[index];
		}
		
        
        GHMenuItemLocation* location = [self.itemLocations objectAtIndex:index];
        CGFloat toAlpha = 1.0;
        
        layer.position = location.position;
		layer.opacity = toAlpha;

		if (self.titleItems.count) {
			titleLayer.position = [self normalizeTitleFrameFor:titleLayer.frame relativeTo:location.position];
			titleLayer.opacity = 0.0f;
		}
		
    }
    else if([anim valueForKey:GHDismissAnimationID]) {
        NSUInteger index = [[anim valueForKey:GHDismissAnimationID] unsignedIntegerValue];
        CALayer *layer = self.menuItems[index];
		CALayer *titleLayer;
		if (self.titleItems.count) {
			titleLayer = self.titleItems[index];
		}

        CGPoint toPosition = self.longPressLocation;
        [CATransaction begin];
        [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
        layer.position = toPosition;
		if (self.titleItems.count) {
			titleLayer.position = [self normalizeTitleFrameFor:titleLayer.frame relativeTo:toPosition];
			titleLayer.opacity = 0.0f;
		}
		
		layer.transform = CATransform3DIdentity;
        layer.opacity = 0.0f;
        [CATransaction commit];
    }
}

- (void) attachPopUpAnimationToLayer:(CALayer *)layer completion:(void (^)(void))completion
{
	CAKeyframeAnimation *animation = [CAKeyframeAnimation
									  animationWithKeyPath:@"transform"];
	
	CATransform3D scale1 = CATransform3DMakeScale(0.5, 0.5, 1);
	CATransform3D scale2 = CATransform3DMakeScale(1.2, 1.2, 1);
	CATransform3D scale3 = CATransform3DMakeScale(0.9, 0.9, 1);
	CATransform3D scale4 = CATransform3DMakeScale(1.0, 1.0, 1);
	
	NSArray *frameValues = [NSArray arrayWithObjects:
							[NSValue valueWithCATransform3D:scale1],
							[NSValue valueWithCATransform3D:scale2],
							[NSValue valueWithCATransform3D:scale3],
							[NSValue valueWithCATransform3D:scale4],
							nil];
	[animation setValues:frameValues];
	
	NSArray *frameTimes = [NSArray arrayWithObjects:
						   [NSNumber numberWithFloat:0.0],
						   [NSNumber numberWithFloat:0.5],
						   [NSNumber numberWithFloat:0.9],
						   [NSNumber numberWithFloat:1.0],
						   nil];
	[animation setKeyTimes:frameTimes];
	
	animation.fillMode = kCAFillModeForwards;
	animation.removedOnCompletion = YES;
	animation.duration = .25;
	
	[CATransaction begin]; {
		[CATransaction setCompletionBlock:completion];
		[layer addAnimation:animation forKey:@"popup"];
	}
	[CATransaction commit];
	
}

- (void)drawCircle:(CGPoint)locationOfTouch
{
    CGContextRef ctx= UIGraphicsGetCurrentContext();
    CGContextSaveGState(ctx);
    CGContextSetLineWidth(ctx,1);
    CGContextSetRGBStrokeColor(ctx,0.8,0.8,0.8,1.0);
    CGContextAddArc(ctx,locationOfTouch.x,locationOfTouch.y,GHMainItemSize/2,0.0,M_PI*2,YES);
    CGContextStrokePath(ctx);
}

// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
    if (self.isShowing) {
        [self drawCircle:self.longPressLocation];
    }
}

@end
