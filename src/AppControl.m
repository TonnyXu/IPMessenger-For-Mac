/*============================================================================*
 * (C) 2001-2003 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for MacOS X
 *	File		: AppControl.m
 *	Module		: アプリケーションコントローラ		
 *============================================================================*/

#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import "AppControl.h"
#import "Config.h"
#import "MessageCenter.h"
#import "AttachmentServer.h"
#import "RecvMessage.h"
#import "ReceiveControl.h"
#import "SendControl.h"
#import "NoticeControl.h"
#import "WindowManager.h"
#import "DebugLog.h"

#define ABSENCE_OFF_MENU_TAG	1000
#define ABSENCE_ITEM_MENU_TAG	2000

/**
 * Handler for Global hot keys.
 * Tonny Xu added @ 2010.03.26
 */
OSStatus myHotKeyHandler(EventHandlerCallRef nextHandler, EventRef anEvent, void  *userData);

/*============================================================================*
 * クラス実装
 *============================================================================*/

@implementation AppControl

/*----------------------------------------------------------------------------*
 * 初期化／解放
 *----------------------------------------------------------------------------*/

// 初期化
- (id)init {
	NSBundle* bundle = [NSBundle mainBundle];
	
	self 					= [super init];
	receiveQueue			= [[NSMutableArray alloc] init];
	receiveQueueLock		= [[NSLock alloc] init];
	iconToggleTimer			= nil;
	iconNormal				= [[NSImage alloc] initWithContentsOfFile:
								[bundle pathForResource:@"IPMsg" ofType:@"icns"]];
	iconNormalReverse		= [[NSImage alloc] initWithContentsOfFile:
								[bundle pathForResource:@"IPMsgReverse" ofType:@"icns"]];
	iconAbsence				= [[NSImage alloc] initWithContentsOfFile:
								[bundle pathForResource:@"IPMsgAbsence" ofType:@"icns"]];
	iconAbsenceReverse		= [[NSImage alloc] initWithContentsOfFile:
								[bundle pathForResource:@"IPMsgAbsenceReverse" ofType:@"icns"]];
	lastDockDraggedDate		= nil;
	lastDockDraggedWindow	= nil;
	
	iconSmallNormal				= [[NSImage alloc] initWithContentsOfFile:
								[bundle pathForResource:@"IPMsg" ofType:@"icns"]];
	[iconSmallNormal setScalesWhenResized:YES];
	[iconSmallNormal setSize : NSMakeSize( 18, 18 ) ];
	iconSmallNormalReverse	= [[NSImage alloc] initWithContentsOfFile:
								[bundle pathForResource:@"IPMsgReverse" ofType:@"icns"]];
	[iconSmallNormalReverse setScalesWhenResized:YES];
	[iconSmallNormalReverse setSize : NSMakeSize( 18, 18 ) ];
	iconSmallAbsence			= [[NSImage alloc] initWithContentsOfFile:
								[bundle pathForResource:@"IPMsgAbsence" ofType:@"icns"]];
	[iconSmallAbsence setScalesWhenResized:YES];
	[iconSmallAbsence setSize : NSMakeSize( 18, 18 ) ];
	iconSmallAbsenceReverse		= [[NSImage alloc] initWithContentsOfFile:
								[bundle pathForResource:@"IPMsgAbsenceReverse" ofType:@"icns"]];
	[iconSmallAbsenceReverse setScalesWhenResized:YES];
	[iconSmallAbsenceReverse setSize : NSMakeSize( 18, 18 ) ];
	
	/*
	NSSize size = NSMakeSize( 20, 20 );
	iconSmallNormalReverse = [[NSImage alloc] initWithSize : size];
//	[iconSmallNormalReverse retain];
	[iconSmallNormalReverse lockFocus];
	[[NSColor whiteColor] set];
	NSRectFill( NSMakeRect(  0,  0, 20, 20 ) );
	[iconSmallNormalReverse unlockFocus];
	
	iconSmallAbsenceReverse = [[NSImage alloc] initWithSize : size];
//	[iconSmallNormalReverse retain];
	[iconSmallAbsenceReverse lockFocus]; 
	[[NSColor whiteColor] set];
	NSRectFill( NSMakeRect(  0,  0, 20, 20 ) );
	[iconSmallAbsenceReverse unlockFocus];
	*/
	
	return self;
}

