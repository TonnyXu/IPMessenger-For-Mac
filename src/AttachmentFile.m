/*============================================================================*
 * (C) 2001-2009 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for MacOS X
 *	File		: AttachmentFile.m
 *	Module		: 添付ファイルオブジェクトクラス		
 *============================================================================*/

#import "AttachmentFile.h"
#import "IPMessenger.h"
#import "NSStringIPMessenger.h"
#import "DebugLog.h"

/*============================================================================*
 * プライベートメソッド定義
 *============================================================================*/
 
@interface AttachmentFile(Private)
- (id)initWithBuffer:(char*)buf needReadModTime:(BOOL)flag;
- (NSMutableDictionary*)fileAttributesDictionary;
- (void)appendExtendAttributeTo:(NSMutableString*)header;
- (void)readExtendAttribute:(char*)buf;
- (BOOL)fileManager:(NSFileManager*)manager shouldProceedAfterError:(NSDictionary*)errorInfo;
@end

//static NSLock* resourceLock = nil;

/*============================================================================*
 * クラス実装
 *============================================================================*/
 
@implementation AttachmentFile

/*----------------------------------------------------------------------------*
 * ファクトリ
 *----------------------------------------------------------------------------*/
 
+ (id)fileWithPath:(NSString*)path {
	return [[[AttachmentFile alloc] initWithPath:path] autorelease];
}

+ (id)fileWithDirectory:(NSString*)dir file:(NSString*)file {
	return [[[AttachmentFile alloc] initWithDirectory:dir file:file] autorelease];
}

+ (id)fileWithMessageAttachment:(char*)attach {
	return [[[AttachmentFile alloc] initWithMessageAttachment:attach] autorelease];
}

+ (id)fileWithDirectory:(NSString*)dir header:(char*)header {
	return [[[AttachmentFile alloc] initWithDirectory:dir header:header] autorelease];
}

/*----------------------------------------------------------------------------*
 * 初期化／解放
 *----------------------------------------------------------------------------*/

