/*============================================================================*
 * (C) 2001-2009 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for MacOS X
 *	File		: UserInfo.m
 *	Module		: ユーザ情報クラス		
 *============================================================================*/

#import <Foundation/Foundation.h>
#import "UserInfo.h"
#import "IPMessenger.h"
#import "RecvMessage.h"
#import "MessageCenter.h"
#import "Config.h"
#import "NSStringIPMessenger.h"
#import "DebugLog.h"

#include <netinet/in.h>
#include <arpa/inet.h>

// プライベートメソッド定義
@interface UserInfo(Private)
- (NSComparisonResult)compareString:(NSString*)str1 with:(NSString*)str2 kanjiPriority:(BOOL)kanji;
@end

// クラス実装
@implementation UserInfo

/*============================================================================*
 * ファクトリ
 *============================================================================*/

+ (id)userWithRecvMessage:(RecvMessage*)msg {
	return [[[UserInfo alloc] initWithRecvMessage:msg] autorelease];
}

+ (id)userWithHostList:(NSArray*)itemArray fromIndex:(unsigned)index {
	return [[[UserInfo alloc] initWithHostList:itemArray fromIndex:index] autorelease];
}

/*============================================================================*
 * 初期化／解放
 *============================================================================*/
 
// 初期化（受信メッセージ）
- (id)initWithRecvMessage:(RecvMessage*)msg {
	if (!(self = [super init])) {
		ERR0(@"self is nil");
		return nil;
	}
	switch (GET_MODE([msg command])) {
	case IPMSG_BR_ENTRY:
	case IPMSG_ANSENTRY:
	case IPMSG_BR_ABSENCE:
		user	= [[msg appendix] retain];
		group	= [[msg appendixOption] retain];
		break;
	default:
		user	= nil;
		group	= nil;
		break;
	}
	address			= [[NSString alloc] initWithCString:inet_ntoa([msg fromAddress]->sin_addr)];
	addressNumber	= ntohl([msg fromAddress]->sin_addr.s_addr);
	portNo			= ntohs([msg fromAddress]->sin_port);
	host			= [[msg hostName] retain];
	logOnUser		= [[msg logOnUser] retain];
	absence			= (([msg command] & IPMSG_ABSENCEOPT) != 0);
	dialup			= (([msg command] & IPMSG_DIALUPOPT) != 0);
	attachment		= (([msg command] & IPMSG_FILEATTACHOPT) != 0);
	encrypt			= (([msg command] & IPMSG_ENCRYPTOPT) != 0);
	version			= nil;
	return self;
}

// 初期化（ホストリスト）
- (id)initWithHostList:(NSArray*)itemArray fromIndex:(unsigned)index {
	if (!(self = [super init])) {
		ERR0(@"self is nil");
		return nil;
	}
	// 初期化
	user		= nil;
	group		= nil;
	address		= nil;
	host		= nil;
	logOnUser	= nil;
	version		= nil;
	// ユーザ名
	user = [itemArray objectAtIndex:index + 5];
	if ([user isEqualToString:@"\b"]) {
		user = nil;
	} else {
		[user retain];
	}
	// グループ名
	group = [itemArray objectAtIndex:index + 6];
	if ([group isEqualToString:@"\b"]) {
		group = nil;
	} else {
		[group retain];
	}
	// アドレス
	address = [[itemArray objectAtIndex:index + 3] retain];
	if (!address) {
		ERR0(@"address is nil");
		[self release];
		return nil;
	}
	// アドレス（数値）
	addressNumber = ntohl(inet_addr([address UTF8String]));
	// ポート番号
	int port = [[itemArray objectAtIndex:index + 4] intValue];
	portNo = (((port & 0xFF00) >> 8) | ((port & 0xFF) << 8));
	// ログイン名
	logOnUser = [[itemArray objectAtIndex:index] retain];
	if (!logOnUser) {
		ERR0(@"logOnName is nil");
		[self release];
		return nil;
	}
	// ホスト名
	host = [[itemArray objectAtIndex:index + 1] retain];
	if (!host) {
		ERR0(@"host is nil");
		[self release];
		return nil;
	}
	// コマンド
	unsigned long command = (unsigned long)[[itemArray objectAtIndex:index + 1] intValue];
	absence		= ((command & IPMSG_ABSENCEOPT) != 0);
	dialup		= ((command & IPMSG_DIALUPOPT) != 0);
	attachment	= ((command & IPMSG_FILEATTACHOPT) != 0);
	encrypt		= ((command & IPMSG_ENCRYPTOPT) != 0);
	return self;
}

