import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n? of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n);
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('zh'),
    Locale('en')
  ];

  /// No description provided for @appName.
  ///
  /// In zh, this message translates to:
  /// **'PetPogo'**
  String get appName;

  /// No description provided for @navHome.
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get navHome;

  /// No description provided for @navMessage.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get navMessage;

  /// No description provided for @navCommunity.
  ///
  /// In zh, this message translates to:
  /// **'社区'**
  String get navCommunity;

  /// No description provided for @navMall.
  ///
  /// In zh, this message translates to:
  /// **'商城'**
  String get navMall;

  /// No description provided for @navProfile.
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get navProfile;

  /// No description provided for @homeGreeting.
  ///
  /// In zh, this message translates to:
  /// **'你好，铲屎官！'**
  String get homeGreeting;

  /// No description provided for @homeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'来看看你的宠物今天在想什么吧？'**
  String get homeSubtitle;

  /// No description provided for @homeConnectedDevices.
  ///
  /// In zh, this message translates to:
  /// **'已连接设备'**
  String get homeConnectedDevices;

  /// No description provided for @homeDevicesActive.
  ///
  /// In zh, this message translates to:
  /// **'{count} 台设备在线'**
  String homeDevicesActive(int count);

  /// No description provided for @homeAddDevice.
  ///
  /// In zh, this message translates to:
  /// **'添加设备'**
  String get homeAddDevice;

  /// No description provided for @aiTranslateTitle.
  ///
  /// In zh, this message translates to:
  /// **'AI 宠物翻译'**
  String get aiTranslateTitle;

  /// No description provided for @aiTranslateBadge.
  ///
  /// In zh, this message translates to:
  /// **'AI 翻译已启动'**
  String get aiTranslateBadge;

  /// No description provided for @aiTranslateDesc.
  ///
  /// In zh, this message translates to:
  /// **'把手机对准你的宠物\n然后录制它发出的声音。'**
  String get aiTranslateDesc;

  /// No description provided for @aiTranslateHoldRecord.
  ///
  /// In zh, this message translates to:
  /// **'长按录音'**
  String get aiTranslateHoldRecord;

  /// No description provided for @aiTranslateRecording.
  ///
  /// In zh, this message translates to:
  /// **'正在录音...'**
  String get aiTranslateRecording;

  /// No description provided for @aiTranslateRelease.
  ///
  /// In zh, this message translates to:
  /// **'松开手指完成录制'**
  String get aiTranslateRelease;

  /// No description provided for @aiTranslateStop.
  ///
  /// In zh, this message translates to:
  /// **'停止录音'**
  String get aiTranslateStop;

  /// No description provided for @aiTranslateAnalyzing.
  ///
  /// In zh, this message translates to:
  /// **'AI 正在分析宠物声音...'**
  String get aiTranslateAnalyzing;

  /// No description provided for @aiTranslatePetSays.
  ///
  /// In zh, this message translates to:
  /// **'💬 宠物说：'**
  String get aiTranslatePetSays;

  /// No description provided for @aiTranslateAgain.
  ///
  /// In zh, this message translates to:
  /// **'再次翻译'**
  String get aiTranslateAgain;

  /// No description provided for @deviceOnline.
  ///
  /// In zh, this message translates to:
  /// **'在线'**
  String get deviceOnline;

  /// No description provided for @deviceOffline.
  ///
  /// In zh, this message translates to:
  /// **'离线'**
  String get deviceOffline;

  /// No description provided for @deviceBattery.
  ///
  /// In zh, this message translates to:
  /// **'电量 {level}%'**
  String deviceBattery(int level);

  /// No description provided for @deviceLocation.
  ///
  /// In zh, this message translates to:
  /// **'位置'**
  String get deviceLocation;

  /// No description provided for @deviceRing.
  ///
  /// In zh, this message translates to:
  /// **'响铃'**
  String get deviceRing;

  /// No description provided for @deviceDetails.
  ///
  /// In zh, this message translates to:
  /// **'详情'**
  String get deviceDetails;

  /// No description provided for @deviceBind.
  ///
  /// In zh, this message translates to:
  /// **'绑定新设备'**
  String get deviceBind;

  /// No description provided for @deviceBindSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'绑定 KeyTracker 或 PetPhone 开启智能追踪'**
  String get deviceBindSubtitle;

  /// No description provided for @deviceNowPlaying.
  ///
  /// In zh, this message translates to:
  /// **'正在播放'**
  String get deviceNowPlaying;

  /// No description provided for @communityTitle.
  ///
  /// In zh, this message translates to:
  /// **'社区'**
  String get communityTitle;

  /// No description provided for @communityTabFollowing.
  ///
  /// In zh, this message translates to:
  /// **'关注'**
  String get communityTabFollowing;

  /// No description provided for @communityTabDiscover.
  ///
  /// In zh, this message translates to:
  /// **'发现'**
  String get communityTabDiscover;

  /// No description provided for @communityFeaturedStory.
  ///
  /// In zh, this message translates to:
  /// **'精选故事'**
  String get communityFeaturedStory;

  /// No description provided for @communityAllPets.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get communityAllPets;

  /// No description provided for @communityDogs.
  ///
  /// In zh, this message translates to:
  /// **'狗'**
  String get communityDogs;

  /// No description provided for @communityCats.
  ///
  /// In zh, this message translates to:
  /// **'猫'**
  String get communityCats;

  /// No description provided for @communityBirds.
  ///
  /// In zh, this message translates to:
  /// **'鸟'**
  String get communityBirds;

  /// No description provided for @communityOthers.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get communityOthers;

  /// No description provided for @mallTitle.
  ///
  /// In zh, this message translates to:
  /// **'商城'**
  String get mallTitle;

  /// No description provided for @mallSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索商品'**
  String get mallSearch;

  /// No description provided for @mallAddToCart.
  ///
  /// In zh, this message translates to:
  /// **'加入购物车'**
  String get mallAddToCart;

  /// No description provided for @mallBuyNow.
  ///
  /// In zh, this message translates to:
  /// **'立即购买'**
  String get mallBuyNow;

  /// No description provided for @mallNearbyStores.
  ///
  /// In zh, this message translates to:
  /// **'附近门店'**
  String get mallNearbyStores;

  /// No description provided for @mallCategories.
  ///
  /// In zh, this message translates to:
  /// **'分类'**
  String get mallCategories;

  /// No description provided for @mallViewAll.
  ///
  /// In zh, this message translates to:
  /// **'查看全部'**
  String get mallViewAll;

  /// No description provided for @mallTrending.
  ///
  /// In zh, this message translates to:
  /// **'热门推荐'**
  String get mallTrending;

  /// No description provided for @mallComingSoon.
  ///
  /// In zh, this message translates to:
  /// **'即将上线'**
  String get mallComingSoon;

  /// No description provided for @mallHeroBannerTitle.
  ///
  /// In zh, this message translates to:
  /// **'全新\nPetPhone\n发布'**
  String get mallHeroBannerTitle;

  /// No description provided for @mallHeroBannerDesc.
  ///
  /// In zh, this message translates to:
  /// **'实时健康监测\n与情绪分析。'**
  String get mallHeroBannerDesc;

  /// No description provided for @mallPreorder.
  ///
  /// In zh, this message translates to:
  /// **'立即预订'**
  String get mallPreorder;

  /// No description provided for @mallReviews.
  ///
  /// In zh, this message translates to:
  /// **'{count} 条评价'**
  String mallReviews(int count);

  /// No description provided for @mallCategoryFood.
  ///
  /// In zh, this message translates to:
  /// **'食品'**
  String get mallCategoryFood;

  /// No description provided for @mallCategoryFoodCount.
  ///
  /// In zh, this message translates to:
  /// **'1200+ 件商品'**
  String get mallCategoryFoodCount;

  /// No description provided for @mallCategoryToys.
  ///
  /// In zh, this message translates to:
  /// **'玩具'**
  String get mallCategoryToys;

  /// No description provided for @mallCategoryToysCount.
  ///
  /// In zh, this message translates to:
  /// **'850+ 件商品'**
  String get mallCategoryToysCount;

  /// No description provided for @messageTitle.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get messageTitle;

  /// No description provided for @messageDirectMessages.
  ///
  /// In zh, this message translates to:
  /// **'私信'**
  String get messageDirectMessages;

  /// No description provided for @messageFriendRequests.
  ///
  /// In zh, this message translates to:
  /// **'{count} 条好友申请'**
  String messageFriendRequests(int count);

  /// No description provided for @messageFriendRequestDesc.
  ///
  /// In zh, this message translates to:
  /// **'{petName} 的主人申请加为好友'**
  String messageFriendRequestDesc(String petName);

  /// No description provided for @messageView.
  ///
  /// In zh, this message translates to:
  /// **'查看'**
  String get messageView;

  /// No description provided for @messageSystemNotif.
  ///
  /// In zh, this message translates to:
  /// **'系统通知'**
  String get messageSystemNotif;

  /// No description provided for @messageSystemNotifDesc.
  ///
  /// In zh, this message translates to:
  /// **'有人点赞了你的帖子'**
  String get messageSystemNotifDesc;

  /// No description provided for @messageInteraction.
  ///
  /// In zh, this message translates to:
  /// **'互动通知'**
  String get messageInteraction;

  /// No description provided for @messageInteractionDesc.
  ///
  /// In zh, this message translates to:
  /// **'Cooper 收到了 12 个点赞'**
  String get messageInteractionDesc;

  /// No description provided for @messageLoginPrompt.
  ///
  /// In zh, this message translates to:
  /// **'登录后查看消息'**
  String get messageLoginPrompt;

  /// No description provided for @messageLoginSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'与其他宠物主人互动'**
  String get messageLoginSubtitle;

  /// No description provided for @messageBindPhone.
  ///
  /// In zh, this message translates to:
  /// **'绑定手机号'**
  String get messageBindPhone;

  /// No description provided for @messageEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无消息'**
  String get messageEmpty;

  /// No description provided for @messageEmptySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'与宠物爱好者们聊起来吧！'**
  String get messageEmptySubtitle;

  /// No description provided for @profileTitle.
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get profileTitle;

  /// No description provided for @profileMyPets.
  ///
  /// In zh, this message translates to:
  /// **'我的宠物'**
  String get profileMyPets;

  /// No description provided for @profileAddNew.
  ///
  /// In zh, this message translates to:
  /// **'添加宠物'**
  String get profileAddNew;

  /// No description provided for @profileFollowers.
  ///
  /// In zh, this message translates to:
  /// **'粉丝'**
  String get profileFollowers;

  /// No description provided for @profileFollowing.
  ///
  /// In zh, this message translates to:
  /// **'关注'**
  String get profileFollowing;

  /// No description provided for @profilePosts.
  ///
  /// In zh, this message translates to:
  /// **'发帖'**
  String get profilePosts;

  /// No description provided for @profilePetParentSince.
  ///
  /// In zh, this message translates to:
  /// **'宠物主人，自 {year}'**
  String profilePetParentSince(String year);

  /// No description provided for @profileBoundDevices.
  ///
  /// In zh, this message translates to:
  /// **'绑定设备'**
  String get profileBoundDevices;

  /// No description provided for @profileOrderHistory.
  ///
  /// In zh, this message translates to:
  /// **'历史订单'**
  String get profileOrderHistory;

  /// No description provided for @profileMyPosts.
  ///
  /// In zh, this message translates to:
  /// **'我的帖子'**
  String get profileMyPosts;

  /// No description provided for @profileSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get profileSettings;

  /// No description provided for @profileLogout.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get profileLogout;

  /// No description provided for @profileGuestMode.
  ///
  /// In zh, this message translates to:
  /// **'游客模式'**
  String get profileGuestMode;

  /// No description provided for @profileGuestSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'绑定手机号，享受完整功能'**
  String get profileGuestSubtitle;

  /// No description provided for @profileLoginRegister.
  ///
  /// In zh, this message translates to:
  /// **'登录 / 注册'**
  String get profileLoginRegister;

  /// No description provided for @profileVaccinated.
  ///
  /// In zh, this message translates to:
  /// **'已接种'**
  String get profileVaccinated;

  /// No description provided for @profileCheckupDue.
  ///
  /// In zh, this message translates to:
  /// **'待复诊'**
  String get profileCheckupDue;

  /// No description provided for @settingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTitle;

  /// No description provided for @settingsSectionService.
  ///
  /// In zh, this message translates to:
  /// **'服务'**
  String get settingsSectionService;

  /// No description provided for @settingsSectionAccount.
  ///
  /// In zh, this message translates to:
  /// **'账户设置'**
  String get settingsSectionAccount;

  /// No description provided for @settingsSectionNotification.
  ///
  /// In zh, this message translates to:
  /// **'消息设置'**
  String get settingsSectionNotification;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get settingsSectionAbout;

  /// No description provided for @settingsLanguage.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get settingsLanguage;

  /// No description provided for @settingsPassword.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get settingsPassword;

  /// No description provided for @settingsAccountManage.
  ///
  /// In zh, this message translates to:
  /// **'账户管理'**
  String get settingsAccountManage;

  /// No description provided for @settingsOrders.
  ///
  /// In zh, this message translates to:
  /// **'订单'**
  String get settingsOrders;

  /// No description provided for @settingsReceiveMessage.
  ///
  /// In zh, this message translates to:
  /// **'接收消息'**
  String get settingsReceiveMessage;

  /// No description provided for @settingsNotificationPermission.
  ///
  /// In zh, this message translates to:
  /// **'通知权限设置'**
  String get settingsNotificationPermission;

  /// No description provided for @settingsVersion.
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get settingsVersion;

  /// No description provided for @settingsTerms.
  ///
  /// In zh, this message translates to:
  /// **'条款'**
  String get settingsTerms;

  /// No description provided for @settingsLogout.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get settingsLogout;

  /// No description provided for @settingsLogoutTitle.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get settingsLogoutTitle;

  /// No description provided for @settingsLogoutContent.
  ///
  /// In zh, this message translates to:
  /// **'确定要退出登录吗？'**
  String get settingsLogoutContent;

  /// No description provided for @settingsLanguageChinese.
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get settingsLanguageChinese;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @commonCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get commonCancel;

  /// No description provided for @commonConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确认'**
  String get commonConfirm;

  /// No description provided for @commonBack.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get commonBack;

  /// No description provided for @commonSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get commonSave;

  /// No description provided for @commonRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get commonRetry;

  /// No description provided for @commonLoading.
  ///
  /// In zh, this message translates to:
  /// **'加载中...'**
  String get commonLoading;

  /// No description provided for @bindDeviceTitle.
  ///
  /// In zh, this message translates to:
  /// **'绑定设备'**
  String get bindDeviceTitle;

  /// No description provided for @bindDeviceSelectType.
  ///
  /// In zh, this message translates to:
  /// **'选择设备类型'**
  String get bindDeviceSelectType;

  /// No description provided for @bindDeviceKeyTracker.
  ///
  /// In zh, this message translates to:
  /// **'KeyTracker'**
  String get bindDeviceKeyTracker;

  /// No description provided for @bindDeviceKeyTrackerDesc.
  ///
  /// In zh, this message translates to:
  /// **'宠物追踪器，实时定位'**
  String get bindDeviceKeyTrackerDesc;

  /// No description provided for @bindDevicePetPhone.
  ///
  /// In zh, this message translates to:
  /// **'PetPhone'**
  String get bindDevicePetPhone;

  /// No description provided for @bindDevicePetPhoneDesc.
  ///
  /// In zh, this message translates to:
  /// **'宠物电话，随时通话'**
  String get bindDevicePetPhoneDesc;

  /// No description provided for @bindDeviceNext.
  ///
  /// In zh, this message translates to:
  /// **'下一步'**
  String get bindDeviceNext;

  /// No description provided for @bindDeviceScanQr.
  ///
  /// In zh, this message translates to:
  /// **'扫描设备二维码'**
  String get bindDeviceScanQr;

  /// No description provided for @bindDeviceScanHint.
  ///
  /// In zh, this message translates to:
  /// **'将设备背面二维码对准扫描框'**
  String get bindDeviceScanHint;

  /// No description provided for @bindDeviceManualInput.
  ///
  /// In zh, this message translates to:
  /// **'手动输入设备码'**
  String get bindDeviceManualInput;

  /// No description provided for @bindDeviceSuccess.
  ///
  /// In zh, this message translates to:
  /// **'绑定成功！'**
  String get bindDeviceSuccess;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppL10nEn();
    case 'zh':
      return AppL10nZh();
  }

  throw FlutterError(
      'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