// 初期化（送信メッセージ添付ファイル用）
- (id)initWithPath:(NSString*)path {
	NSFileManager*	fileManager;
	NSDictionary*	attrs;
	NSString*		work;
	NSRange			range;
			
	self			= [super init];
	fileName		= nil;
	escapedFileName	= nil;
	filePath		= nil;
	fileSize		= 0LL;
	createTime		= nil;
	modTime			= nil;
	hfsFileType		= 0;
	hfsCreator		= 0;
	finderFlags		= 0;
	permission		= 0;
	fileAttribute	= 0;
	handle			= nil;
	
	fileManager = [NSFileManager defaultManager];
	// ファイル存在チェック
	if (![fileManager fileExistsAtPath:path]) {
		ERR1(@"file not exists(%@)", path);
		[self release];
		return nil;
	}
	// ファイル読み込みチェック
	if (![fileManager isReadableFileAtPath:path]) {
		ERR1(@"file not readable(%@)", path);
		[self release];
		return nil;
	}
	// ファイル属性取得
	attrs = [fileManager fileAttributesAtPath:path traverseLink:NO];
	// 初期化
	fileName	= [[path lastPathComponent] copy];
	filePath	= [path copy];
	fileSize	= [[attrs objectForKey:NSFileSize] unsignedLongLongValue];
	createTime	= [[attrs objectForKey:NSFileCreationDate] copy];
	modTime		= [[attrs objectForKey:NSFileModificationDate] copy];
	permission	= [[attrs objectForKey:NSFilePosixPermissions] unsignedIntValue];
	hfsFileType	= [[attrs objectForKey:NSFileHFSTypeCode] unsignedLongValue];
	hfsCreator	= [[attrs objectForKey:NSFileHFSCreatorCode] unsignedLongValue];
	// 初期化（fileAttribute)
	work = [attrs objectForKey:NSFileType];
	if ([work isEqualToString:NSFileTypeRegular]) {
		fileAttribute	= IPMSG_FILE_REGULAR;
	} else if ([work isEqualToString:NSFileTypeDirectory]) {
		fileAttribute	= IPMSG_FILE_DIR;
		fileSize		= 0LL;	// 0じゃない場合があるみたいなので
	} else {
		WRN2(@"filetype unsupported(%@ is %@)", filePath, work);
		[self release];
		return nil;
	}
	if ([[attrs objectForKey:NSFileExtensionHidden] boolValue]) {
		fileAttribute |= IPMSG_FILE_EXHIDDENOPT;
	}
	if ([[attrs objectForKey:NSFileImmutable] boolValue]) {
		fileAttribute |= IPMSG_FILE_RONLYOPT;
	}
	// ファイル属性取得（FinderInfo）
	if (![self isDirectory]) {
		FSRef		fsRef;
		OSStatus	osStatus;
		osStatus = FSPathMakeRef((const UInt8*)[filePath UTF8String], &fsRef, NULL);
		if (osStatus != noErr) {
			ERR2(@"FSRef make error(%@,status=%d)", filePath, osStatus);
		} else {
			FSCatalogInfo	catInfo;
			OSErr			osError;
			osError = FSGetCatalogInfo(&fsRef, kFSCatInfoFinderInfo, &catInfo, NULL, NULL, NULL);
			if (osError != noErr) {
				ERR2(@"FSCatalogInfo get error(err=%d,%@)", osError, filePath);
			} else {
				FInfo* info = (FInfo*)(&catInfo.finderInfo[0]);
				finderFlags = info->fdFlags;
				// エイリアスファイルは除く
				if (finderFlags & kIsAlias) {
					ERR1(@"file is hfs Alias(%@)", filePath);
					[self release];
					return nil;
				}
				// 非表示ファイル
				if (finderFlags & kIsInvisible) {
					fileAttribute |= IPMSG_FILE_HIDDENOPT;
				}
			}
		}			
	}
	// ファイル名エスケープ（":"→"::"）
	range = [fileName rangeOfString:@":"];
	if (range.location != NSNotFound) {
		NSMutableString*	escaped	= [NSMutableString stringWithCapacity:[fileName length] + 10];
		NSArray*			array	= [fileName componentsSeparatedByString:@":"];
		unsigned			i;
		for (i = 0; i < [array count]; i++) {
			if (i != 0) {
				[escaped appendString:@"::"];
			}
			[escaped appendString:[array objectAtIndex:i]];
		}
		escapedFileName = [[NSString alloc] initWithString:escaped];
	} else {
		escapedFileName = [fileName retain];
	}
	// リソースフォーク確認
	/*
	{
		FSSpec	fsSpec;
		OSErr	osErr;
		if (![path getFSSpec:&fsSpec]) {
			WRN1(@"FSSpec get error(%@)", path);
		} else {
			SInt16 resFile;
			if (!resourceLock) {
				resourceLock = [[NSLock alloc] init];
			}
			[resourceLock lock];
			resFile = FSpOpenResFile(&fsSpec, fsRdPerm);
			osErr	= ResError();
			if ((resFile != -1) && (osErr == noErr)) {
				SInt16 numOfTypes = Count1Types();
				SInt16 i;
				DBG2(@"ResFork has %d Types(%@)", numOfTypes, path);
				for (i = 0; i < numOfTypes; i++) {
					ResType resType;
					SInt16 numOfRes;
					SInt16 j;
					Get1IndType(&resType, i);
					DBG5(@"  Type[%d] is '%c%c%c%c'", i, ((char*)&resType)[0], ((char*)&resType)[1], ((char*)&resType)[2], ((char*)&resType)[3]);
					numOfRes = Count1Resources(resType);
					DBG1(@"  (has %d resources)", numOfRes);
					for (j = 0; j < numOfRes; j++) {
						Handle resHandle;
						unsigned long size;
						SInt16 workID = -256;
						ResType workType;
						char workName[256];
						resHandle = GetIndResource(resType, j);
						size = GetHandleSize(resHandle);
						workName[0] = 0;
						GetResInfo(resHandle, &workID, &workType, workName);
						DBG3(@"    id=%5d,name=%s,size=%u", workID, workName, size);
					}
				}
				CloseResFile(resFile);
			} else {
				DBG1(@"no ResFork(%@)", path);
			}
			[resourceLock unlock];
		}
	}
	*/
	
	return self;
}

// 初期化（送信ディレクトリ内の個別ファイル）
- (id)initWithDirectory:(NSString*)dir file:(NSString*)file {
	return [self initWithPath:[dir stringByAppendingPathComponent:file]];
}

// 初期化（受信メッセージの添付ファイル）
- (id)initWithMessageAttachment:(char*)attach {
	return [self initWithBuffer:attach needReadModTime:YES];
}

