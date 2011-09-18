/*============================================================================*
 * (C) 2001-2003 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for MacOS X
 *	File		: main.m
 *	Module		: アプリケーションエントリポイント		
 *	Description	: アプリケーションメイン関数（ProjectBuilderによる自動生成）
 *============================================================================*/

#import <Cocoa/Cocoa.h>

int main(int argc, const char *argv[])
{
	// 添付ファイルのクライアントからの切断時のサーバクラッシュを避けるため
	signal(SIGPIPE, SIG_IGN);
	return NSApplicationMain(argc, argv);
}
