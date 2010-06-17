/*============================================================================*
 * (C) 2001-2009 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for MacOS X
 *	File		: Config.m
 *	Module		: 初期設定情報管理クラス		
 *============================================================================*/

#import <Cocoa/Cocoa.h>
#import "Config.h"
#import "RefuseInfo.h"
#import "DebugLog.h"

#include <netinet/in.h>
#include <arpa/inet.h>

/*============================================================================*
 * 定数定義
 *============================================================================*/


// 基本
static NSString* GEN_VERSION			= @"Version";
static NSString* GEN_USER_NAME			= @"UserName";
static NSString* GEN_GROUP_NAME			= @"GroupName";
static NSString* GEN_PASSWORD			= @"UserPassword";
static NSString* GEN_MACHINENAME_TYPE	= @"MachineNameType";
static NSString* GEN_HOSTDOMAIN_DEL		= @"RemoveDomainFromHostName";
static NSString* GEN_USE_STATUS_BAR		= @"UseStatusBarMenu";

// ネットワーク
static NSString* NET_PORT_NO			= @"PortNo";
static NSString* NET_BROADCAST			= @"Broadcast";
static NSString* NET_DIALUP				= @"Dialup";

// 送信
static NSString* SEND_QUOT_STR			= @"QuotationString";
static NSString* SEND_DOCK_SEND			= @"OpenSendWindowWhenDockClick";
static NSString* SEND_SEAL_CHECK		= @"SealCheckDefaultOn";
static NSString* SEND_HIDE_REPLY		= @"HideRecieveWindowWhenSendReply";
static NSString* SEND_OPENSEAL_CHECK	= @"CheckSealOpened";
static NSString* SEND_ALL_USER_CHECK	= @"ToAllUsersCheckEnabled";
static NSString* SEND_MULTI_USER_CHECK	= @"AllowSendingToMutipleUser";
static NSString* SEND_MSG_FONT_NAME		= @"SendMessageFontName";
static NSString* SEND_MSG_FONT_SIZE		= @"SendMessageFontSize";

// 受信
static NSString* RECV_SOUND				= @"ReceiveSound";
static NSString* RECV_QUOT_CHECK		= @"QuotCheckDefaultOn";
static NSString* RECV_NON_POPUP			= @"NonPopupReceive";
static NSString* RECV_ABSENCE_NONPOPUP	= @"NonPopupReceiveWhenAbsenceMode";
static NSString* RECV_BOUND_IN_NONPOPUP	= @"DockIconBoundInNonPopupReceive";
static NSString* RECV_CLICKABLE_URL		= @"UseClickableURL";
static NSString* RECV_MSG_FONT_NAME		= @"ReceiveMessageFontName";
static NSString* RECV_MSG_FONT_SIZE		= @"ReceiveMessageFontSize";

// 不在
static NSString* ABSENCE				= @"Absence";

// 通知拒否
static NSString* REFUSE					= @"RefuseCondition";

// ユーザリスト
static NSString* ULIST_DISP_LOGON		= @"DisplayLogOnName";
static NSString* ULIST_DISP_IP			= @"DisplayIPAddress";
static NSString* ULIST_SORT_RULE		= @"UserListSortRules";
static NSString* ULIST_IGNORE_CASE		= @"SortUserListWithIgnoreCase";
static NSString* ULIST_KANJI_PRIORITY	= @"GivePriorityToMultiByteCharacters";

// ログ
static NSString* LOG_STD_ON				= @"StandardLogEnabled";
static NSString* LOG_STD_CHAIN			= @"StandardLogWhenLockedMessageOpened";
static NSString* LOG_STD_FILE			= @"StandardLogFile";
static NSString* LOG_ALT_ON				= @"AlternateLogEnabled";
static NSString* LOG_ALT_SELECTION		= @"AlternateLogWithSelectedRange";
static NSString* LOG_ALT_FILE			= @"AlternateLogFile";
static NSString* LOG_LINE_ENDING		= @"LogLineEnding";

// ウィンドウ位置／サイズ
static NSString* RCVWIN_SIZE_W			= @"ReceiveWindowWidth";
static NSString* RCVWIN_SIZE_H			= @"ReceiveWindowHeight";
static NSString* RCVWIN_POS_X			= @"ReceiveWindowOriginX";
static NSString* RCVWIN_POS_Y			= @"ReceiveWindowOriginY";
static NSString* SNDWIN_SIZE_W			= @"SendWindowWidth";
static NSString* SNDWIN_SIZE_H			= @"SendWindowHeight";
static NSString* SNDWIN_SIZE_SPLIT		= @"SendWindowSplitPoint";
static NSString* SNDWIN_POS_X			= @"SendWindowOriginX";
static NSString* SNDWIN_POS_Y			= @"SendWindowOriginY";

/*============================================================================*
 * クラス実装
 *============================================================================*/

@implementation Config

/*----------------------------------------------------------------------------*
 * ファクトリ
 *----------------------------------------------------------------------------*/
 
// 共有インスタンスを返す
+ (Config*)sharedConfig {
	static Config* sharedConfig = nil;
	if (!sharedConfig) {
		sharedConfig = [[Config alloc] init];
	}
	return sharedConfig;
}

/*----------------------------------------------------------------------------*
 * 内部利用
 *----------------------------------------------------------------------------*/

// ブロードキャスト対象アドレスリスト更新
- (void)updateBroadcastAddresses {
	int	i;
	if (broadcastAddresses) {
		[broadcastAddresses removeAllObjects];
	} else {
		broadcastAddresses = [[NSMutableArray alloc] init];
	}
	for (i = 0; i < [broadcastHostList count]; i++) {
		NSString* addr = [[NSHost hostWithName:[broadcastHostList objectAtIndex:i]] address];
		if (addr) {
			if (![broadcastAddresses containsObject:addr]) {
				[broadcastAddresses addObject:addr];
			}
		}
	}
	for (i = 0; i < [broadcastIPList count]; i++) {
		NSString* addr = [broadcastIPList objectAtIndex:i];
		if (![broadcastAddresses containsObject:addr]) {
			[broadcastAddresses addObject:addr];
		}
	}
}

