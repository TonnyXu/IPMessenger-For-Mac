/*============================================================================*
 * (C) 2001-2003 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for MacOS X
 *	File		: MessageCenter.h
 *	Module		: メッセージ送受信管理クラス		
 *============================================================================*/

#import <Foundation/Foundation.h>

@class RecvMessage;
@class SendMessage;
@class UserInfo;
@class AttachmentInfo;

// IPMsg受信パケット解析構造体
typedef struct {
	unsigned	version;			// バージョン番号
	unsigned	packetNo;			// パケット番号
	char		userName[256];		// ログインユーザ名
	char		hostName[256];		// ホスト名
	unsigned	command;			// コマンド番号
	char		extension[4096];	// 拡張部

} IPMsgData;

/*============================================================================*
 * クラス定義
 *============================================================================*/

@interface MessageCenter : NSObject {
	unsigned long			localAddr;		// ローカルホストアドレス
	int						portNo;			// ソケットポート番号
	int						sockUDP;		// ソケットディスクリプタ（UDP/通常メッセージ用）
	NSLock*					sockLock;		// 送信排他ロック
	NSFileHandle*			handle;			// 読み込みハンドル
	NSMutableDictionary*	sendList;		// 応答待ちメッセージ一覧（再送用）
	NSConnection*			connection;		// メッセージ受信スレッドとのコネクション
}

// ファクトリ
+ (MessageCenter*)sharedCenter;
+ (long)nextMessageID;

// 受信Rawデータの分解
+ (BOOL)parseReceiveData:(char*)buffer length:(int)len into:(IPMsgData*)data;

// メッセージ送信（ブロードキャスト）
- (void)broadcastEntry;
- (void)broadcastAbsence;
- (void)broadcastExit;

// メッセージ送信（通常）
- (void)sendMessage:(SendMessage*)msg to:(NSArray*)to;
- (void)sendOpenSealMessage:(RecvMessage*)info;
- (void)sendReleaseAttachmentMessage:(RecvMessage*)info;

// その他
+ (BOOL)valid;
- (UserInfo*)localUser;
- (int)portNo;

@end
