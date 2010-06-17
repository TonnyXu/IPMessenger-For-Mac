/*============================================================================*
 * (C) 2001-2003 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for MacOS X
 *	File		: SendWindow.m
 *	Module		: メッセージ送信ウィンドウ		
 *============================================================================*/
 
#import "SendWindow.h"
#import "SendControl.h"
#import "DebugLog.h"

@implementation SendWindow

- (id)initWithContentRect:(NSRect)contentRect styleMask:(unsigned int)styleMask backing:(NSBackingStoreType)backingType defer:(BOOL)flag {
//	styleMask |= NSTexturedBackgroundWindowMask;
	self = [super initWithContentRect:contentRect styleMask:styleMask backing:backingType defer:flag];
	return self;
}

- (void)keyDown:(NSEvent*)theEvent {
	// Enterキー入力時、送信処理を行う
    NSString *keyBind = @"";
	if ([theEvent modifierFlags] & NSCommandKeyMask ){
        keyBind = [keyBind stringByAppendingString:@"Command +"];
    }
	if ([theEvent modifierFlags] & NSAlternateKeyMask ){
        keyBind = [keyBind stringByAppendingString:@"Option +"];
    }
	if ([theEvent modifierFlags] & NSAlphaShiftKeyMask ){
        keyBind = [keyBind stringByAppendingString:@"Shift +"];
    }
    
    keyBind = [keyBind stringByAppendingFormat:@"%d",[theEvent keyCode]];

    NSLog(@">>>> User pressed %@", keyBind);
    
    if ([theEvent modifierFlags] & NSCommandKeyMask && [theEvent keyCode] == 3) {
        // ⌘ + F, do searching.
        NSLog(@"In SendWindow.m");
        [self.delegate focusOnSearchField];
    }
    
//	}else if (([theEvent keyCode] == 52) &&
//		([[self delegate] respondsToSelector:@selector(sendMessage:)])) {
////		DBG0(@"send!(byEnter)");
//		[[self delegate] sendMessage:self];
//	} else {
//		[super keyDown:theEvent];
//	}
}


@end