// 通知拒否リスト変換
- (NSMutableArray*)convertRefuseDefaultsToInfo:(NSArray*)array {
	NSMutableArray* newArray = [[[NSMutableArray alloc] init] autorelease];
	if (array) {
		int	i;
		for (i = 0; i < [array count]; i++) {
			NSDictionary*		dic 			= (NSDictionary*)[array objectAtIndex:i];
			IPRefuseTarget		target			= 0;
			NSString*			targetStr		= [dic objectForKey:@"Target"];
			NSString*			string			= [dic objectForKey:@"String"];
			IPRefuseCondition	condition		= 0;
			NSString*			conditionStr	= [dic objectForKey:@"Condition"];
			if (!targetStr || !string || !conditionStr) {
				continue;
			}
			if ([targetStr isEqualToString:@"UserName"]) {			target = IP_REFUSE_USER;	}
			else if ([targetStr isEqualToString:@"GroupName"]) {	target = IP_REFUSE_GROUP;	}
			else if ([targetStr isEqualToString:@"MachineName"]) {	target = IP_REFUSE_MACHINE;	}
			else if ([targetStr isEqualToString:@"LogOnName"]) {	target = IP_REFUSE_LOGON;	}
			else if ([targetStr isEqualToString:@"IPAddress"]) {	target = IP_REFUSE_ADDRESS;	}
			else {
				WRN1(@"invalid refuse target(%@)", targetStr);
				continue;
			}
			if ([string length] <= 0) {
				continue;
			}
			if ([conditionStr isEqualToString:@"Match"]) {			condition = IP_REFUSE_MATCH;	}
			else if ([conditionStr isEqualToString:@"Contain"]) {	condition = IP_REFUSE_CONTAIN;	}
			else if ([conditionStr isEqualToString:@"Start"]) {		condition = IP_REFUSE_START;	}
			else if ([conditionStr isEqualToString:@"End"]) {		condition = IP_REFUSE_END;		}
			else {
				WRN1(@"invalid refuse condition(%@)", conditionStr);
				continue;
			}

			[newArray addObject:[[[RefuseInfo alloc] initWithTarget:target string:string condition:condition] autorelease]];
		}
	}
	return newArray;
}

- (NSMutableArray*)convertRefuseInfoToDefaults:(NSArray*)array {
	int				i;
	NSMutableArray* newArray = [[[NSMutableArray alloc] init] autorelease];
	for (i = 0; i < [array count]; i++) {
		RefuseInfo*				info		= (RefuseInfo*)[array objectAtIndex:i];
		NSMutableDictionary*	dict		= [[[NSMutableDictionary alloc] init] autorelease];
		NSString*				target		= nil;
		NSString*				condition	= nil;
		switch ([info target]) {
		case IP_REFUSE_USER:	target = @"UserName";		break;
		case IP_REFUSE_GROUP:	target = @"GroupName";		break;
		case IP_REFUSE_MACHINE:	target = @"MachineName";	break;
		case IP_REFUSE_LOGON:	target = @"LogOnName";		break;
		case IP_REFUSE_ADDRESS:	target = @"IPAddress";		break;
		default:
			WRN1(@"invalid refuse target(%d)", [info target]);
			continue;
		}
		switch ([info condition]) {
		case IP_REFUSE_MATCH:	condition = @"Match";		break;
		case IP_REFUSE_CONTAIN:	condition = @"Contain";		break;
		case IP_REFUSE_START:	condition = @"Start";		break;
		case IP_REFUSE_END:		condition = @"End";			break;
		default:
			WRN1(@"invalid refuse condition(%d)", [info condition]);
			continue;
		}
		[dict setObject:target			forKey:@"Target"];
		[dict setObject:[info string]	forKey:@"String"];
		[dict setObject:condition		forKey:@"Condition"];
		[newArray addObject:dict];
	}
	return newArray;
}

// AppleTalkホスト名を取得
static int hex2bin(char c) {
	switch (c) {
	case '0': case '1': case '2': case '3': case '4':
	case '5': case '6': case '7': case '8': case '9':
		return c - '0';
	case 'A': case 'B': case 'C': case 'D': case 'E': case 'F':
		return c - 'A' + 10;
	case 'a': case 'b': case 'c': case 'd': case 'e': case 'f':
		return c - 'a' + 10;
	default:
		return -1;
	}
}

- (NSString*)appleTalkHostname {
// 本来取得のためのAPIがあるはずだが、わからないため
// 暫定的処理として/etc/hostconfigを直接参照する
	if (!appleTalkHostname) {
		NSString*		string		= [NSString stringWithContentsOfFile:@"/etc/hostconfig"];
		NSArray*		strings		= [string componentsSeparatedByString:@"\n"];
		NSEnumerator*	enumerator	= [strings objectEnumerator];
		while ((string = [enumerator nextObject])) {
			if ([string length] > 0) {
				NSRange range = [string rangeOfString:@"APPLETALK_HOSTNAME=*"];
				if (range.location != NSNotFound) {
					char*	ptr;
					char	name[129];
					int		i;
					int		len;
					range.length	= [string length] - 20 - 1;
					range.location	= 20;
					ptr				= (char*)[[string substringWithRange:range] UTF8String];
					len				= (range.length > 256) ? 128 : (range.length / 2);
					for (i = 0; i < len; i++) {
						if (isxdigit(ptr[i*2]) && isxdigit(ptr[i*2+1])) {
							name[i] = hex2bin(ptr[i*2]) << 4 | hex2bin(ptr[i*2+1]);
						} else {
							name[i] = ' ';
						}
						if (name[i] == ':') {
							name[i] = ' ';
						}
					}
					name[i] = '\0';	
					appleTalkHostname = [[NSString stringWithCString:name] retain];
				}
			}
		}
	}
	return appleTalkHostname;
}

/*----------------------------------------------------------------------------*
 * 初期化／解放
 *----------------------------------------------------------------------------*/

