/*============================================================================*
 * (C) 2001-2009 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for MacOS X
 *	File		: PrefControl.m
 *	Module		: 環境設定パネルコントローラ		
 *============================================================================*/

#import <Cocoa/Cocoa.h>
#import "PrefControl.h"
#import "AppControl.h"
#import "Config.h"
#import "RefuseInfo.h"
#import "MessageCenter.h"
#import "UserManager.h"
#import "LogManager.h"
#import "DebugLog.h"

#include <unistd.h>
#include <netinet/in.h>
#include <arpa/inet.h>

/*============================================================================*
 * クラス実装
 *============================================================================*/

@implementation PrefControl

/*----------------------------------------------------------------------------*
 * 最新状態に更新
 *----------------------------------------------------------------------------*/
 
- (void)update {
	Config*		config = [Config sharedConfig];
	NSString*	work;
	
	// 全般タブ
	[baseUserNameField			setStringValue:	[config userName]];
	[baseGroupNameField 		setStringValue:	[config groupName]];
	[baseLogOnNameField			setStringValue: NSUserName()];
	[baseMachineNameField		setStringValue:	[config machineName]];
	[baseMachineNameMatrix		selectCellAtRow:[config machineNameType] column:0];
	[[baseMachineNameMatrix cellAtRow:1 column:0] setEnabled:[config canUseAppleTalkHostname]];
	[baseHostDomainRmoveCheck	setEnabled:		([config machineNameType] == 0)];
	[baseHostDomainRmoveCheck	setState:		[config hostnameRemoveDomain]];
	[receiveStatusBarCheckBox	setState:		[config useStatusBar]];

	// 送信タブ
	[sendQuotField				setStringValue:	[config quoteString]];
	[sendSingleClickCheck		setState:		[config openNewOnDockClick]];
	[sendDefaultSealCheck		setState:		[config sealCheckDefault]];
	[sendHideWhenReplyCheck		setState:		[config hideReceiveWindowOnReply]];
	[sendOpenNotifyCheck		setState:		[config noticeSealOpened]];
	[sendAllUsersCheck			setState:		[config sendAllUsersCheckEnabled]];
	[sendMultipleUserCheck		setState:		[config allowSendingToMultiUser]];
	[sendAllUsersCheck			setEnabled:		[sendMultipleUserCheck state]];
	// 受信タブ
	work = [config receiveSoundName];
	if (work && ([work length] > 0)) {
		[receiveSoundPopup selectItemWithTitle:(work)];
	} else {
		[receiveSoundPopup selectItemAtIndex:0];
	}
	[receiveDefaultQuotCheck	setState:[config quoteCheckDefault]];
	[receiveNonPopupCheck		setState:[config nonPopup]];
	[receiveNonPopupModeMatrix	setEnabled:[config nonPopup]];
	[receiveNonPopupBoundMatrix setEnabled:[config nonPopup]];
	[receiveNonPopupBoundMatrix	selectCellWithTag:[config iconBoundModeInNonPopup]];
	if ([config nonPopupWhenAbsence]) {
		[receiveNonPopupModeMatrix selectCellAtRow:1 column:0];
	}
	[receiveClickableURLCheck	setState:[config useClickableURL]];
	
	// ネットワークタブ
	[netPortNoField				setIntValue:	[config portNo]];
	[netDialupCheck				setState:		[config dialup]];
	
	// ユーザリストタブ
	[userlistLogonDispCheck		setState:		[config displayLogOnName]];
	[userlistAddressDispCheck	setState:		[config displayIPAddress]];
	[userlistIgnoreCaseCheck	setState:		[config sortByIgnoreCase]];
	[userlistKanjiPriorityCheck	setState:		[config sortByKanjiPriority]];

	// ログタブ
	[logStdEnableCheck			setState:		[config standardLogEnabled]];
	[logStdWhenOpenChainCheck	setState:		[config logChainedWhenOpen]];
	[logStdWhenOpenChainCheck	setEnabled:		[config standardLogEnabled]];
	[logStdPathField			setStringValue:	[config standardLogFile]];
	[logStdPathField			setEnabled:		[config standardLogEnabled]];
	[logStdPathRefButton		setEnabled:		[config standardLogEnabled]];
	[logAltEnableCheck			setState:		[config alternateLogEnabled]];
	[logAltSelectionCheck		setState:		[config logWithSelectedRange]];
	[logAltSelectionCheck		setEnabled:		[config alternateLogEnabled]];
	[logAltPathField			setStringValue:	[config alternateLogFile]];
	[logAltPathField			setEnabled:		[config alternateLogEnabled]];
	[logAltPathRefButton		setEnabled:		[config alternateLogEnabled]];
	[logLineEndingsPopup		selectItem:		[logLineEndingsPopup itemAtIndex:[config logLineEnding]]];
}

/*----------------------------------------------------------------------------*
 *  ボタン押下時処理
 *----------------------------------------------------------------------------*/

