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

@protocol GHContextOverlayViewDataSource;
@protocol GHContextOverlayViewDelegate;

@interface GHContextMenuView : UIView

@property (nonatomic, weak) id<GHContextOverlayViewDataSource> dataSource;
@property (nonatomic, weak) id<GHContextOverlayViewDelegate> delegate;

@property (nonatomic, assign) GHContextMenuActionType menuActionType;

- (void) reloadData;
- (void) longPressDetected:(UIGestureRecognizer*) gestureRecognizer;

@end

@protocol GHContextOverlayViewDataSource <NSObject>

@required
- (NSInteger) numberOfMenuItems;
- (UIImage *) imageForItemAtIndex:(NSInteger) index;
- (NSString *) titleForItemAtIndex:(NSInteger) index;

@optional
-(BOOL) shouldShowMenuAtPoint:(CGPoint) point;

@end

@protocol GHContextOverlayViewDelegate <NSObject>

- (void) didSelectItemAtIndex:(NSInteger) selectedIndex forMenuAtPoint:(CGPoint) point;

@end