// 初期化
- (id)init {
	NSUserDefaults*			defaults = [NSUserDefaults standardUserDefaults];
	NSMutableDictionary*	dic;
	NSArray*				array;
	NSDictionary*			broadDic;
	int						i;
	NSString*				fontName;
	float					fontSize;

	self = [super init];
	
	// デフォルト値の設定
	dic = [[NSMutableDictionary alloc] init];
	// 全般
	[dic setObject:NSFullUserName()						forKey:GEN_USER_NAME];
	[dic setObject:@""									forKey:GEN_GROUP_NAME];
	[dic setObject:@""									forKey:GEN_PASSWORD];
	[dic setObject:[NSNumber numberWithInt:0]			forKey:GEN_MACHINENAME_TYPE];
	[dic setObject:[NSNumber numberWithBool:NO]			forKey:GEN_HOSTDOMAIN_DEL];
	[dic setObject:[NSNumber numberWithBool:NO]			forKey:GEN_USE_STATUS_BAR];
	// ネットワーク
	[dic setObject:[NSNumber numberWithInt:2425]		forKey:NET_PORT_NO];
	[dic setObject:[NSNumber numberWithBool:NO]			forKey:NET_DIALUP];
	// 送信
	[dic setObject:@">"									forKey:SEND_QUOT_STR];
	[dic setObject:[NSNumber numberWithBool:NO]			forKey:SEND_DOCK_SEND];
	[dic setObject:[NSNumber numberWithBool:NO]			forKey:SEND_SEAL_CHECK];
	[dic setObject:[NSNumber numberWithBool:YES]		forKey:SEND_HIDE_REPLY];
	[dic setObject:[NSNumber numberWithBool:YES]		forKey:SEND_OPENSEAL_CHECK];
	[dic setObject:[NSNumber numberWithBool:YES]		forKey:SEND_ALL_USER_CHECK];
	[dic setObject:[NSNumber numberWithBool:YES]		forKey:SEND_MULTI_USER_CHECK];
	// 受信
	[dic setObject:@""									forKey:RECV_SOUND];
	[dic setObject:[NSNumber numberWithBool:YES]		forKey:RECV_QUOT_CHECK];
	[dic setObject:[NSNumber numberWithBool:NO]			forKey:RECV_NON_POPUP];
	[dic setObject:[NSNumber numberWithInt:IPMSG_BOUND_ONECE]	forKey:RECV_BOUND_IN_NONPOPUP];
	[dic setObject:[NSNumber numberWithBool:NO]			forKey:RECV_ABSENCE_NONPOPUP];
	[dic setObject:[NSNumber numberWithBool:YES]		forKey:RECV_CLICKABLE_URL];
	// ユーザリスト
	[dic setObject:[NSNumber numberWithBool:NO]			forKey:ULIST_DISP_LOGON];
	[dic setObject:[NSNumber numberWithBool:NO]			forKey:ULIST_DISP_IP];
	[dic setObject:[NSNumber numberWithBool:NO]			forKey:ULIST_IGNORE_CASE];
	[dic setObject:[NSNumber numberWithBool:NO]			forKey:ULIST_KANJI_PRIORITY];
	{
		NSMutableArray* sortArray = [[[NSMutableArray alloc] init] autorelease];
		[sortArray addObject:[NSNumber numberWithInt:IPMSG_SORT_OFF|IPMSG_SORT_ASC|IPMSG_SORT_NAME]];
		[sortArray addObject:[NSNumber numberWithInt:IPMSG_SORT_OFF|IPMSG_SORT_ASC|IPMSG_SORT_GROUP]];
		[sortArray addObject:[NSNumber numberWithInt:IPMSG_SORT_OFF|IPMSG_SORT_ASC|IPMSG_SORT_IP]];
		[sortArray addObject:[NSNumber numberWithInt:IPMSG_SORT_OFF|IPMSG_SORT_ASC|IPMSG_SORT_MACHINE]];
		[sortArray addObject:[NSNumber numberWithInt:IPMSG_SORT_OFF|IPMSG_SORT_ASC|IPMSG_SORT_DESCRIPTION]];
		[dic setObject:sortArray forKey:ULIST_SORT_RULE];
	}
	// ログ
	[dic setObject:[NSNumber numberWithBool:NO]			forKey:LOG_STD_ON];
	[dic setObject:[NSNumber numberWithBool:NO]			forKey:LOG_STD_CHAIN];
	[dic setObject:@"~/Library/Logs/ipmsg.log"			forKey:LOG_STD_FILE];
	[dic setObject:[NSNumber numberWithBool:NO]			forKey:LOG_ALT_ON];
	[dic setObject:[NSNumber numberWithBool:NO]			forKey:LOG_ALT_SELECTION];
	[dic setObject:@"~/Library/Logs/ipmsg_alt.log"		forKey:LOG_ALT_FILE];
	[dic setObject:[NSNumber numberWithInt:IPMSG_LF]	forKey:LOG_LINE_ENDING];
	
	[defaults registerDefaults:dic];
	[dic release];
	
	// 不在文のデフォルト値
	defaultAbsences = [[NSMutableArray alloc] init];
	for (i = 0; i < 8; i++) {
		NSString* key1	= [NSString stringWithFormat:@"Pref.Absence.Def%d.Title", i];
		NSString* key2	= [NSString stringWithFormat:@"Pref.Absence.Def%d.Message", i];
		dic		= [[[NSMutableDictionary alloc] init] autorelease];
		[dic setObject:NSLocalizedString(key1, nil) forKey:@"Title"];
		[dic setObject:NSLocalizedString(key2, nil) forKey:@"Message"];
		[defaultAbsences addObject:dic];
	}
	
	// フォントのデフォルト値
	fontName			= NSLocalizedString(@"Message.DefaultFontName", nil);
	fontSize			= 12;
	defaultMessageFont	= [[NSFont fontWithName:fontName size:fontSize] retain];
	if (!defaultMessageFont) {
		defaultMessageFont = [[NSFont systemFontOfSize:[NSFont systemFontSize]] retain];
	}

	// 全般
	userName				= [[defaults stringForKey:	GEN_USER_NAME] copy];
	groupName				= [[defaults stringForKey:	GEN_GROUP_NAME] copy];
	password				= [[defaults stringForKey:	GEN_PASSWORD] copy];
	machineName				= nil;
	unixHostname			= [[[NSHost currentHost] name] copy];
	appleTalkHostname		= nil;
	[self appleTalkHostname];
	machineNameType			= [defaults integerForKey:	GEN_MACHINENAME_TYPE];
	hostnameRemoveDomain	= [defaults boolForKey:		GEN_HOSTDOMAIN_DEL];
	if (!appleTalkHostname && (machineNameType == 1)) {
		// コンピュータ名が指定されていない場合、UNIXホスト名に強制変更する
		machineNameType = 0;
	}
	useStatusBar			= [defaults boolForKey:		GEN_USE_STATUS_BAR];
	// ネットワーク
	portNo					= [defaults integerForKey:	NET_PORT_NO];
	dialup					= [defaults boolForKey:		NET_DIALUP];
	broadDic				= [defaults dictionaryForKey:NET_BROADCAST];
	broadcastHostList		= [[NSMutableArray alloc] initWithArray:[broadDic objectForKey:@"Host"]];
	broadcastIPList			= [[NSMutableArray alloc] initWithArray:[broadDic objectForKey:@"IPAddress"]];
	broadcastAddresses		= nil;
	[self updateBroadcastAddresses]; 
	// 送信
	quoteString				= [[defaults stringForKey:	SEND_QUOT_STR] copy];
	openNewOnDockClick		= [defaults boolForKey:		SEND_DOCK_SEND];
	sealCheckDefault		= [defaults boolForKey:		SEND_SEAL_CHECK];
	hideRcvWinOnReply		= [defaults boolForKey:		SEND_HIDE_REPLY];
	noticeSealOpened		= [defaults boolForKey:		SEND_OPENSEAL_CHECK];
	sendAllUsersEnabled		= [defaults boolForKey:		SEND_ALL_USER_CHECK];
	allowSendingMultiUser	= [defaults boolForKey:		SEND_MULTI_USER_CHECK];
	fontName				= [defaults stringForKey:	SEND_MSG_FONT_NAME];
	fontSize				= [defaults floatForKey:	SEND_MSG_FONT_SIZE];
	sendMessageFont			= (fontName && (fontSize > 0)) ? [[NSFont fontWithName:fontName size:fontSize] retain] : nil;
	// 受信
	[self setReceiveSoundWithName:[defaults stringForKey:	RECV_SOUND]];
	quoteCheckDefault		= [defaults boolForKey:		RECV_QUOT_CHECK];
	nonPopup				= [defaults boolForKey:		RECV_NON_POPUP];
	nonPopupWhenAbsence		= [defaults boolForKey:		RECV_ABSENCE_NONPOPUP];
	nonPopupIconBound		= [defaults integerForKey:	RECV_BOUND_IN_NONPOPUP];
	useClickableURL			= [defaults boolForKey:		RECV_CLICKABLE_URL];
	fontName				= [defaults stringForKey:	RECV_MSG_FONT_NAME];
	fontSize				= [defaults floatForKey:	RECV_MSG_FONT_SIZE];
	receiveMessageFont		= (fontName && (fontSize > 0)) ? [[NSFont fontWithName:fontName size:fontSize] retain] : nil;
	// 不在
	array					= [defaults arrayForKey:	ABSENCE];
	absenceList				= [[NSMutableArray alloc] initWithArray:((array) ? array : defaultAbsences)];
	absenceIndex			= -1;
	// 通知拒否
	refuseList				= [[self convertRefuseDefaultsToInfo:[defaults arrayForKey:REFUSE]] retain];
	// ユーザリスト
	displayLogOnName		= [defaults boolForKey:		ULIST_DISP_LOGON];
	displayIPAddress		= [defaults boolForKey:		ULIST_DISP_IP];
	sortRuleList			= [[NSMutableArray alloc] initWithArray:[defaults arrayForKey:ULIST_SORT_RULE]];
	sortByIgnoreCase		= [defaults boolForKey:		ULIST_IGNORE_CASE];
	sortByKanjiPriority		= [defaults boolForKey:		ULIST_KANJI_PRIORITY];
	// ログ
	standardLogEnabled		= [defaults boolForKey:		LOG_STD_ON];
	logChainedWhenOpen		= [defaults boolForKey:		LOG_STD_CHAIN];
	standardLogFile			= [[defaults stringForKey:	LOG_STD_FILE] copy];
	alternateLogEnabled		= [defaults boolForKey:		LOG_ALT_ON];
	logWithSelectedRange	= [defaults boolForKey:		LOG_ALT_SELECTION];
	alternateLogFile		= [[defaults stringForKey:	LOG_ALT_FILE] copy];
	logLineEnding			= [defaults integerForKey:	LOG_LINE_ENDING];

	// 送受信ウィンドウ位置／サイズ
	sndWinPos.x				= [defaults floatForKey:	SNDWIN_POS_X];
	sndWinPos.y				= [defaults floatForKey:	SNDWIN_POS_Y];
	sndWinSize.width		= [defaults floatForKey:	SNDWIN_SIZE_W];
	sndWinSize.height		= [defaults floatForKey:	SNDWIN_SIZE_H];
	sndWinSplit				= [defaults floatForKey:	SNDWIN_SIZE_SPLIT];
	rcvWinPos.x				= [defaults floatForKey:	SNDWIN_POS_X];
	rcvWinPos.y				= [defaults floatForKey:	SNDWIN_POS_Y];
	rcvWinSize.width		= [defaults floatForKey:	SNDWIN_SIZE_W];
	rcvWinSize.height		= [defaults floatForKey:	SNDWIN_SIZE_H];

	return self;
}