// 解放
- (void)dealloc {
	[receiveQueue		release];
	[receiveQueueLock	release];
	[iconToggleTimer	release];
	[iconNormal			release];
	[iconNormalReverse	release];
	[iconAbsence		release];
	[iconAbsenceReverse	release];
	[super dealloc];
}

/*----------------------------------------------------------------------------*
 * メッセージ送受信／ウィンドウ関連
 *----------------------------------------------------------------------------*/
 
// 新規メッセージウィンドウ表示処理
- (IBAction)newMessage:(id)sender {
	if (![NSApp isActive]) {
		activatedFlag = -1;		// アクティベートで新規ウィンドウが開いてしまうのを抑止
		[NSApp activateIgnoringOtherApps:YES];
	}
	[[SendControl alloc] initWithSendMessage:nil recvMessage:nil];
}

// メッセージ受信時処理
- (void)receiveMessage:(RecvMessage*)msg {
	Config*			config	= [Config sharedConfig];
	ReceiveControl*	recv;
	// 表示中のウィンドウがある場合無視する
	if ([[WindowManager sharedManager] receiveWindowForKey:msg]) {
		WRN1(@"already visible message.(%@)", msg);
		return;
	}
	// 受信音再生
	[[config receiveSound] play];
	// 受信ウィンドウ生成（まだ表示しない）
	recv = [[ReceiveControl alloc] initWithRecvMessage:msg];
	if ([config nonPopup]) {
		if (([config nonPopupWhenAbsence] && [config isAbsence]) ||
			(![config nonPopupWhenAbsence])) {
			// ノンポップアップの場合受信キューに追加
			[receiveQueueLock lock];
			[receiveQueue addObject:recv];
			[receiveQueueLock unlock];
			switch ([config iconBoundModeInNonPopup]) {
			case IPMSG_BOUND_ONECE:
				[NSApp requestUserAttention:NSInformationalRequest];
				break;
			case IPMSG_BOUND_REPEAT:
				[NSApp requestUserAttention:NSCriticalRequest];
				break;
			case IPMSG_BOUND_NONE:
			default:
				break;
			}
			if (!iconToggleTimer) {
				// アイコントグル開始
				iconToggleState	= YES;
				iconToggleTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
																   target:self
																 selector:@selector(toggleIcon:)
																 userInfo:nil
																  repeats:YES];
			}
			return;
		}
	}
	if (![NSApp isActive]) {
		[NSApp activateIgnoringOtherApps:YES];
	}
	[recv showWindow];
}

// すべてのウィンドウを閉じる
- (IBAction)closeAllWindows:(id)sender {
	NSEnumerator*	e = [[NSApp orderedWindows] objectEnumerator];
	NSWindow*		win;
	while ((win = (NSWindow*)[e nextObject])) {
		if ([win isVisible]) {
			[win performClose:self];
		}
	}
}

// すべての通知ダイアログを閉じる
- (IBAction)closeAllDialogs:(id)sender {
	NSEnumerator*	e = [[NSApp orderedWindows] objectEnumerator];
	NSWindow*		win;
	while ((win = (NSWindow*)[e nextObject])) {
		if ([[win delegate] isKindOfClass:[NoticeControl class]]) {
			[win performClose:self];
		}
	}
}

/*----------------------------------------------------------------------------*
 * 不在メニュー関連
 *----------------------------------------------------------------------------*/

