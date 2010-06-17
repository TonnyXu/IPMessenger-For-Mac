/*============================================================================*
 * (C) 2001-2009 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for MacOS X
 *	File		: RefuseInfo.m
 *	Module		: 通知拒否条件情報クラス		
 *============================================================================*/

#import "RefuseInfo.h"
#import "UserInfo.h"
#import "DebugLog.h"

/*============================================================================*
 * クラス実装
 *============================================================================*/

@implementation RefuseInfo

/*----------------------------------------------------------------------------*
 * 初期化／解放
 *----------------------------------------------------------------------------*/

// 初期化
- (id)initWithTarget:(IPRefuseTarget)aTarget string:(NSString*)aString condition:(IPRefuseCondition)aCondition {
	self = [super self];
	target		= aTarget;
	string		= [aString copy];
	condition	= aCondition;
	return self;
}

// 解放
- (void)dealloc {
	[string release];
	[super dealloc];
}

/*----------------------------------------------------------------------------*
 * getter
 *----------------------------------------------------------------------------*/

- (IPRefuseTarget)target {
	return target;
}

- (NSString*)string {
	return string;
}

- (IPRefuseCondition)condition {
	return condition;
}

/*----------------------------------------------------------------------------*
 * setter
 *----------------------------------------------------------------------------*/

- (void)setTarget:(IPRefuseTarget)aTarget {
	target = aTarget;
}

- (void)setString:(NSString*)aString {
	[string release];
	string = [aString copy];
}

- (void)setCondition:(IPRefuseCondition)aCondition {
	condition = aCondition;
}

/*----------------------------------------------------------------------------*
 * その他
 *----------------------------------------------------------------------------*/

- (BOOL)match:(UserInfo*)user {
	NSString* targetStr		= nil;	
	switch (target) {
	case IP_REFUSE_USER:	targetStr = [user user];		break;
	case IP_REFUSE_GROUP:	targetStr = [user group];		break;
	case IP_REFUSE_MACHINE:	targetStr = [user host];		break;
	case IP_REFUSE_LOGON:	targetStr = [user logOnUser];	break;
	case IP_REFUSE_ADDRESS:	targetStr = [user address];		break;
	default:
		WRN1(@"invalid refuse target(%d)", target);
		return NO;
	}
	switch (condition) {
	case IP_REFUSE_MATCH:
		return [targetStr isEqualToString:string];
	case IP_REFUSE_CONTAIN:
		return ([targetStr rangeOfString:string].location != NSNotFound);
	case IP_REFUSE_START:
	{
		int len1 = [targetStr length];
		int len2 = [string length];
		if (len1 > len2) {
			return [[targetStr substringToIndex:(len2)] isEqualToString:string];
		} else if (len1 == len2) {
			return [targetStr isEqualToString:string];
		}
	}
		break;
	case IP_REFUSE_END:
	{
		int len1 = [targetStr length];
		int len2 = [string length];
		if (len1 > len2) {
			return [[targetStr substringFromIndex:(len1 - len2)] isEqualToString:string];
		} else if (len1 == len2) {
			return [targetStr isEqualToString:string];
		}
	}
		break; 
	default:
		WRN1(@"invalid refuse condition(%d)", condition);
		break;
	}
	return NO;
}

/* コピー処理 （NSCopyingプロトコル） */
- (id)copyWithZone:(NSZone*)zone {
	return [[RefuseInfo allocWithZone:zone]
				initWithTarget:target
						string:string
					 condition:condition];
}

- (NSString*)description {
	NSString* targetStr		= nil;
	NSString* conditionStr	= nil;
	
	switch (target) {
	case IP_REFUSE_USER:	targetStr = NSLocalizedString(@"Refuse.Desc.Name", nil);		break;
	case IP_REFUSE_GROUP:	targetStr = NSLocalizedString(@"Refuse.Desc.Group", nil);		break;
	case IP_REFUSE_MACHINE:	targetStr = NSLocalizedString(@"Refuse.Desc.Machine", nil);		break;
	case IP_REFUSE_LOGON:	targetStr = NSLocalizedString(@"Refuse.Desc.LogOn", nil);		break;
	case IP_REFUSE_ADDRESS:	targetStr = NSLocalizedString(@"Refuse.Desc.IPAddress", nil);	break;
	default:
		WRN1(@"invalid refuse target(%d)", target);
		break;
	}
	switch (condition) {
	case IP_REFUSE_MATCH:	conditionStr = NSLocalizedString(@"Refuse.Desc.Match", nil);	break;
	case IP_REFUSE_CONTAIN:	conditionStr = NSLocalizedString(@"Refuse.Desc.Contain", nil);	break;
	case IP_REFUSE_START:	conditionStr = NSLocalizedString(@"Refuse.Desc.Start", nil);	break;
	case IP_REFUSE_END:		conditionStr = NSLocalizedString(@"Refuse.Desc.End", nil);		break;
	default:
		WRN1(@"invalid refuse condition(%d)", condition);
		break;
	}
	
	// 英語環境では順番が変わるので注意（かなり暫定処理）
	if ([NSLocalizedString(@"IPMsg.provisional.lang", nil) isEqualToString:@"e"]) {
		return [NSString stringWithFormat:NSLocalizedString(@"Refuse.Description.Format", nil),
																targetStr, conditionStr, string];
	}
	return [NSString stringWithFormat:NSLocalizedString(@"Refuse.Description.Format", nil),
																targetStr, string, conditionStr];
}

@end
