/*============================================================================*
 * (C) 2001-2009 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for MacOS X
 *	File		: RecvMessage.m
 *	Module		: 受信メッセージクラス		
 *============================================================================*/

#import "RecvMessage.h"
#import "IPMessenger.h"
#import "Config.h"
#import "UserManager.h"
#import "UserInfo.h"
#import "Attachment.h"
#import "NSStringIPMessenger.h"
#import "DebugLog.h"

#import <netinet/in.h>
#import <arpa/inet.h>

@implementation RecvMessage

/*============================================================================*
 * ファクトリ
 *============================================================================*/

// インスタンス生成
+ (RecvMessage*)messageWithBuffer:(const void*)buf length:(size_t)len from:(struct sockaddr_in*)addr {
	return [[[RecvMessage alloc] initWithBuffer:buf length:len from:addr] autorelease];
}

/*============================================================================*
 * 初期化／解放
 *============================================================================*/

// 初期化
- (id)initWithBuffer:(const void*)buf length:(size_t)len from:(struct sockaddr_in*)addr {

	/*------------------------------------------------------------------------*
	 * 準備
	 *------------------------------------------------------------------------*/
	 
	if (!(self = [super init])) {
		ERR0(@"self is nil([super init])");
		return self;
	}
	
	// メンバ初期化
	receiveDate		= [[NSDate date] retain];
	fromUser		= nil;
	unknownUser		= NO;
	packetNo		= 0;
	logOnUser		= nil;
	hostName		= nil;
	command			= 0;
	appendix		= nil;
	appendixOption	= nil;
	attachments		= nil;
	hostList		= nil;
	continueCount	= 0;
	needLog			= [[Config sharedConfig] standardLogEnabled];
	if (addr) {
		fromAddress	= *addr;
	}

	// パラメタチェック
	if (!buf) {
		ERR0(@"parameter error(buf is NULL)");
		[self release];
		return nil;
	}
	if (len <= 0) {
		ERR1(@"parameter error(len is %d)", len);
		[self release];
		return nil;
	}
	if (!addr) {
		ERR0(@"parameter error(addr is NULL)");
		[self release];
		return nil;
	}
	
	// バッファコピー
	char buffer[len + 1];
	memcpy(buffer, buf, len);
	buffer[len] = '\0';
	while (buffer[len] == '\0') {
		len--;		// 末尾余白削除
	}
	
	/*------------------------------------------------------------------------*
	 * バッファ解析
	 *------------------------------------------------------------------------*/
	 
	char*	ptr;				// ワーク
	char*	tok;				// ワーク
	char*	message		= NULL;	// 追加部C文字列
	char*	subMessage	= NULL;	// 追加部オプションC文字列
	
	// 追加部オプション
	if (len - strlen(buffer) > 0) {
		subMessage = &buffer[strlen(buffer) + 1];
		appendixOption = [[NSString alloc] initWithIPMsgCString:subMessage];
	}
	
	// バージョン番号
	if (!(tok = strtok_r(buffer, MESSAGE_SEPARATOR, &ptr))) {
		ERR1(@"msg:illegal format(version get error,\"%s\")", buf);
		[self release];
		return nil;
	}
	if (strtol(tok, NULL, 10) != IPMSG_VERSION) {
		ERR1(@"msg:version invalid(%d)", strtol(tok, NULL, 10));
		[self release];
		return nil;
	}
	
	// パケット番号
	if (!(tok = strtok_r(NULL, MESSAGE_SEPARATOR, &ptr))) {
		ERR1(@"msg:illegal format(version get error,\"%s\")", buf);
		[self release];
		return nil;
	}
	packetNo = strtol(tok, NULL, 10);
	
	// ログイン名
	if (!(tok = strtok_r(NULL, MESSAGE_SEPARATOR, &ptr))) {
		ERR1(@"msg:illegal format(logOn get error,\"%s\")", buf);
		[self release];
		return nil;
	}
	logOnUser = [[NSString alloc] initWithIPMsgCString:tok];
	
	// ホスト名
	if (!(tok = strtok_r(NULL, MESSAGE_SEPARATOR, &ptr))) {
		ERR1(@"msg:illegal format(host get error,\"%s\")", buf);
		[self release];
		return nil;
	}
	hostName = [[NSString alloc] initWithIPMsgCString:tok];
	
	// コマンド番号
	if (!(tok = strtok_r(NULL, MESSAGE_SEPARATOR, &ptr))) {
		ERR1(@"msg:illegal format(command get error,\"%s\")", buf);
		[self release];
		return nil;
	}
	command = strtoul(tok, NULL, 10);
	
	// 追加部
	message	= ptr;
	if (message) {
		appendix = [[NSString alloc] initWithIPMsgCString:message];
	}

	// ユーザ特定
	fromUser = [[[UserManager sharedManager] userForLogOnUser:logOnUser address:addr] retain];
	if (!fromUser) {
		// 未知のユーザ
		unknownUser = YES;
		fromUser = [[UserInfo alloc] initWithRecvMessage:self];
	}
	
	/*------------------------------------------------------------------------*
	 * メッセージ種別による処理
	 *------------------------------------------------------------------------*/
	
	switch (GET_MODE(command)) {
	// エントリ系メッセージではユーザ情報を通知されたメッセージ（最新）に従って再作成する
	case IPMSG_BR_ENTRY:
	case IPMSG_ANSENTRY:
	case IPMSG_BR_ABSENCE:
		[fromUser release];
		fromUser = [[UserInfo alloc] initWithRecvMessage:self];
		break;
	// 添付ファイル付きの通常メッセージは添付を取り出し
	case IPMSG_SENDMSG:
		if ((command & IPMSG_FILEATTACHOPT) && subMessage) {
			NSMutableArray* array = [[[NSMutableArray alloc] initWithCapacity:10] autorelease];
			for (tok = strtok_r(subMessage, "\a", &ptr); tok; tok = strtok_r(NULL, "\a", &ptr)) {
				Attachment* attach = [Attachment attachmentWithMessageAttachment:tok];
				if (attach) {
					[array addObject:attach];
				} else {
					ERR1(@"attach str parse error.(%s)", tok);
				}
			}
			if ([array count] > 0) {
				attachments = [array retain];
			}
		}
		break;
	// ホストリストメッセージならリストを取り出し
	case IPMSG_ANSLIST:
		if (message) {
			NSArray*		lists		= [appendix componentsSeparatedByString:@"\a"];
			int				totalCount	= [[lists objectAtIndex:1] intValue];
			NSMutableArray*	array		= [[[NSMutableArray alloc] initWithCapacity:10] autorelease];
			if (totalCount > 0) {
				int				i;
				continueCount	= [[lists objectAtIndex:0] intValue];
				if ([lists count] < (unsigned)(totalCount * 7 + 2)) {
					WRN3(@"hostlist:invalid data(items=%d,totalCount=%d,%@)", [lists count], totalCount, self);
					totalCount = ([lists count] - 2) / 7;
				}
				for (i = 0; i < totalCount; i++) {
					UserInfo* newUser = [UserInfo userWithHostList:lists fromIndex:(i * 7 + 2)];
					if (newUser) {
						[array addObject:newUser];
					}
				}
				if ([array count] > 0) {
					hostList = [array retain];
				}
			}
		}
		break;
	default:
		break;
	}
	
	return self;
}

