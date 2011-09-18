/*============================================================================*
 * (C) 2001-2003 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for MacOS X
 *	File		: RetryInfo.m
 *	Module		: メッセージ再送情報クラス		
 *============================================================================*/

#import "RetryInfo.h"
#import "UserInfo.h"

/*============================================================================*
 * クラス実装
 *============================================================================*/

@implementation RetryInfo

/*----------------------------------------------------------------------------*
 * 初期化／解放
 *----------------------------------------------------------------------------*/

// 初期化
- (id)initWithCommand:(int)cmd to:(UserInfo*)to message:(NSData*)msg attach:(NSData*)attach {
	self		= [super init];
	command		= cmd;
	toUser		= [to retain];
	msgBody		= [msg retain];
	attachMsg	= [attach retain];
	retryCount	= 0;
	return self;
}

// 解放
- (void)dealloc {
	[toUser		release];
	[msgBody	release];
	[attachMsg	release];
	[super dealloc];
}

/*----------------------------------------------------------------------------*
 * getter
 *----------------------------------------------------------------------------*/

- (int)command {
	return command;
}

- (UserInfo*)toUser {
	return toUser;
}

- (NSData*)messageBody {
	return msgBody;
}

- (NSData*)attachMessage {
	return attachMsg;
}

- (int)retryCount {
	return retryCount;
}

// リトライ回数操作
- (void)upRetryCount {
	retryCount++;
}

- (void)resetRetryCount {
	retryCount = 0;
}

@end