// 初期化（ディレクトリ添付ファイル内の個別ファイル）
- (id)initWithDirectory:(NSString*)dir header:(char*)header {
	self = [self initWithBuffer:header needReadModTime:NO];
	if (self) {
		// ファイルパス
		if ([self isParentDirectory]) {
			filePath = [[dir stringByDeletingLastPathComponent] retain];
		} else {
			filePath = [[dir stringByAppendingPathComponent:fileName] retain];
		}
	}	
	return self;
}

// 解放
- (void)dealloc {
	[fileName release];
	[escapedFileName release];
	[filePath release];
	[createTime release];
	[modTime release];
	[handle release];
	[super dealloc];
}

/*----------------------------------------------------------------------------*
 * getter/setter
 *----------------------------------------------------------------------------*/
 
// ファイル名
- (NSString*)name {
	return fileName;
}

// ファイルパス
- (NSString*)path {
	return filePath;
}

// ファイルサイズ
- (unsigned long long)size {
	return fileSize;
}

// 通常ファイル判定
- (BOOL)isRegularFile {
	return (GET_MODE(fileAttribute) == IPMSG_FILE_REGULAR);
}

// ディレクトリ判定
- (BOOL)isDirectory {
	return (GET_MODE(fileAttribute) == IPMSG_FILE_DIR);
}

// 親ディレクトリ判定
- (BOOL)isParentDirectory {
	return (GET_MODE(fileAttribute) == IPMSG_FILE_RETPARENT);
}

// 拡張子非表示判定
- (BOOL)isExtensionHidden {
	return ((fileAttribute & IPMSG_FILE_EXHIDDENOPT) != 0);
}

// ディレクトリ設定（ファイル保存時）
- (void)setDirectory:(NSString*)dir {
	if (filePath) {
		ERR2(@"filePath already exist(%@,dir=%@)", filePath, dir);
		return;
	}
	filePath = [[dir stringByAppendingPathComponent:fileName] retain];
}

/*----------------------------------------------------------------------------*
 * アイコン関連
 *----------------------------------------------------------------------------*/

- (NSImage*)iconImage {
	NSWorkspace* ws = [NSWorkspace sharedWorkspace];
	// 絶対パス（ローカルファイル）
	if (filePath) {
		if ([filePath isAbsolutePath]) {
			return [ws iconForFile:filePath];
		}
	}
	// ディレクトリ
	if ([self isDirectory]) {
		if ([[fileName pathExtension] isEqualToString:@"app"]) {
			return [ws iconForFileType:@"app"];
		}
		return [ws iconForFileType:NSFileTypeForHFSTypeCode(kGenericFolderIcon)];
	}
	// ファイルタイプあり
	if (hfsFileType != 0) {
		return [ws iconForFileType:NSFileTypeForHFSTypeCode(hfsFileType)];
	}
	// 最後のたのみ拡張子
	return [ws iconForFileType:[fileName pathExtension]];
}

/*----------------------------------------------------------------------------*
 * ファイル入出力関連
 *----------------------------------------------------------------------------*/

// ファイル存在チェック
- (BOOL)isFileExists {
	return [[NSFileManager defaultManager] fileExistsAtPath:filePath];
}