- (NSMenuItem*)createAbsenceMenuItemAtIndex:(int)index state:(BOOL)state {
	NSMenuItem* item = [[[NSMenuItem alloc] init] autorelease];
	[item setTitle:[[Config sharedConfig] absenceTitleAtIndex:index]];
	[item setEnabled:YES];
	[item setState:state];
	[item setTarget:self];
	[item setAction:@selector(absenceMenuChanged:)];
	[item setTag:ABSENCE_ITEM_MENU_TAG + index];
	return item;
}

// 不在メニュー作成
- (void)buildAbsenceMenu {
	Config* config	= [Config sharedConfig];
	int		num		= [config numberOfAbsences];
	int		index	= [config absenceIndex];
	int		i;
	
	// 不在モード解除とその下のセパレータ以外を一旦削除
	for (i = [absenceMenu numberOfItems] - 1; i > 1 ; i--) {
		[absenceMenu removeItemAtIndex:i];
	}
	for (i = [absenceMenuForDock numberOfItems] - 1; i > 1 ; i--) {
		[absenceMenuForDock removeItemAtIndex:i];
	}
	for (i = [absenceMenuForStatusBar numberOfItems] - 1; i > 1 ; i--) {
		[absenceMenuForStatusBar removeItemAtIndex:i];
	}
	if (num > 0) {
		for (i = 0; i < num; i++) {
			[absenceMenu addItem:[self createAbsenceMenuItemAtIndex:i state:(i == index)]];
			[absenceMenuForDock addItem:[self createAbsenceMenuItemAtIndex:i state:(i == index)]];
			[absenceMenuForStatusBar addItem:[self createAbsenceMenuItemAtIndex:i state:(i == index)]];
		}
	}
	[absenceOffMenuItem setState:(index == -1)];
	[absenceOffMenuItemForDock setState:(index == -1)];
	[absenceOffMenuItemForStatusBar setState:(index == -1)];
	[absenceMenu update];
	[absenceMenuForDock update];
	[absenceMenuForStatusBar update];
}

// 不在メニュー選択ハンドラ
- (IBAction)absenceMenuChanged:(id)sender {
	Config*	config	= [Config sharedConfig];
	int		oldIdx	= [config absenceIndex];
	int		newIdx;
	
	if ([sender tag] == ABSENCE_OFF_MENU_TAG) {
		newIdx = -2;
	} else {
		newIdx = [sender tag] - ABSENCE_ITEM_MENU_TAG;
	}
	
	// 現在選択されている不在メニューのチェックを消す
	if (oldIdx == -1) {
		oldIdx = -2;
	}
	[[absenceMenu				itemAtIndex:oldIdx + 2] setState:NSOffState];
	[[absenceMenuForDock		itemAtIndex:oldIdx + 2] setState:NSOffState];
	[[absenceMenuForStatusBar	itemAtIndex:oldIdx + 2] setState:NSOffState];
	
	// 選択された項目にチェックを入れる
	[[absenceMenu				itemAtIndex:newIdx + 2] setState:NSOnState];
	[[absenceMenuForDock		itemAtIndex:newIdx + 2] setState:NSOnState];
	[[absenceMenuForStatusBar	itemAtIndex:newIdx + 2] setState:NSOnState];
		
	// 選択された項目によってアイコンを変更する
	if (newIdx < 0) {
		[NSApp setApplicationIconImage:iconNormal];
		[statusBarItem setImage:iconSmallNormal];
	} else {
		[NSApp setApplicationIconImage:iconAbsence];
		[statusBarItem setImage:iconSmallAbsence];
	}
		
	[sender setState:NSOnState];

	[config setAbsenceIndex:newIdx];
	[[MessageCenter sharedCenter] broadcastAbsence];
}

// 不在解除
- (void)setAbsenceOff {
	[self absenceMenuChanged:absenceOffMenuItem];
}

/*----------------------------------------------------------------------------*
 * ステータスバー関連
 *----------------------------------------------------------------------------*/
 