// 解放
- (void)dealloc {
	[receiveDate release];
	[fromUser release];
	[logOnUser release];
	[hostName release];
	[appendix release];
	[appendixOption release];
	[attachments release];
	[hostList release];
	[super dealloc];
}

/*============================================================================*
 * getter（相手情報）
 *============================================================================*/

// 送信元ユーザ
- (UserInfo*)fromUser {
	return fromUser;
}

// 未知のユーザからの受信かどうか
- (BOOL)isUnknownUser {
	return unknownUser;
}

// 送信元アドレス
- (struct sockaddr_in*)fromAddress {
	return &fromAddress;
}

/*============================================================================*
 * getter（共通）
 *============================================================================*/
 
// パケット番号
- (int)packetNo {
	return packetNo;
}

// 受信日時
- (NSDate*)receiveDate {
	return receiveDate;
}

// ログインユーザ
- (NSString*)logOnUser {
	return logOnUser;
}

// ホスト名
- (NSString*)hostName {
	return hostName;
}

// 受信コマンド
- (unsigned long)command {
	return command;
}

// 拡張部
- (NSString*)appendix {
	return appendix;
}

// 拡張部追加部
- (NSString*)appendixOption {
	return appendixOption;
}

/*============================================================================*
 * getter（IPMSG_SENDMSGのみ）
 *============================================================================*/
 
