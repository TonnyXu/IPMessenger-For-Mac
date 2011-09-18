/*============================================================================*
 * (C) 2001-2009 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for MacOS X
 *	File		: NSStringIPMessenger.m
 *	Module		: NSStringカテゴリ拡張		
 *============================================================================*/

#import "NSStringIPMessenger.h"
#import "DebugLog.h"

@implementation NSString(IPMessenger)

// IPMessenger用送受信文字列変換（C文字列→NSString)
+ (id)stringWithIPMsgCString:(const char*)UTF8String {
	return [[[NSString alloc] initWithIPMsgCString:UTF8String] autorelease];
}

// IPMessenger用送受信文字列変換（C文字列→NSString)
- (id)initWithIPMsgCString:(const char*)UTF8String {
	NSData* data;
	if (!UTF8String) {
		[self release];
		return nil;
	}
	data = [NSData dataWithBytes:UTF8String length:strlen(UTF8String)];
	self = [self initWithData:data encoding:NSShiftJISStringEncoding];
	// 日本語環境なら'\'は'¥'に変換（IPMsgのプロトコルがSJISだから）
	if ([NSLocalizedString(@"IPMsg.provisional.lang", nil) isEqualToString:@"j"]) {	
		NSRange range = [self rangeOfString:@"\\" options:NSLiteralSearch];
		if (range.location != NSNotFound) {
			NSMutableString* str = [self mutableCopy];
			while (range.location != NSNotFound) {
				[str replaceCharactersInRange:range withString:@"¥"];
				range = [str rangeOfString:@"\\" options:NSLiteralSearch];
			}
			[self release];
			self = str;
		}
	}
	return self;
}

// IPMessenger用送受信文字列変換（NSString→C文字列)
- (const char*)ipmsgCString {
	NSData*			data1;
	NSMutableData*	data2;
	NSRange			range = [self rangeOfString:@"¥" options:NSLiteralSearch];
	if (range.location != NSNotFound) {
		// '¥'は'\'に変換しておかないと文字化けする（IPMsgのプロトコルがSJISだから）
		NSMutableString* str = [[self mutableCopy] autorelease];
		while (range.location != NSNotFound) {
			[str replaceCharactersInRange:range withString:@"\\"];
			range = [str rangeOfString:@"¥" options:NSLiteralSearch];
		}
		data1 = [str dataUsingEncoding:NSShiftJISStringEncoding allowLossyConversion:YES];
	} else {
		// '¥'がないならそのまま
		data1 = [self dataUsingEncoding:NSShiftJISStringEncoding allowLossyConversion:YES];
	}
	data2 = [NSMutableData dataWithLength:([data1 length] + 1)];
	[data2 setData:data1];
	return (const char*)[data2 bytes];
}

@end