- (IBAction)buttonPressed:(id)sender {
	// パスワード変更ボタン（シートオープン）
	if (sender == basePasswordButton) {
		NSString* password = [[Config sharedConfig] password];
		// フィールドの内容を最新に
		[pwdSheetOldPwdField setEnabled:NO];
		[pwdSheet setInitialFirstResponder:pwdSheetNewPwdField1];
		if (password) {
			if ([password length] > 0) {
				[pwdSheetOldPwdField setEnabled:YES];
				[pwdSheet setInitialFirstResponder:pwdSheetOldPwdField];
			}
		}
		[pwdSheetOldPwdField setStringValue:@""];
		[pwdSheetNewPwdField1 setStringValue:@""];
		[pwdSheetNewPwdField2 setStringValue:@""];
		[pwdSheetErrorLabel setStringValue:@""];
		// シート表示
		[NSApp beginSheet:pwdSheet
		   modalForWindow:panel
			modalDelegate:self
		   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
			  contextInfo:nil];
	}
	// パスワード変更シート変更（OK）ボタン
	else if (sender == pwdSheetOKButton) {
		NSString*	oldPwd		= [pwdSheetOldPwdField stringValue];
		NSString*	newPwd1		= [pwdSheetNewPwdField1 stringValue];
		NSString*	newPwd2		= [pwdSheetNewPwdField2 stringValue];
		NSString*	password	= [[Config sharedConfig] password];
		[pwdSheetErrorLabel setStringValue:@""];
		// 旧パスワードチェック
		if (password) {
			if ([password length] > 0) {
				if ([oldPwd length] <= 0) {
					[pwdSheetErrorLabel setStringValue:NSLocalizedString(@"Pref.PwdMod.NoOldPwd", nil)];
					return;
				}
				if (![password isEqualToString:[NSString stringWithCString:crypt([oldPwd UTF8String], "IP")]] &&
					![password isEqualToString:oldPwd]) {
					// 平文とも比較するのはv0.4までとの互換性のため
					[pwdSheetErrorLabel setStringValue:NSLocalizedString(@"Pref.PwdMod.OldPwdErr", nil)];
					return;
				}
			}
		}
		// 新パスワード２回入力チェック
		if (![newPwd1 isEqualToString:newPwd2]) {
			[pwdSheetErrorLabel setStringValue:NSLocalizedString(@"Pref.PwdMod.NewPwdErr", nil)];
			return;
		}
		// ここまでくれば正しいのでパスワード値変更
		if ([newPwd1 length] > 0) {
			[[Config sharedConfig] setPassword:[NSString stringWithCString:crypt([newPwd1 UTF8String], "IP")]];
		} else {
			[[Config sharedConfig] setPassword:@""];
		}
		[NSApp endSheet:pwdSheet returnCode:NSOKButton];
	}
	// パスワード変更シートキャンセルボタン
	else if (sender == pwdSheetCancelButton) {
		[NSApp endSheet:pwdSheet returnCode:NSCancelButton];
	}
	// ブロードキャストアドレス追加ボタン（シートオープン）
	else if (sender == netBroadAddButton) {
		// フィールドの内容を初期化
		[bcastSheetField setStringValue:@""];
		[bcastSheetErrorLabel setStringValue:@""];
		[bcastSheetMatrix selectCellAtRow:0 column:0];
		[bcastSheetResolveCheck setEnabled:NO];
		[bcastSheet setInitialFirstResponder:bcastSheetField];

		// シート表示
		[NSApp beginSheet:bcastSheet
		   modalForWindow:panel
			modalDelegate:self
		   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
			  contextInfo:nil];
	}
	// ブロードキャストアドレス削除ボタン
	else if (sender == netBroadDeleteButton) {
		int index = [netBroadAddressTable selectedRow];
		if (index != -1) {
			[[Config sharedConfig] removeBroadcastAtIndex:index];
			[netBroadAddressTable reloadData];
			[netBroadAddressTable deselectAll:self];
		}
	}
	// ブロードキャストシートOKボタン
	else if (sender == bcastSheetOKButton) {
		Config*		config	= [Config sharedConfig];
		NSString*	string	= [bcastSheetField stringValue];
		BOOL		ip		= ([bcastSheetMatrix selectedColumn] == 0);
		// 入力文字列チェック
		if ([string length] <= 0) {
			if (ip) {
				[bcastSheetErrorLabel setStringValue:NSLocalizedString(@"Pref.Broadcast.EmptyIP", nil)];
			} else {
				[bcastSheetErrorLabel setStringValue:NSLocalizedString(@"Pref.Broadcast.EmptyHost", nil)];
			}
			return;
		}
		// IPアドレス設定の場合
		if (ip) {
			unsigned long 	inetaddr = inet_addr([string UTF8String]);
			struct in_addr	addr;
			NSString*		strAddr;
			if (inetaddr == INADDR_NONE) {
				[bcastSheetErrorLabel setStringValue:NSLocalizedString(@"Pref.Broadcast.WrongIP", nil)];
				return;
			}
			addr.s_addr = inetaddr;
			strAddr		= [NSString stringWithCString:inet_ntoa(addr)];
			if ([config containsBroadcastWithAddress:strAddr]) {
				[bcastSheetErrorLabel setStringValue:NSLocalizedString(@"Pref.Broadcast.ExistIP", nil)];
				return;
			}
			[config addBroadcastWithAddress:strAddr];
		}
		// ホスト名設定の場合
		else {
			// アドレス確認
			if ([bcastSheetResolveCheck state]) {
				if (![[NSHost hostWithName:string] address]) {
					[bcastSheetErrorLabel setStringValue:NSLocalizedString(@"Pref.Broadcast.UnknownHost", nil)];
					return;
				}
			}
			if ([config containsBroadcastWithHost:string]) {
				[bcastSheetErrorLabel setStringValue:NSLocalizedString(@"Pref.Broadcast.ExistHost", nil)];
				return;
			}
			[config addBroadcastWithHost:string];
		}
		[bcastSheetErrorLabel setStringValue:@""];
		[netBroadAddressTable reloadData];
		[NSApp endSheet:bcastSheet returnCode:NSOKButton];
	}
	// ブロードキャストシートキャンセルボタン
	else if (sender == bcastSheetCancelButton) {
		[NSApp endSheet:bcastSheet returnCode:NSCancelButton];
	}
	// 不在追加ボタン／編集ボタン
	else if ((sender == absenceAddButton) || (sender == absenceEditButton)) {
		NSString* title		= @"";
		NSString* msg		= @"";
		absenceEditIndex	= -1;
		if (sender == absenceEditButton) {
			Config* config		= [Config sharedConfig];
			absenceEditIndex	= [absenceTable selectedRow];
			title				= [config absenceTitleAtIndex:absenceEditIndex];
			msg					= [config absenceMessageAtIndex:absenceEditIndex];
		}
		// フィールドの内容を初期化
		[absenceSheetTitleField setStringValue:title];
		[absenceSheetMessageArea setString:msg];
		[absenceSheetErrorLabel setStringValue:@""];
		[absenceSheet setInitialFirstResponder:absenceSheetTitleField];
		
		// シート表示
		[NSApp beginSheet:absenceSheet
		   modalForWindow:panel
			modalDelegate:self
		   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
			  contextInfo:nil];
	}
	// 不在削除ボタン
	else if (sender == absenceDeleteButton) {
		Config* config	= [Config sharedConfig];
		int		absIdx	= [config absenceIndex];
		int		rmvIdx	= [absenceTable selectedRow];
		[config removeAbsenceAtIndex:rmvIdx];
		if (rmvIdx == absIdx) {
			[config setAbsenceIndex:-1];
			[[MessageCenter sharedCenter] broadcastAbsence];
		} else if (rmvIdx < absIdx) {
			[config setAbsenceIndex:absIdx - 1];
		}
		[absenceTable reloadData];
		[absenceTable deselectAll:self];
		[[NSApp delegate] buildAbsenceMenu];
	}
	// 不在上へボタン
	else if (sender == absenceUpButton) {
		Config* config	= [Config sharedConfig];
		int		absIdx	= [config absenceIndex];
		int		upIdx	= [absenceTable selectedRow];
		[config upAbsenceAtIndex:upIdx];
		if (upIdx == absIdx) {
			[config setAbsenceIndex:absIdx - 1];
		} else if (upIdx == absIdx + 1) {
			[config setAbsenceIndex:absIdx + 1];
		}
		[absenceTable reloadData];
		[absenceTable selectRow:upIdx-1 byExtendingSelection:NO];
		[[NSApp delegate] buildAbsenceMenu];
	}
	// 不在下へボタン	
	else if (sender == absenceDownButton) {
		Config* config	= [Config sharedConfig];
		int		absIdx	= [config absenceIndex];
		int		downIdx	= [absenceTable selectedRow];
		int index = [absenceTable selectedRow];
		[config downAbsenceAtIndex:downIdx];
		if (downIdx == absIdx) {
			[config setAbsenceIndex:absIdx + 1];
		} else if (downIdx == absIdx - 1) {
			[config setAbsenceIndex:absIdx - 1];
		}
		[absenceTable reloadData];
		[absenceTable selectRow:index+1 byExtendingSelection:NO];
		[[NSApp delegate] buildAbsenceMenu];
	}
	// 不在定義初期化ボタン
	else if (sender == absenceResetButton) {
		// 不在モードを解除して送信するか確認
		NSBeginCriticalAlertSheet(	NSLocalizedString(@"Pref.AbsenceReset.Title", nil),
									NSLocalizedString(@"Pref.AbsenceReset.OK", nil),
									NSLocalizedString(@"Pref.AbsenceReset.Cancel", nil),
									nil,
									panel,
									self,
									@selector(sheetDidEnd:returnCode:contextInfo:),
									nil,
									sender,
									NSLocalizedString(@"Pref.AbsenceReset.Msg", nil));
	}
	// 不在シートOKボタン
	else if (sender == absenceSheetOKButton) {
		Config*		config	= [Config sharedConfig];
		NSString*	title	= [absenceSheetTitleField stringValue];
		NSString*	msg		= [NSString stringWithString:[absenceSheetMessageArea string]];
		int			index	= [absenceTable selectedRow];
		int			absIdx	= [config absenceIndex];
		[absenceSheetErrorLabel setStringValue:@""];
		// タイトルチェック
		if ([title length] <= 0) {
			[absenceSheetErrorLabel setStringValue:NSLocalizedString(@"Pref.Absence.NoTitle", nil)];
			return;
		}
		if ([msg length] <= 0) {
			[absenceSheetErrorLabel setStringValue:NSLocalizedString(@"Pref.Absence.NoMessage", nil)];
			return;
		}
		if (absenceEditIndex == -1) {
			if ([config containsAbsenceTitle:title]) {
				[absenceSheetErrorLabel setStringValue:NSLocalizedString(@"Pref.Absence.ExistTitle", nil)];
				return;
			}
			[config addAbsenceTitle:title message:msg atIndex:index];
			if ((index != -1) && (absIdx != -1) && (index <= absIdx)) {
				[config setAbsenceIndex:absIdx + 1];
			}
		} else {
			[config setAbsenceTitle:title message:msg atIndex:index];
			if (absIdx == index) {
				[[MessageCenter sharedCenter] broadcastAbsence];
			}
		}
		[absenceTable reloadData];
		[absenceTable deselectAll:self];
		[absenceTable selectRow:((index == -1) ? 0 : (index)) byExtendingSelection:NO];
		[[NSApp delegate] buildAbsenceMenu];
		[NSApp endSheet:absenceSheet returnCode:NSOKButton];
	}
	// 不在シートCancelボタン
	else if (sender == absenceSheetCancelButton) {
		[NSApp endSheet:absenceSheet returnCode:NSCancelButton];
	}
	// 通知拒否追加ボタン／編集ボタン
	else if ((sender == refuseAddButton) || (sender == refuseEditButton)) {
		IPRefuseTarget		target		= 0;
		NSString* 			string		= @"";
		IPRefuseCondition	condition	= 0;
		
		refuseEditIndex	= -1;
		if (sender == refuseEditButton) {
			RefuseInfo*	info;
			refuseEditIndex	= [refuseTable selectedRow];
			info			= [[Config sharedConfig] refuseInfoAtIndex:refuseEditIndex];
			target			= [info target];
			string			= [info string];
			condition		= [info condition];
		}
		// フィールドの内容を初期化
		[refuseSheetField setStringValue:string];
		[refuseSheetTargetPopup selectItemAtIndex:target];
		[refuseSheetCondPopup selectItemAtIndex:condition];
		[refuseSheetErrorLabel setStringValue:@""];
		[refuseSheet setInitialFirstResponder:refuseSheetTargetPopup];
		
		// シート表示
		[NSApp beginSheet:refuseSheet
		   modalForWindow:panel
			modalDelegate:self
		   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
			  contextInfo:nil];
	}
	// 通知拒否削除ボタン
	else if (sender == refuseDeleteButton) {
		[[Config sharedConfig] removeRefuseInfoAtIndex:[refuseTable selectedRow]];
		[refuseTable reloadData];
		[refuseTable deselectAll:self];
// broadcast entry?
	}
	// 通知拒否上へボタン
	else if (sender == refuseUpButton) {
		int index = [refuseTable selectedRow];
		[[Config sharedConfig] upRefuseInfoAtIndex:index];
		[refuseTable reloadData];
		[refuseTable selectRow:index-1 byExtendingSelection:NO];
// broadcast entry?
	}
	// 通知拒否下へボタン	
	else if (sender == refuseDownButton) {
		int index = [refuseTable selectedRow];
		[[Config sharedConfig] downRefuseInfoAtIndex:index];
		[refuseTable reloadData];
		[refuseTable selectRow:index+1 byExtendingSelection:NO];
// broadcast entry?
	}
	// 通知拒否シートOKボタン
	else if (sender == refuseSheetOKButton) {
		IPRefuseTarget		target		= [refuseSheetTargetPopup indexOfSelectedItem];
		NSString*			string		= [refuseSheetField stringValue];
		IPRefuseCondition	condition	= [refuseSheetCondPopup indexOfSelectedItem];
		int					index		= [refuseTable selectedRow];
		RefuseInfo*			info;
		// 入力文字チェック
		if ([string length] <= 0) {
			[refuseSheetErrorLabel setStringValue:NSLocalizedString(@"Pref.Refuse.Error.NoInput", nil)];
			return;
		}
		
		info = [[[RefuseInfo alloc] initWithTarget:target string:string condition:condition] autorelease];
		if (refuseEditIndex == -1) {
			// 新規
			[[Config sharedConfig] addRefuseInfo:info atIndex:index];
			[refuseTable deselectAll:self];
		} else {
			// 変更
			[[Config sharedConfig] setRefuseInfo:info atIndex:refuseEditIndex];
		}
		[refuseTable reloadData];
		[NSApp endSheet:refuseSheet returnCode:NSOKButton];
	}
	// 通知拒否シートCancelボタン
	else if (sender == refuseSheetCancelButton) {
		[NSApp endSheet:refuseSheet returnCode:NSCancelButton];
	}
	// ユーザソートルール上へボタン
	else if (sender == userlistSortUpButton) {
		int index = [userlistSortTable selectedRow];
		[[Config sharedConfig] moveSortRuleFromIndex:index toIndex:index-1];
		[userlistSortTable reloadData];
		[userlistSortTable selectRow:index-1 byExtendingSelection:NO];
		[[UserManager sharedManager] sortUsers];
	}
	// ユーザソートルール下へボタン
	else if (sender == userlistSortDownButton) {
		int index = [userlistSortTable selectedRow];
		[[Config sharedConfig] moveSortRuleFromIndex:index toIndex:index+1];
		[userlistSortTable reloadData];
		[userlistSortTable selectRow:index+1 byExtendingSelection:NO];
		[[UserManager sharedManager] sortUsers];
	}
	// 標準ログファイル参照ボタン／重要ログファイル参照ボタン
	else if ((sender == logStdPathRefButton) || (sender == logAltPathRefButton)) {
		NSSavePanel*	sp = [NSSavePanel savePanel];
		NSString*		orgPath;
		// SavePanel 設定
		if (sender == logStdPathRefButton) {
			orgPath = [[Config sharedConfig] standardLogFile];
		} else {
			orgPath = [[Config sharedConfig] alternateLogFile];
		}
		[sp setRequiredFileType:@"log"];
		[sp setPrompt:NSLocalizedString(@"Log.File.SaveSheet.OK", nil)];
		// シート表示
		[sp beginSheetForDirectory:[orgPath stringByDeletingLastPathComponent]
							  file:[orgPath lastPathComponent]
					modalForWindow:panel
					 modalDelegate:self
					didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
					   contextInfo:sender];
	}
	// その他（バグ）
	else {
		ERR1(@"unknwon button pressed. %@", sender);
	}	
}

