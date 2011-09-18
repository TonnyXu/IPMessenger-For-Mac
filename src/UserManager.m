/*============================================================================*
 * (C) 2001-2003 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for MacOS X
 *	File		: UserManager.m
 *	Module		: ユーザ一覧管理クラス		
 *============================================================================*/

#import <Foundation/Foundation.h>
#import "UserManager.h"
#import "UserInfo.h"
#import "DebugLog.h"

#import <netinet/in.h>
#import <arpa/inet.h>

/*============================================================================*
 * クラス実装
 *============================================================================*/

@implementation UserManager

@synthesize userList, subsetUserList, allUserList;
/*----------------------------------------------------------------------------*
 * ファクトリ
 *----------------------------------------------------------------------------*/

// 共有インスタンスを返す
+ (UserManager*)sharedManager {
	static UserManager* sharedManager = nil;
	if (!sharedManager) {
		sharedManager = [[UserManager alloc] init];
	}
	return sharedManager;
}

/*----------------------------------------------------------------------------*
 * 初期化／解放
 *----------------------------------------------------------------------------*/
 
// 初期化
- (id)init {
	self		= [super init];
	self.userList	= [NSMutableArray array];
//    self.subsetUserList = [NSMutableArray array];
    self.allUserList = self.userList;
	dialupDic	= [[NSMutableDictionary alloc] init];
	lock		= [[NSLock alloc] init];
	return self;
}

// 解放
- (void)dealloc {
	[userList	release];
    [subsetUserList release];
    [allUserList release];
	[dialupDic	release];
	[lock		release];
	[super dealloc];
}

/*----------------------------------------------------------------------------*
 * ユーザ情報取得
 *----------------------------------------------------------------------------*/
 
// ユーザ数を返す
- (int)numberOfUsers {
	return [userList count];
}

// 指定ユーザのインデックス番号を返す（見つからない場合NSNotFound）
- (int)indexOfUser:(UserInfo*)user {
	return [userList indexOfObject:user];
}

// 指定インデックスのユーザ情報を返す（見つからない場合nil）
- (UserInfo*)userAtIndex:(int)index {
	return [userList objectAtIndex:index];
}

// 指定キーのユーザ情報を返す（見つからない場合nil）
- (UserInfo*)userForLogOnUser:(NSString*)logOn address:(struct sockaddr_in*)addr {
	int i;
	for (i = 0; i < [userList count]; i++) {
		UserInfo* u = [userList objectAtIndex:i];
		if ([[u logOnUser] isEqualToString:logOn] &&
			([u addressNumber] == ntohl(addr->sin_addr.s_addr)) &&
			([u portNo] == ntohs(addr->sin_port))) {
			return u;
		}
	}
	return nil;
}

/*----------------------------------------------------------------------------*
 * ユーザ情報追加／削除
 *----------------------------------------------------------------------------*/

// ユーザ一覧変更通知発行
- (void)fireUserListChangeNotice {
	[[NSNotificationCenter defaultCenter] postNotificationName:NOTICE_USER_LIST_CHANGE object:nil];
}

// ユーザ追加
- (void)appendUser:(UserInfo*)info {
	if (info) {
		int index;
		[lock lock];
		index = [allUserList indexOfObject:info];
		if (index == NSNotFound) {
			// なければ追加
			[allUserList addObject:info];
		} else {
			// あれば置き換え
			[allUserList replaceObjectAtIndex:index withObject:info];
		}
		// リストのソート
		[allUserList sortUsingSelector:@selector(compare:)];
		// ダイアルアップユーザであればアドレス一覧を更新
		if ([info dialup]) {
			[dialupDic setObject:[info address] forKey:info];
		}
		[self fireUserListChangeNotice];
		[lock unlock];
	}
}

// ユーザ削除
- (void)removeUser:(UserInfo*)info {
	if (info) {
		int index;
		[lock lock];
		index = [self indexOfUser:info];
		if (index != NSNotFound) {
			// あれば削除
			[userList removeObjectAtIndex:index];
			[dialupDic removeObjectForKey:info];
			[self fireUserListChangeNotice];
		}
		[lock unlock];
	}
}

// ずべてのユーザを削除
- (void)removeAllUsers {
	[lock lock];
	[userList removeAllObjects];
	[dialupDic removeAllObjects];
	[self fireUserListChangeNotice];
	[lock unlock];
}

/*----------------------------------------------------------------------------*
 * その他
 *----------------------------------------------------------------------------*/

// ユーザ一覧の再ソート
- (void)sortUsers {
	// リストのソート
	[userList sortUsingSelector:@selector(compare:)];
	[self fireUserListChangeNotice];
}

// ダイアルアップアドレス一覧
- (NSArray*)dialupAddresses {
	return [dialupDic allValues];
}

@end
