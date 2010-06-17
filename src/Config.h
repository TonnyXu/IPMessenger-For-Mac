/*============================================================================*
 * (C) 2001-2003 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for MacOS X
 *	File		: Config.h
 *	Module		: 初期設定情報管理クラス		
 *============================================================================*/

#import <Cocoa/Cocoa.h>

@class UserInfo;
@class RefuseInfo;

/*============================================================================*
 * 定数定義
 *============================================================================*/

// ユーザリストソートルール種別
typedef enum {
	IPMSG_SORT_ASC			= 0x0001,
	IPMSG_SORT_DESC			= 0x0002,
	IPMSG_SORT_NAME			= 0x0010,
	IPMSG_SORT_GROUP		= 0x0020,
	IPMSG_SORT_IP			= 0x0030,
	IPMSG_SORT_MACHINE		= 0x0040,
	IPMSG_SORT_DESCRIPTION	= 0x0050,
	IPMSG_SORT_ON			= 0x1000,
	IPMSG_SORT_OFF			= 0x2000,

} IPMsgUserSortRuleType;

#define IPMSG_SORT_ORDER_MASK	0x000F
#define IPMSG_SORT_TYPE_MASK	0x00F0
#define IPMSG_SORT_ONOFF_MASK	0xF000

// ログ改行コード 
typedef enum {
	IPMSG_LF,
	IPMSG_CR,
	IPMSG_CRLF
	
} IPMsgLogLineEnding;

// ノンポップアップ受信アイコンバウンド種別
typedef enum {
	IPMSG_BOUND_ONECE	= 0,	
	IPMSG_BOUND_REPEAT	= 1,
	IPMSG_BOUND_NONE	= 2
	
} IPMsgIconBoundType;

/*============================================================================*
 * クラス定義
 *============================================================================*/

@interface Config : NSObject
{
	//-------- 不揮発の設定値（永続化必要）　----------------------------
	// 全般
	NSString*			userName;				// ユーザ名
	NSString*			groupName;				// グループ名
	NSString*			password;				// パスワード
	int					machineNameType;		// マシン名取得元（0:hostname/1:AppleTalk）
	BOOL				hostnameRemoveDomain;	// ドメインサフィックスを除去
	BOOL				useStatusBar;			// メニューバーの右端にアイコンを追加するか
	// ネットワーク
	int					portNo;					// ポート番号
	NSMutableArray*		broadcastHostList;		// ブロードキャスト一覧（ホスト名）
	NSMutableArray*		broadcastIPList;		// ブロードキャスト一覧（IPアドレス）
	NSMutableArray*		broadcastAddresses;		// ブロードキャストアドレス一覧
	BOOL				dialup;					// ダイアルアップ接続
	// 送信
	NSString*			quoteString;			// 引用文字列
	BOOL				openNewOnDockClick;		// Dockクリック時送信ウィンドウオープン
	BOOL				sealCheckDefault;		// 封書チェックをデフォルト
	BOOL				hideRcvWinOnReply;		// 送信時受信ウィンドウをクローズ
	BOOL				noticeSealOpened;		// 開封確認を行う
	BOOL				sendAllUsersEnabled;	// 全員へ送信チェックボックス有効
	BOOL				allowSendingMultiUser;	// 複数ユーザ宛送信を許可
	NSFont*				sendMessageFont;		// 送信ウィンドウメッセージ部フォント
	// 受信
	NSSound*			receiveSound;			// 受信音
	BOOL				quoteCheckDefault;		// 引用チェックをデフォルト
	BOOL				nonPopup;				// ノンポップアップ受信
	BOOL				nonPopupWhenAbsence;	// 不在時ノンポップアップ受信
	IPMsgIconBoundType	nonPopupIconBound;		// ノンポップアップ受信時アイコンバウンド種別
	BOOL				useClickableURL;		// クリッカブルURLを使用する
	NSFont*				receiveMessageFont;		// 受信ウィンドウメッセージ部フォント
	// 不在
	NSMutableArray*		absenceList;			// 不在定義
	// 通知拒否
	NSMutableArray*		refuseList;				// 拒否条件リスト
	// ユーザリスト
	BOOL				displayLogOnName;		// ログオン名を表示する
	BOOL				displayIPAddress;		// IPアドレスを表示する
	BOOL				sortByIgnoreCase;		// 大文字小文字を無視する
	BOOL				sortByKanjiPriority;	// 漢字を優先する
	NSMutableArray*		sortRuleList;			// ソートルール
	// ログ
	BOOL				standardLogEnabled;		// 標準ログを使用する
	BOOL				logChainedWhenOpen;		// 錠前付きは開封時にログ
	NSString*			standardLogFile;		// 標準ログファイルパス
	BOOL				alternateLogEnabled;	// 重要ログを使用する
	BOOL				logWithSelectedRange;	// 選択範囲を記録する
	NSString*			alternateLogFile;		// 重要ログファイルパス
	IPMsgLogLineEnding	logLineEnding;			// ログ改行コード
	