/*----------------------------------------------------------------------------*
 *  Matrix変更時処理
 *----------------------------------------------------------------------------*/
 
- (IBAction)matrixChanged:(id)sender {
	Config* config = [Config sharedConfig];
	// 全般：ホスト名取得元
	if (sender == baseMachineNameMatrix) {
		[config setMachineNameType:[baseMachineNameMatrix selectedRow]];
		[baseHostDomainRmoveCheck setEnabled:([config machineNameType] == 0)];
		[baseMachineNameField setStringValue:[config machineName]];
		[[MessageCenter sharedCenter] broadcastAbsence];
	}
	// 受信：ノンポップアップ受信モード
	else if (sender == receiveNonPopupModeMatrix) {
		[config setNonPopupWhenAbsence:([receiveNonPopupModeMatrix selectedRow] == 1)];
	}
	// 受信：ノンポップアップ時アイコンバウンド設定
	else if (sender == receiveNonPopupBoundMatrix) {
		[config setIconBoundModeInNonPopup:[[sender selectedCell] tag]];
	}
	// ブロードキャスト種別
	else if (sender == bcastSheetMatrix) {
		[bcastSheetResolveCheck setEnabled:([bcastSheetMatrix selectedColumn] == 1)];
	}
	// その他
	else {
		ERR1(@"unknown matrix changed. %@", sender);
	}
}