//
- (id)initWithUser:(NSString*)userName
			 group:(NSString*)groupName
		   address:(NSString*)ipAddress
			  port:(unsigned short)port
		   machine:(NSString*)machineName
			 logOn:(NSString*)logOnUserName
		   absence:(BOOL)absenceFlag
			dialup:(BOOL)dialupFlag
		attachment:(BOOL)attachFlag
		   encrypt:(BOOL)encryptFlag {
	self			= [super init];
	user			= [userName retain];
	group			= [groupName retain];
	address			= [ipAddress retain];
	addressNumber	= ntohl(inet_addr([address UTF8String]));
	portNo			= port;
	host			= [machineName retain];
	logOnUser		= [logOnUserName retain];
	absence			= absenceFlag;
	dialup			= dialupFlag;
	attachment		= attachFlag;
	encrypt			= encryptFlag;
	version			= nil;
	return self;
}

// 解放
- (void)dealloc {
	[user release];
	[group release];
	[address release];
	[host release];
	[logOnUser release];
	[version release];
	[super dealloc];
}

/*============================================================================*
 * getter
 *============================================================================*/
 
// ユーザ名
- (NSString*)user {
	return user;
}

// グループ名
- (NSString*)group {
	return group;
}

// IPアドレス（文字列）
- (NSString*)address {
	return address;
}

// IPアドレス（数値）
- (unsigned long)addressNumber {
	return addressNumber;
}

// ポート番号
- (unsigned short)portNo {
	return portNo;
}

// マシン名
- (NSString*)host {
	return host;
}

// ログオンユーザ名
- (NSString*)logOnUser {
	return logOnUser;
}

// 不在
- (BOOL)absence {
	return absence;
}

// ダイアルアップ接続
- (BOOL)dialup {
	return dialup;
}

// ファイル添付サポート
- (BOOL)attachmentSupport {
	return attachment;
}

// 暗号化サポート
- (BOOL)encryptSupport {
	return encrypt;
}

// バージョン情報
- (NSString*)version {
	return version;
}

- (void)setVersion:(NSString*)ver {
	[ver retain];
	[version release];
	version = ver;
}

/*============================================================================*
 * 表示文字列
 *============================================================================*/
 
- (NSString*)summeryString {
	Config*				config	= [Config sharedConfig];
	NSMutableString*	desc	= [[[NSMutableString alloc] init] autorelease];

	// ユーザ名
	[desc appendString:((user) ? user : logOnUser)];
	// ログオン名
	if ([config displayLogOnName]) {
		[desc appendString:@"["];
		[desc appendString:logOnUser];
		[desc appendString:@"]"];
	}
	// 不在マーク
	if (absence) {
		[desc appendString:@"*"];
	}
	// グループ名
	[desc appendString:@" ("];
	if (group) {
		[desc appendString:group];
		[desc appendString:@"/"];
	}
	// マシン名
	[desc appendString:host];
	// IPアドレス
	if ([config displayIPAddress]) {
		[desc appendString:@"/"];
		[desc appendString:address];
	}
	[desc appendString:@")"];
	
	return desc;
}

/*----------------------------------------------------------------------------*
 * その他
 *----------------------------------------------------------------------------*/

// 等価判定
- (BOOL)isEqual:(id)anObject {
	if ([anObject isKindOfClass:[self class]]) {
		UserInfo* target = anObject;
		return ([logOnUser isEqualToString:target->logOnUser] &&
				(addressNumber == target->addressNumber) && (portNo == target->portNo));
	}
	return NO;
}

// オブジェクト文字列表現
- (NSString*)description {
	return [NSString stringWithFormat:@"%@%@%@", user, group, host];
}