// 解放
- (void)dealloc {
	[userName			release];
	[groupName			release];
	[machineName		release];
	[unixHostname		release];
	[appleTalkHostname	release];
	[password			release];
	[broadcastHostList	release];
	[broadcastIPList	release];
	[broadcastAddresses	release];
	[receiveSound		release];
	[receiveMessageFont	release];
	[quoteString		release];
	[sendMessageFont	release];
	[absenceList		release];
	[refuseList			release];
	[defaultAbsences	release];
	[sortRuleList		release];
	[standardLogFile	release];
	[alternateLogFile	release];
	[defaultMessageFont	release];
	[super dealloc];
}

/*----------------------------------------------------------------------------*
 * 永続化
 *----------------------------------------------------------------------------*/
- (void)save {
	NSUserDefaults*			def = [NSUserDefaults standardUserDefaults];
	NSMutableDictionary*	dic = [[[NSMutableDictionary alloc] init] autorelease];
	NSString*				ver = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
	
	// 全般
	[def setObject: ver						forKey:GEN_VERSION];
	[def setObject:	userName				forKey:GEN_USER_NAME];
	[def setObject:	groupName				forKey:GEN_GROUP_NAME];
	[def setObject:	password				forKey:GEN_PASSWORD];
	[def setInteger:machineNameType			forKey:GEN_MACHINENAME_TYPE];
	[def setBool:	hostnameRemoveDomain	forKey:GEN_HOSTDOMAIN_DEL];
	[def setBool:	useStatusBar			forKey:GEN_USE_STATUS_BAR];
	
	// ネットワーク
	[def setInteger:portNo					forKey:NET_PORT_NO];
	[def setBool:	dialup					forKey:NET_DIALUP];
	[dic setObject:	broadcastHostList		forKey:@"Host"];
	[dic setObject:	broadcastIPList			forKey:@"IPAddress"];
	[def setObject:	dic						forKey:NET_BROADCAST];
	// 送信
	[def setObject:	quoteString				forKey:SEND_QUOT_STR];
	[def setBool:	openNewOnDockClick		forKey:SEND_DOCK_SEND];
	[def setBool:	sealCheckDefault		forKey:SEND_SEAL_CHECK];
	[def setBool:	hideRcvWinOnReply		forKey:SEND_HIDE_REPLY];
	[def setBool:	noticeSealOpened		forKey:SEND_OPENSEAL_CHECK];
	[def setBool:	sendAllUsersEnabled		forKey:SEND_ALL_USER_CHECK];
	[def setBool:	allowSendingMultiUser	forKey:SEND_MULTI_USER_CHECK];
	if (sendMessageFont) {
		[def setObject:	[sendMessageFont fontName]	forKey:SEND_MSG_FONT_NAME];
		[def setFloat:	[sendMessageFont pointSize]	forKey:SEND_MSG_FONT_SIZE];
	}
	// 受信
	[def setObject:	[receiveSound name]		forKey:RECV_SOUND];
	[def setBool:	quoteCheckDefault		forKey:RECV_QUOT_CHECK];
	[def setBool:	nonPopup				forKey:RECV_NON_POPUP];
	[def setBool:	nonPopupWhenAbsence		forKey:RECV_ABSENCE_NONPOPUP];
	[def setInteger:nonPopupIconBound		forKey:RECV_BOUND_IN_NONPOPUP];
	[def setBool:	useClickableURL			forKey:RECV_CLICKABLE_URL];
	if (receiveMessageFont) {
		[def setObject:	[receiveMessageFont fontName]	forKey:RECV_MSG_FONT_NAME];
		[def setFloat:	[receiveMessageFont pointSize]	forKey:RECV_MSG_FONT_SIZE];
	}
	
	// 不在
	[def setObject:	absenceList				forKey:ABSENCE];
	// 通知拒否
	[def setObject:	[self convertRefuseInfoToDefaults:refuseList]
											forKey:REFUSE];
	// ユーザリスト
	[def setBool:	displayLogOnName		forKey:ULIST_DISP_LOGON];
	[def setBool:	displayIPAddress		forKey:ULIST_DISP_IP];
	[def setObject:	sortRuleList			forKey:ULIST_SORT_RULE];
	[def setBool:	sortByIgnoreCase		forKey:ULIST_IGNORE_CASE];
	[def setBool:	sortByKanjiPriority		forKey:ULIST_KANJI_PRIORITY];
	// ログ
	[def setBool:	standardLogEnabled		forKey:LOG_STD_ON];
	[def setBool:	logChainedWhenOpen		forKey:LOG_STD_CHAIN];
	[def setObject:	standardLogFile			forKey:LOG_STD_FILE];
	[def setBool:	alternateLogEnabled		forKey:LOG_ALT_ON];
	[def setBool:	logWithSelectedRange	forKey:LOG_ALT_SELECTION];
	[def setObject:	alternateLogFile		forKey:LOG_ALT_FILE];
	[def setInteger:logLineEnding			forKey:LOG_LINE_ENDING];
	
	// 送受信ウィンドウ位置／サイズ
	[def setFloat:	sndWinPos.x				forKey:SNDWIN_POS_X];
	[def setFloat:	sndWinPos.y				forKey:SNDWIN_POS_Y];
	[def setFloat:	sndWinSize.width		forKey:SNDWIN_SIZE_W];
	[def setFloat:	sndWinSize.height		forKey:SNDWIN_SIZE_H];
	[def setFloat:	sndWinSplit				forKey:SNDWIN_SIZE_SPLIT];
	[def setFloat:	rcvWinPos.x				forKey:RCVWIN_POS_X];
	[def setFloat:	rcvWinPos.y				forKey:RCVWIN_POS_Y];
	[def setFloat:	rcvWinSize.width		forKey:RCVWIN_SIZE_W];
	[def setFloat:	rcvWinSize.height		forKey:RCVWIN_SIZE_H];
	
	// 保存
	[def synchronize];
}

