/*============================================================================*
 * (C) 2001-2003 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for MacOS X
 *	File		: SendMessage.m
 *	Module		: 送信メッセージ情報クラス		
 *============================================================================*/

#import "SendMessage.h"
#import "MessageCenter.h"
#import "DebugLog.h"

@implementation SendMessage

/*============================================================================*
 * ファクトリ
 *============================================================================*/

// インスタンス生成
+ (id)messageWithMessage:(NSString*)msg attachments:(NSArray*)attach seal:(BOOL)seal lock:(BOOL)lock {
	return [[[SendMessage alloc] initWithMessage:msg attachments:attach seal:seal lock:lock] autorelease];
}

/*============================================================================*
 * 初期化／解放
 *============================================================================*/

// 初期化
- (id)initWithMessage:(NSString*)msg attachments:(NSArray*)attach seal:(BOOL)seal lock:(BOOL)lock {
	if (!(self = [super init])) {
		ERR0(@"self is nil([super init])");
		return self;
	}
	packetNo	= [MessageCenter nextMessageID];
	message		= [msg mutableCopy];
	attachments	= [attach retain];
	sealed		= seal;
	locked		= lock;

	return self;
}

// 解放
- (void)dealloc {
	[message release];
	[attachments release];
	[super dealloc];
}

/*============================================================================*
 * 初期化／解放
 *============================================================================*/

// パケット番号
- (long)packetNo {
	return packetNo;
}

// メッセージ
- (NSString*)message {
	return message;
}

// 添付ファイル
- (NSArray*)attachments {
	return attachments;
}

// 封書フラグ
- (BOOL)sealed {
	return sealed;
}

// 施錠フラグ
- (BOOL)locked {
	return locked;
}

/*============================================================================*
 * その他（親クラスオーバーライド）
 *============================================================================*/

// オブジェクト文字列表現
- (NSString*)description {
	return [NSString stringWithFormat:@"SendMessage:PacketNo=%d", packetNo];
}

// オブジェクトコピー
- (id)copyWithZone:(NSZone*)zone {
	SendMessage* newObj	= [[SendMessage allocWithZone:zone] init];
	if (newObj) {
		newObj->packetNo	= packetNo;
		newObj->message		= [message retain];
		newObj->attachments	= [attachments retain];
		newObj->sealed		= sealed;
		newObj->locked		= locked;
	} else {
		ERR1(@"copy error(%@)", self);
	}
	
	return newObj;
}

@end
