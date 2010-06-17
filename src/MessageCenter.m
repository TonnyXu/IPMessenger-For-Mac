/*============================================================================*
 * (C) 2001-2009 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for MacOS X
 *	File		: MessageCenter.m
 *	Module		: メッセージ送受信管理クラス		
 *============================================================================*/

#import <Cocoa/Cocoa.h>

#import "IPMessenger.h"
#import "MessageCenter.h"
#import "AppControl.h"
#import "Config.h"
#import "PortChangeControl.h"
#import "UserManager.h"
#import "UserInfo.h"
#import "RecvMessage.h"
#import "SendMessage.h"
#import "RetryInfo.h"
#import "NoticeControl.h"
#import "AttachmentServer.h"
#import "Attachment.h"
#import "AttachmentFile.h"
#import "NSStringIPMessenger.h"
#import	"DebugLog.h"

// UNIXソケット関連
#include <stdlib.h>
#include <unistd.h>
#include <netdb.h>
#include <time.h>
#include <sys/types.h>
#include <sys/param.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <net/if.h>
#include <netinet/in.h>
#include <arpa/inet.h>

/*============================================================================*
 * 定数定義
 *============================================================================*/

#ifndef OSIOCGIFADDR
#define	OSIOCGIFADDR			_IOWR('i', 13, struct ifreq)
#endif

#define MAX_INTERFACE			20
#define MY_NAME_BUF				256
#define PACKET_NO_BUF			64
#define RETRY_INTERVAL			2.0
#define RETRY_MAX				3


#if 0
#define IFR_NEXT(ifr)	\
    ((struct ifreq *) ((char *) (ifr) + sizeof(*(ifr)) + \
      MAX(0, (int) (ifr)->ifr_addr.sa_len - (int) sizeof((ifr)->ifr_addr))))
#endif

/*============================================================================*
 * グローバル変数
 *============================================================================*/
 
static BOOL valid = NO;

/*============================================================================*
 * プライベートメソッド（カテゴリ）
 *============================================================================*/
 
@interface MessageCenter(Private)

@end

/*============================================================================*
 * クラス実装
 *============================================================================*/

@implementation MessageCenter

/*----------------------------------------------------------------------------*
 * ファクトリ
 *----------------------------------------------------------------------------*/

// 共有インスタンスを返す
+ (MessageCenter*)sharedCenter {
	static MessageCenter* sharedCenter = nil;
	if (!sharedCenter) {
		sharedCenter = [[MessageCenter alloc] init];
	}
	return sharedCenter;
}

+ (long)nextMessageID {
	static long messageID	= 0;
	/*
	long		work		= (long)([[NSDate date] timeIntervalSinceReferenceDate] * 100);
	if (messageID == work) {
		work++;
	}
	messageID = work;
	*/
	return ++messageID;
}

/*----------------------------------------------------------------------------*
 * 内部利用
 *----------------------------------------------------------------------------*/

// 自ホストIPアドレスを取得する
static unsigned long getInterfaceAddress(int sock) {

	struct ifconf	ifc;					// NIC情報取得用
	struct ifreq	reqBuf[MAX_INTERFACE];	// NIC情報格納領域
	struct ifreq*	linkIF;					// ワーク
	unsigned long	address = 0;			// アドレス

//testAddr();

	// インターフェイス一覧を獲得
	ifc.ifc_len = sizeof(reqBuf);
	ifc.ifc_buf = (caddr_t)reqBuf;
	if (ioctl(sock, SIOCGIFCONF, &ifc) != 0) {
		ERR0(@"interface address get error.");
		return address;
	}
	
	linkIF = (struct ifreq*)ifc.ifc_buf;
	while ((char*)linkIF < &ifc.ifc_buf[ifc.ifc_len]) {
		if (address) {
			break;
		}
		// AF_LINKのインターフェイスを検索
		if (linkIF->ifr_addr.sa_family == AF_LINK) {
			// "en"で始まるインターフェイスのみ対象
			if (strncmp(linkIF->ifr_name, "en", 2) == 0) {
				struct ifreq* inetIF = (struct ifreq*)ifc.ifc_buf;
				while ((char *)inetIF < &ifc.ifc_buf[ifc.ifc_len]) {
					if (address) {
						break;
					}
					// AF_INETのインターフェイスを検索
					if (inetIF->ifr_addr.sa_family == AF_INET) {
						// AF_LINK かつ AF_INET のインターフェイスを特定
						if (strcmp(inetIF->ifr_name, linkIF->ifr_name) == 0) {
							struct ifreq ifr;
							strcpy(ifr.ifr_name, linkIF->ifr_name);
							if (ioctl(sock, OSIOCGIFADDR, (caddr_t)&ifr) < 0) {
								// インターフェイス情報取得エラー（通常ありえない）
								ERR1(@"interface(%s) get info error.", ifr.ifr_name);
							} else {
								struct sockaddr_in*	sin = (struct sockaddr_in *)&ifr.ifr_addr;
							//	DBG3(@"getInterfaceAddress:interface(%s):address=%s(0x%08X)", ifr.ifr_name,
							//					inet_ntoa(sin->sin_addr), sin->sin_addr.s_addr);
								address = ntohl(sin->sin_addr.s_addr);
							}
						}
					}
					inetIF = (struct ifreq*)((char*)inetIF + _SIZEOF_ADDR_IFREQ(*inetIF));
				}
			}
		}
		linkIF = (struct ifreq*)((char*)linkIF + _SIZEOF_ADDR_IFREQ(*linkIF));
	}
	
	return address;
}

