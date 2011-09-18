/*============================================================================*
 * (C) 2001-2003 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for MacOS X
 *	File		: LogManager.m
 *	Module		: ログ管理クラス		
 *============================================================================*/

#import <Foundation/Foundation.h>
#import "LogManager.h"
#import "UserInfo.h"
#import "Config.h"
#import "RecvMessage.h"
#import "SendMessage.h"
#import "DebugLog.h"

// 定数定義
static NSString* LogHeadStart	= @"=====================================\n";
static NSString* LogMsgStart	= @"-------------------------------------\n";

// プライベートメソッド定義
@interface LogManager(Private)
- (void)writeLog:(NSString*)msg;
@end

// クラス実装
@implementation LogManager

/*============================================================================*
 * ファクトリ
 *============================================================================*/

// 標準ログ
+ (LogManager*)standardLog {
	static LogManager* standardLog = nil;
	if (!standardLog) {
		standardLog = [[LogManager alloc] initWithPath:[[Config sharedConfig] standardLogFile]];
	}
	return standardLog;
}

// 重要ログ
+ (LogManager*)alternateLog {
	static LogManager* alternateLog	= nil;
	if (!alternateLog) {
		alternateLog = [[LogManager alloc] initWithPath:[[Config sharedConfig] alternateLogFile]];
	}
	return alternateLog;
}

/*============================================================================*
 * 初期化／解放
 *============================================================================*/
 
// 初期化
- (id)initWithPath:(NSString*)path {

	if (!(self = [super init])) {
		ERR0(@"self is nil([super init])");
		return self;
	}
	if (!path) {
		[self release];
		return nil;
	}

	filePath	= [[path stringByExpandingTildeInPath] retain];
	dateFormat	= [[NSDateFormatter alloc] initWithDateFormat:NSLocalizedString(@"IPMsg.DateFormat", nil) allowNaturalLanguage:NO];

	return self;
}

// 解放
- (void)dealloc {
	[filePath release];
	[dateFormat	release];
	[super dealloc];
}

/*============================================================================*
 * ファイルパス変更
 *============================================================================*/

// ファイルパス変更
- (void)setFilePath:(NSString*)path {
	[filePath release];
	filePath = [[path stringByExpandingTildeInPath] retain];
}

/*============================================================================*
 * ログ出力
 *============================================================================*/

// 受信ログ出力
- (void)writeRecvLog:(RecvMessage*)info {
	[self writeRecvLog:info withRange:NSMakeRange(0, 0)];
}

// 受信ログ出力
- (void)writeRecvLog:(RecvMessage*)info withRange:(NSRange)range {
	NSMutableString* msg = [[[NSMutableString alloc] init] autorelease];
	// メッセージ編集
	[msg appendString:LogHeadStart];
	[msg appendFormat:@" From: %@\n", [[info fromUser] summeryString]];
	[msg appendFormat:@"  at %@", [dateFormat stringForObjectValue:[info receiveDate]]];
	if ([info broadcast]) {
		[msg appendString:NSLocalizedString(@"Log.Type.Broadcast", nil)];
	}
	if ([info absence]) {
		[msg appendString:NSLocalizedString(@"Log.Type.AutoRet", nil)];
	}
	if ([info multicast]) {
		[msg appendString:NSLocalizedString(@"Log.Type.Multicast", nil)];
	}
	if ([info locked]) {
		[msg appendString:NSLocalizedString(@"Log.Type.Locked", nil)];
	} else if ([info sealed]) {
		[msg appendString:NSLocalizedString(@"Log.Type.Sealed", nil)];
	}
	[msg appendString:@"\n"];
	[msg appendString:LogMsgStart];
	if (range.length > 0) {
		[msg appendString:[[info appendix] substringWithRange:range]];
	} else {
		[msg appendString:[info appendix]];
	}
	[msg appendString:@"\n\n"];
	// ログ出力
	[self writeLog:msg];
}

// 送信ログ出力
- (void)writeSendLog:(SendMessage*)info to:(NSArray*)to {
	NSMutableString*	msg = [[[NSMutableString alloc] init] autorelease];
	int					i;
	// メッセージ編集
	[msg appendString:LogHeadStart];
	for (i = 0; i < [to count]; i++) {
		[msg appendFormat:@" To: %@\n", [[to objectAtIndex:i] summeryString]];
	}
	[msg appendFormat:@"  at %@", [dateFormat stringForObjectValue:[NSCalendarDate date]]];
	if ([to count] > 1) {
		[msg appendString:NSLocalizedString(@"Log.Type.Multicast", nil)];
	}
	if ([info locked]) {
		[msg appendString:NSLocalizedString(@"Log.Type.Locked", nil)];
	} else if ([info sealed]) {
		[msg appendString:NSLocalizedString(@"Log.Type.Sealed", nil)];
	}
	if ([[info attachments] count] > 0) {
		[msg appendString:NSLocalizedString(@"Log.Type.Attachment", nil)];
	}
	[msg appendString:@"\n"];
	[msg appendString:LogMsgStart];
	[msg appendString:[info message]];
	[msg appendString:@"\n\n"];
	// ログ出力
	[self writeLog:msg];
}

@end

/*============================================================================*
 * プライベートメソッド
 *============================================================================*/

@implementation LogManager(Private)

// メッセージ出力（内部用）
- (void)writeLog:(NSString*)msg {
	static NSData*	cr		= nil;
	static NSData*	crlf	= nil;
	NSFileHandle*	file;
	NSFileManager*	fileMgr	= [NSFileManager defaultManager];
	if (!msg) {
		return;
	}
	if ([msg length] <= 0) {
		return;
	}
	if (![fileMgr fileExistsAtPath:filePath]) {
		if (![fileMgr createFileAtPath:filePath contents:nil attributes:nil]) {
			ERR1(@"LogFile Create Error.(%@)", filePath);
			return;
		}
	}
	file = [NSFileHandle fileHandleForWritingAtPath:filePath];
	if (file) {
		IPMsgLogLineEnding lineEnd = [[Config sharedConfig] logLineEnding];
		[file seekToEndOfFile];
		if (lineEnd == IPMSG_LF) {
			[file writeData:[msg dataUsingEncoding:NSShiftJISStringEncoding]];
		} else {
			NSArray*	lineArray	= [msg componentsSeparatedByString:@"\n"];
			NSData*		lineEndData;
			int			i;
			if (lineEnd == IPMSG_CR) {
				if (!cr) {
					cr = [[NSData dataWithBytes:"\r" length:1] retain];
				}
				lineEndData = cr;
			} else {
				if (!crlf) {
					crlf = [[NSData dataWithBytes:"\r\n" length:2] retain];
				}
				lineEndData = crlf;
			}
			for (i = 0; i < [lineArray count]; i++) {
				[file writeData:[[lineArray objectAtIndex:i] dataUsingEncoding:NSShiftJISStringEncoding]];
				[file writeData:lineEndData];
			}
		}
		[file closeFile];
	} else {
		ERR1(@"LogFile open Error.(%@)", filePath);
	}
}

@end