/*----------------------------------------------------------------------------*
 * 「全般」関連
 *----------------------------------------------------------------------------*/

// ユーザ名
- (NSString*)userName {
	return userName;
}

- (void)setUserName:(NSString*)name {
	[userName autorelease];
	userName = [name copy];
}

// グループ名
- (NSString*)groupName {
	return groupName;
}

- (void)setGroupName:(NSString*)name {
	[groupName autorelease];
	groupName = [name copy];
}

// パスワード
- (NSString*)password {
	return password;
}

- (void)setPassword:(NSString*)pass {
	[password autorelease];
	password = [pass copy];
}

// マシン名
- (NSString*)machineName {
	if (!machineName) {
		// AppleTalk
		if (machineNameType == 1) {
			machineName = [appleTalkHostname retain];
		}
		// ドメイン削除ホスト
		if (!machineName && hostnameRemoveDomain) {
			NSRange range = [unixHostname rangeOfString:@"."];
			if (range.location != NSNotFound) {
				machineName = [[unixHostname substringToIndex:range.location] retain];
			}
		}
		// ホスト
		if (!machineName) {
			machineName = [unixHostname retain];
		}
	}
	return machineName;
}

- (BOOL)canUseAppleTalkHostname {
	return ([self appleTalkHostname] != nil);
}