/*----------------------------------------------------------------------------*
 * 初期化／解放
 *----------------------------------------------------------------------------*/

// 初期化
- (id)init {

	int					sockopt	= 1;		// ソケットオプション（ブロードキャスト許可）
	struct sockaddr_in	addr;				// バインド用アドレス
	Config*				config	= [Config sharedConfig];
	
	self			= [super init];
	localAddr		= 0;
	sockLock		= [[NSLock alloc] init];
	portNo			= [config portNo];
	sendList		= [[NSMutableDictionary alloc] init];
	valid			= FALSE;
	sockUDP			= -1;
	connection		= nil;
	if (portNo <= 0) {
		portNo = IPMSG_DEFAULT_PORT;
	}
	
	// 乱数初期化
	srand(time(NULL));
	
	// ソケットオープン
	if ((sockUDP = socket(AF_INET, SOCK_DGRAM, 0)) == -1) {
		// Dockアイコンバウンド
		[NSApp requestUserAttention:NSCriticalRequest];
		// エラーダイアログ表示
		NSRunCriticalAlertPanel(NSLocalizedString(@"Err.UDPSocketOpen.title", nil),
								NSLocalizedString(@"Err.UDPSocketOpen.msg", nil),
								@"OK", nil, nil);
		// プログラム終了
		[NSApp terminate:self];
		[self autorelease];
		return nil;
	}

	// ソケットバインドアドレスの用意
	memset(&addr, 0, sizeof(addr));
	addr.sin_family			= AF_INET;
	addr.sin_addr.s_addr	= htonl(INADDR_ANY);
	addr.sin_port			= htons(portNo);

	// ソケットバインド
	while (bind(sockUDP, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
		int result;
		// Dockアイコンバウンド
		[NSApp requestUserAttention:NSCriticalRequest];
		// エラーダイアログ表示
		result = NSRunCriticalAlertPanel(
							NSLocalizedString(@"Err.UDPSocketBind.title", nil),
							NSLocalizedString(@"Err.UDPSocketBind.msg", nil),
							NSLocalizedString(@"Err.UDPSocketBind.ok", nil),
							nil,
							NSLocalizedString(@"Err.UDPSocketBind.alt", nil),
							portNo);
		if (result == NSOKButton) {
			// プログラム終了
			[NSApp terminate:self];
			[self autorelease];
			return nil;
		}
		[[[PortChangeControl alloc] init] autorelease];
		portNo			= [config portNo];
		addr.sin_port	= htons(portNo);
	}

	// ブロードキャスト許可設定
	sockopt = 1;
	setsockopt(sockUDP, SOL_SOCKET, SO_BROADCAST, &sockopt, sizeof(sockopt));
	// バッファサイズ設定
	sockopt = MAX_SOCKBUF;
	setsockopt(sockUDP, SOL_SOCKET, SO_SNDBUF, &sockopt, sizeof(sockopt));
	setsockopt(sockUDP, SOL_SOCKET, SO_RCVBUF, &sockopt, sizeof(sockopt));
	
	// ローカルアドレスの取得
	localAddr = getInterfaceAddress(sockUDP);
	if (!localAddr) {
		// Dockアイコンバウンド
		[NSApp requestUserAttention:NSCriticalRequest];
		// エラーダイアログ表示
		NSRunCriticalAlertPanel(NSLocalizedString(@"Err.NetCheck.title", nil),
								NSLocalizedString(@"Err.NetCheck.msg", nil),
								@"OK", nil, nil);
	}
	
	// 受信スレッド起動
	{
		NSPort*			port1	= [NSPort port];
		NSPort*			port2	= [NSPort port];
		NSArray*		array	= [NSArray arrayWithObjects:port2, port1, nil];
		connection = [[NSConnection alloc] initWithReceivePort:port1 sendPort:port2];
		[connection setRootObject:self];
		[NSThread detachNewThreadSelector:@selector(serverThread:) toTarget:self withObject:array];
	}
	valid = YES;

	return self;
}

// 解放
-(void)dealloc {
	[handle release];
	[sockLock release];
	[sendList release];
	[connection release];
	if (sockUDP != -1) {
		close(sockUDP);
	}
	[super dealloc];
}

/*----------------------------------------------------------------------------*
 * プライベート使用
 *----------------------------------------------------------------------------*/

// ログインユーザ名
static NSString* loginUser() {
	static NSString* loginUserName = nil;
	if (!loginUserName) {
		loginUserName = NSUserName();
	}
	return loginUserName;
}

// メンバ認識系パケットで使用する起動ユーザのユーザ名／グループ名文字列の編集
static void myName(char* nameBuf, char* groupBuf) {
	Config* 	config	= [Config sharedConfig];
	NSString*	user	= [config userName];
#ifdef IPMSG_DEBUG
	// 開発中(developmentビルド)はグループ名をバージョン番号にしてしまう
	NSString*	group	= [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
#else
	NSString*	group	= [config groupName];
#endif
	NSString*	absence	= @"";

	nameBuf[0]	= '\0';
	groupBuf[0]	= '\0';
	
	if (!user) {
		user = loginUser();
	} else if ([user length] <= 0) {
		user = loginUser();
	}
	if (group) {
		if ([group length] <= 0) {
			group = nil;
		}
	}
	if ([config isAbsence]) {
		absence = [config absenceTitleAtIndex:[config absenceIndex]];
	}

	if ([config isAbsence]) {
		sprintf(nameBuf, "%s[%s]", [user ipmsgCString], [absence ipmsgCString]);
	} else {
		strcpy(nameBuf, [user ipmsgCString]);
	}
	
	if (group) {
		strcpy(groupBuf, [group ipmsgCString]);
	}
	
	return;
}

// データ送信実処理
- (int)sendTo:(struct sockaddr_in*)toAddr messageID:(long)mid command:(long)cmd data:(char*)data option:(char*)opt {
	Config*	config = [Config sharedConfig];
	char	buffer[MAX_SOCKBUF];
	int		len;
	int		dataLen	= (data) ? strlen(data) : 0;
	int		optLen	= (opt) ? strlen(opt) : 0; 
	
	// 不在モードチェック
	if ([config isAbsence]) {
		cmd |= IPMSG_ABSENCEOPT;
	}
	// ダイアルアップチェック
	if ([config dialup]) {
		cmd |= IPMSG_DIALUPOPT;
	}
	
	[sockLock lock];	// ソケットロック
	
	// メッセージID採番
	mid = (mid < 0) ? [MessageCenter nextMessageID] : mid;
	
	// メッセージヘッダ部編集
	memset(buffer, 0, sizeof(buffer));
	sprintf(buffer, "%d:%ld:%s:%s:%ld:",
						IPMSG_VERSION,
						mid,
						[loginUser() ipmsgCString],
						[[config machineName] ipmsgCString],
						cmd);
	len = strlen(buffer);
	
	// パケットサイズあふれ調整
	if (len + dataLen + optLen > sizeof(buffer) - 1) {
		// メッセージ本文を削る
		dataLen = sizeof(buffer) - 1 - len - optLen;
	}
	if (dataLen >= 0) {
		// メッセージ本文設定
		if (dataLen > 0) {
			strncpy(&buffer[len], data, dataLen);
			len += dataLen;
		}
		// 追加部設定（メッセージ本文との間に'\0'が必要）
		if (optLen > 0) {
			strncpy(&buffer[len + 1], opt, optLen);
			len += (optLen + 1);
		}
		// 送信
		sendto(sockUDP, buffer, len + 1, 0, (struct sockaddr*)toAddr, sizeof(struct sockaddr_in));
	} else {
		ERR3(@"buffer overflow.(len=%d,dataLen=%d,optLen=%d)", len, dataLen, optLen);
		mid = -1;
	}
	
	[sockLock unlock];	// ロック解除

	return mid;
}

- (int)sendTo:(struct sockaddr_in*)toAddr messageID:(int)mid command:(int)cmd {
	return [self sendTo:toAddr messageID:mid command:cmd data:NULL option:NULL];
}

- (int)sendTo:(struct sockaddr_in*)toAddr messageID:(int)mid command:(int)cmd data:(char*)data {
	return [self sendTo:toAddr messageID:mid command:cmd data:data option:NULL];
}

- (int)sendTo:(struct sockaddr_in*)toAddr messageID:(int)mid command:(int)cmd numberData:(int)data {
	char buf[32];
	sprintf(buf, "%d", data);
	return [self sendTo:toAddr messageID:mid command:cmd data:buf option:NULL];
}

// ブロードキャスト送信処理
- (void)sendBroadcast:(int)cmd data:(char*)data option:(char*)opt {
	struct sockaddr_in	bcast;		// ブロードキャストアドレス
	NSMutableSet*		castSet;	// 個別ブロードキャストアドレス一覧
	NSEnumerator*		castEnum;	// 個別ブロードキャスト列挙
	NSString*			address;	// 個別ブロードキャストアドレス
	
	memset(&bcast, 0, sizeof(bcast));
	bcast.sin_family		= AF_INET;
	bcast.sin_port			= htons(portNo);

	// ブロードキャスト（ローカル）アドレスの送信
	bcast.sin_addr.s_addr	= htonl(INADDR_BROADCAST);
	[self sendTo:&bcast messageID:-1 command:cmd data:data option:opt];
	
	// 個別ブロードキャストアドレス一覧作成
	castSet = [[[NSMutableSet alloc] init] autorelease];
	[castSet addObjectsFromArray:[[Config sharedConfig] broadcastAddresses]];
	[castSet addObjectsFromArray:[[UserManager sharedManager] dialupAddresses]];
	
	// 個別ブロードキャストの送信
	castEnum = [castSet objectEnumerator];
	while ((address = [castEnum nextObject])) {
		unsigned long	inetaddr = inet_addr([address UTF8String]);
		if (inetaddr != INADDR_NONE) {
			bcast.sin_addr.s_addr = inetaddr;
			[self sendTo:&bcast messageID:-1 command:cmd data:data option:opt];
		}
	}
}

// 全ユーザに送信
- (void)sendAllUsers:(int)cmd data:(char*)data option:(char*)opt {
	UserManager*		mgr;	// ユーザマネージャ
	int					num;	// ユーザ数
	struct sockaddr_in	to;		// 送信先アドレス
	int					i;		// カウンタ
	
	mgr	= [UserManager sharedManager];
	num = [mgr numberOfUsers];
	to.sin_family	= AF_INET;
	for (i = 0; i < num; i++) {
		UserInfo*		user	= [mgr userAtIndex:i];
		unsigned long	addr	= [user addressNumber];
		if (addr != INADDR_NONE) {
			to.sin_addr.s_addr	= htonl([user addressNumber]);
			to.sin_port			= htons([user portNo]);
			[self sendTo:&to messageID:-1 command:cmd data:data option:opt];
		}
	}
}
	
/*----------------------------------------------------------------------------*
 * メッセージ送信（ブロードキャスト）
 *----------------------------------------------------------------------------*/

// BR_ENTRYのブロードキャスト
- (void)broadcastEntry {
	char name[MY_NAME_BUF];
	char group[MY_NAME_BUF];
	UserInfo* user = [self localUser];
	myName(name, group);
	[self sendBroadcast:IPMSG_NOOPERATION data:NULL option:NULL];
	[self sendBroadcast:IPMSG_BR_ENTRY|IPMSG_FILEATTACHOPT data:name option:group];
	// 自分をユーザ一覧に追加（とれないことがあるため）
	if (![[Config sharedConfig] refuseUser:user]) {
		[[UserManager sharedManager] appendUser:user];
	}
	DBG2(@"broadcast entry(%s:%s).", name, group);
}

// BR_ABSENCEのブロードキャスト
- (void)broadcastAbsence {
	char name[MY_NAME_BUF];
	char group[MY_NAME_BUF];
	myName(name, group);
	[self sendAllUsers:IPMSG_BR_ABSENCE|IPMSG_FILEATTACHOPT data:name option:group];
	DBG2(@"broadcast absence(%s:%s).", name, group);
}

// BR_EXITをブロードキャスト
- (void)broadcastExit {
	char name[MY_NAME_BUF];
	char group[MY_NAME_BUF];
	myName(name, group);
	[self sendBroadcast:IPMSG_BR_EXIT data:name option:group];
	DBG0(@"broadcast exit.");
}

/*----------------------------------------------------------------------------*
 * メッセージ送信（通常）
 *----------------------------------------------------------------------------*/

// 通常メッセージの送信
- (void)sendMessage:(SendMessage*)msg to:(NSArray*)toUsers {
	int					i;
	struct sockaddr_in	to;
	unsigned int		command	= IPMSG_SENDMSG | IPMSG_SENDCHECKOPT;
	NSArray*			attach	= [msg attachments];
	int					num		= [toUsers count];
	char				msgBuf[MAX_SOCKBUF];
	char				attachBuf[MAX_SOCKBUF];
	NSData*				body;
	NSData*				opt;

	// メッセージ編集
	strncpy(msgBuf, [[msg message] ipmsgCString], MAX_SOCKBUF - 1);
	// 添付ファイル追加
	attachBuf[0] = '\0';
	if ([attach count] > 0) {
		AttachmentServer*	attachManager	= [AttachmentServer sharedServer];
		NSNumber*			messageID		= [NSNumber numberWithInt:[msg packetNo]];
		char*				work			= &attachBuf[0];
		command	|= IPMSG_FILEATTACHOPT;
		for (i = 0; i < [attach count]; i++) {
			Attachment* info = [attach objectAtIndex:i];
			[info setFileID:i];
			sprintf(work, "%s%c",
				[[[info file] stringForMessageAttachment:[[info fileID] intValue]] ipmsgCString],
				FILELIST_SEPARATOR);
			work += strlen(work);
			[attachManager addAttachment:info messageID:messageID];
		}
	}
	
	// コマンドの決定
	if (num > 1) {
		command |= IPMSG_MULTICASTOPT;
	}
	if ([msg sealed]) {
		command |= IPMSG_SECRETOPT;
		if ([msg locked]) {
			command |= IPMSG_PASSWORDOPT;
		}
	}

	body	= [[[NSData alloc] initWithBytes:msgBuf length:strlen(msgBuf) + 1] autorelease];
	opt		= [[[NSData alloc] initWithBytes:attachBuf length:strlen(attachBuf) + 1] autorelease];
	// 各ユーザに送信
	for (i = 0; i < num; i++) {
		UserInfo* info = [toUsers objectAtIndex:i];
		if (info) {
			int			mid;
			RetryInfo*	retryInfo;
			memset(&to, 0, sizeof(to));
			to.sin_family		= AF_INET;
			to.sin_addr.s_addr	= htonl([info addressNumber]);
			to.sin_port			= htons([info portNo]);
			// 送信
			if (([attach count] > 0) && [info attachmentSupport]) {
				mid = [self sendTo:&to messageID:[msg packetNo]
										 command:command|IPMSG_FILEATTACHOPT
											data:msgBuf
										  option:attachBuf];
				[[AttachmentServer sharedServer] addUser:info messageID:[NSNumber numberWithInt:mid]];
			} else {
				mid = [self sendTo:&to messageID:[msg packetNo] command:command data:msgBuf];
			}
			// 応答待ちメッセージ一覧に追加
			retryInfo = [[RetryInfo alloc] initWithCommand:command to:info message:body attach:opt];
			[sendList setObject:retryInfo forKey:[NSNumber numberWithInt:mid]];
			// タイマ発行
			[NSTimer scheduledTimerWithTimeInterval:RETRY_INTERVAL
											 target:self
										   selector:@selector(retryMessage:)
										   userInfo:[NSNumber numberWithInt:mid]
											repeats:YES];
		}
	}
}

// 応答タイムアウト時処理
- (void)retryMessage:(NSTimer*)timer {
	NSNumber*	msgid		= [timer userInfo];
	RetryInfo*	retryInfo	= [sendList objectForKey:msgid];
	if (retryInfo) {
		UserInfo*			user;
		unsigned int		command;
		struct sockaddr_in	to;
		char*				message;
		char*				attach;
		if ([retryInfo retryCount] >= RETRY_MAX) {
			int ret = NSRunCriticalAlertPanel(
							NSLocalizedString(@"Send.Retry.Title", nil),
							NSLocalizedString(@"Send.Retry.Msg", nil),
							NSLocalizedString(@"Send.Retry.OK", nil),
							NSLocalizedString(@"Send.Retry.Cancel", nil),
							nil, [[retryInfo toUser] user]);
			if (ret == NSAlertAlternateReturn) {
				// 再送キャンセル
				// 応答待ちメッセージ一覧からメッセージのエントリを削除
				[sendList removeObjectForKey:msgid];
				// 添付情報破棄
				[[AttachmentServer sharedServer] removeAttachmentsByMessageID:msgid needLock:YES clearTimer:YES];
				// タイマ解除
				[timer invalidate];
				return;
			}
			[retryInfo resetRetryCount];
		}
		user	= [retryInfo toUser];
		command = [retryInfo command];
		message	= (char*)[[retryInfo messageBody] bytes];
		attach	= (char*)[[retryInfo attachMessage] bytes];
		// ユーザに送信
		memset(&to, 0, sizeof(to));
		to.sin_family		= AF_INET;
		to.sin_addr.s_addr	= htonl([user addressNumber]);
		to.sin_port			= htons([user portNo]);
		// 送信
		[self sendTo:&to messageID:[msgid intValue] command:command data:message option:attach];
		[retryInfo upRetryCount];
	} else {
		// タイマ解除
		[timer invalidate];
	}
}

// 封書開封通知を送信
- (void)sendOpenSealMessage:(RecvMessage*)info {
	if (info) {
		// 送信
		[self sendTo:[info fromAddress] messageID:-1 command:IPMSG_READMSG numberData:[info packetNo]];
	}
}

// 添付破棄通知を送信
- (void)sendReleaseAttachmentMessage:(RecvMessage*)info {
	if (info) {
		// 送信
		[self sendTo:[info fromAddress] messageID:-1 command:IPMSG_RELEASEFILES numberData:[info packetNo]];
	}
}

// 一定時間後にENTRY応答を送信
- (void)sendAnsEntryAfter:(NSTimeInterval)aSecond to:(UserInfo*)toUser {
	[NSTimer scheduledTimerWithTimeInterval:aSecond target:self selector:@selector(sendAnsEntry:) userInfo:toUser repeats:NO];
}

- (void)sendAnsEntry:(NSTimer*)aTimer {
	struct sockaddr_in	to;					// 送信先アドレス
	char				name[MY_NAME_BUF];
	char				group[MY_NAME_BUF];
	UserInfo*			user = [aTimer userInfo];
		
	// メッセージ準備
	memset(&to, 0, sizeof(to));
	to.sin_family		= AF_INET;
	to.sin_addr.s_addr	= htonl([user addressNumber]);
	to.sin_port			= htons([user portNo]);

	// 送信
	myName(name, group);
	[self sendTo:&to messageID:-1 command:IPMSG_ANSENTRY|IPMSG_FILEATTACHOPT data:name option:group];
}

/*----------------------------------------------------------------------------*
 * メッセージ受信
 *----------------------------------------------------------------------------*/

// 受信後実処理
- (void)processReceiveMessage {
	Config*				config	= nil;
	RecvMessage*		msg		= nil;
	static char*		version	= NULL;
	unsigned long		command;
	UserInfo*			fromUser;
	struct sockaddr_in*	from;
	int					packetNo;
	NSString*			appendix;
	char				buff[MAX_SOCKBUF];	// 受信バッファ
	int					len;
	struct sockaddr_in	addr;
	socklen_t			addrLen = sizeof(addr);
	
	// 受信
	len = recvfrom(sockUDP, buff, MAX_SOCKBUF, 0, (struct sockaddr*)&addr, &addrLen);
	if (len == -1) {
		ERR1(@"processReceiveMessage:recvFrom error(sock=%d)", sockUDP);
		return;
	}
	// 解析
	msg = [RecvMessage messageWithBuffer:buff length:len from:&addr];
	if (!msg) {
		ERR1(@"Receive Buffer parse error(%s)", buff);
		return;
	}
	
	command		= [msg command];
	fromUser	= [msg fromUser];
	from		= [msg fromAddress];
	packetNo	= [msg packetNo];
	appendix	= [msg appendix];
	config		= [Config sharedConfig];
	
	// 受信メッセージに応じた処理
	switch (GET_MODE(command)) {
	/*-------- 無処理メッセージ ---------*/
	case IPMSG_NOOPERATION:
		// NOP
		break;
	/*-------- ユーザエントリ系メッセージ ---------*/
	case IPMSG_BR_ENTRY:
	case IPMSG_ANSENTRY:
	case IPMSG_BR_ABSENCE:
		if ([config refuseUser:fromUser]) {
			// 通知拒否ユーザにはBR_EXITを送って相手からみえなくする
			char name[MY_NAME_BUF];
			char group[MY_NAME_BUF];
			myName(name, group);
			[self sendTo:from messageID:-1 command:IPMSG_BR_EXIT data:name option:group];
		} else {
			if (GET_MODE(command) == IPMSG_BR_ENTRY) {
				if (ntohl(from->sin_addr.s_addr) != localAddr) {
					// 応答を送信（自分自身以外）
					NSTimeInterval	second	= 0.5;
					int				userNum	= [[UserManager sharedManager] numberOfUsers];
					if ((userNum < 50) || ((localAddr ^ htonl(from->sin_addr.s_addr) << 8) == 0)) {
						// ユーザ数50人以下またはアドレス上位24bitが同じ場合 0 〜 1023 ms
						second = (1023 & rand()) / 1024.0;
					} else if (userNum < 300) {
						// ユーザ数が300人以下なら 0 〜 2047 ms
						second = (2047 & rand()) / 2048.0;
					} else {
						// それ以上は 0 〜 4095 ms
						second = (4095 & rand()) / 4096.0;
					}
					[self sendAnsEntryAfter:second to:fromUser];
				}
			}
			// ユーザ一覧に追加
			[[UserManager sharedManager] appendUser:fromUser];
			// バージョン情報問い合わせ
			[self sendTo:from messageID:-1 command:IPMSG_GETINFO];
		}
		break;
	case IPMSG_BR_EXIT:
		// ユーザ一覧から削除
		[[UserManager sharedManager] removeUser:fromUser];
		// 添付ファイルを削除
		[[AttachmentServer sharedServer] removeUser:fromUser];
		break;
	/*-------- ホストリスト関連 ---------*/
	case IPMSG_BR_ISGETLIST:
	case IPMSG_OKGETLIST:
	case IPMSG_GETLIST:
	case IPMSG_BR_ISGETLIST2:
		// NOP
		break;
	case IPMSG_ANSLIST:
//		DBG1(@"ANSLIST(%@)", fromUser);
		if ([msg hostList]) {
			UserManager*	userManager	= [UserManager sharedManager];
			NSArray*		userArray	= [msg hostList];
			int				i;
			for (i = 0; i < [userArray count]; i++) {
				UserInfo* newUser = [userArray objectAtIndex:i];
				if (![config refuseUser:newUser]) {
//					DBG1(@"append user from hostlist(%@)", newUser);
					[userManager appendUser:newUser];
				}
			}
		}
		if ([msg hostListContinueCount] > 0) {
			// 継続のGETLIST送信
			[self sendTo:from messageID:-1 command:IPMSG_GETLIST numberData:[msg hostListContinueCount]];
		} else {
			// BR_ENTRY送信（受信したホストに教えるため）
			[self broadcastEntry];
		}
		break;
	/*-------- メッセージ関連 ---------*/
	case IPMSG_SENDMSG:		// メッセージ送信パケット
		if ((command & IPMSG_SENDCHECKOPT) && !(command & IPMSG_AUTORETOPT) && !(command & IPMSG_BROADCASTOPT)) {
			// RCVMSGを返す
			[self sendTo:from messageID:-1 command:IPMSG_RECVMSG numberData:packetNo];
		}
		if ([config isAbsence] && !(command & IPMSG_AUTORETOPT) && !(command & IPMSG_BROADCASTOPT)) {
			// 不在応答を返す
			char* msg = (char*)[[config absenceMessageAtIndex:[config absenceIndex]] ipmsgCString];
			[self sendTo:from messageID:-1 command:IPMSG_SENDMSG|IPMSG_AUTORETOPT data:msg];
		}
		if ([msg isUnknownUser]) {
			// ユーザエントリ系メッセージをやりとりしていないユーザからの受信
			if ((command & IPMSG_NOADDLISTOPT) == 0) {
				// リストに追加するためにENTRYパケット送信
				char name[MY_NAME_BUF];
				char group[MY_NAME_BUF];
				myName(name, group);
				[self sendTo:from messageID:-1 command:IPMSG_BR_ENTRY data:name option:group];
			}
		}
		[[NSApp delegate] receiveMessage:msg];
		break;
	case IPMSG_RECVMSG:		// メッセージ受信確認パケット
		// 応答待ちメッセージ一覧から受信したメッセージのエントリを削除
		[sendList removeObjectForKey:[NSNumber numberWithInt:[appendix intValue]]];
		break;
	case IPMSG_READMSG:		// 封書開封通知パケット
		if (command & IPMSG_READCHECKOPT) {
			// READMSG受信確認通知をとばす
			[self sendTo:from messageID:-1 command:IPMSG_ANSREADMSG numberData:packetNo];
		}
		if ([config noticeSealOpened]) {
			// 封書が開封されたダイアログを表示
			[[NoticeControl alloc] initWithTitle:NSLocalizedString(@"SealOpenDlg.title", nil)
										 message:[fromUser summeryString]
											date:nil];
		}
		break;
	case IPMSG_DELMSG:		// 封書破棄通知パケット
		// 無処理
		break;
	case IPMSG_ANSREADMSG:
		// READMSGの確認通知。やるべきことは特になし
		break;
	/*-------- 情報取得関連 ---------*/
	case IPMSG_GETINFO:		// 情報取得要求
		// バージョン情報のパケットを返す
		if (!version) {
			// なければ編集
			id			ver	= [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
			NSString*	msg	= [NSString stringWithFormat:NSLocalizedString(@"Version.Msg.string", nil), ver];
			const char*	str = [msg ipmsgCString];
			version	= malloc(strlen(str) + 1);
			strcpy(version, str);
		}
		[self sendTo:from messageID:-1 command:IPMSG_SENDINFO data:version];
		break;
	case IPMSG_SENDINFO:	// バージョン情報
		// バージョン情報をユーザ情報に設定
		[fromUser setVersion:appendix];
		DBG3(@"%@:%@ = %@", [fromUser logOnUser], [fromUser host], appendix);
		break;
	/*-------- 不在関連 ---------*/
	case IPMSG_GETABSENCEINFO:
		// 不在文のパケットを返す
		if ([config isAbsence]) {
			NSString* msg = [config absenceMessageAtIndex:[config absenceIndex]];
			[self sendTo:from messageID:-1 command:IPMSG_SENDABSENCEINFO data:(char*)[msg ipmsgCString]];
		} else {
			[self sendTo:from messageID:-1 command:IPMSG_SENDABSENCEINFO data:"Not Absence Mode."];
		}
		break;
	case IPMSG_SENDABSENCEINFO:
		// 不在情報をダイアログに出す
		[[NoticeControl alloc] initWithTitle:[fromUser summeryString] message:appendix date:nil];
		break;
	/*-------- 添付関連 ---------*/
	case IPMSG_RELEASEFILES:	// 添付破棄通知
		[[AttachmentServer sharedServer] removeUser:fromUser messageID:[NSNumber numberWithInt:[appendix intValue]]];
		break;
	/*-------- 暗号化関連 ---------*/
	case IPMSG_GETPUBKEY:		// 公開鍵要求
		DBG1(@"IPMSG_GETPUBKEY:%@", appendix);
		break;
	case IPMSG_ANSPUBKEY:
		DBG1(@"IPMSG_ANSPUBKEY:%@", appendix);
		break;
	/*-------- その他パケット／未知パケット（を受信） ---------*/
	default:
		ERR1(@"Unknown Message Received(%@)", msg);
		break;
	}

//	return FALSE;
}

// メッセージ受信スレッド
- (void)serverThread:(NSArray*)portArray {
	NSAutoreleasePool*	pool = [[NSAutoreleasePool alloc] init];
	fd_set				fdSet;
	struct timeval		tv;
	int					ret;
	BOOL				shutdown = NO;
	NSConnection*		conn = [[NSConnection alloc] initWithReceivePort:[portArray objectAtIndex:0]
																sendPort:[portArray objectAtIndex:1]];
	id					proxy = [conn rootProxy];
	DBG0(@"MsgReceiveThread start.");
	while (!shutdown) {
		FD_ZERO(&fdSet);
		FD_SET(sockUDP, &fdSet);
		tv.tv_sec	= 1;
		tv.tv_usec	= 0;
		ret = select(sockUDP + 1, &fdSet, NULL, NULL, &tv);
		if (ret < 0) {
			ERR1(@"serverThread:select error(%d)", ret);
			continue;
		}
		if (ret == 0) {
			// タイムアウト
			continue;
		}
		[proxy processReceiveMessage];
	}
	DBG0(@"MsgReceiveThread end.");

	[conn release];
	[pool release];
}

/*----------------------------------------------------------------------------*
 * その他
 *----------------------------------------------------------------------------*/

+ (BOOL)valid {
	return valid;
}

- (int)portNo {
	return portNo;
}

- (UserInfo*)localUser {
	static UserInfo* localUser = nil;
	if (!localUser && localAddr) {
		Config* config = [Config sharedConfig];
		char	name[MY_NAME_BUF];
		char	group[MY_NAME_BUF];
		struct sockaddr_in	addr;
		
		addr.sin_addr.s_addr = htonl(localAddr);
		myName(name, group);
		localUser = [[UserInfo alloc] initWithUser:[NSString stringWithCString:name]
											 group:[NSString stringWithCString:group]
										   address:[NSString stringWithCString:inet_ntoa(addr.sin_addr)]
											port:portNo
										   machine:[config machineName]
											 logOn:loginUser()
										   absence:[config isAbsence]
											dialup:[config dialup]
										attachment:YES
										   encrypt:NO];
	}
	return localUser;
}

/*----------------------------------------------------------------------------*
 * メッセージ解析関連
 *----------------------------------------------------------------------------*/
 
// 受信Rawデータの分解
+ (BOOL)parseReceiveData:(char*)buffer length:(int)len into:(IPMsgData*)data {
	char* work	= buffer;
	char* ptr	= buffer;
	if (!buffer || !data || (len <= 0)) {
		return NO;
	}
	
	// バージョン番号
	data->version = strtoul(ptr, &work, 16);
	if (*work != ':') {
		return NO;
	}
	ptr = work + 1;
	
	// パケット番号
	data->packetNo = strtoul(ptr, &work, 16);
	if (*work != ':') {
		return NO;
	}
	ptr = work + 1;
	
	// ログインユーザ名
	work = strchr(ptr, ':');
	if (!work) {
		return NO;
	}
	*work = '\0';
	strncpy(data->userName, ptr, sizeof(data->userName) - 1);
	ptr = work + 1;
	
	// ホスト名
	work = strchr(ptr, ':');
	if (!work) {
		return NO;
	}
	*work = '\0';
	strncpy(data->hostName, ptr, sizeof(data->hostName) - 1);
	ptr = work + 1;
	
	// コマンド番号
	data->command = strtoul(ptr, &work, 10);
	if (*work != ':') {
		return NO;
	}
	ptr = work + 1;
	
	// 拡張部
	strncpy(data->extension, ptr, sizeof(data->extension) - 1);
	
	return YES;
}


@end