/* コピー処理 （NSCopyingプロトコル） */
- (id)copyWithZone:(NSZone*)zone {
	UserInfo* newObj = [[UserInfo allocWithZone:zone] init];
	if (newObj) {
		newObj->user			= [user retain];
		newObj->group			= [group retain];
		newObj->address			= [address retain];
		newObj->addressNumber	= addressNumber;
		newObj->portNo			= portNo;
		newObj->host			= [host retain];
		newObj->logOnUser		= [logOnUser retain];
		newObj->absence			= absence;
		newObj->dialup			= dialup;
		newObj->attachment		= attachment;
		newObj->encrypt			= encrypt;
		newObj->version			= [version retain];		
	} else {
		ERR1(@"copy error(%@)", self);
	}
	return newObj;
}

// 大小比較
- (NSComparisonResult)compare:(UserInfo*)target {
	Config* 	config		= [Config sharedConfig];
	BOOL		kanji		= [config sortByKanjiPriority];
	BOOL		ignoreCase	= [config sortByIgnoreCase];
	NSString*	str1;
	NSString*	str2;
	int			i;
	// ソートルールによる比較
	for (i = 0; i < [config numberOfSortRules]; i++) {
		if ([config sortRuleEnabledAtIndex:i]) {
			IPMsgUserSortRuleType type	= [config sortRuleTypeAtIndex:i];
			IPMsgUserSortRuleType order	= [config sortRuleOrderAtIndex:i];
			// 数値の比較
			if (type == IPMSG_SORT_IP) {
				unsigned long addr1 = [self addressNumber];
				unsigned long addr2 = [target addressNumber];
				if (addr1 < addr2) {
					return (order == IPMSG_SORT_ASC) ? NSOrderedAscending : NSOrderedDescending;
				} else if (addr1 > addr2) {
					return (order == IPMSG_SORT_ASC) ? NSOrderedDescending : NSOrderedAscending;
				}
			}
			// 文字列の比較
			else {
				NSComparisonResult result;
				switch ([config sortRuleTypeAtIndex:i]) {
				case IPMSG_SORT_NAME:
					str1 = [self user];
					str2 = [target user];
					break;
				case IPMSG_SORT_GROUP:
					str1 = [self group];
					str2 = [target group];
					break;
				case IPMSG_SORT_MACHINE:
					str1 = [self host];
					str2 = [target host];
					break;
				case IPMSG_SORT_DESCRIPTION:
					str1 = [self summeryString];
					str2 = [target summeryString];
					break;
				default:
					continue;
				}
				if (ignoreCase) {
					str1 = [str1 lowercaseString];
					str2 = [str2 lowercaseString];
				}
				if (order == IPMSG_SORT_ASC) {
					result = [self compareString:str1 with:str2 kanjiPriority:kanji];
				} else {
					result = [self compareString:str2 with:str1 kanjiPriority:kanji];
				}
				if (result != NSOrderedSame) {
					return result;
				}
			}
		}
	}
	// すべて等しいため表示文字列で昇順比較
	str1 = [self summeryString];
	str2 = [target summeryString];
	if (ignoreCase) {
		str1 = [str1 lowercaseString];
		str2 = [str2 lowercaseString];
	}
	return [self compareString:str1 with:str2 kanjiPriority:kanji];
}

@end

/*============================================================================*
 * プライベートメソッド
 *============================================================================*/

@implementation UserInfo(Private)

- (NSComparisonResult)compareString:(NSString*)str1 with:(NSString*)str2 kanjiPriority:(BOOL)kanji {
	// 漢字を優先する
	if (kanji) {
		int 	len1	= [str1 length];
		int 	len2	= [str2 length];
		int 	len		= (len1 <= len2) ? len1 : len2;
		int 	i;
		unichar	c1;
		unichar	c2;
		for (i = 0; i < len; i++) {
			c1 = [str1 characterAtIndex:i];
			c2 = [str2 characterAtIndex:i];
			if (((c1 & 0xFF00) != 0) && ((c2 & 0xFF00) == 0)) {
				return NSOrderedAscending;
			} else if (((c1 & 0xFF00) == 0) && ((c2 & 0xFF00) != 0)) {
				return NSOrderedDescending;
			} else if (c1 < c2) {
				return NSOrderedAscending;
			} else if (c1 > c2) {
				return NSOrderedDescending;
			}
		}
		if (len1 < len2) {
			return NSOrderedAscending;
		} else if (len1 > len2) {
			return NSOrderedDescending;
		}
		return NSOrderedSame;
	}
	// 通常比較
	return [str1 compare:str2];
}

@end
