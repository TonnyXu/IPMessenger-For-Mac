/*============================================================================*
 * (C) 2001-2003 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for MacOS X
 *	File		: DebugLog.m
 *	Module		: デバッグログ機能		
 *	Description	: デバッグログ出力関数
 *============================================================================*/
 
#import "DebugLog.h"

/*----------------------------------------------------------------------------*
 * ログ出力
 *----------------------------------------------------------------------------*/
#if defined(IPMSG_DEBUG)

#define LOG_TO_CONSOLE	1

void IPMsgLog(NSString* level, char* file, int line, NSString* msg) {
	static NSLock*			writeLock	= nil;
	static NSDateFormatter* format		= nil;
	NSString*				str;
	char*					pFile;
	if (!format) {
		format = [[NSDateFormatter alloc] initWithDateFormat:@"%Y/%m/%d %H:%M:%S.%F" allowNaturalLanguage:NO];
	}
	if (!writeLock) {
		writeLock = [[NSLock alloc] init];
	}
	str = [format stringForObjectValue:[NSDate date]];
	pFile = strrchr(file, '/');
	if (!pFile) {
		pFile = file;
	} else {
		pFile++;
	}
	[writeLock lock];
NS_DURING
#if LOG_TO_CONSOLE
	printf("%s%s %s[%d] %s\n", [level UTF8String], [str UTF8String], pFile, line, [msg UTF8String]);
#else
	{
		NSString*	dir	= [[[NSBundle mainBundle] bundlePath] stringByDeletingLastPathComponent];
		NSString*	log	= [dir stringByAppendingPathComponent:@"DebugLog.txt"];
		FILE*		fp	= fopen([log fileSystemRepresentation], "a");
		if (fp) {
			fprintf(fp, "%s%s %s[%d] %s\n", [level UTF8String], [str UTF8String], pFile, line, [msg UTF8String]);
			fflush(fp);
		} else {
			printf("%s%s %s[%d] %s\n", [level UTF8String], [str UTF8String], pFile, line, [msg UTF8String]);
		}
	}
#endif
NS_HANDLER
	printf("!!! logging error !!!(UTF8String convert)");
NS_ENDHANDLER
	[writeLock unlock];
}

#endif