// 書き込み用に開く
- (BOOL)openFileForWrite {
	NSFileManager* fileManager = [NSFileManager defaultManager];
	
	if (handle) {
		// 既に開いていれば閉じる（バグ）
		WRN1(@"openToRead:Recalled(%@)", filePath);
		[handle closeFile];
		[handle release];
		handle = nil;
	}
	if (!filePath) {
		// ファイルパス未定義は受信添付ファイルの場合ありえる（バグ）
		ERR1(@"openToWrite:filePath not specified.(%@)", fileName);
		return NO;
	}
	
	switch (GET_MODE(fileAttribute)) {
	case IPMSG_FILE_REGULAR:	// 通常ファイル
//		DBG2(@"openToWrite:type[file]=%@,size=%d", fileName, fileSize);
		// 既存ファイルがあれば削除
		if ([fileManager fileExistsAtPath:filePath]) {
			if (![fileManager removeFileAtPath:filePath handler:self]) {
				ERR1(@"opneToWrite:remove error exist file(%@)", filePath);
				return NO;
			}
		}
		// ファイル作成
		if (![fileManager createFileAtPath:filePath contents:nil attributes:[self fileAttributesDictionary]]) {
			ERR1(@"openToWrite:file create error(%@)", filePath);
			return NO;
		}
		// オープン（サイズ０は除く）
		if (fileSize > 0) {
			handle = [[NSFileHandle fileHandleForWritingAtPath:filePath] retain];
			if (!handle) {
				ERR1(@"openToWrite:file open error(%@)", filePath);
				return NO;
			}
		}
		break;
	case IPMSG_FILE_DIR:		// 子ディレクトリ
//		DBG1(@"openToWrite:type[subDir]=%@", fileName);
		// 既存ファイルがあれば削除
		if ([fileManager fileExistsAtPath:filePath]) {
			if (![fileManager removeFileAtPath:filePath handler:self]) {
				ERR1(@"opneToWrite:remove error exist dir(%@)", filePath);
				return NO;
			}
		}
		// ディレクトリ作成
		if (![fileManager createDirectoryAtPath:filePath attributes:[self fileAttributesDictionary]]) {
			ERR1(@"openToWrite:dir create error(%@)", filePath);
			return NO;
		}		
		break;
	case IPMSG_FILE_RETPARENT:	// 親ディレクトリ
//		DBG1(@"dir:type[parentDir]=%@", fileName);
		break;
	case IPMSG_FILE_SYMLINK:	// シンボリックリンク
		WRN1(@"dir:type[symlink] not support.(%@)", fileName);
		break;
	case IPMSG_FILE_CDEV:		// キャラクタ特殊ファイル
		WRN1(@"dir:type[cdev] not support.(%@)", fileName);
		break;
	case IPMSG_FILE_BDEV:		// ブロック特殊ファイル
		WRN1(@"dir:type[bdev] not support.(%@)", fileName);
		break;
	case IPMSG_FILE_FIFO:		// FIFOファイル
		WRN1(@"dir:type[fifo] not support.(%@)", fileName);
		break;
	case IPMSG_FILE_RESFORK:	// リソースフォーク
// リソースフォーク対応時に修正が必要
		WRN1(@"dir:type[resfork] not support yet.(%@)", fileName);
		break;
	default:					// 未知
		WRN2(@"dir:unknown type(%@,attr=0x%08X)", fileName, fileAttribute);
		break;
	}
	
	return YES;
}

// ファイル書き込み
- (BOOL)writeData:(void*)data length:(unsigned)len {
	BOOL result = YES;
	if (handle) {
NS_DURING
		[handle writeData:[NSData dataWithBytesNoCopy:data length:len freeWhenDone:NO]];
NS_HANDLER
		ERR1(@"writeData:write error(size=%u)", len);
		result = NO;
NS_ENDHANDLER
	}
	return result;
}

// ファイルクローズ
- (void)closeFile {
	if (handle) {
		[handle closeFile];
		[handle release];
		handle = nil;
	}
	if ([self isRegularFile] || [self isDirectory]) {
		NSFileManager*			fileManager;
		NSDictionary*			orgDic;
		NSMutableDictionary*	newDic;
		// FileManager属性の設定
		fileManager = [NSFileManager defaultManager];
		orgDic		= [fileManager fileAttributesAtPath:filePath traverseLink:NO];
		newDic		= [NSMutableDictionary dictionaryWithCapacity:[orgDic count]];
		[newDic addEntriesFromDictionary:orgDic];
		[newDic addEntriesFromDictionary:[self fileAttributesDictionary]];
		[newDic setObject:[NSNumber numberWithBool:((fileAttribute&IPMSG_FILE_RONLYOPT) != 0)] forKey:NSFileImmutable];
		[fileManager changeFileAttributes:newDic atPath:filePath];
		// FinderInfoの設定
		if (finderFlags != 0) {
			FSRef		fsRef;
			OSStatus	osStatus;
			osStatus = FSPathMakeRef((const UInt8*)[filePath UTF8String], &fsRef, NULL);
			if (osStatus != noErr) {
				ERR2(@"FSRef make error(%@,status=%d)", filePath, osStatus);
			} else {
				FSCatalogInfo	catInfo;
				FSSpec			fsSpec;
				OSErr			osError;
				osError = FSGetCatalogInfo(&fsRef, kFSCatInfoFinderInfo, &catInfo, NULL, &fsSpec, NULL);
				if (osError != noErr) {
					ERR2(@"FSCatalogInfo get error(err=%d,%@)", osError, filePath);
				} else {
					FInfo* info = (FInfo*)(&catInfo.finderInfo[0]);
					info->fdFlags =	finderFlags;
					if (fileAttribute & IPMSG_FILE_HIDDENOPT) {
						info->fdFlags |= kIsInvisible;
					}
					osError = FSSetCatalogInfo(&fsRef, kFSCatInfoFinderInfo, &catInfo);
					if (osError != noErr) {
						ERR3(@"FSCatalogInfo set error(0x%02X,err=%d,%@)", info->fdFlags, osError, filePath);
					} else {
						FlushVol(NULL, fsSpec.vRefNum);
					}
				}
			}			
		}
	}
}

