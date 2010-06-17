/*============================================================================*
 * (C) 2001-2003 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for MacOS X
 *	File		: AttachStatusControl.h
 *	Module		: 添付ファイル状況表示パネルコントローラ		
 *============================================================================*/

#import <Cocoa/Cocoa.h>

@class AttachmentServer;

@interface AttachStatusControl : NSObject
{
	IBOutlet NSPanel*		panel;
	IBOutlet NSOutlineView*	attachTable;
	IBOutlet NSButton*		dispAlwaysCheck;
	IBOutlet NSButton*		deleteButton;
}

- (IBAction)buttonPressed:(id)sender;
- (IBAction)checkboxChanged:(id)sender;

@end