// マシン名入手元
- (int)machineNameType {
	return machineNameType;
}

- (void)setMachineNameType:(int)type {
	if (machineNameType != type) {
		machineNameType = type;
		[machineName autorelease];
		machineName = nil;
	}
}

// ホスト名からドメインを削除
- (BOOL)hostnameRemoveDomain {
	return hostnameRemoveDomain;
}

- (void)setHostnameRemoveDomain:(BOOL)flag {
	if (hostnameRemoveDomain != flag) {
		hostnameRemoveDomain = flag;
		[machineName autorelease];
		machineName = nil;
	}
}

// ステータスバー
- (BOOL)useStatusBar {
	return useStatusBar;
}

- (void)setUseStatusBar:(BOOL)use {
	useStatusBar = use;
}

/*----------------------------------------------------------------------------*
 * 「ネットワーク」関連
 *----------------------------------------------------------------------------*/
 
// ポート番号
- (int)portNo {
	return portNo;
}

- (void)setPortNo:(int)port {
	portNo = port;
}

// ダイアルアップ接続
- (BOOL)dialup {
	return dialup;
}

- (void)setDialup:(BOOL)flag {
	dialup = flag;
}

// ブロードキャスト
- (NSArray*)broadcastAddresses {
	return broadcastAddresses;
}

- (int)numberOfBroadcasts {
	return [broadcastHostList count] + [broadcastIPList count];
}

- (NSString*)broadcastAtIndex:(int)index {
	int hostnum = [broadcastHostList count];
	if (index < hostnum) {
		return [broadcastHostList objectAtIndex:index];
	}
	return [broadcastIPList objectAtIndex:index - hostnum];
}

- (BOOL)containsBroadcastWithAddress:(NSString*)address {
	return [broadcastIPList containsObject:address];
}

- (BOOL)containsBroadcastWithHost:(NSString*)host {
	return [broadcastHostList containsObject:host];
}

- (void)addBroadcastWithAddress:(NSString*)address {
	[broadcastIPList addObject:address];
	[broadcastIPList sortUsingSelector:@selector(compare:)];
	[self updateBroadcastAddresses];
}

- (void)addBroadcastWithHost:(NSString*)host {
	[broadcastHostList addObject:host];
	[broadcastHostList sortUsingSelector:@selector(compare:)];
	[self updateBroadcastAddresses];
}

- (void)removeBroadcastAtIndex:(int)index {
	int hostnum = [broadcastHostList count];
	if (index < hostnum) {
		[broadcastHostList removeObjectAtIndex:index];
	} else {
		[broadcastIPList removeObjectAtIndex:index - hostnum];
	}
	[self updateBroadcastAddresses];
}
	
/*----------------------------------------------------------------------------*
 * 「送信」関連
 *----------------------------------------------------------------------------*/

// 引用文字列
- (NSString*)quoteString {
	return quoteString;
}

- (void)setQuoteString:(NSString*)string {
	[quoteString autorelease];
	quoteString = [string copy];
}

// Dockをクリックでウィンドウオープン
- (BOOL)openNewOnDockClick {
	return openNewOnDockClick;
}

- (void)setOpenNewOnDockClick:(BOOL)open {
	openNewOnDockClick = open;
}

// 引用チェックをデフォルト
- (BOOL)sealCheckDefault {
	return sealCheckDefault;
}

- (void)setSealCheckDefault:(BOOL)seal {
	sealCheckDefault = seal;
}

// 返信時に受信ウィンドウをクローズ
- (BOOL)hideReceiveWindowOnReply {
	return hideRcvWinOnReply;
}

- (void)setHideReceiveWindowOnReply:(BOOL)hide {
	hideRcvWinOnReply = hide;
}

// 開封チェックを行う
- (BOOL)noticeSealOpened {
	return noticeSealOpened;
}

- (void)setNoticeSealOpened:(BOOL)check {
	noticeSealOpened = check;
}

// 全員に送信チェックボックス有効
- (BOOL)sendAllUsersCheckEnabled {
	return sendAllUsersEnabled;
}

- (void)setSendAllUsersCheckEnabled:(BOOL)check {
	sendAllUsersEnabled = check;
}

// 複数ユーザへの送信を許可
- (BOOL)allowSendingToMultiUser {
	return allowSendingMultiUser;
}

- (void)setAllowSendingToMultiUser:(BOOL)allow {
	allowSendingMultiUser = allow;
}

// メッセージ部フォント
- (NSFont*)defaultSendMessageFont {
	return defaultMessageFont;
}

- (NSFont*)sendMessageFont {
	return (sendMessageFont) ? sendMessageFont : defaultMessageFont;
}

- (void)setSendMessageFont:(NSFont*)font {
	[font retain];
	[sendMessageFont release];
	sendMessageFont = font;
}

/*----------------------------------------------------------------------------*
 * 「受信」関連
 *----------------------------------------------------------------------------*/
 
// 受信音
- (NSSound*)receiveSound {
	return receiveSound;
}

- (NSString*)receiveSoundName {
	return [receiveSound name];
}

- (void)setReceiveSoundWithName:(NSString*)soundName {
	[receiveSound autorelease];
	receiveSound = nil;
	if (soundName) {
		if ([soundName length] > 0) {
			receiveSound = [[NSSound soundNamed:soundName] retain];
		}
	}
}