/*----------------------------------------------------------------------------*
 * 添付処理関連
 *----------------------------------------------------------------------------*/

// ファイル添付（メッセージ付加用）文字列
- (NSString*)stringForMessageAttachment:(unsigned)fileID {
	unsigned mtimeVal = (unsigned)[modTime timeIntervalSince1970];
	NSMutableString* work = [NSMutableString stringWithCapacity:64];
	[work appendFormat:@"%d:%@:%llX:%X:%X:", fileID, escapedFileName, fileSize, mtimeVal, fileAttribute];
	[self appendExtendAttributeTo:work];
	return work;
}

// ディレクトリ添付（ディレクトリデータ送信時付加用）文字列
- (NSString*)stringForDirectoryHeader {
	NSMutableString* work = [NSMutableString stringWithCapacity:64];
	[work appendFormat:@"%@:%llX:%X:", escapedFileName, fileSize, fileAttribute];
	[self appendExtendAttributeTo:work];
	return [NSString stringWithFormat:@"%04X:%@", strlen([work ipmsgCString]) + 5, work];
}

/*----------------------------------------------------------------------------*
 * その他
 *----------------------------------------------------------------------------*/

// オブジェクト概要
- (NSString*)description {
	return [NSString stringWithFormat:@"AttachmentFile[%@(size=%llX)]", fileName, fileSize];
}

/*----------------------------------------------------------------------------*
 * 内部処理（Private）
 *----------------------------------------------------------------------------*/

// 受信バッファ解析初期化共通処理
- (id)initWithBuffer:(char*)buf needReadModTime:(BOOL)flag {
	char*	ptr;
	char*	work;
	NSRange	range;
	self			= [super init];
	fileName		= nil;
	escapedFileName	= nil;
	filePath		= nil;
	fileSize		= 0LL;
	createTime		= nil;
	modTime			= nil;
	hfsFileType		= 0;
	hfsCreator		= 0;
	finderFlags		= 0;
	permission		= 0;
	fileAttribute	= 0;
	handle			= nil;
	
	if (!buf) {
		ERR0(@"parameter buf is NULL");
		[self release];
		return nil;
	}
	ptr = buf;
	
	/*------------------------------------------------------------------------*
	 * ファイル名
	 *------------------------------------------------------------------------*/
	// "::"エスケープ対応取り出し
	work = strchr(ptr, ':');
	if (!work) {
		ERR1(@"file name error(%s)", ptr);
		[self release];
		return nil;
	}
	while (work[1] == ':') {
		work = strchr(work + 2, ':');
		if (!work) {
			ERR1(@"file name error(%s)", ptr);
			[self release];
			return nil;
		}
	}
	*work = '\0';
	escapedFileName = [NSString stringWithIPMsgCString:ptr];
	// "/" → "_" 置換
	range = [escapedFileName rangeOfString:@"/"];
	if (range.location != NSNotFound) {
		NSMutableString* esc = [[escapedFileName mutableCopy] autorelease];
		range = [esc rangeOfString:@"/"];
		while (range.location != NSNotFound) {
			[esc replaceCharactersInRange:range withString:@"_"];
			range = [esc rangeOfString:@"/"];
		}
		escapedFileName = [NSString stringWithString:esc];
	}
	[escapedFileName retain];
	// "::"エスケープ復元
	range = [escapedFileName rangeOfString:@"::"];
	if (range.location != NSNotFound) {
		NSMutableString*	esc		= [[[NSMutableString alloc] initWithCapacity:[escapedFileName length]] autorelease];
		NSArray*			array	= [escapedFileName componentsSeparatedByString:@"::"];
		int					i;
		for (i = 0; i < [array count]; i++) {
			[esc appendString:[array objectAtIndex:i]];
			if (i != [array count] - 1) {
				[esc appendString:@":"];
			}
		}
		fileName = [[NSString alloc] initWithString:esc];
	} else {
		fileName = [escapedFileName retain];
	}
	ptr = work + 1;
	
	/*------------------------------------------------------------------------*
	 * ファイルサイズ
	 *------------------------------------------------------------------------*/
	work = strchr(ptr, ':');
	if (!work) {
		ERR2(@"file size error(%s,file=@)", ptr, fileName);
		[self release];
		return nil;
	}
	*work = '\0';
	fileSize = strtoull(ptr, NULL, 16);
	ptr = work + 1;
	
	/*------------------------------------------------------------------------*
	 * 更新時刻（MessageAttachmentのみ）
	 *------------------------------------------------------------------------*/
	if (flag) {
		work = strchr(ptr, ':');
		if (!work) {
			ERR2(@"modDate attr error(%s,file=@)", ptr, fileName);
			[self release];
			return nil;
		}
		*work = '\0';
		modTime = [[NSDate dateWithTimeIntervalSince1970:strtol(ptr, NULL, 16)] retain];
		ptr = work + 1;
	}
	
	/*------------------------------------------------------------------------*
	 * ファイル属性
	 *------------------------------------------------------------------------*/
	work = strchr(ptr, ':');
	if (!work) {
		ERR2(@"file attr error(%s,file=%@)", ptr, fileName);
		[self release];
		return nil;
	}
	*work = '\0';
	fileAttribute = strtoul(ptr, NULL, 16);
	ptr = work + 1;
	
	/*------------------------------------------------------------------------*
	 * 拡張ファイル属性
	 *------------------------------------------------------------------------*/
	while (*ptr) {
		work = strchr(ptr, ':');
		if (!work) {
			ERR2(@"extend attr error(%s,file=%@)", ptr, fileName);
			[self release];
			return nil;
		}
		*work = '\0';
		[self readExtendAttribute:ptr];
		ptr = work + 1;
	}
	 
	return self;
}

