/*============================================================================*
 * (C) 2001-2003 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for MacOS X
 *	File		: ReceiveMessageView.m
 *	Module		: 受信メッセージ表示View		
 *============================================================================*/

#import "ReceiveMessageView.h"
#import "Config.h"

/*============================================================================*
 * クラス実装
 *============================================================================*/

@implementation ReceiveMessageView

- (id)initWithFrame:(NSRect)frameRect {
	Config* config = [Config sharedConfig];
	self = [super initWithFrame:frameRect];
	[self setEditable:NO];
	[self setBackgroundColor:[NSColor windowBackgroundColor]];
	[self setFont:[config receiveMessageFont]];
	[self setUsesRuler:YES];
	return self;
}

- (void)changeFont:(id)sender {
	[self setFont:[sender convertFont:[self font]]];
}

- (void)keyDown:(NSEvent*)theEvent {
	// タブキーはフォーカス移動にする
	if ([theEvent keyCode] == 48) {
		[[self window] makeFirstResponder:[self nextValidKeyView]];
	}
	// enterキーは送信に使うので無視（親Viewに中継）する
	else if ([theEvent keyCode] == 52) {
		[[self superview] keyDown:theEvent];
	}
	else {
		[super keyDown:theEvent];
	}
}

@end
