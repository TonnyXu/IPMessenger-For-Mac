/*============================================================================*
 * (C) 2001-2003 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for MacOS X
 *	File		: SendMessageView.h
 *	Module		: 送信メッセージ表示View		
 *============================================================================*/

#import <Cocoa/Cocoa.h>

@interface SendMessageView : NSTextView
{
	BOOL duringDragging;
}
@end