// ファイル属性（NSFileManager用）作成
- (NSMutableDictionary*)fileAttributesDictionary {
	NSMutableDictionary* attr = [NSMutableDictionary dictionaryWithCapacity:10];
	// アクセス権（安全のため0600は必ず付与）
	if (permission != 0) {
		[attr setObject:[NSNumber numberWithUnsignedInt:(permission|0600)] forKey:NSFilePosixPermissions];
	}
	// 作成日時
	if (createTime) {
		[attr setObject:createTime forKey:NSFileCreationDate];
	}
	// 更新日時
	if (modTime) {
		[attr setObject:modTime forKey:NSFileModificationDate];
	}
	// 拡張子非表示
	[attr setObject:[NSNumber numberWithBool:((fileAttribute|IPMSG_FILE_EXHIDDENOPT) != 0)] forKey:NSFileExtensionHidden];
	// ファイルタイプ
	if (hfsFileType != 0) {
		[attr setObject:[NSNumber numberWithUnsignedLong:hfsFileType] forKey:NSFileHFSTypeCode];
	}
	// クリエータ
	if (hfsCreator != 0) {
		[attr setObject:[NSNumber numberWithUnsignedLong:hfsCreator] forKey:NSFileHFSCreatorCode];
	}
	return attr;
}

// 拡張ファイル属性編集
- (void)appendExtendAttributeTo:(NSMutableString*)header {
	if (createTime) {
		[header appendFormat:@"%X=%X:", IPMSG_FILE_CREATETIME, (unsigned)[createTime timeIntervalSince1970]];
	}
	if (modTime) {
		[header appendFormat:@"%X=%X:", IPMSG_FILE_MTIME, (unsigned)[modTime timeIntervalSince1970]];
	}
	if (permission != 0) {
		[header appendFormat:@"%X=%X:", IPMSG_FILE_PERM, permission];
	}
	if (hfsFileType != 0) {
		[header appendFormat:@"%X=%X:", IPMSG_FILE_FILETYPE, hfsFileType];
	}
	if (hfsCreator != 0) {
		[header appendFormat:@"%X=%X:", IPMSG_FILE_CREATOR, hfsCreator];
	}
	if (finderFlags != 0) {
		[header appendFormat:@"%X=%X:", IPMSG_FILE_FINDERINFO, finderFlags];
	}
}

