/*============================================================================*
 * (C) 2001-2003 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for MacOS X
 *	File		: RefuseInfo.h
 *	Module		: 通知拒否条件情報クラス		
 *============================================================================*/

#import <Foundation/Foundation.h>

@class UserInfo;

/*============================================================================*
 * 定数定義
 *============================================================================*/

// 拒否判定対象
typedef enum {
	IP_REFUSE_USER,			// ユーザ名
	IP_REFUSE_GROUP,		// グループ名
	IP_REFUSE_MACHINE,		// マシン名
	IP_REFUSE_LOGON,		// ログオン名
	IP_REFUSE_ADDRESS		// IPアドレス

} IPRefuseTarget;

// 拒否判定条件
typedef enum {
	IP_REFUSE_MATCH,		// 一致する
	IP_REFUSE_CONTAIN,		// 含む
	IP_REFUSE_START,		// 始まる
	IP_REFUSE_END			// 終わる

} IPRefuseCondition;
	
/*============================================================================*
 * クラス定義
 *============================================================================*/

@interface RefuseInfo : NSObject {
	IPRefuseTarget		target;		// 判定対象
	NSString*			string;		// 文字列
	IPRefuseCondition	condition;	// 判定条件
}

// 初期化
- (id)initWithTarget:(IPRefuseTarget)aTarget string:(NSString*)aString condition:(IPRefuseCondition)aCondition;

// getter
- (IPRefuseTarget)target;
- (NSString*)string;
- (IPRefuseCondition)condition;

// setter
- (void)setTarget:(IPRefuseTarget)aTarget;
- (void)setString:(NSString*)aString;
- (void)setCondition:(IPRefuseCondition)aCondition;

// 判定
- (BOOL)match:(UserInfo*)user;

@end
