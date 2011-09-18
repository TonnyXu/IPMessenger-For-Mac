/*============================================================================*
 * (C) 2001-2003 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for MacOS X
 *	File		: SendControl.h
 *	Module		: 送信メッセージウィンドウコントローラ		
 *============================================================================*/

#import <Cocoa/Cocoa.h>

@class UserInfo;
@class RecvMessage;

extern NSString * const WindowFrameName;
extern NSString * const SplitViewFrameName;
extern NSString * const SearchAutosaveName;
/*============================================================================*
 * クラス定義
 *============================================================================*/

@interface SendControl : NSObject
{
	IBOutlet NSWindow*		window;				// 送信ウィンドウ
	IBOutlet NSSplitView*	splitView;
	IBOutlet NSView*		splitSubview1;
	IBOutlet NSView*		splitSubview2;
	IBOutlet NSTableView*	userTable;			// ユーザ一覧
	IBOutlet NSTextField*	userNumLabel;		// ユーザ数ラベル
	IBOutlet NSButton*		sendAllCheck;		// 全員に送信チェックボックス
	IBOutlet NSButton*		refreshButton;		// 更新ボタン
	IBOutlet NSButton*		passwordCheck;		// 鍵チェックボックス
	IBOutlet NSButton*		sealCheck;			// 封書チェックボックス
	IBOutlet NSTextView*	messageArea;		// メッセージ入力欄
	IBOutlet NSButton*		sendButton;			// 送信ボタン
	IBOutlet NSButton*		attachButton;		// 添付ファイルDrawerトグルボタン
	IBOutlet NSDrawer*		attachDrawer;		// 添付ファイルDrawer
	IBOutlet NSTableView*	attachTable;		// 添付ファイル一覧
	IBOutlet NSButton*		attachAddButton;	// 添付追加ボタン
	IBOutlet NSButton*		attachDelButton;	// 添付削除ボタン
	IBOutlet NSSearchField*	searchField;		// 検索フィルド
	NSMutableArray*			attachments;		// 添付ファイル
	NSMutableDictionary*	attachmentsDic;		// 添付ファイル辞書
	RecvMessage*			receiveMessage;		// 返信元メッセージ
	NSMutableArray*			selectedUsers;		// 選択ユーザリスト
	NSLock*					selectedUsersLock;	// 選択ユーザリストロック
}

// 初期化
- (id)initWithSendMessage:(NSString*)msg recvMessage:(RecvMessage*)recv;

// ハンドラ
- (IBAction)buttonPressed:(id)sender;
- (IBAction)checkboxChanged:(id)sender;

- (IBAction)sendPressed:(id)sender;
- (IBAction)sendMessage:(id)sender;
- (void)userListChanged:(NSNotification*)aNotification;

// 添付ファイル
- (void)appendAttachmentByPath:(NSString*)path;

// その他
- (IBAction)updateUserList:(id)sender;
- (NSWindow*)window;
- (void)setAttachHeader;

// Search
- (void) focusOnSearchField;
- (IBAction) searchUserList:(id)sender;
- (void) doSearching;

@end
