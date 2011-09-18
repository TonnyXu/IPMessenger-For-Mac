/*============================================================================*
 * (C) 2001-2003 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for MacOS X
 *	File		: RetryInfo.h
 *	Module		: メッセージ再送情報クラス		
 *============================================================================*/

#import <Foundation/Foundation.h>

@class UserInfo;

/*============================================================================*
 * クラス定義
 *============================================================================*/

@interface RetryInfo : NSObject {
	int			command;		// 送信コマンド
	UserInfo*	toUser;			// 送信相手
	NSData*		msgBody;		// メッセージ文字列
	NSData*		attachMsg;		// 添付文字列
	int			retryCount;		// リトライ回数
}

// 初期化／解放
- (id)initWithCommand:(int)cmd to:(UserInfo*)to message:(NSData*)msg attach:(NSData*)attach;
- (void)dealloc;

// getter
- (int)command;
- (UserInfo*)toUser;
- (NSData*)messageBody;
- (NSData*)attachMessage;
- (int)retryCount;

// リトライ回数操作
- (void)upRetryCount;
- (void)resetRetryCount;

@end
