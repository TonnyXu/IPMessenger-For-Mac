/*============================================================================*
 * (C) 2001-2003 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for MacOS X
 *	File		: LogManager.h
 *	Module		: ログ管理クラス		
 *============================================================================*/

#import <Foundation/Foundation.h>

@class RecvMessage;
@class SendMessage;

/*============================================================================*
 * クラス定義
 *============================================================================*/

@interface LogManager : NSObject {
	NSString*			filePath;		// ログファイルパス
	NSDateFormatter*	dateFormat;		// 日時出力フォーマット
}

// ファクトリ
+ (LogManager*)standardLog;
+ (LogManager*)alternateLog;

// ファイルパス変更
- (void)setFilePath:(NSString*)path;

// ログ出力
- (void)writeRecvLog:(RecvMessage*)info;
- (void)writeRecvLog:(RecvMessage*)info withRange:(NSRange)range;
- (void)writeSendLog:(SendMessage*)info to:(NSArray*)to;

@end