// 拡張ファイル属性解析
- (void)readExtendAttribute:(char*)buf {
	char*			sKey;
	char*			sVal;
	char*			work = strchr(buf, '=');
	unsigned long	key;
	unsigned long	val;
	if (!work) {
		ERR1(@"extend attribute invalid(%s)", buf);
		return;
	}
	*work = '\0';
	sKey = buf;
	sVal = &work[1];
	if (strlen(sKey) == 0) {
		ERR0(@"extend attribute key invalid");
		return;
	}
	if (strlen(sVal) == 0) {
		ERR0(@"extend attribute val invalid");
		return;
	}
	key = strtoul(sKey, NULL, 16);
	val = strtoul(sVal, NULL, 16);
	switch (key) {
	case IPMSG_FILE_UID:
		WRN2(@"extAttr:UID unsupported(%d[0x%X])", val, val);
		break;
	case IPMSG_FILE_USERNAME:
		WRN2(@"extAttr:USERNAME unsupported(%d[0x%X])", val, val);
		break;
	case IPMSG_FILE_GID:
		WRN2(@"extAttr:GID unsupported(%d[0x%X])", val, val);
		break;
	case IPMSG_FILE_GROUPNAME:
		WRN2(@"extAttr:GROUPNAME unsupported(%d[0x%X])", val, val);
		break;
	case IPMSG_FILE_PERM:
		permission = val;
//		DBG1(@"extAttr:PERM=0%03o", permission);
		break;
	case IPMSG_FILE_MAJORNO:
		WRN2(@"extAttr:MAJORNO unsupported(%d[0x%X])", val, val);
		break;
	case IPMSG_FILE_MINORNO:
		WRN2(@"extAttr:MINORNO unsupported(%d[0x%X])", val, val);
		break;
	case IPMSG_FILE_CTIME:
		WRN2(@"extAttr:CTIME unsupported(%d[0x%X])", val, val);
		break;
	case IPMSG_FILE_MTIME:
		[modTime release];
		modTime = [[NSDate dateWithTimeIntervalSince1970:val] retain];
//		DBG2(@"extAttr:MTIME=%d(%@)", val, modTime);
		break;
	case IPMSG_FILE_ATIME:
		WRN2(@"extAttr:ATIME unsupported(%d[0x%X])", val, val);
		break;
	case IPMSG_FILE_CREATETIME:
		createTime = [[NSDate dateWithTimeIntervalSince1970:val] retain];
//		DBG2(@"extAttr:CREATETIME=%d(%@)", val, createTime);
		break;
	case IPMSG_FILE_CREATOR:
		hfsCreator = val;
//		DBG5(@"extAttr:CREATOR=0x%08X('%c%c%c%c')", hfsCreator,
//				((char*)&val)[0], ((char*)&val)[1], ((char*)&val)[2], ((char*)&val)[3]);
		break;
	case IPMSG_FILE_FILETYPE:
		hfsFileType = val;
//		DBG5(@"extAttr:FILETYPE=0x%08X('%c%c%c%c')", hfsFileType,
//				((char*)&val)[0], ((char*)&val)[1], ((char*)&val)[2], ((char*)&val)[3]);
		break;
	case IPMSG_FILE_FINDERINFO:
		finderFlags = val;
//		DBG3(@"extAttr:FINDERINFO=0x%04X('%c%c')", finderFlags, ((char*)&val)[0], ((char*)&val)[1]);
		break;
	case IPMSG_FILE_ACL:
		WRN2(@"extAttr:ACL unsupported(%d[0x%X])", val, val);
		break;
	case IPMSG_FILE_ALIASFNAME:
		WRN2(@"extAttr:ALIASFNAME unsupported(%d[0x%X])", val, val);
		break;
	case IPMSG_FILE_UNICODEFNAME:
		WRN2(@"extAttr:UNICODEFNAME unsupported(%d[0x%X])", val, val);
		break;
	default:
		WRN3(@"extAttr:unknownType(0x%08X,val=%d[0x%X])", key, val, val);
		break;
	}	
}

- (BOOL)fileManager:(NSFileManager*)manager shouldProceedAfterError:(NSDictionary*)errorInfo {
	// エラーが起きるのはまずアクセス権がない場合に決まっているのでメッセージも決めうち
	// 本来はエラーの原因を調べる必要がある
	NSRunAlertPanel(NSLocalizedString(@"RecvDlg.Attach.NoPermission.Title", nil),
					NSLocalizedString(@"RecvDlg.Attach.NoPermission.Msg", nill),
					NSLocalizedString(@"RecvDlg.Attach.NoPermission.OK", nil),
					nil, nil, [errorInfo objectForKey:@"Path"]);
	return NO;
}

@end
