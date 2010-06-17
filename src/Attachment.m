/*============================================================================*
 * (C) 2001-2003 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for MacOS X
 *	File		: Attachment.m
 *	Module		: 添付ファイル情報クラス		
 *============================================================================*/

#import "Attachment.h"
#import "IPMessenger.h"
#import "AttachmentFile.h"
#import "UserInfo.h"
#import "DebugLog.h"

/*============================================================================*
 * クラス実装
 *============================================================================*/

@implementation Attachment

/*----------------------------------------------------------------------------*
 * ファクトリ
 *----------------------------------------------------------------------------*/

+ (id)attachmentWithFile:(AttachmentFile*)attach {
	return [[[Attachment alloc] initWithFile:attach] autorelease];
}

+ (id)attachmentWithMessageAttachment:(char*)buf {
	return [[[Attachment alloc] initWithMessageAttachment:buf] autorelease];
}

/*----------------------------------------------------------------------------*
 * 初期化／解放
 *----------------------------------------------------------------------------*/

// 初期化（送信用）
- (id)initWithFile:(AttachmentFile*)attach {
	self				= [super init];
	fileID				= nil;
	file				= [attach retain];
	iconImage			= [[file iconImage] retain];
	sentUsers			= [[NSMutableArray alloc] init];
	downloadComplete	= NO;
	[iconImage setSize:NSMakeSize(16, 16)];
	return self;
}

// 初期化（受信用）
- (id)initWithMessageAttachment:(char*)buf {
	char*	work;
	char*	ptr;
	
	self				= [super init];
	fileID				= nil;
	file				= nil;
	iconImage			= nil;
	sentUsers			= [[NSMutableArray alloc] init];
	downloadComplete	= NO;

	if (!buf) {
		ERR0(@"parameter error buf is NULL.");
		[self release];
		return nil;
	}
	ptr = buf;
	
	// File ID
	work = strchr(ptr, ':');
	if (!work) {
		ERR1(@"file ID error(%s)", ptr);
		[self release];
		return nil;
	}
	*work	= '\0';
	fileID	= [[NSNumber alloc] initWithLong:strtol(ptr, NULL, 10)];
	ptr = work + 1;
	
	// ファイルオブジェクト
	file = [[AttachmentFile fileWithMessageAttachment:ptr] retain];
	if (!file) {
		ERR1(@"file attach parse error(%s)", ptr);
		[self release];
		return nil;
	}
	
	// アイコン
	iconImage = [[file iconImage] retain];
	[iconImage setSize:NSMakeSize(16, 16)];
	
	return self;
}

// 解放
- (void)dealloc {
	[fileID release];
	[file release];
	[iconImage release];
	[sentUsers release];
	[super dealloc];
}

/*----------------------------------------------------------------------------*
 * getter/setter
 *----------------------------------------------------------------------------*/

// ファイルID
- (NSNumber*)fileID {
	return fileID;
}

- (void)setFileID:(int)fid {
	[fileID release];
	fileID = [[NSNumber alloc] initWithInt:fid];
}

// ファイルオブジェクト
- (AttachmentFile*)file {
	return file;
}

// ファイルアイコン
- (NSImage*)iconImage {
	return iconImage;
}

// ダウンロード完了フラグ
- (BOOL)downloadComplete {
	return downloadComplete;
}

- (void)setDownloadComplete:(BOOL)flag {
	downloadComplete = flag;
}

/*----------------------------------------------------------------------------*
 * 送信ユーザ管理
 *----------------------------------------------------------------------------*/

// 送信ユーザ追加
- (void)appendUser:(UserInfo*)user {
	if (user) {
		if (![self containsUser:user]) {
			[sentUsers addObject:user];
		}
	}
}

// 送信ユーザ削除
- (void)removeUser:(UserInfo*)user {
	[sentUsers removeObject:user];
}

// 送信ユーザ数
- (unsigned)numberOfUsers {
	return [sentUsers count];
}

// インデックス指定ユーザ情報
- (UserInfo*)userAtIndex:(unsigned)index {
	return [sentUsers objectAtIndex:index];
}

// 送信ユーザ検索
- (BOOL)containsUser:(UserInfo*)user {
	return [sentUsers containsObject:user];
}

/*----------------------------------------------------------------------------*
 * その他
 *----------------------------------------------------------------------------*/

// オブジェクト概要
- (NSString*)description {
	return [NSString stringWithFormat:@"AttachmentItem[FileID:%@,File:%@,Users:%d]",
											fileID, [file name], [sentUsers count]];
}

// オブジェクトコピー処理
- (id)copyWithZone:(NSZone*)zone {
	Attachment* newObj = [[self class] allocWithZone:zone];
	if (newObj) {
		newObj->fileID		= [fileID retain];
		newObj->file		= [file retain];
		newObj->iconImage	= [iconImage retain];
		newObj->sentUsers	= [sentUsers retain];
	}
	return newObj;
}

@end
