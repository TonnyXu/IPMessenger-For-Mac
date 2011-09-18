/*============================================================================*
 * (C) 2001-2003 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for MacOS X
 *	File		: UserInfo.h
 *	Module		: ユーザ情報クラス		
 *============================================================================*/

#import <Foundation/Foundation.h>

@class RecvMessage;

/*============================================================================*
 * クラス定義
 *============================================================================*/
@interface UserInfo : NSObject <NSCopying> {
	NSString*		user;			// IPMsgユーザ名（ニックネーム）
	NSString*		group;			// IPMsgグループ名
	NSString*		address;		// IPアドレス（文字列）
	unsigned long	addressNumber;	// IPアドレス（数値）
	unsigned short	portNo;			// ポート番号
	NSString*		host;			// マシン名
	NSString*		logOnUser;		// ログインユーザ名
	BOOL			absence;		// 不在
	BOOL			dialup;			// ダイアルアップ
	BOOL			attachment;		// ファイル添付サポート
	BOOL			encrypt;		// 暗号化サポート
	NSString*		version;		// バージョン情報
}

// ファクトリ
+ (id)userWithRecvMessage:(RecvMessage*)msg;
+ (id)userWithHostList:(NSArray*)itemArray fromIndex:(unsigned)index;

// 初期化
- (id)initWithRecvMessage:(RecvMessage*)msg;
- (id)initWithHostList:(NSArray*)itemArray fromIndex:(unsigned)index;
			
- (id)initWithUser:(NSString*)userName
			 group:(NSString*)groupName
		   address:(NSString*)ipAddress
			  port:(unsigned short)port
		   machine:(NSString*)machineName
			 logOn:(NSString*)logOnUserName
		   absence:(BOOL)absenceFlag
			dialup:(BOOL)dialupFlag
		attachment:(BOOL)attachFlag
		   encrypt:(BOOL)encryptFlag;

// getter/setter
- (NSString*)user;
- (NSString*)group;
- (NSString*)address;
- (unsigned long)addressNumber;
- (unsigned short)portNo;
- (NSString*)host;
- (NSString*)logOnUser;
- (BOOL)absence;
- (BOOL)dialup;
- (BOOL)attachmentSupport;
- (BOOL)encryptSupport;
- (NSString*)version;
- (void)setVersion:(NSString*)ver;

// 表示文字列
- (NSString*)summeryString;

@end