- (void)initStatusBar {
	if (statusBarItem == nil) {
		// ステータスバーアイテムの初期化
		statusBarItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
		[statusBarItem retain];
		[statusBarItem setTitle:@""];
		[statusBarItem setImage:iconSmallNormal];
		[statusBarItem setMenu:statusBarMenu];
		[statusBarItem setHighlightMode:YES];
	}
}

- (void)removeStatusBar {
	if (statusBarItem != nil) {
		// ステータスバーアイテムを破棄
		[[NSStatusBar systemStatusBar] removeStatusItem:statusBarItem];
		[statusBarItem release];
		statusBarItem = nil;
	}
}

- (void)clickStatusBar:(id)sender{
	activatedFlag = -1;		// アクティベートで新規ウィンドウが開いてしまうのを抑止
	[NSApp activateIgnoringOtherApps:YES];
	[self applicationShouldHandleReopen:NSApp hasVisibleWindows:NO];
}

/*----------------------------------------------------------------------------*
 * その他
 *----------------------------------------------------------------------------*/

// Webサイトに飛ぶ
- (IBAction)gotoHomePage:(id)sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:NSLocalizedString(@"IPMsg.HomePage", nil)]];
}

// Nibファイルロード完了時
- (void)awakeFromNib {
	// Register for global hot keys.
	EventHotKeyRef myHotKeyRef;
    EventHotKeyID myHotKeyID;
    EventTypeSpec eventType;
	
	eventType.eventClass = kEventClassKeyboard;	
    eventType.eventKind = kEventHotKeyPressed;
	
	InstallApplicationEventHandler(&myHotKeyHandler,1,&eventType,NULL,NULL);
	
	myHotKeyID.signature='mhk1';	
    myHotKeyID.id=1;
	
	// Register the hot key to the system.
	RegisterEventHotKey(46, // 'm' key
						cmdKey+optionKey, // The short cut is 'command + option + m'
						myHotKeyID, 
						GetApplicationEventTarget(), 
						0, 
						&myHotKeyRef);
	
	
	
	Config*		config		= [Config sharedConfig];
	NSPoint		receivePos	= [config receiveWindowPosition];
	NSPoint		sendPos		= [config sendWindowPosition];
	// メニュー設定
	[receiveWindowPosFixMenuItem setState:((receivePos.x != 0) || (receivePos.y != 0))];
	[sendWindowPosFixMenuItem setState:((sendPos.x != 0) || (sendPos.y != 0))];
	[self buildAbsenceMenu];
	
	// ステータスバー
	if([config useStatusBar]){
		[self initStatusBar];
	}
}

// アプリ起動完了時処理
- (void)applicationDidFinishLaunching: (NSNotification*)aNotification {
	// 画面位置計算時の乱数初期化
	srand(time(NULL));
	// フラグ初期化
	activatedFlag = -1;

/*
	{
		NSStringEncoding* encodings = (NSStringEncoding*)[NSString availableStringEncodings];
		DBG0(@"ENCODINGS*****");
		DBG1(@" default=%@", [NSString localizedNameOfStringEncoding:[NSString defaultCStringEncoding]]);
		while (*encodings) {
			DBG2(@" %08X:%@", *encodings, [NSString localizedNameOfStringEncoding:*encodings]);
			encodings++;
		}
	}
*/

	// ENTRYパケットのブロードキャスト
	[[MessageCenter sharedCenter] broadcastEntry];
	// 添付ファイルサーバの起動
	[AttachmentServer sharedServer];
}

// ログ参照クリック時
- (void) openLog:(id)sender{
	Config*	config	= [Config sharedConfig];
	// ログファイルのフルパスを取得する
	NSString *filePath = [[config standardLogFile] stringByExpandingTildeInPath];
	// デフォルトのアプリでログを開く
	[[NSWorkspace sharedWorkspace] openFile : filePath];
}

