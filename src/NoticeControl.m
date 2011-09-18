/*============================================================================*
 * (C) 2001-2003 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for MacOS X
 *	File		: NoticeControl.m
 *	Module		: 通知ダイアログコントローラ		
 *============================================================================*/

#import <Cocoa/Cocoa.h>
#import "NoticeControl.h"

/*============================================================================*
 * クラス実装
 *============================================================================*/

@implementation NoticeControl

/*----------------------------------------------------------------------------*
 * 初期化
 *----------------------------------------------------------------------------*/

// 初期化
- (id)initWithTitle:(NSString*)title message:(NSString*)msg date:(NSDate*)date {
	self = [super init];
	// nibファイルロード
	if (![NSBundle loadNibNamed:@"NoticeDialog.nib" owner:self]) {
		[self autorelease];
		return nil;
	}
	// 表示文字列設定
	[titleLabel		setStringValue:title];
	[messageLabel	setStringValue:msg];
	[dateLabel		setObjectValue:((date) ? date : [NSCalendarDate date])];
	// ダイアログ表示
	[window makeKeyAndOrderFront:self];

	return self;
}

/*----------------------------------------------------------------------------*
 * その他
 *----------------------------------------------------------------------------*/

// Nibファイルロード完了時処理
- (void)awakeFromNib {
	NSPoint	centerPoint;
	int		sw	= [[NSScreen mainScreen] visibleFrame].size.width;
	int		sh	= [[NSScreen mainScreen] visibleFrame].size.height;
	int		ww	= [window frame].size.width;
	int		wh	= [window frame].size.height;
	
	// 画面表示位置計算
	centerPoint.x = (sw - ww) / 2 + (rand() % (sw / 4)) - sw / 8;
	centerPoint.y = (sh - wh) / 2 + (rand() % (sh / 4)) - sh / 8; 
	[window setFrameOrigin:centerPoint];
	
	// ウィンドウメニューから除外
	[window setExcludedFromWindowsMenu:YES];
}

// ウィンドウクローズ時処理
- (void)windowWillClose:(NSNotification*)aNotification {
	[self release];
}

@end
