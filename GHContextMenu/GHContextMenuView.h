//
//  GHContextOverlayView.h
//  GHContextMenu
//
//  Created by Tapasya on 27/01/14.
//  Copyright (c) 2014 Tapasya. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, GHContextMenuActionType){
    // Default
    GHContextMenuActionTypePan,
    // Allows tap action in order to trigger an action
    GHContextMenuActionTypeTap,
    //Allows for both
    GHContextmenuActionTypePanAndTap
};

typedef NS_ENUM(NSInteger, GHContextMenuAnchor){
    // Default
    GHContextMenuAnchorTouch,
    // Anchors the menu to the center of the containing view instead of the touch
    GHContextMenuAnchorContainingView,
};

@protocol GHContextOverlayViewDataSource;
@protocol GHContextOverlayViewDelegate;

@interface GHContextMenuView : UIView

@property (nonatomic, weak) id<GHContextOverlayViewDataSource> dataSource;
@property (nonatomic, weak) id<GHContextOverlayViewDelegate> delegate;

@property (nonatomic, assign) GHContextMenuActionType menuActionType;
@property (nonatomic, assign) GHContextMenuAnchor menuAnchor;

- (void) reloadData;
- (void) longPressDetected:(UIGestureRecognizer*) gestureRecognizer;

@end

@protocol GHContextOverlayViewDataSource <NSObject>

@required
- (NSInteger) numberOfMenuItemsForMenuView:(GHContextMenuView*)menuView;
- (UIImage *) menuView:(GHContextMenuView*)menuView imageForItemAtIndex:(NSInteger) index;
- (NSString *) menuView:(GHContextMenuView*)menuView titleForItemAtIndex:(NSInteger) index;

@optional
-(BOOL) menuView:(GHContextMenuView*)menuView shouldShowMenuAtPoint:(CGPoint) point;

@end

@protocol GHContextOverlayViewDelegate <NSObject>

- (void) menuView:(GHContextMenuView*)menuView didSelectItemAtIndex:(NSInteger)selectedIndex forMenuAtPoint:(CGPoint) point;

@end
