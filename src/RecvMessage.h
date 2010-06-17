/*============================================================================*
 * (C) 2001-2003 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for MacOS X
 *	File		: RecvMessage.h
 *	Module		: 受信メッセージクラス		
 *============================================================================*/

#import <Foundation/Foundation.h>
#import <netinet/in.h>

@class UserInfo;

/*============================================================================*
 * クラス定義
 *============================================================================*/
@interface RecvMessage : NSObject <NSCopying> {
	NSDate*				receiveDate;	// 受信日時
	UserInfo*			fromUser;		// 送信元ユーザ
	BOOL				unknownUser;	// 未知のユーザフラグ
	struct sockaddr_in	fromAddress;	// 送信元アドレス
	long				packetNo;		// パケット番号
	NSString*			logOnUser;		// ログイン名
	NSString*			hostName;		// ホスト名
	unsigned long		command;		// コマンド番号
	NSString*			appendix;		// 追加部
	NSString*			appendixOption;	// 追加部オプション
	NSMutableArray*		attachments;	// 添付ファイル
	NSMutableArray*		hostList;		// ホストリスト
	int					continueCount;	// ホストリスト継続ユーザ番号
	BOOL				needLog;		// ログ出力フラグ
}

// ファクトリ
+ (RecvMessage*)messageWithBuffer:(const void*)buf length:(size_t)len from:(struct sockaddr_in*)addr;

// 初期化／解放
- (id)initWithBuffer:(const void*)buf length:(size_t)len from:(struct sockaddr_in*)addr;
- (void)dealloc;

// getter（相手情報）
- (UserInfo*)fromUser;
- (BOOL)isUnknownUser;
- (struct sockaddr_in*)fromAddress;

// getter（共通）
- (int)packetNo;
- (NSDate*)receiveDate;
- (NSString*)logOnUser;
- (NSString*)hostName;
- (unsigned long)command;
- (NSString*)appendix;
- (NSString*)appendixOption;

// getter（IPMSG_SENDMSGのみ）
- (BOOL)sealed;
- (BOOL)locked;
- (BOOL)multicast;
- (BOOL)broadcast;
- (BOOL)absence;
- (NSArray*)attachments;

// getter（IPMSG_ANSLISTのみ）
- (NSArray*)hostList;
- (int)hostListContinueCount;

// その他
- (void)removeDownloadedAttachments;
- (BOOL)needLog;
- (void)setNeedLog:(BOOL)flag;

@end