/*----------------------------------------------------------------------------*
 *  テキストフィールド変更時処理
 *----------------------------------------------------------------------------*/

- (BOOL)control:(NSControl*)control textShouldEndEditing:(NSText*)fieldEditor {
	// 全般：ユーザ名
	if (control == baseUserNameField) {
		NSRange r = [[fieldEditor string] rangeOfString:@":"];
		if (r.location != NSNotFound) {
			return NO;
		}
	}
	// 全般：グループ名
	else if (control == baseGroupNameField) {
		NSRange r = [[fieldEditor string] rangeOfString:@":"];
		if (r.location != NSNotFound) {
			return NO;
		}
	}
	return YES;
}

- (void)controlTextDidEndEditing:(NSNotification*)aNotification {
	Config* config	= [Config sharedConfig];
	id		obj		= [aNotification object];
	// 全般：ユーザ名
	if (obj == baseUserNameField) {
		[config setUserName:[baseUserNameField stringValue]];
		[[MessageCenter sharedCenter] broadcastAbsence];
	}
	// 全般：グループ名
	else if (obj == baseGroupNameField) {
		[config setGroupName:[baseGroupNameField stringValue]];
		[[MessageCenter sharedCenter] broadcastAbsence];
	}
	// 全般：ポート番号
	else if (obj == netPortNoField) {
		[config setPortNo:[netPortNoField intValue]];
	}
	// 送信：引用文字列
	else if (obj == sendQuotField) {
		[config setQuoteString:[sendQuotField stringValue]];
	}
	// ログ：標準ログ
	else if (obj == logStdPathField) {
		NSString* path = [logStdPathField stringValue];
		[config setStandardLogFile:path];
		[[LogManager standardLog] setFilePath:path];
	}
	// ログ：重要ログ
	else if (obj == logAltPathField) {
		NSString* path = [logAltPathField stringValue];
		[config setAlternateLogFile:path];
		[[LogManager alternateLog] setFilePath:path];
	}
	// その他（バグ）
	else {
		ERR1(@"unknwon text end edit. %@", obj);
	}
}