// 引用チェックをデフォルト
- (BOOL)quoteCheckDefault {
	return quoteCheckDefault;
}

- (void)setQuoteCheckDefault:(BOOL)quote {
	quoteCheckDefault = quote;
}

// ノンポップアップ受信
- (BOOL)nonPopup {
	return nonPopup;
}

- (void)setNonPopup:(BOOL)nonPop {
	nonPopup = nonPop;
}

// 不在時ノンポップアップ受信
- (BOOL)nonPopupWhenAbsence {
	return nonPopupWhenAbsence;
}

- (void)setNonPopupWhenAbsence:(BOOL)nonPop {
	nonPopupWhenAbsence = nonPop;
}

// ノンポップアップ受信時アイコンバウンド種別
- (IPMsgIconBoundType)iconBoundModeInNonPopup {
	return nonPopupIconBound;
}

- (void)setIconBoundModeInNonPopup:(IPMsgIconBoundType)type {
	nonPopupIconBound = type;
}

// クリッカブルURL
- (BOOL)useClickableURL {
	return useClickableURL;
}

- (void)setUseClickableURL:(BOOL)clickable {
	useClickableURL = clickable;
}

// メッセージ部フォント
- (NSFont*)defaultReceiveMessageFont {
	return defaultMessageFont;
}

- (NSFont*)receiveMessageFont {
	return (receiveMessageFont) ? receiveMessageFont : defaultMessageFont;
}

- (void)setReceiveMessageFont:(NSFont*)font {
	[font retain];
	[receiveMessageFont release];
	receiveMessageFont = font;
}

/*----------------------------------------------------------------------------*
 * 「不在」関連
 *----------------------------------------------------------------------------*/

- (int)numberOfAbsences {
	return [absenceList count];
}

- (NSString*)absenceTitleAtIndex:(int)index {
	return [[absenceList objectAtIndex:index] objectForKey:@"Title"];
}

- (NSString*)absenceMessageAtIndex:(int)index {
	return [[absenceList objectAtIndex:index] objectForKey:@"Message"];
}

- (BOOL)containsAbsenceTitle:(NSString*)title {
	int i;
	for (i = 0; i < [absenceList count]; i++) {
		NSDictionary* dic = [absenceList objectAtIndex:i];
		if ([title isEqualToString:[dic objectForKey:@"Title"]]) {
			return YES;
		}
	}
	return NO;
}

- (void)addAbsenceTitle:(NSString*)title message:(NSString*)msg atIndex:(int)index {
	id obj = [[[NSMutableDictionary alloc] init] autorelease];
	[obj setObject:title	forKey:@"Title"];
	[obj setObject:msg		forKey:@"Message"];
	if ((index < 0) || (index >= [absenceList count])) {
		[absenceList addObject:obj];
	} else {
		[absenceList insertObject:obj atIndex:index];
	}
}

- (void)setAbsenceTitle:(NSString*)title message:(NSString*)msg atIndex:(int)index {
	if ((index >= 0) && (index < [absenceList count])) {
		id obj = [[[NSMutableDictionary alloc] init] autorelease];
		[obj setObject:title	forKey:@"Title"];
		[obj setObject:msg		forKey:@"Message"];
		[absenceList replaceObjectAtIndex:index withObject:obj];
	}
}

- (void)upAbsenceAtIndex:(int)index {
	id obj = [[absenceList objectAtIndex:index] retain];
	[absenceList removeObjectAtIndex:index];
	[absenceList insertObject:obj atIndex:index - 1];
	[obj release];
}

- (void)downAbsenceAtIndex:(int)index {
	id obj = [[absenceList objectAtIndex:index] retain];
	[absenceList removeObjectAtIndex:index];
	[absenceList insertObject:obj atIndex:index + 1];
	[obj release];
}

- (void)removeAbsenceAtIndex:(int)index {
	[absenceList removeObjectAtIndex:index];
}

- (void)resetAllAbsences {
	[absenceList removeAllObjects];
	[absenceList addObjectsFromArray:defaultAbsences];
}

- (BOOL)isAbsence {
	return (absenceIndex != -1);
}

- (int)absenceIndex {
	return absenceIndex;
}

- (void)setAbsenceIndex:(int)index {
	if ((index >= 0) && (index < [absenceList count])) {
		absenceIndex = index;
	} else {
		absenceIndex = -1;
	}
}

/*----------------------------------------------------------------------------*
 * 「通知拒否」関連
 *----------------------------------------------------------------------------*/

- (int)numberOfRefuseInfo {
	return [refuseList count];
}

- (RefuseInfo*)refuseInfoAtIndex:(int)index {
	return [refuseList objectAtIndex:index];
}

- (void)addRefuseInfo:(RefuseInfo*)info atIndex:(int)index {
	if ((index < 0) || (index >= [refuseList count])) {
		[refuseList addObject:info];
	} else {
		[refuseList insertObject:info atIndex:index];
	}
}

- (void)setRefuseInfo:(RefuseInfo*)info atIndex:(int)index {
	[refuseList replaceObjectAtIndex:index withObject:info];
}

- (void)upRefuseInfoAtIndex:(int)index {
	id obj = [[refuseList objectAtIndex:index] retain];
	[refuseList removeObjectAtIndex:index];
	[refuseList insertObject:obj atIndex:index - 1];
	[obj release];
}

- (void)downRefuseInfoAtIndex:(int)index {
	id obj = [[refuseList objectAtIndex:index] retain];
	[refuseList removeObjectAtIndex:index];
	[refuseList insertObject:obj atIndex:index + 1];
	[obj release];
}
 
- (void)removeRefuseInfoAtIndex:(int)index {
	[refuseList removeObjectAtIndex:index];
}

- (BOOL)refuseUser:(UserInfo*)user {
	int i;
	for (i = 0; i < [refuseList count]; i++) {
		RefuseInfo* info = (RefuseInfo*)[refuseList objectAtIndex:i];
		if ([info match:user]) {
			return YES;
		}
	}
	return NO;
}

/*----------------------------------------------------------------------------*
 * 「ユーザリスト」関連
 *----------------------------------------------------------------------------*/