	// 送受信ウィンドウ位置／サイズ
	NSPoint				sndWinPos;				// 送信ウィンドウ位置
	NSSize				sndWinSize;				// 送信ウィンドウサイズ
	float				sndWinSplit;			// 送信ウィンドウ分割位置
	NSPoint				rcvWinPos;				// 受信ウィンドウ位置
	NSSize				rcvWinSize;				// 受信ウィンドウサイズ

	//-------- 揮発の設定値（永続化不要）　------------------------------
	NSString*			machineName;			// ホスト名
	NSString*			unixHostname;			// ホスト名（UNIX）
	NSString*			appleTalkHostname;		// ホスト名（AppleTalk）
	NSMutableArray*		defaultAbsences;		// 不在定義の初期値
	int					absenceIndex;			// 不在モード
	NSFont*				defaultMessageFont;		// 送受信ウィンドウメッセージ標準フォント
}

// ファクトリ
+ (Config*)sharedConfig;

// 永続化
- (void)save;

// ----- getter / setter ------
// 全般
- (NSString*)userName;
- (void)setUserName:(NSString*)name;

- (NSString*)groupName;
- (void)setGroupName:(NSString*)name;

- (NSString*)password;
- (void)setPassword:(NSString*)pass;

- (NSString*)machineName;
- (BOOL)canUseAppleTalkHostname;

- (int)machineNameType;
- (void)setMachineNameType:(int)type;

- (BOOL)hostnameRemoveDomain;
- (void)setHostnameRemoveDomain:(BOOL)flag;

- (BOOL)useStatusBar;
- (void)setUseStatusBar:(BOOL)use;

// ネットワーク
- (int)portNo;
- (void)setPortNo:(int)port;

- (BOOL)dialup;
- (void)setDialup:(BOOL)flag;

- (NSArray*)broadcastAddresses;
- (int)numberOfBroadcasts;
- (NSString*)broadcastAtIndex:(int)index;
- (BOOL)containsBroadcastWithAddress:(NSString*)address;
- (BOOL)containsBroadcastWithHost:(NSString*)host;
- (void)addBroadcastWithAddress:(NSString*)address;
- (void)addBroadcastWithHost:(NSString*)host;
- (void)removeBroadcastAtIndex:(int)index;

// 送信
- (NSString*)quoteString;
- (void)setQuoteString:(NSString*)string;

- (BOOL)openNewOnDockClick;
- (void)setOpenNewOnDockClick:(BOOL)open;

- (BOOL)sealCheckDefault;
- (void)setSealCheckDefault:(BOOL)seal;

- (BOOL)hideReceiveWindowOnReply;
- (void)setHideReceiveWindowOnReply:(BOOL)hide;

- (BOOL)noticeSealOpened;
- (void)setNoticeSealOpened:(BOOL)check;

- (BOOL)sendAllUsersCheckEnabled;
- (void)setSendAllUsersCheckEnabled:(BOOL)check;

- (BOOL)allowSendingToMultiUser;
- (void)setAllowSendingToMultiUser:(BOOL)allow;

- (NSFont*)defaultSendMessageFont;
- (NSFont*)sendMessageFont;
- (void)setSendMessageFont:(NSFont*)font;

// 受信
- (NSSound*)receiveSound;
- (NSString*)receiveSoundName;
- (void)setReceiveSoundWithName:(NSString*)soundName;

- (BOOL)quoteCheckDefault;
- (void)setQuoteCheckDefault:(BOOL)quote;

- (BOOL)nonPopup;
- (void)setNonPopup:(BOOL)nonPop;