/*----------------------------------------------------------------------------*
 *  チェックボックス変更時処理
 *----------------------------------------------------------------------------*/

- (IBAction)checkboxChanged:(id)sender {
	Config* config = [Config sharedConfig];
	// 全般：ドメインサフィックスを除去
	if (sender == baseHostDomainRmoveCheck) {
		[config setHostnameRemoveDomain:[baseHostDomainRmoveCheck state]];
		[baseMachineNameField setStringValue:[config machineName]];
		[[MessageCenter sharedCenter] broadcastAbsence];
	}
	// 全般：ステータスバーを使用するか
	else if (sender == receiveStatusBarCheckBox) {
		AppControl* appCtl = (AppControl*)[NSApp delegate];
		[config setUseStatusBar:[receiveStatusBarCheckBox state]];
		if ([config useStatusBar]) {
			[appCtl initStatusBar];
		} else {
			[appCtl removeStatusBar];
		}
	}
	// 送信：DOCKのシングルクリックで新規送信ウィンドウ
	else if (sender == sendSingleClickCheck) {
		[config setOpenNewOnDockClick:[sendSingleClickCheck state]];
	}
	// 送信：引用チェックをデフォルト
	else if (sender == sendDefaultSealCheck) {
		[config setSealCheckDefault:[sendDefaultSealCheck state]];
	}
	// 送信：返信時に受信ウィンドウをクローズ
	else if (sender == sendHideWhenReplyCheck) {
		[config setHideReceiveWindowOnReply:[sendHideWhenReplyCheck state]];
	}
	// 送信：開封通知を行う
	else if (sender == sendOpenNotifyCheck) {
		[config setNoticeSealOpened:[sendOpenNotifyCheck state]];
	}
	// 送信：全員に送信チェック有効
	else if (sender == sendAllUsersCheck) {
		[config setSendAllUsersCheckEnabled:[sendAllUsersCheck state]];
	}
	// 送信：複数ユーザ宛送信を許可
	else if (sender == sendMultipleUserCheck) {
		[config setAllowSendingToMultiUser:[sendMultipleUserCheck state]];
		[sendAllUsersCheck setEnabled:[sendMultipleUserCheck state]];
		if (![sendMultipleUserCheck state]) {
			[config setSendAllUsersCheckEnabled:NO];
			[sendAllUsersCheck setState:NO];
		}
	}
	// 受信：引用チェックをデフォルト
	else if (sender == receiveDefaultQuotCheck) {
		[config setQuoteCheckDefault:[receiveDefaultQuotCheck state]];
	}
	// 受信：ノンポップアップ受信
	else if (sender == receiveNonPopupCheck) {
		[config setNonPopup:[receiveNonPopupCheck state]];
		[receiveNonPopupModeMatrix setEnabled:[receiveNonPopupCheck state]];
		[receiveNonPopupBoundMatrix setEnabled:[receiveNonPopupCheck state]];
	}
	// 受信：クリッカブルURL
	else if (sender == receiveClickableURLCheck) {
		[config setUseClickableURL:[receiveClickableURLCheck state]];
	}
	// ネットワーク：ダイアルアップ接続
	else if (sender == netDialupCheck) {
		[config setDialup:[netDialupCheck state]];
	}
	// ユーザリスト：ログオン名を表示する
	else if (sender == userlistLogonDispCheck) {
		[config setDisplayLogOnName:[userlistLogonDispCheck state]];
		[[UserManager sharedManager] sortUsers];
	}
	// ユーザリスト：IPアドレスを表示する
	else if (sender == userlistAddressDispCheck) {
		[config setDisplayIPAddress:[userlistAddressDispCheck state]];
		[[UserManager sharedManager] sortUsers];
	}
	// ユーザリスト：大文字小文字を無視する
	else if (sender == userlistIgnoreCaseCheck) {
		[config setSortByIgnoreCase:[userlistIgnoreCaseCheck state]];
		[[UserManager sharedManager] sortUsers];
	}
	// ユーザリスト：漢字を優先する
	else if (sender == userlistKanjiPriorityCheck) {
		[config setSortByKanjiPriority:[userlistKanjiPriorityCheck state]];
		[[UserManager sharedManager] sortUsers];
	}
	// ログ：標準ログを使用する
	else if (sender == logStdEnableCheck) {
		BOOL enable = [logStdEnableCheck state];
		[config setStandardLogEnabled:enable];
		[logStdWhenOpenChainCheck setEnabled:enable];
		[logStdPathField setEnabled:enable];
		[logStdPathRefButton setEnabled:enable];
		if (!enable) {
			[logStdWhenOpenChainCheck setState:NO];
		}
	}
	// ログ：錠前付きは開封後にログ
	else if (sender == logStdWhenOpenChainCheck) {
		[config setLogChainedWhenOpen:[logStdWhenOpenChainCheck state]];
	}
	// ログ：重要ログを使用する
	else if (sender == logAltEnableCheck) {
		BOOL enable = [logAltEnableCheck state];
		[config setAlternateLogEnabled:enable];
		[logAltSelectionCheck setEnabled:enable];
		[logAltPathField setEnabled:enable];
		[logAltPathRefButton setEnabled:enable];
		if (!enable) {
			[logAltSelectionCheck setState:NO];
		}
	}
	// ログ：選択範囲を記録
	else if (sender == logAltSelectionCheck) {
		[config setLogWithSelectedRange:[logAltSelectionCheck state]];
	}
	// 不明（バグ）
	else {
		ERR1(@"unknwon chackbox changed. %@", sender);
	}
}
 
