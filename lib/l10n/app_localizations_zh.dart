// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppL10nZh extends AppL10n {
  AppL10nZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'PetPogo';

  @override
  String get navHome => '首页';

  @override
  String get navMessage => '消息';

  @override
  String get navCommunity => '社区';

  @override
  String get navMall => '商城';

  @override
  String get navProfile => '我的';

  @override
  String get homeGreeting => '你好，铲屎官！';

  @override
  String get homeSubtitle => '来看看你的宠物今天在想什么吧？';

  @override
  String get homeConnectedDevices => '已连接设备';

  @override
  String homeDevicesActive(int count) {
    return '$count 台设备在线';
  }

  @override
  String get homeAddDevice => '添加设备';

  @override
  String get aiTranslateTitle => 'AI 宠物翻译';

  @override
  String get aiTranslateBadge => 'AI 翻译已启动';

  @override
  String get aiTranslateDesc => '把手机对准你的宠物\n然后录制它发出的声音。';

  @override
  String get aiTranslateHoldRecord => '长按录音';

  @override
  String get aiTranslateRecording => '正在录音...';

  @override
  String get aiTranslateRelease => '松开手指完成录制';

  @override
  String get aiTranslateStop => '停止录音';

  @override
  String get aiTranslateAnalyzing => 'AI 正在分析宠物声音...';

  @override
  String get aiTranslatePetSays => '💬 宠物说：';

  @override
  String get aiTranslateAgain => '再次翻译';

  @override
  String get deviceOnline => '在线';

  @override
  String get deviceOffline => '离线';

  @override
  String deviceBattery(int level) {
    return '电量 $level%';
  }

  @override
  String get deviceLocation => '位置';

  @override
  String get deviceRing => '响铃';

  @override
  String get deviceDetails => '详情';

  @override
  String get deviceBind => '绑定新设备';

  @override
  String get deviceBindSubtitle => '绑定 KeyTracker 或 PetPhone 开启智能追踪';

  @override
  String get deviceNowPlaying => '正在播放';

  @override
  String get communityTitle => '社区';

  @override
  String get communityTabFollowing => '关注';

  @override
  String get communityTabDiscover => '发现';

  @override
  String get communityFeaturedStory => '精选故事';

  @override
  String get communityAllPets => '全部';

  @override
  String get communityDogs => '狗';

  @override
  String get communityCats => '猫';

  @override
  String get communityBirds => '鸟';

  @override
  String get communityOthers => '其他';

  @override
  String get mallTitle => '商城';

  @override
  String get mallSearch => '搜索商品';

  @override
  String get mallAddToCart => '加入购物车';

  @override
  String get mallBuyNow => '立即购买';

  @override
  String get mallNearbyStores => '附近门店';

  @override
  String get mallCategories => '分类';

  @override
  String get mallViewAll => '查看全部';

  @override
  String get mallTrending => '热门推荐';

  @override
  String get mallComingSoon => '即将上线';

  @override
  String get mallHeroBannerTitle => '全新\nPetPhone\n发布';

  @override
  String get mallHeroBannerDesc => '实时健康监测\n与情绪分析。';

  @override
  String get mallPreorder => '立即预订';

  @override
  String mallReviews(int count) {
    return '$count 条评价';
  }

  @override
  String get mallCategoryFood => '食品';

  @override
  String get mallCategoryFoodCount => '1200+ 件商品';

  @override
  String get mallCategoryToys => '玩具';

  @override
  String get mallCategoryToysCount => '850+ 件商品';

  @override
  String get messageTitle => '消息';

  @override
  String get messageDirectMessages => '私信';

  @override
  String messageFriendRequests(int count) {
    return '$count 条好友申请';
  }

  @override
  String messageFriendRequestDesc(String petName) {
    return '$petName 的主人申请加为好友';
  }

  @override
  String get messageView => '查看';

  @override
  String get messageSystemNotif => '系统通知';

  @override
  String get messageSystemNotifDesc => '有人点赞了你的帖子';

  @override
  String get messageInteraction => '互动通知';

  @override
  String get messageInteractionDesc => 'Cooper 收到了 12 个点赞';

  @override
  String get messageLoginPrompt => '登录后查看消息';

  @override
  String get messageLoginSubtitle => '与其他宠物主人互动';

  @override
  String get messageBindPhone => '绑定手机号';

  @override
  String get messageEmpty => '暂无消息';

  @override
  String get messageEmptySubtitle => '与宠物爱好者们聊起来吧！';

  @override
  String get profileTitle => '我的';

  @override
  String get profileMyPets => '我的宠物';

  @override
  String get profileAddNew => '添加宠物';

  @override
  String get profileFollowers => '粉丝';

  @override
  String get profileFollowing => '关注';

  @override
  String get profilePosts => '发帖';

  @override
  String profilePetParentSince(String year) {
    return '宠物主人，自 $year';
  }

  @override
  String get profileBoundDevices => '绑定设备';

  @override
  String get profileOrderHistory => '历史订单';

  @override
  String get profileMyPosts => '我的帖子';

  @override
  String get profileSettings => '设置';

  @override
  String get profileLogout => '退出登录';

  @override
  String get profileGuestMode => '游客模式';

  @override
  String get profileGuestSubtitle => '绑定手机号，享受完整功能';

  @override
  String get profileLoginRegister => '登录 / 注册';

  @override
  String get profileVaccinated => '已接种';

  @override
  String get profileCheckupDue => '待复诊';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsSectionService => '服务';

  @override
  String get settingsSectionAccount => '账户设置';

  @override
  String get settingsSectionNotification => '消息设置';

  @override
  String get settingsSectionAbout => '关于';

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsPassword => '密码';

  @override
  String get settingsAccountManage => '账户管理';

  @override
  String get settingsOrders => '订单';

  @override
  String get settingsReceiveMessage => '接收消息';

  @override
  String get settingsNotificationPermission => '通知权限设置';

  @override
  String get settingsVersion => '版本';

  @override
  String get settingsTerms => '条款';

  @override
  String get settingsLogout => '退出登录';

  @override
  String get settingsLogoutTitle => '退出登录';

  @override
  String get settingsLogoutContent => '确定要退出登录吗？';

  @override
  String get settingsLanguageChinese => '简体中文';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get commonCancel => '取消';

  @override
  String get commonConfirm => '确认';

  @override
  String get commonBack => '返回';

  @override
  String get commonSave => '保存';

  @override
  String get commonRetry => '重试';

  @override
  String get commonLoading => '加载中...';

  @override
  String get bindDeviceTitle => '绑定设备';

  @override
  String get bindDeviceSelectType => '选择设备类型';

  @override
  String get bindDeviceKeyTracker => 'KeyTracker';

  @override
  String get bindDeviceKeyTrackerDesc => '宠物追踪器，实时定位';

  @override
  String get bindDevicePetPhone => 'PetPhone';

  @override
  String get bindDevicePetPhoneDesc => '宠物电话，随时通话';

  @override
  String get bindDeviceNext => '下一步';

  @override
  String get bindDeviceScanQr => '扫描设备二维码';

  @override
  String get bindDeviceScanHint => '将设备背面二维码对准扫描框';

  @override
  String get bindDeviceManualInput => '手动输入设备码';

  @override
  String get bindDeviceSuccess => '绑定成功！';
}