// アプリ終了前確認
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication*)sender {
	// 表示されている受信ウィンドウがあれば終了確認
	NSEnumerator*	e = [[NSApp orderedWindows] objectEnumerator];
	NSWindow*		win;
	while ((win = (NSWindow*)[e nextObject])) {
		if ([win isVisible] && [[win delegate] isKindOfClass:[ReceiveControl class]]) {
			int ret = NSRunCriticalAlertPanel(
								NSLocalizedString(@"ShutDown.Confirm1.Title", nil),
								NSLocalizedString(@"ShutDown.Confirm1.Msg", nil),
								NSLocalizedString(@"ShutDown.Confirm1.OK", nil),
								NSLocalizedString(@"ShutDown.Confirm1.Cancel", nil),
								nil);
			if (ret == NSAlertAlternateReturn) {
				[win makeKeyAndOrderFront:self];
				// 終了キャンセル
				return NSTerminateCancel;
			}
			break;
		}
	}
	// ノンポップアップの未読メッセージがあれば終了確認
	[receiveQueueLock lock];
	if ([receiveQueue count] > 0) {
		int ret = NSRunCriticalAlertPanel(
								NSLocalizedString(@"ShutDown.Confirm2.Title", nil),
								NSLocalizedString(@"ShutDown.Confirm2.Msg", nil),
								NSLocalizedString(@"ShutDown.Confirm2.OK", nil),
								NSLocalizedString(@"ShutDown.Confirm2.Other", nil),
								NSLocalizedString(@"ShutDown.Confirm2.Cancel", nil));
		if (ret == NSAlertOtherReturn) {
			[receiveQueueLock unlock];
			// 終了キャンセル
			return NSTerminateCancel;
		} else if (ret == NSAlertAlternateReturn) {
			[receiveQueueLock unlock];
			[self applicationShouldHandleReopen:NSApp hasVisibleWindows:NO];
			// 終了キャンセル
			return NSTerminateCancel;
		}
	}
	[receiveQueueLock unlock];
	// 終了
	return NSTerminateNow;
}

// アプリ終了時処理
- (void)applicationWillTerminate:(NSNotification*)aNotification {
	// EXITパケットのブロードキャスト
	if ([MessageCenter valid]) {
		[[MessageCenter sharedCenter] broadcastExit];
	}
	// 添付ファイルサーバの終了
	[[AttachmentServer sharedServer] shutdownServer];
	
	// ステータスバー消去
	if ([[Config sharedConfig] useStatusBar] && (statusBarItem != nil)) {
		// [self removeStatusBar]を呼ぶと落ちる（なぜ？）
		[[NSStatusBar systemStatusBar] removeStatusItem:statusBarItem];
	}
	
	// 初期設定の保存
	[[Config sharedConfig] save];
	
}

// アプリアクティベート
- (void)applicationDidBecomeActive:(NSNotification*)aNotification {
	// 初回だけは無視（起動時のアクティベートがあるので）
	activatedFlag = (activatedFlag == -1) ? NO : YES;
}

// Dockファイルドロップ時
- (BOOL)application:(NSApplication*)theApplication openFile:(NSString*)fileName {
	DBG1(@"drop file=%@", fileName);
	if (lastDockDraggedDate && lastDockDraggedWindow) {
		if ([lastDockDraggedDate timeIntervalSinceNow] > -0.5) {
			[lastDockDraggedWindow appendAttachmentByPath:fileName];
		} else {
			[lastDockDraggedDate release];
			lastDockDraggedDate		= nil;
			lastDockDraggedWindow	= nil;
		}
	}
	if (!lastDockDraggedDate) {
		lastDockDraggedWindow = [[SendControl alloc] initWithSendMessage:nil recvMessage:nil];
		[lastDockDraggedWindow appendAttachmentByPath:fileName];
		lastDockDraggedDate = [[NSDate alloc] init];
	}
	return YES;
}