/*----------------------------------------------------------------------------*
 *  プルダウン変更時処理
 *----------------------------------------------------------------------------*/

- (IBAction)popupChanged:(id)sender {
	Config* config = [Config sharedConfig];
	// 受信音
	if (sender == receiveSoundPopup) {
		if ([receiveSoundPopup indexOfSelectedItem] > 0) {
			[config setReceiveSoundWithName:[receiveSoundPopup titleOfSelectedItem]];
			[[config receiveSound] play];
		} else {
			[config setReceiveSoundWithName:nil];
		}
	}
	// 改行コード
	else if (sender == logLineEndingsPopup) {
		[config setLogLineEnding:[logLineEndingsPopup indexOfSelectedItem]];
	}
	// その他（バグ）
	else {
		ERR1(@"unknown popup changed. %@", sender);
	}
}

/*----------------------------------------------------------------------------*
 *  リスト選択変更時処理
 *----------------------------------------------------------------------------*/
 
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
	id tbl = [aNotification object];
	// ブロードキャストリスト
	if (tbl == netBroadAddressTable) {
		// １つ以上のアドレスが選択されていない場合は削除ボタンが押下不可
		[netBroadDeleteButton setEnabled:([netBroadAddressTable numberOfSelectedRows] > 0)];
	}
	// 不在リスト
	else if (tbl == absenceTable) {
		int index = [absenceTable selectedRow];
		[absenceEditButton setEnabled:(index != -1)];
		[absenceDeleteButton setEnabled:(index != -1)];
		[absenceUpButton setEnabled:(index > 0)];
		[absenceDownButton setEnabled:((index >= 0) && (index < [absenceTable numberOfRows] - 1))];
	}
	// 通知拒否リスト
	else if (tbl == refuseTable) {
		int index = [refuseTable selectedRow];
		[refuseEditButton setEnabled:(index != -1)];
		[refuseDeleteButton setEnabled:(index != -1)];
		[refuseUpButton setEnabled:(index > 0)];
		[refuseDownButton setEnabled:((index >= 0) && (index < [refuseTable numberOfRows] - 1))];
	}
	// ソートルール
	else if (tbl == userlistSortTable) {
		int index = [userlistSortTable selectedRow];
		[userlistSortUpButton setEnabled:(index > 0)];
		[userlistSortDownButton setEnabled:((index >= 0) && (index < [userlistSortTable numberOfRows] - 1))];
	}
	// その他（バグ）
	else {
		ERR1(@"unknown table selection changed (%@)", tbl);
	}
}

