/*============================================================================*
 * (C) 2001-2003 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for MacOS X
 *	File		: DebugLog.h
 *	Module		: デバッグログ機能		
 *	Description	: デバッグログマクロ定義
 *============================================================================*/

#include <Foundation/Foundation.h>

/*============================================================================*
 * 出力フラグ
 *		IPMSG_DEBUGがメインスイッチ（定義がない場合全レベル強制OFF）
 *		※ ProjectBuilderのビルドスタイルにて定義されている
 *			・Deployment ビルドスタイル：出力しない（定義なし）
 *			・Developmentビルドスタイル：出力する（定義あり）
 *============================================================================*/
 
// レベル別出力フラグ
//		0:出力しない
//		1:出力する
#define IPMSG_LOG_DBG	1
#define IPMSG_LOG_WRN	1
#define IPMSG_LOG_ERR	1

/*============================================================================*
 * デバッグレベルログ
 *============================================================================*/
 
#if defined(IPMSG_DEBUG) && (IPMSG_LOG_DBG == 1)
	#define _LOG_DBG					@"D ",__FILE__,__LINE__
	#define DBG0(fmt)					IPMsgLog(_LOG_DBG,fmt)
	#define DBG1(fmt,a1)				IPMsgLog(_LOG_DBG,[NSString stringWithFormat:fmt,a1])
	#define DBG2(fmt,a1,a2)				IPMsgLog(_LOG_DBG,[NSString stringWithFormat:fmt,a1,a2])
	#define DBG3(fmt,a1,a2,a3)			IPMsgLog(_LOG_DBG,[NSString stringWithFormat:fmt,a1,a2,a3])
	#define DBG4(fmt,a1,a2,a3,a4)		IPMsgLog(_LOG_DBG,[NSString stringWithFormat:fmt,a1,a2,a3,a4])
	#define DBG5(fmt,a1,a2,a3,a4,a5)	IPMsgLog(_LOG_DBG,[NSString stringWithFormat:fmt,a1,a2,a3,a4,a5])
#else
	#define DBG0(fmt)
	#define DBG1(fmt,a1)
	#define DBG2(fmt,a1,a2)
	#define DBG3(fmt,a1,a2,a3)
	#define DBG4(fmt,a1,a2,a3,a4)
	#define DBG5(fmt,a1,a2,a3,a4,a5)
#endif

/*============================================================================*
 * 警告レベルログ
 *============================================================================*/

#if defined(IPMSG_DEBUG) && (IPMSG_LOG_WRN == 1)
	#define _LOG_WRN					@"W-",__FILE__,__LINE__
	#define WRN0(fmt)					IPMsgLog(_LOG_WRN,fmt)
	#define WRN1(fmt,a1)				IPMsgLog(_LOG_WRN,[NSString stringWithFormat:fmt,a1])
	#define WRN2(fmt,a1,a2)				IPMsgLog(_LOG_WRN,[NSString stringWithFormat:fmt,a1,a2])
	#define WRN3(fmt,a1,a2,a3)			IPMsgLog(_LOG_WRN,[NSString stringWithFormat:fmt,a1,a2,a3])
	#define WRN4(fmt,a1,a2,a3,a4)		IPMsgLog(_LOG_WRN,[NSString stringWithFormat:fmt,a1,a2,a3,a4])
	#define WRN5(fmt,a1,a2,a3,a4,a5)	IPMsgLog(_LOG_WRN,[NSString stringWithFormat:fmt,a1,a2,a3,a4,a5])
#else
	#define WRN0(fmt)
	#define WRN1(fmt,a1)
	#define WRN2(fmt,a1,a2)
	#define WRN3(fmt,a1,a2,a3)
	#define WRN4(fmt,a1,a2,a3,a4)
	#define WRN5(fmt,a1,a2,a3,a4,a5)
#endif

/*============================================================================*
 * エラーレベルログ
 *============================================================================*/
 
#if defined(IPMSG_DEBUG) && (IPMSG_LOG_ERR == 1)
	#define _LOG_ERR					@"E*",__FILE__,__LINE__
	#define ERR0(fmt)					IPMsgLog(_LOG_ERR,fmt)
	#define ERR1(fmt,a1)				IPMsgLog(_LOG_ERR,[NSString stringWithFormat:fmt,a1])
	#define ERR2(fmt,a1,a2)				IPMsgLog(_LOG_ERR,[NSString stringWithFormat:fmt,a1,a2])
	#define ERR3(fmt,a1,a2,a3)			IPMsgLog(_LOG_ERR,[NSString stringWithFormat:fmt,a1,a2,a3])
	#define ERR4(fmt,a1,a2,a3,a4)		IPMsgLog(_LOG_ERR,[NSString stringWithFormat:fmt,a1,a2,a3,a4])
	#define ERR5(fmt,a1,a2,a3,a4,a5)	IPMsgLog(_LOG_ERR,[NSString stringWithFormat:fmt,a1,a2,a3,a4,a5])
#else
	#define ERR0(fmt)
	#define ERR1(fmt,a1)
	#define ERR2(fmt,a1,a2)
	#define ERR3(fmt,a1,a2,a3)
	#define ERR4(fmt,a1,a2,a3,a4)
	#define ERR5(fmt,a1,a2,a3,a4,a5)
#endif

/*============================================================================*
 * 関数プロトタイプ
 *============================================================================*/

#ifdef __cplusplus
extern "C" {
#endif

#if defined(IPMSG_DEBUG)
// ログ出力関数
void IPMsgLog(NSString* level, char* file, int line, NSString* msg);
#endif

#ifdef __cplusplus
}	// extern "C"
#endif