// 封書フラグ
- (BOOL)sealed {
	return ((command & IPMSG_SECRETOPT) != 0);
}

// 施錠フラグ
- (BOOL)locked {
	return ((command & IPMSG_PASSWORDOPT) != 0);
}

// マルチキャストフラグ
- (BOOL)multicast {
	return ((command & IPMSG_MULTICASTOPT) != 0);
}

// ブロードキャストフラグ
- (BOOL)broadcast {
	return ((command & IPMSG_BROADCASTOPT) != 0);
}

// 不在フラグ
- (BOOL)absence {
	return ((command & IPMSG_AUTORETOPT) != 0);
}

// 添付ファイルリスト
- (NSArray*)attachments {
	return attachments;
}

/*============================================================================*
 * getter（IPMSG_ANSLISTのみ）
 *============================================================================*/
 
// ホストリスト
- (NSArray*)hostList {
	return hostList;
}

// ホストリスト継続番号
- (int)hostListContinueCount {
	return continueCount;
}

/*============================================================================*
 * その他
 *============================================================================*/

// ダウンロード完了済み添付ファイル削除
- (void)removeDownloadedAttachments {
	int index;
	for (index = [attachments count] - 1; index >= 0; index--) {
		if ([[attachments objectAtIndex:index] downloadComplete]) {
			[attachments removeObjectAtIndex:index];
		}
	}
}

// ログ未出力フラグ
- (BOOL)needLog {
	return needLog;
}

// ログ出力済設定
- (void)setNeedLog:(BOOL)flag {
	needLog = flag;
}

/*============================================================================*
 * その他（親クラスオーバーライド）
 *============================================================================*/
 
// 等価判定
- (BOOL)isEqual:(id)obj {
	if ([obj isKindOfClass:[self class]]) {
		RecvMessage* target = obj;
		return ([fromUser isEqual:target->fromUser] && (packetNo == target->packetNo));
	}
	return NO;
}

// オブジェクト文字列表現
- (NSString*)description {
	return [NSString stringWithFormat:@"RecvMessage:command=0x%08X,PacketNo=%d,from=%@", command, packetNo, fromUser];
}

// オブジェクトコピー
- (id)copyWithZone:(NSZone*)zone {
	RecvMessage* newObj	= [[RecvMessage allocWithZone:zone] init];
	if (newObj) {
		newObj->receiveDate		= [receiveDate retain];
		newObj->fromUser		= [fromUser retain];
		newObj->unknownUser		= unknownUser;
		newObj->fromAddress		= fromAddress;
		newObj->packetNo		= packetNo;
		newObj->logOnUser		= [logOnUser retain];
		newObj->hostName		= [hostName retain];
		newObj->command			= command;
		newObj->appendix		= [appendix retain];
		newObj->appendixOption	= [appendixOption retain];
		newObj->attachments		= [attachments retain];
		newObj->hostList		= [hostList retain];
		newObj->continueCount	= continueCount;
		newObj->needLog			= needLog;
	} else {
		ERR1(@"copy error(%@)", self);
	}
	
	return newObj;
}

@end
