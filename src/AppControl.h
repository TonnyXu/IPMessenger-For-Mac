/*============================================================================*
 * (C) 2001-2003 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for MacOS X
 *	File		: AppControl.h
 *	Module		: アプリケーションコントローラ		
 *============================================================================*/

#import <Cocoa/Cocoa.h>

@class RecvMessage;
@class SendControl;

/*============================================================================*
 * クラス定義
 *============================================================================*/

@interface AppControl : NSObject
{
	IBOutlet NSMenu*		absenceMenu;					// 不在メニュー
	IBOutlet NSMenuItem*	absenceOffMenuItem;				// 不在解除メニュー項目
	IBOutlet NSMenu*		absenceMenuForDock;				// Dock用不在メニュー
	IBOutlet NSMenuItem*	absenceOffMenuItemForDock;		// Dock用不在解除メニュー項目
	IBOutlet NSMenu*		absenceMenuForStatusBar;		// ステータスバー用不在メニュー
	IBOutlet NSMenuItem*	absenceOffMenuItemForStatusBar;	// ステータスバー用不在解除メニュー項目
	
	IBOutlet NSMenuItem*	receiveWindowPosFixMenuItem;	// 受信ウィンドウ固定位置メニュー項目
	IBOutlet NSMenuItem*	sendWindowPosFixMenuItem;		// 送信ウィンドウ固定位置メニュー項目
	IBOutlet NSMenuItem*	showNonPopupMenuItem;			// ノンポップアップ表示メニュー項目
	
	IBOutlet NSMenu*		statusBarMenu;					// ステータスバー用のメニュー
	NSStatusItem*			statusBarItem;					// ステータスアイテムのインスタンス
	
	BOOL					activatedFlag;					// アプリケーションアクティベートフラグ
	
	NSMutableArray*			receiveQueue;					// 受信メッセージキュー
	NSLock*					receiveQueueLock;				// 受信メッセージキュー排他ロック
	
	NSTimer*				iconToggleTimer;				// アイコントグル用タイマー
	BOOL					iconToggleState;				// アイコントグル状態（YES:通常/NO:リバース)	
	
	NSImage*				iconNormal;						// 通常時アプリアイコン
	NSImage*				iconNormalReverse;				// 通常時アプリアイコン（反転）
	NSImage*				iconAbsence;					// 不在時アプリアイコン
	NSImage*				iconAbsenceReverse;				// 不在時アプリアイコン（反転）
	NSImage* 				iconSmallNormal;				// 通常時アプリスモールアイコン
	NSImage* 				iconSmallNormalReverse;			// 通常時アプリスモールアイコン（反転）
	NSImage*				iconSmallAbsence;				// 不在時アプリスモールアイコン
	NSImage*				iconSmallAbsenceReverse;		// 不在時アプリスモールアイコン（反転）
	
	NSDate*					lastDockDraggedDate;			// 前回Dockドラッグ受付時刻
	SendControl*			lastDockDraggedWindow;			// 前回Dockドラッグ時生成ウィンドウ
}

// メッセージ送受信／ウィンドウ関連処理
- (IBAction)newMessage:(id)sender;
- (void)receiveMessage:(RecvMessage*)msg;
- (IBAction)closeAllWindows:(id)sender;
- (IBAction)closeAllDialogs:(id)sender;
- (IBAction)showNonPopupMessage:(id)sender;

// 不在関連処理
- (IBAction)absenceMenuChanged:(id)sender;
- (void)buildAbsenceMenu;
- (void)setAbsenceOff;

// ステータスバー関連
- (IBAction)clickStatusBar:(id)sender;
- (void)initStatusBar;
- (void)removeStatusBar;

// その他
- (IBAction)gotoHomePage:(id)sender;
- (IBAction)openLog:(id)sender;

@end