// テーブルダブルクリック時処理
- (void)tableDoubleClicked:(id)sender {
	int index = [sender selectedRow];
	// 不在定義リスト
	if (sender == absenceTable) {
		if (index >= 0) {
			[absenceEditButton performClick:self];
		}
	}
	// 通知拒否条件リスト
	else if (sender == refuseTable) {
		if (index >= 0) {
			[refuseEditButton performClick:self];
		}
	}
	// その他（バグ）
	else {
		ERR1(@"unknown table double clicked (%@)", sender);
	}
}

/*----------------------------------------------------------------------------*
 *  シート終了時処理
 *----------------------------------------------------------------------------*/
 
- (void)sheetDidEnd:(NSWindow*)sheet returnCode:(int)code contextInfo:(void*)info {
	// 不在定義リセット
	if (info == absenceResetButton) {
		if (code == NSOKButton) {
			[[Config sharedConfig] resetAllAbsences];
			[absenceTable reloadData];
			[absenceTable deselectAll:self];
			[[NSApp delegate] buildAbsenceMenu];
		}
	}
	// 標準ログ選択
	else if (info == logStdPathRefButton) {
		if (code == NSOKButton) {
			NSSavePanel*	sp = (NSSavePanel*)sheet;
			NSString*		fn = [[sp filename] stringByAbbreviatingWithTildeInPath];
			[[Config sharedConfig] setStandardLogFile:fn];
			[logStdPathField setStringValue:fn];
		}
	}
	// 重要ログ選択
	else if (info == logAltPathRefButton) {
		if (code == NSOKButton) {
			NSSavePanel*	sp = (NSSavePanel*)sheet;
			NSString*		fn = [[sp filename] stringByAbbreviatingWithTildeInPath];
			[[Config sharedConfig] setAlternateLogFile:fn];
			[logAltPathField setStringValue:fn];
		}
	}
	[sheet orderOut:self];
}

/*----------------------------------------------------------------------------*
 * NSTableDataSourceメソッド
 *----------------------------------------------------------------------------*/

- (int)numberOfRowsInTableView:(NSTableView*)aTableView {
	// ブロードキャスト
	if (aTableView == netBroadAddressTable) {
		return [[Config sharedConfig] numberOfBroadcasts];
	}
	// 不在
	else if (aTableView == absenceTable) {
		return [[Config sharedConfig] numberOfAbsences];
	}
	// 通知拒否
	else if (aTableView == refuseTable) {
		return [[Config sharedConfig] numberOfRefuseInfo];
	}
	// ユーザリストソート
	else if (aTableView == userlistSortTable) {
		return [[Config sharedConfig] numberOfSortRules];
	}
	// その他（バグ）
	else {
		ERR1(@"number of rows in unknown table (%@)", aTableView);
	}
	return 0;
}

