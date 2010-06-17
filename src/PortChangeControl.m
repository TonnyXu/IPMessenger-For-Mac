/*============================================================================*
 * (C) 2001-2003 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for MacOS X
 *	File		: PortChangeControl.m
 *	Module		: ポート変更ダイアログコントローラクラス		
 *============================================================================*/
 
#import "PortChangeControl.h"
#import "Config.h"
#import "DebugLog.h"

@implementation PortChangeControl

/*----------------------------------------------------------------------------*
 * 初期化
 *----------------------------------------------------------------------------*/

// 初期化
- (id)init {
	self = [super init];
	
	// nibファイルロード
	if (![NSBundle loadNibNamed:@"PortChangeDialog.nib" owner:self]) {
		[self autorelease];
		return nil;
	}
	[portNoField setObjectValue:[NSNumber numberWithInt:[[Config sharedConfig] portNo]]];
	
	// ダイアログ表示
	[panel center];
	[panel setExcludedFromWindowsMenu:YES];	
	[panel makeKeyAndOrderFront:self];

	// モーダル開始
	[NSApp runModalForWindow:panel];
	
	return self;
}

- (IBAction)buttonPressed:(id)sender {
	if (sender == okButton) {
		int	newVal = [portNoField intValue];
		if (newVal != 0) {
			// ポート変更／ウィンドウクローズ／モーダル終了
			[[Config sharedConfig] setPortNo:newVal];
			[panel close];
			[NSApp stopModal];
		}
	} else {
		ERR1(@"Unknown Button Pressed(%@)", sender);
	}
}

- (IBAction)textChanged:(id)sender {
	if (sender == portNoField) {
		// NOP
	} else {
		ERR1(@"Unknown TextField Changed(%@)", sender);
	}
}

/*----------------------------------------------------------------------------*
 * その他
 *----------------------------------------------------------------------------*/

// ウィンドウクローズ時処理
- (void)windowWillClose:(NSNotification*)aNotification {
	[self release];
}


@end
