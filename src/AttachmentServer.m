/*============================================================================*
 * (C) 2001-2009 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for MacOS X
 *	File		: AttachmentServer.m
 *	Module		: 送信添付ファイル管理クラス		
 *============================================================================*/

#import "AttachmentServer.h"
#import "IPMessenger.h"
#import "Attachment.h"
#import "AttachmentFile.h"
#import "MessageCenter.h"
#import "UserManager.h"
#import "UserInfo.h"
#import "Config.h"
#import "NSStringIPMessenger.h"
#import "DebugLog.h"

#include <unistd.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <arpa/inet.h>

static BOOL valid = FALSE;

// IPMsgファイル送信依頼情報
typedef struct {
	unsigned	messageID;			// メッセージID
	unsigned	fileID;				// ファイルID
	unsigned	offset;				// オフセット位置

} IPMsgAttachRequest;

/*============================================================================*
 * プライベートメソッド定義
 *============================================================================*/
 
@interface AttachmentServer(Private)
// 添付ファイルサーバ関連
- (void)serverThread:(id)obj;
- (BOOL)sendFile:(AttachmentFile*)file to:(int)sock sendHeader:(BOOL)flag;
- (BOOL)sendDirectory:(AttachmentFile*)file to:(int)sock;
- (void)attachSendThread:(id)obj;
- (BOOL)parseAttachRequest:(char*)buffer into:(IPMsgAttachRequest*)req;

// その他
- (void)fireAttachListChangeNotice;
@end

/*============================================================================*
 * クラス実装
 *============================================================================*/

@implementation AttachmentServer

/*----------------------------------------------------------------------------*
 * ファクトリ
 *----------------------------------------------------------------------------*/

// 共有インスタンス獲得
+ (AttachmentServer*)sharedServer {
	static AttachmentServer* sharedManager = nil;
	if (!sharedManager && [MessageCenter valid]) {
		sharedManager = [[AttachmentServer alloc] init];
	}
	return sharedManager;
}

// 有効チェック
+ (BOOL)isAvailable {
	return valid;
}

// サーバ停止
- (void)shutdownServer {
	DBG0(@"Shutdown Attachment Server...");
	shutdown = YES;
	[serverLock lock];	// サーバロックがとれるのはサーバスレッドが終了した時
	DBG0(@"Attachment Server finished.");
	[serverLock unlock];
}

/*----------------------------------------------------------------------------*
 * 初期化／解放
 *----------------------------------------------------------------------------*/

