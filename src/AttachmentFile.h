/*============================================================================*
 * (C) 2001-2003 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for MacOS X
 *	File		: AttachmentFile.h
 *	Module		: 添付ファイルオブジェクトクラス		
 *============================================================================*/

#import <Cocoa/Cocoa.h>

/*============================================================================*
 * クラス定義
 *============================================================================*/

@interface AttachmentFile : NSObject
{
	NSString*			fileName;			// ファイル名
	NSString*			escapedFileName;	// ファイル名（エスケープ済み）
	NSString*			filePath;			// ファイルパス
	unsigned long long	fileSize;			// ファイルサイズ
	NSDate*				createTime;			// ファイル作成時刻
	NSDate*				modTime;			// ファイル更新時刻
	OSType				hfsFileType;		// ファイルタイプ
	OSType				hfsCreator;			// クリエータコード
	UInt16				finderFlags;		// Finder属性フラグ（Carbon）
	unsigned			permission;			// POSIXファイルアクセス権
	unsigned			fileAttribute;		// ファイル属性(IPMsg形式)
	NSFileHandle*		handle;				// 出力ハンドル
}

// ファクトリ
+ (id)fileWithPath:(NSString*)path;
+ (id)fileWithDirectory:(NSString*)dir file:(NSString*)file;
+ (id)fileWithMessageAttachment:(char*)attach;
+ (id)fileWithDirectory:(NSString*)dir header:(char*)header;

// 初期化／解放
- (id)initWithPath:(NSString*)path;
- (id)initWithDirectory:(NSString*)dir file:(NSString*)file;
- (id)initWithMessageAttachment:(char*)attach;
- (id)initWithDirectory:(NSString*)dir header:(char*)header;
- (void)dealloc;

// getter/setter
- (NSString*)name;
- (NSString*)path;
- (unsigned long long)size;
- (BOOL)isRegularFile;
- (BOOL)isDirectory;
- (BOOL)isParentDirectory;
- (BOOL)isExtensionHidden;
- (void)setDirectory:(NSString*)dir;

// アイコン
- (NSImage*)iconImage;

// ファイル入出力関連
- (BOOL)isFileExists;
- (BOOL)openFileForWrite;
- (BOOL)writeData:(void*)data length:(unsigned)len;
- (void)closeFile;

// 添付処理関連
- (NSString*)stringForMessageAttachment:(unsigned)fileID;
- (NSString*)stringForDirectoryHeader;

@end