- (BOOL)validateMenuItem:(NSMenuItem*)item {
	if (item == showNonPopupMenuItem) {
		if ([[Config sharedConfig] nonPopup]) {
			return ([receiveQueue count] > 0);
		}
		return NO;
	}
	return YES;
}

- (IBAction)showNonPopupMessage:(id)sender {
	[self applicationShouldHandleReopen:NSApp hasVisibleWindows:NO];
}

// Dockクリック時
- (BOOL)applicationShouldHandleReopen:(NSApplication*)theApplication hasVisibleWindows:(BOOL)flag {
	int 		i;
	BOOL		b;
	BOOL		noWin = YES;
	Config*		config = [Config sharedConfig];
	NSArray*	wins;
	// ノンポップアップのキューにメッセージがあれば表示
	[receiveQueueLock lock];
	b = ([receiveQueue count] > 0);
	for (i = 0; i < [receiveQueue count]; i++) {
		[[receiveQueue objectAtIndex:i] showWindow];
	}
	[receiveQueue removeAllObjects];
	// アイコントグルアニメーションストップ
	if (b && iconToggleTimer) {
		[iconToggleTimer invalidate];
		iconToggleTimer = nil;
		[NSApp setApplicationIconImage:(([config isAbsence]) ? iconAbsence : iconNormal)];
		[statusBarItem setImage:(([config isAbsence]) ? iconSmallAbsence : iconSmallNormal)];
	}
	[receiveQueueLock unlock];
	// 新規送信ウィンドウのオープン

//DBG1(@"#window = %d", [[NSApp windows] count]);
	wins = [NSApp windows];
	for (i = 0; i < [wins count]; i++) {
		NSWindow* win = [wins objectAtIndex:i];
//		[win orderFront:self];
//		if ([[win delegate] isKindOfClass:[ReceiveControl class]] ||
//			[[win delegate] isKindOfClass:[SendControl class]]) {
		if ([win isVisible]) {
			noWin = NO;
			break;
		}
	}
	if (activatedFlag != -1) {
		if ((noWin || !activatedFlag) &&
			!b && [config openNewOnDockClick]) {
			// ・クリック前からアクティブアプリだったか、または表示中のウィンドウが一個もない
			// ・環境設定で指定されている
			// ・ノンポップアップ受信でキューイングされた受信ウィンドウがない
			// のすべてを満たす場合、新規送信ウィンドウを開く
			[self newMessage:self];
		}
	}
	activatedFlag = NO;
	return YES;
}

// アイコン点滅処理（タイマコールバック）
- (void)toggleIcon:(NSTimer*)timer {
	NSImage* img1;
	NSImage* img2;
	iconToggleState = !iconToggleState;
	
	
	if ([[Config sharedConfig] isAbsence]) {
		img1 = (iconToggleState) ? iconAbsence : iconAbsenceReverse;
		img2 = (iconToggleState) ? iconSmallAbsence : iconSmallAbsenceReverse;
	} else {
		img1 = (iconToggleState) ? iconNormal : iconNormalReverse;
		img2 = (iconToggleState) ? iconSmallNormal : iconSmallNormalReverse;
	}
	
	// ステータスバーアイコン
	if ([[Config sharedConfig] useStatusBar]) {
		if (statusBarItem == nil) {
			[self initStatusBar];
		}
		[statusBarItem setImage:img2];
	}
	// Dockアイコン
	[NSApp setApplicationIconImage:img1];
}

@end

OSStatus myHotKeyHandler(EventHandlerCallRef nextHandler, EventRef anEvent, void  *userData)
{
	if (![NSApp isActive]) {
		//activatedFlag = -1;		// アクティベートで新規ウィンドウが開いてしまうのを抑止
		[NSApp activateIgnoringOtherApps:YES];
	}
	[[SendControl alloc] initWithSendMessage:nil recvMessage:nil];
	
//	NSLog(@"Hit me!");
	return noErr;	
}