// ログオン名を表示する
- (BOOL)displayLogOnName {
	return displayLogOnName;
}

- (void)setDisplayLogOnName:(BOOL)disp {
	displayLogOnName = disp;
}

// IPアドレスを表示する
- (BOOL)displayIPAddress {
	return displayIPAddress;
}

- (void)setDisplayIPAddress:(BOOL)disp {
	displayIPAddress = disp;
}

// ソートルール
- (int)numberOfSortRules {
	return [sortRuleList count];
}

- (void)moveSortRuleFromIndex:(int)from toIndex:(int)to {
	NSNumber* number = [[sortRuleList objectAtIndex:from] retain];
	if (number) {
		[sortRuleList removeObjectAtIndex:from];
		[sortRuleList insertObject:number atIndex:to];
		[number release];
	}
}

- (IPMsgUserSortRuleType)sortRuleTypeAtIndex:(int)index {
	return [[sortRuleList objectAtIndex:index] intValue] & IPMSG_SORT_TYPE_MASK;
}

- (BOOL)sortRuleEnabledAtIndex:(int)index {
	return (([[sortRuleList objectAtIndex:index] intValue] & IPMSG_SORT_ONOFF_MASK) == IPMSG_SORT_ON);
}

- (void)setSortRuleEnabled:(BOOL)flag atIndex:(int)index {
	NSNumber* number = [sortRuleList objectAtIndex:index];
	if (number) {
		int value = [number intValue];
		value &= ~IPMSG_SORT_ONOFF_MASK;
		value |= ((flag) ? IPMSG_SORT_ON : IPMSG_SORT_OFF);
		[sortRuleList replaceObjectAtIndex:index withObject:[NSNumber numberWithInt:value]];
	}
}

- (IPMsgUserSortRuleType)sortRuleOrderAtIndex:(int)index {
	return [[sortRuleList objectAtIndex:index] intValue] & IPMSG_SORT_ORDER_MASK;
}
	
- (void)setSortRuleOrder:(IPMsgUserSortRuleType)order atIndex:(int)index {
	NSNumber* number = [sortRuleList objectAtIndex:index];
	if (number) {
		int value = [number intValue];
		value &= ~IPMSG_SORT_ORDER_MASK;
		value |= order;
		[sortRuleList replaceObjectAtIndex:index withObject:[NSNumber numberWithInt:value]];
	}
}

// 大文字小文字を無視する
- (BOOL)sortByIgnoreCase {
	return sortByIgnoreCase;
}

- (void)setSortByIgnoreCase:(BOOL)flag {
	sortByIgnoreCase = flag;
}

// 漢字を優先する
- (BOOL)sortByKanjiPriority {
	return sortByKanjiPriority;
}

- (void)setSortByKanjiPriority:(BOOL)flag {
	sortByKanjiPriority = flag;
}

/*----------------------------------------------------------------------------*
 * 「ログ」関連
 *----------------------------------------------------------------------------*/

// 標準ログを使用する
- (BOOL)standardLogEnabled {
	return standardLogEnabled;
}

- (void)setStandardLogEnabled:(BOOL)b {
	standardLogEnabled = b;
}

// 錠前付きは開封時にログ
- (BOOL)logChainedWhenOpen {
	return logChainedWhenOpen;
}

- (void)setLogChainedWhenOpen:(BOOL)b {
	logChainedWhenOpen = b;
}

// 標準ログファイル
- (NSString*)standardLogFile {
	return standardLogFile;
}

- (void)setStandardLogFile:(NSString*)path {
	[standardLogFile autorelease];
	standardLogFile = [path copy];
}

// 重要ログを使用する
- (BOOL)alternateLogEnabled {
	return alternateLogEnabled;
}

- (void)setAlternateLogEnabled:(BOOL)b {
	alternateLogEnabled = b;
}

// 選択範囲を記録する
- (BOOL)logWithSelectedRange {
	return logWithSelectedRange;
}

- (void)setLogWithSelectedRange:(BOOL)b {
	logWithSelectedRange = b;
}

// 重要ログファイル
- (NSString*)alternateLogFile {
	return alternateLogFile;
}
- (void)setAlternateLogFile:(NSString*)path {
	[alternateLogFile autorelease];
	alternateLogFile = [path copy];
}

// 改行コード
- (IPMsgLogLineEnding)logLineEnding {
	return logLineEnding;
}

- (void)setLogLineEnding:(IPMsgLogLineEnding)lineEnding {
	logLineEnding = lineEnding;
}

/*----------------------------------------------------------------------------*
 * 送受信ウィンドウ位置／サイズ関連
 *----------------------------------------------------------------------------*/

// 受信ウィンドウ位置
- (NSPoint)sendWindowPosition {
	return sndWinPos;
}

- (void)setSendWindowPosition:(NSPoint)point {
	sndWinPos = point;
}

- (void)resetSendWindowPosition {
	sndWinPos.x	= 0;
	sndWinPos.y = 0;
}

// 受信ウィンドウサイズ
- (NSSize)sendWindowSize {
	return sndWinSize;
}

- (float)sendWindowSplit {
	return sndWinSplit;
}

- (void)setSendWindowSize:(NSSize)size split:(int)split {
	sndWinSize	= size;
	sndWinSplit	= split;
}

- (void)resetSendWindowSize {
	sndWinSize.width	= 0;
	sndWinSize.height	= 0;
	sndWinSplit			= 0;
}

// 受信ウィンドウ位置
- (NSPoint)receiveWindowPosition {
	return rcvWinPos;
}

- (void)setReceiveWindowPosition:(NSPoint)position {
	rcvWinPos = position;
}

- (void)resetReceiveWindowPosition {
	rcvWinPos.x	= 0;
	rcvWinPos.y	= 0;
}

// 受信ウィンドウサイズ
- (NSSize)receiveWindowSize {
	return rcvWinSize;
}

- (void)setReceiveWindowSize:(NSSize)size {
	rcvWinSize = size;
}

- (void)resetReceiveWindowSize {
	rcvWinSize.width	= 0;
	rcvWinSize.height	= 0;
}

@end