/*============================================================================*
 * (C) 2001-2003 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for MacOS X
 *	File		: SendMessage.h
 *	Module		: 送信メッセージクラス		
 *============================================================================*/

#import <Foundation/Foundation.h>

/*============================================================================*
 * クラス定義
 *============================================================================*/

@interface SendMessage : NSObject <NSCopying> {
	long				packetNo;		// パケット番号
	NSMutableString*	message;		// 送信メッセージ
	NSArray*			attachments;	// 添付ファイル
	BOOL				sealed;			// 封書フラグ
	BOOL				locked;			// 施錠フラグ
}

// ファクトリ
+ (id)messageWithMessage:(NSString*)msg attachments:(NSArray*)attach seal:(BOOL)seal lock:(BOOL)lock;

// 初期化／解放
- (id)initWithMessage:(NSString*)msg attachments:(NSArray*)attach seal:(BOOL)seal lock:(BOOL)lock;
- (void)dealloc;
			   
// getter
- (long)packetNo;
- (NSString*)message;
- (NSArray*)attachments;
- (BOOL)sealed;
- (BOOL)locked;

@end