- (id)tableView:(NSTableView*)aTableView
		objectValueForTableColumn:(NSTableColumn*)aTableColumn
		row:(int)rowIndex {
	// ブロードキャスト
	if (aTableView == netBroadAddressTable) {
		return [[Config sharedConfig] broadcastAtIndex:rowIndex];
	}
	// 不在
	else if (aTableView == absenceTable) {
		return [[Config sharedConfig] absenceTitleAtIndex:rowIndex];
	}
	// 通知拒否リスト
	else if (aTableView == refuseTable) {
		return [[Config sharedConfig] refuseInfoAtIndex:rowIndex];
	}
	// ユーザリストソート
	else if (aTableView == userlistSortTable) {
		NSString* key = [aTableColumn identifier];
		if ([key isEqualToString:@"OnOff"]) {
			return [NSNumber numberWithBool:[[Config sharedConfig] sortRuleEnabledAtIndex:rowIndex]];
		}
		else if ([key isEqualToString:@"ConditionName"]) {
			switch ([[Config sharedConfig] sortRuleTypeAtIndex:rowIndex]) {
			case IPMSG_SORT_NAME:
				return NSLocalizedString(@"Sort.RuleName.Name", nil);
			case IPMSG_SORT_GROUP:
				return NSLocalizedString(@"Sort.RuleName.Group", nil);
			case IPMSG_SORT_IP:
				return NSLocalizedString(@"Sort.RuleName.Address", nil);
			case IPMSG_SORT_MACHINE:
				return NSLocalizedString(@"Sort.RuleName.Machine", nil);
			case IPMSG_SORT_DESCRIPTION:
				return NSLocalizedString(@"Sort.RuleName.Description", nil);
			default:
				return NSLocalizedString(@"Sort.RuleName.Unknown", nil);
			}
		}
		else if ([key isEqualToString:@"SortOrder"]) {
			switch ([[Config sharedConfig] sortRuleOrderAtIndex:rowIndex]) {
			case IPMSG_SORT_DESC:
				return [NSNumber numberWithInt:1];
			case IPMSG_SORT_ASC:
			default:
				return [NSNumber numberWithInt:0];
			}
		}
	}
	// その他（バグ）
	else {
		ERR1(@"object in unknown table (%@)", aTableView);
	}
	return nil;
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)value
					forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex {
	if (aTableView == userlistSortTable) {
		NSString* key = [aTableColumn identifier];
		if ([key isEqualToString:@"OnOff"]) {
			[[Config sharedConfig] setSortRuleEnabled:[value boolValue] atIndex:rowIndex];
			[[UserManager sharedManager] sortUsers];
		}
		else if ([key isEqualToString:@"SortOrder"]) {
			[[Config sharedConfig] setSortRuleOrder:(([value intValue] == 1) ? IPMSG_SORT_DESC : IPMSG_SORT_ASC) atIndex:rowIndex];
			[[UserManager sharedManager] sortUsers];
		}
	}
}

/*----------------------------------------------------------------------------*
 *  その他
 *----------------------------------------------------------------------------*/

// 初期化
- (void)awakeFromNib {	
	NSTableColumn*		column;
	NSButtonCell*		buttonCell;
	NSPopUpButtonCell*	popupCell;

	// サウンドプルダウンを準備
	NSFileManager*	fm		= [NSFileManager defaultManager];
	NSArray*		dirs	= NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSAllDomainsMask, YES);
	int				i, j;

	for (i = 0; i < [dirs count]; i++) {
		NSString*	dir		= [[dirs objectAtIndex:i] stringByAppendingPathComponent:@"Sounds"];
		NSArray*	files	= [fm directoryContentsAtPath:dir];
		for (j = 0; j < [files count]; j++) {
			[receiveSoundPopup addItemWithTitle:[[files objectAtIndex:j] stringByDeletingPathExtension]];
		}
	}

	// ソートリストdataCell設定
	column		= [userlistSortTable tableColumnWithIdentifier:@"OnOff"];
	buttonCell	= [[[NSButtonCell alloc] init] autorelease];
	[buttonCell setButtonType:NSSwitchButton];
	[buttonCell setTitle:@""];
	[buttonCell setControlSize:NSSmallControlSize];
	[column setDataCell:buttonCell];
	column		= [userlistSortTable tableColumnWithIdentifier:@"SortOrder"];
	popupCell	= [[[NSPopUpButtonCell alloc] init] autorelease];
	[popupCell setBordered:NO];
	[popupCell setControlSize:NSSmallControlSize];
	[popupCell setImagePosition:NSImageLeft];
	[popupCell addItemWithTitle:NSLocalizedString(@"Sort.RuleOrder.Ascending", nil)];
	[popupCell addItemWithTitle:NSLocalizedString(@"Sort.RuleOrder.Descending", nil)];
	[column setDataCell:popupCell];

	// テーブルダブルクリック時設定
	[absenceTable setDoubleAction:@selector(tableDoubleClicked:)];
	[refuseTable setDoubleAction:@selector(tableDoubleClicked:)];
	
	// テーブルドラッグ設定
	
	// コントロールの設定値を最新状態に
	[self update];

	// 画面中央に移動
	[panel center];
}

// ウィンドウ表示時
- (void)windowDidBecomeKey:(NSNotification *)aNotification {
	[self update];
}

// ウィンドウクローズ時
- (void)windowWillClose:(NSNotification *)aNotification {
	// 設定を保存
	[[Config sharedConfig] save];
}

@end