- (BOOL)nonPopupWhenAbsence;
- (void)setNonPopupWhenAbsence:(BOOL)nonPop;

- (IPMsgIconBoundType)iconBoundModeInNonPopup;
- (void)setIconBoundModeInNonPopup:(IPMsgIconBoundType)type;

- (BOOL)useClickableURL;
- (void)setUseClickableURL:(BOOL)clickable;

- (NSFont*)defaultReceiveMessageFont;
- (NSFont*)receiveMessageFont;
- (void)setReceiveMessageFont:(NSFont*)font;

// 不在
- (int)numberOfAbsences;
- (NSString*)absenceTitleAtIndex:(int)index;
- (NSString*)absenceMessageAtIndex:(int)index;
- (BOOL)containsAbsenceTitle:(NSString*)title;
- (void)addAbsenceTitle:(NSString*)title message:(NSString*)msg atIndex:(int)index;
- (void)setAbsenceTitle:(NSString*)title message:(NSString*)msg atIndex:(int)index;
- (void)upAbsenceAtIndex:(int)index;
- (void)downAbsenceAtIndex:(int)index;
- (void)removeAbsenceAtIndex:(int)index;
- (void)resetAllAbsences;

- (BOOL)isAbsence;
- (int)absenceIndex;
- (void)setAbsenceIndex:(int)index;

// 通知拒否
- (int)numberOfRefuseInfo;
- (RefuseInfo*)refuseInfoAtIndex:(int)index;
- (void)addRefuseInfo:(RefuseInfo*)info atIndex:(int)index;
- (void)setRefuseInfo:(RefuseInfo*)info atIndex:(int)index;
- (void)upRefuseInfoAtIndex:(int)index;
- (void)downRefuseInfoAtIndex:(int)index;
- (void)removeRefuseInfoAtIndex:(int)index;

- (BOOL)refuseUser:(UserInfo*)user;

// ユーザリスト
- (BOOL)displayLogOnName;
- (void)setDisplayLogOnName:(BOOL)disp;

- (BOOL)displayIPAddress;
- (void)setDisplayIPAddress:(BOOL)disp;

- (BOOL)sortByIgnoreCase;
- (void)setSortByIgnoreCase:(BOOL)flag;

- (BOOL)sortByKanjiPriority;
- (void)setSortByKanjiPriority:(BOOL)flag;

- (int)numberOfSortRules;
- (void)moveSortRuleFromIndex:(int)from toIndex:(int)to;
- (IPMsgUserSortRuleType)sortRuleTypeAtIndex:(int)index;
- (BOOL)sortRuleEnabledAtIndex:(int)index;
- (void)setSortRuleEnabled:(BOOL)flag atIndex:(int)index;
- (IPMsgUserSortRuleType)sortRuleOrderAtIndex:(int)index;
- (void)setSortRuleOrder:(IPMsgUserSortRuleType)order atIndex:(int)index;

// ログ
- (BOOL)standardLogEnabled;
- (void)setStandardLogEnabled:(BOOL)b;

- (BOOL)logChainedWhenOpen;
- (void)setLogChainedWhenOpen:(BOOL)b;

- (NSString*)standardLogFile;
- (void)setStandardLogFile:(NSString*)path;

- (BOOL)alternateLogEnabled;
- (void)setAlternateLogEnabled:(BOOL)b;

- (BOOL)logWithSelectedRange;
- (void)setLogWithSelectedRange:(BOOL)b;

- (NSString*)alternateLogFile;
- (void)setAlternateLogFile:(NSString*)path;

- (IPMsgLogLineEnding)logLineEnding;
- (void)setLogLineEnding:(IPMsgLogLineEnding)ending;

// 送受信ウィンドウ位置／サイズ
- (NSPoint)sendWindowPosition;
- (void)setSendWindowPosition:(NSPoint)point;
- (void)resetSendWindowPosition;

- (NSSize)sendWindowSize;
- (float)sendWindowSplit;
- (void)setSendWindowSize:(NSSize)size split:(int)split;
- (void)resetSendWindowSize;

- (NSPoint)receiveWindowPosition;
- (void)setReceiveWindowPosition:(NSPoint)position;
- (void)resetReceiveWindowPosition;

- (NSSize)receiveWindowSize;
- (void)setReceiveWindowSize:(NSSize)size;
- (void)resetReceiveWindowSize;

@end
