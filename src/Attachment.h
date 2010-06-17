/*============================================================================*
 * (C) 2001-2003 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for MacOS X
 *	File		: Attachment.h
 *	Module		: 添付ファイル情報クラス		
 *============================================================================*/

#include <Cocoa/Cocoa.h>

@class AttachmentFile;
@class UserInfo;

/*============================================================================*
 * クラス定義
 *============================================================================*/

@interface Attachment : NSObject <NSCopying>
{
	NSNumber*		fileID;				// ファイルID
	AttachmentFile*	file;				// ファイルオブジェクト
	NSImage*		iconImage;			// ファイルアイコン
	NSMutableArray*	sentUsers;			// 送信ユーザ（送信ファイル用）
	BOOL			downloadComplete;	// ダウンロード完了フラグ（受信ファイル用）
}

// ファクトリ
+ (id)attachmentWithFile:(AttachmentFile*)attach;
+ (id)attachmentWithMessageAttachment:(char*)buf;

// 初期化／解放
- (id)initWithFile:(AttachmentFile*)attach;
- (id)initWithMessageAttachment:(char*)buf;
- (void)dealloc;

// getter/setter
- (NSNumber*)fileID;
- (void)setFileID:(int)fid;
- (AttachmentFile*)file;
- (NSImage*)iconImage;
- (BOOL)downloadComplete;
- (void)setDownloadComplete:(BOOL)flag;

// 送信ユーザ管理
- (void)appendUser:(UserInfo*)user;
- (void)removeUser:(UserInfo*)user;
- (unsigned)numberOfUsers;
- (UserInfo*)userAtIndex:(unsigned)index;
- (BOOL)containsUser:(UserInfo*)user;

@end