// 初期化 
- (id)init {
	int					sockopt	= 1;		// ソケットオプション
	struct sockaddr_in	addr;				// バインド用アドレス
	int					portNo;				// ポート番号
	
	// 変数初期化
	self		= [super init];
	attachDic	= [[NSMutableDictionary alloc] init]; 
	lockObj		= [[NSLock alloc] init];
	serverLock	= [[NSLock alloc] init];
	serverSock	= -1;
	shutdown	= FALSE;
	portNo		= [[MessageCenter sharedCenter] portNo];
	fileManager	= [NSFileManager defaultManager];
	if (portNo <= 0) {
		portNo = IPMSG_DEFAULT_PORT;
	}
	
	// ソケットオープン
	if ((serverSock = socket(AF_INET, SOCK_STREAM, 0)) == -1) {
		ERR0(@"serverSock:socket error");
		// Dockアイコンバウンド
		[NSApp requestUserAttention:NSCriticalRequest];
		// エラーダイアログ表示
		NSRunCriticalAlertPanel(NSLocalizedString(@"Err.TCPSocketOpen.title", nil),
								NSLocalizedString(@"Err.TCPSocketOpen.msg", nil),
								NSLocalizedString(@"Err.TCPSocketOpen.ok", nil),
								nil, nil);
		return self;
	}
	
	// ソケットバインドアドレスの用意
	memset(&addr, 0, sizeof(addr));
	addr.sin_family			= AF_INET;
	addr.sin_addr.s_addr	= htonl(INADDR_ANY);
	addr.sin_port			= htons(portNo);
	
	// ソケットバインド
	if (bind(serverSock, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
		ERR0(@"serverSock:bind error");
		// Dockアイコンバウンド
		[NSApp requestUserAttention:NSCriticalRequest];
		// エラーダイアログ表示
		NSRunCriticalAlertPanel(
							NSLocalizedString(@"Err.TCPSocketBind.title", nil),
							NSLocalizedString(@"Err.TCPSocketBind.msg", nil),
							NSLocalizedString(@"Err.TCPSocketBind.ok", nil),
							nil, nil, portNo);
		return self;
	}

	// REUSE ADDR
	sockopt = 1;
	setsockopt(serverSock, SOL_SOCKET, SO_REUSEADDR, &sockopt, sizeof(sockopt));
	
	// サーバ初期化
	if (listen(serverSock, 5) != 0) {
		ERR0(@"serverSock:listen error");
		// Dockアイコンバウンド
		[NSApp requestUserAttention:NSCriticalRequest];
		// エラーダイアログ表示
		NSRunCriticalAlertPanel(
							NSLocalizedString(@"Err.TCPSocketListen.title", nil),
							NSLocalizedString(@"Err.TCPSocketListen.msg", nil),
							NSLocalizedString(@"Err.TCPSocketListen.ok", nil),
							nil, nil);
		return self;
	}
	
	// 添付要求受信スレッド
	[NSThread detachNewThreadSelector:@selector(serverThread:) toTarget:self withObject:nil];
	
	valid = YES;
	
	return self;
}

// 解放
- (void)dealloc {
// 全タイマストップは？
	[attachDic release];
	[lockObj release];
	[serverLock release];
	if (serverSock != -1) {
		close(serverSock);
	}
	[super dealloc];
}

/*----------------------------------------------------------------------------*
 * 送信添付ファイル情報管理
 *----------------------------------------------------------------------------*/

// 添付ファイル管理タイムアウト
- (void)clearAttachmentByTimeout:(id)aTimer {
	[self removeAttachmentsByMessageID:(NSNumber*)[aTimer userInfo] needLock:YES clearTimer:NO];
}

// 送信添付ファイル追加
- (void)addAttachment:(Attachment*)attach messageID:(NSNumber*)mid {
	if (attach && mid) {
		NSMutableDictionary* dic;
		[lockObj lock];
		dic = [attachDic objectForKey:mid];
		if (!dic) {
			// 既に同一メッセージIDの管理情報がない場合
			NSTimer* timer;
			// 新しい下位辞書の作成／登録
			dic = [[NSMutableDictionary alloc] init];
			if (dic) {
				[attachDic setObject:dic forKey:mid];
			} else {
				ERR0(@"allocation/init error(dic)");
			}
			// 破棄タイマの設定
			timer = [NSTimer scheduledTimerWithTimeInterval:(24 * 60 * 60)
													 target:self
												   selector:@selector(clearAttachmentByTimeout:)
												   userInfo:mid
													repeats:NO];
			if (timer) {
				[dic setObject:timer forKey:@"Timer"];
			} else {
				ERR0(@"release timer alloc/init error");
			}
		}
		if (dic) {
			// 添付管理情報の追加
			[dic setObject:attach forKey:[attach fileID]];
			[self fireAttachListChangeNotice];
		}
		[lockObj unlock];
	}
}

- (void)removeAttachmentByMessageID:(NSNumber*)mid {
	[self removeAttachmentsByMessageID:mid needLock:YES clearTimer:YES];
}

- (void)removeAttachmentByMessageID:(NSNumber*)mid fileID:(NSNumber*)fid {
	NSMutableDictionary* dic;
	[lockObj lock];
	// メッセージIDに対応する下位辞書の検索
	dic = [attachDic objectForKey:mid];
	if (dic) {
		[dic removeObjectForKey:fid];
		if ([dic count] <= 1) {
			// 添付情報がなくなった場合(Timerはあるはず)
			[self removeAttachmentsByMessageID:mid needLock:NO clearTimer:YES];
		}
		[self fireAttachListChangeNotice];
	} else {
		WRN1(@"attach info not found(mid=%@)", mid);
	}
	[lockObj unlock];
}

// 指定メッセージID添付ファイル削除
- (void)removeAttachmentsByMessageID:(NSNumber*)mid needLock:(BOOL)lockFlag clearTimer:(BOOL)clearFlag {
	NSMutableDictionary* dic;
	if (lockFlag) {
		[lockObj lock];
	}
	// メッセージIDに対応する下位辞書の検索
	dic = [attachDic objectForKey:mid];
	if (dic) {
		if (clearFlag) {
		NSTimer* timer = [dic objectForKey:@"Timer"];
			// タイマストップ
			if (timer) {
				if ([timer isValid]) {
					[timer invalidate];
				}
			}
		}
		// 管理情報破棄
		[attachDic removeObjectForKey:mid];
		[self fireAttachListChangeNotice];
	} else {
		WRN1(@"attach info not found(mid=%@)", mid);
	}
	if (lockFlag) {
		[lockObj unlock];
	}
}

// 送信添付ファイル検索
- (Attachment*)attachmentWithMessageID:(NSNumber*)mid fileID:(NSNumber*)fid {
	if (mid && fid) {
		NSMutableDictionary* dic = [attachDic objectForKey:mid];
		if (dic) {
			return [dic objectForKey:fid];
		}
	}
	return nil;
}

/*----------------------------------------------------------------------------*
 * 送信ユーザ管理
 *----------------------------------------------------------------------------*/

- (void)addUser:(UserInfo*)user messageID:(NSNumber*)mid {
	NSMutableDictionary* dic;
	[lockObj lock];
	dic = [attachDic objectForKey:mid];
	if (dic) {
		NSArray*	keys = [dic allKeys];
		int			i;
		for (i = 0; i < [keys count]; i++) {
			Attachment* attach;
			id			fid = [keys objectAtIndex:i];
			if ([fid isEqual:@"Timer"]) {
				continue;
			}
			attach = [dic objectForKey:fid];
			if (attach) {
				if (![attach containsUser:user]) {
					[attach appendUser:user];
				} else {
					ERR3(@"attach send user already exist(%@,%@,%@)", mid, fid, user);
				}
				[self fireAttachListChangeNotice];
			} else {
				ERR2(@"attach item not found(%@,%@)", mid, fid);
			}
		}
	} else {
		ERR1(@"attach mid not found(%@)", mid);
	}
	[lockObj unlock];
}

- (BOOL)containsUser:(UserInfo*)user messageID:(NSNumber*)mid fileID:(NSNumber*)fid {
	NSMutableDictionary* dic = [attachDic objectForKey:mid];
	if (dic) {
		Attachment* item = [dic objectForKey:fid];
		if (item) {
			return [item containsUser:user];
		} else {
			ERR2(@"attach item not found(%@,%@)", mid, fid);
		}
	} else {
		ERR1(@"attach mid not found(%@)", mid);
	}
	return NO;
}

// 添付ファイル送信ユーザ削除
- (void)removeUser:(UserInfo*)user {
	NSEnumerator* keys = [attachDic keyEnumerator];
	id key;
	while ((key = [keys nextObject])) {
		[self removeUser:user messageID:key];
	}
}
	
// 添付ファイル送信ユーザ削除
- (void)removeUser:(UserInfo*)user messageID:(NSNumber*)mid {
	NSMutableDictionary* dic;
	[lockObj lock];
	dic = [attachDic objectForKey:mid];
	if (dic) {
		NSArray*	keys = [dic allKeys];
		int			i;
		for (i = 0; i < [keys count]; i++) {
			Attachment*	item;
			id			fid = [keys objectAtIndex:i];
			if ([fid isEqual:@"Timer"]) {
				continue;
			}
			item = [dic objectForKey:fid];
			if (item) {
				if ([item containsUser:user]) {
					[item removeUser:user];
					if ([item numberOfUsers] <= 0) {
						DBG2(@"all user finished.(%@,%@)remove", mid, fid);
						[dic removeObjectForKey:fid];
						if ([dic count] <= 1) {
							// 添付情報がなくなった場合(Timerはあるはず)
							[self removeAttachmentsByMessageID:mid needLock:NO clearTimer:YES];
						}
					}
					[self fireAttachListChangeNotice];
				}
			} else {
				ERR2(@"attach item not found(%@,%@)", mid, fid);
			}
		}
	} else {
		ERR1(@"attach mid not found(%@)", mid);
	}
	[lockObj unlock];
}

// 添付ファイル送信ユーザ削除
- (void)removeUser:(UserInfo*)user messageID:(NSNumber*)mid fileID:(NSNumber*)fid {
	NSMutableDictionary* dic;
	[lockObj lock];
	dic = [attachDic objectForKey:mid];
	if (dic) {
		Attachment* item = [dic objectForKey:fid];
		if (item) {
			if ([item containsUser:user]) {
				[item removeUser:user];
				if ([item numberOfUsers] <= 0) {
					[dic removeObjectForKey:fid];
					if ([dic count] <= 1) {
						// 添付情報がなくなった場合(Timerはあるはず)
						[self removeAttachmentsByMessageID:mid needLock:NO clearTimer:YES];
					}
				}
				[self fireAttachListChangeNotice];
			} else {
				ERR3(@"attach send user not found(%@,%@,%@)", mid, fid, user);
			}
		} else {
			ERR2(@"attach item not found(%@,%@)", mid, fid);
		}
	} else {
		ERR1(@"attach mid not found(%@)", mid);
	}
	[lockObj unlock];
}

/*----------------------------------------------------------------------------*
 * その他
 *----------------------------------------------------------------------------*/
 
- (int)numberOfMessageIDs {
	return [attachDic count];
}

- (NSNumber*)messageIDAtIndex:(int)index {
	NSArray* keys = [attachDic allKeys];
	if ((index < 0) || (index >= [attachDic count])) {
		return nil;
	}
	return [keys objectAtIndex:index];
}

- (int)numberOfAttachmentsInMessageID:(NSNumber*)mid {
	NSDictionary* dic = [attachDic objectForKey:mid];
	return (dic != nil) ? ([dic count] - 1) : 0;
}

- (Attachment*)attachmentInMessageID:(NSNumber*)mid atIndex:(int)index {
	NSDictionary* dic = [attachDic objectForKey:mid];
	if (dic) {
		int			count = 0;
		int			i;
		NSArray*	vals = [dic allValues];
		for (i = 0; i < [vals count]; i++) {
			id val = [vals objectAtIndex:i];
			if ([val isKindOfClass:[Attachment class]]) {
				if (count == index) {
					return val;
				}
				count++;
			}
		}
	}
	return nil;
}

- (id)attachmentAtIndex:(int)index {
	int			count = 0;
	NSArray*	keys1;
	int			i;
	keys1 = [attachDic allKeys];
	for (i = 0; i < [keys1 count]; i++) {
		int				j;
		id				key1	= [keys1 objectAtIndex:i];
		NSDictionary*	dic		= [attachDic objectForKey:key1];
		NSArray*		keys2	= [dic allKeys];
		for (j = 0; j < [keys2 count]; j++) {
			id key2	= [keys2 objectAtIndex:j];
			id item = [dic objectForKey:key2];
			if ([item isKindOfClass:[Attachment class]]) {
				if (count == index) {
					return item;
				}
				count++;
			}
		}
	}
	return nil;
}

/*----------------------------------------------------------------------------*
 * ファイルサーバ（Private）
 *----------------------------------------------------------------------------*/

// 要求受付スレッド
- (void)serverThread:(id)obj {
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	struct sockaddr_in	clientAddr;
	socklen_t			len = sizeof(clientAddr);
	fd_set				fdSet;
	struct timeval		tv;
	int					ret;
		
	[serverLock lock];
	
	DBG0(@"ServerThread start.");
	while (!shutdown) {
		FD_ZERO(&fdSet);
		FD_SET(serverSock, &fdSet);
		tv.tv_sec	= 1;
		tv.tv_usec	= 0;
		ret = select(serverSock + 1, &fdSet, NULL, NULL, &tv);
		if (ret < 0) {
			ERR1(@"serverThread:select error(%d)", ret);
			break;
		}
		if (ret == 0) {
			// タイムアウト
			continue;
		}
		if (FD_ISSET(serverSock, &fdSet)) {
			int newSock = accept(serverSock, (struct sockaddr*)&clientAddr, &len);
			if (newSock < 0) {
				ERR1(@"serverThread:accept error(%d)", newSock);
				break;
			} else {
				NSNumber*	sockfd	= [NSNumber numberWithInt:newSock];
				NSNumber*	address = [NSNumber numberWithUnsignedLong:ntohl(clientAddr.sin_addr.s_addr)];
				NSArray*	param	= [NSArray arrayWithObjects:sockfd, address, nil];
				DBG2(@"serverThread:FileRequest recv(sock=%@,address=%s)", sockfd, inet_ntoa(clientAddr.sin_addr));
				[NSThread detachNewThreadSelector:@selector(attachSendThread:) toTarget:self withObject:param];
				[sockfd release];
			}
		}
	}
	DBG0(@"ServerThread end.");

	[serverLock unlock];
	[pool release];
}

// ファイル送信スレッド
- (void)attachSendThread:(id)obj {
	NSAutoreleasePool*	pool	= [[NSAutoreleasePool alloc] init];
	int					sock	= [[obj objectAtIndex:0] intValue];		// 送信ソケットディスクリプタ
	struct sockaddr_in	addr;
	int					waitTime;										// タイムアウト管理
	fd_set				fdSet;											// ソケット監視用
	struct timeval		tv;												// ソケット監視用
	char				buf[256];										// リクエスト読み込みバッファ
	int					ret;
	
	DBG1(@"sendThread:start(fd=%d).", sock);
	
	addr.sin_addr.s_addr	= htonl([[obj objectAtIndex:1] unsignedLongValue]);
	addr.sin_port			= htons([[MessageCenter sharedCenter] portNo]);
	
	// パラメタチェック
	if (sock < 0) {
		ERR1(@"sendThread:no socket(%d)", sock);
		[pool release];
		[NSThread exit];
	}
	
	for (waitTime = 0; waitTime < 30; waitTime++) {
		// リクエスト受信待ち
		memset(buf, 0, sizeof(buf));
		FD_ZERO(&fdSet);
		FD_SET(sock, &fdSet);
		tv.tv_sec	= 1;
		tv.tv_usec	= 0;
		ret = select(sock + 1, &fdSet, NULL, NULL, &tv);
		if (ret < 0) {
			ERR1(@"sendThread:select error(%d)", ret);
			break;
		}
		if (ret == 0) {
			continue;
		}
		if (FD_ISSET(sock, &fdSet)) {
			NSString*			logOn;
			UserInfo*			user;
			NSNumber*			mid;
			NSNumber*			fid;
			Attachment*			attach;
			AttachmentFile*		file;
			IPMsgData			recvData;
			IPMsgAttachRequest	req;
			int					len;
			// リクエスト読み込み
			len = recv(sock, buf, sizeof(buf) - 1, 0);
			if (len < 0) {
				ERR1(@"sendThread:recvError(%d)", len);
				break;
			}
			// リクエスト解析
			buf[len] = '\0';
			DBG1(@"sendThread:recvRequest(%s)", buf);
			if (![MessageCenter parseReceiveData:buf length:len into:&recvData]) {
				ERR1(@"sendThread:Command Parse Error(%s)", buf);
				break;
			}
			// ユーザの特定
			logOn	= [NSString stringWithIPMsgCString:recvData.userName];
			user	= [[UserManager sharedManager] userForLogOnUser:logOn address:&addr];
			if (!user) {
				ERR3(@"sendThread:User find error(%@/%s:%d)", logOn, inet_ntoa(addr.sin_addr), htons(addr.sin_port));
				break;
			}
			// 添付ファイル解析
			if (![self parseAttachRequest:recvData.extension into:&req]) {
				ERR1(@"sendThread:Attach parse Error(%s)", recvData.extension);
				break;
			}
			mid		= [NSNumber numberWithInt:req.messageID];
			fid		= [NSNumber numberWithInt:req.fileID];
			attach	= [self attachmentWithMessageID:mid fileID:fid];
			if (!attach) {
				ERR2(@"sendThread:attach not found.(%@/%@)", mid, fid);
				break;
			}
			// 送信ユーザであるかチェック
			if (![self containsUser:user messageID:mid fileID:fid]) {
				ERR1(@"sendThread:user(%@) not contained.", user);
				break;
			}
			// ファイル送信
			file = [attach file];
			if (!file) {
				ERR0(@"sendThread:file invalid(nil)");
				break;
			}
			switch (GET_MODE(recvData.command)) {
			case IPMSG_GETFILEDATA:	// 通常ファイル
				if (![file isRegularFile]) {
					ERR1(@"sendThread:type is not file(%@)", [file path]);
					break;
				}
				if ([self sendFile:file to:sock sendHeader:NO]) {
					[self removeUser:user messageID:mid fileID:fid];
					DBG0(@"sendThread:File Request processing complete.");
				} else {
					ERR1(@"sendThread:sendFile error(%@)", [file path]);
				}
				break;
			case IPMSG_GETDIRFILES:	// ディレクトリ
				if (![file isDirectory]) {
					ERR1(@"sendThread:type is not directory(%@)", [file path]);
					break;
				}
				if ([self sendDirectory:file to:sock]) {
					[self removeUser:user messageID:mid fileID:fid];
					DBG0(@"sendThread:Dir Request processing complete.");
				} else {
					ERR1(@"sendThread:sendDir error(%@)", [file path]);
				}
				break;
			default:	// その他
				ERR2(@"sendThread:invalid command([0x%08X],%@)", GET_MODE(recvData.command), [file path]);
				break;
			}
			break;
		}
	}
	if (waitTime >= 30) {
		ERR0(@"sendThread:recv TimeOut.");
	}
	
	close(sock);
	DBG1(@"sendThread:finish.(fd=%d)", sock);
	[pool release];
}

// ディレクトリ送信
- (BOOL)sendDirectory:(AttachmentFile*)dir to:(int)sock {
	char*		header;
	NSArray*	files;
	int			i;
	// ディレクトリヘッダ送信
	header = (char*)[[dir stringForDirectoryHeader] ipmsgCString];
	if (send(sock, header, strlen(header), 0) < 0) {
		ERR2(@"dir:dir header send error(%s,%@)", header, [dir path]);
		return NO;
	}

	// ディレクトリ直下ファイル送信ループ
	files = [fileManager directoryContentsAtPath:[dir path]];
	for (i = 0; i < [files count]; i++) {
//DBG2(@"send:%@ %@", [dir path], [files objectAtIndex:i]);
		NSDictionary*	attrs;
		NSString*		type;
		AttachmentFile* child;
		child = [AttachmentFile fileWithDirectory:[dir path] file:[files objectAtIndex:i]];
		if (!child) {
			ERR3(@"dir:child[%d] of '%@' invalid(%@)", i, [dir path], [files objectAtIndex:i]);
			continue;
		}
//		DBG2(@"dir:child[%d] send start(%@)", i, [child name]);
		attrs	= [fileManager fileAttributesAtPath:[child path] traverseLink:NO];
		type	= [attrs objectForKey:NSFileType];
		// 子ファイル
		if ([type isEqualToString:NSFileTypeRegular]) {
			// ファイルデータ送信
			if (![self sendFile:child to:sock sendHeader:YES]) {
				ERR3(@"dir:file send error(%@[child[%d]of'%@'])", [child name], i, [dir path]);
				return NO;
			}
		}
		// 子ディレクトリ
		else if ([type isEqualToString:NSFileTypeDirectory]) {
			// ディレクトリ送信（再帰呼び出し）
			if (![self sendDirectory:child to:sock]) {
				ERR3(@"dir:subdir send error(%@[child[%d]of'%@'])", [child name], i, [dir path]);
				return NO;
			}
		}
		// 非サポート
		else {
			ERR4(@"dir:unsupported file type(%@,%@[child[%d]of'%@'])", type, [child name], i, [dir path]);
			continue;
		}
	}
	
	// 親ディレクトリ復帰ヘッダ送信
	header = "000B:.:0:3:";	// IPMSG_FILE_RETPARENT = 0x3
	if (send(sock, header, strlen(header), 0) < 0) {
		ERR2(@"dir:to parent header send error(%s,%@)", header, [dir path]);
		return NO;
	}
	
//	DBG1(@"SendDirComplete(%@)", [dir path]);
			
	return YES;
}

// ファイル送信処理（ヘッダなし、ファイルデータのみ）
- (BOOL)sendFile:(AttachmentFile*)file to:(int)sock sendHeader:(BOOL)flag {
	// 送信準備
	int				size		= 8192;
	NSFileHandle*	fileHandle	= [NSFileHandle fileHandleForReadingAtPath:[file path]];
	if (!fileHandle) {
		ERR1(@"sendFileData:Open Error(%@)", [file path]);
		return NO;
	}
	if (flag) {
		// ファイルヘッダ送信
		char* header = (char*)[[file stringForDirectoryHeader] ipmsgCString];
		if (send(sock, header, strlen(header), 0) < 0) {
			ERR1(@"header send error(%s)", header);
			[fileHandle closeFile];
			return NO;
		}
	}
	// 送信ループ
	while (YES) {
		// ファイル読み込み
		NSData*	data = [fileHandle readDataOfLength:size];
		if (!data) {
			ERR1(@"sendFileData:Read Error(data is nil,path=%@)", [file path]);
			[fileHandle closeFile];
			return NO;
		}
		// 送信完了チェック
		if ([data length] == 0) {
//			DBG1(@"SendFileComplete1(%@)", [file path]);
			break;
		}
		// データ送信
		if (send(sock, [data bytes], [data length], 0) < 0) {
			ERR1(@"sendFileData:Send Error(path=%@)", [file path]);
			[fileHandle closeFile];
			return NO;
		}
		if ([data length] != size) {
			// 送信完了
//			DBG1(@"SendFileComplete2(%@)", [file path]);
			break;
		}
	}
	
	[fileHandle closeFile];
	
	return YES;
}

// 添付送信リクエスト情報解析
- (BOOL)parseAttachRequest:(char*)buffer into:(IPMsgAttachRequest*)req {
	char* ptr = buffer;
	char* work;
	if (!buffer) {
		ERR0(@"Parameter error(buffer is NULL)");
		return NO;
	}
	if (!req) {
		ERR0(@"Parameter error(req is NULL)");
		return NO;
	}
	
	// メッセージID
	req->messageID = strtoul(ptr, &work, 16);
	if (*work != ':') {
		ERR1(@"messageID parse error(%s)", ptr);
		return NO;
	}
	ptr = work + 1;
	
	// ファイルID
	req->fileID = strtoul(ptr, &work, 16);
	if (*work != ':') {
		ERR1(@"fileID parse error(%s)", ptr);
		return NO;
	}
	ptr = work + 1;

	// オフセット
	req->offset = strtoul(ptr, &work, 16);
	if ((*work != ':') && (*work != '\0')) {
		ERR1(@"offset parse error(%s)", ptr);
		return NO;
	}

	return YES;
}

/*----------------------------------------------------------------------------*
 * 内部利用（Private）
 *----------------------------------------------------------------------------*/

// 添付管理情報変更通知発行
- (void)fireAttachListChangeNotice {
	[[NSNotificationCenter defaultCenter] postNotificationName:NOTICE_ATTACH_LIST_CHANGE object:nil];
}

@end
