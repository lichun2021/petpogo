// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'PetPogo';

  @override
  String get navHome => 'Home';

  @override
  String get navMessage => 'Message';

  @override
  String get navCommunity => 'Community';

  @override
  String get navMall => 'Mall';

  @override
  String get navProfile => 'Profile';

  @override
  String get homeGreeting => 'Hello, Human!';

  @override
  String get homeSubtitle =>
      'Ready to understand what your pet is thinking today?';

  @override
  String get homeConnectedDevices => 'Connected Devices';

  @override
  String homeDevicesActive(int count) {
    return '$count Devices Active';
  }

  @override
  String get homeAddDevice => 'Add Device';

  @override
  String get aiTranslateTitle => 'AI Pet Translator';

  @override
  String get aiTranslateBadge => 'AI TRANSLATOR ACTIVE';

  @override
  String get aiTranslateDesc =>
      'Point your phone towards your pet\nand record their sound.';

  @override
  String get aiTranslateHoldRecord => 'Hold to Record';

  @override
  String get aiTranslateRecording => 'Recording...';

  @override
  String get aiTranslateRelease => 'Release to stop recording';

  @override
  String get aiTranslateStop => 'Stop Recording';

  @override
  String get aiTranslateAnalyzing => 'AI is analyzing your pet\'s sound...';

  @override
  String get aiTranslatePetSays => '💬 Pet says:';

  @override
  String get aiTranslateAgain => 'Translate Again';

  @override
  String get deviceOnline => 'ONLINE';

  @override
  String get deviceOffline => 'OFFLINE';

  @override
  String deviceBattery(int level) {
    return 'Battery $level%';
  }

  @override
  String get deviceLocation => 'Location';

  @override
  String get deviceRing => 'Ring';

  @override
  String get deviceDetails => 'Details';

  @override
  String get deviceBind => 'Bind New Device';

  @override
  String get deviceBindSubtitle =>
      'Bind a KeyTracker or PetPhone to start smart tracking';

  @override
  String get deviceNowPlaying => 'NOW PLAYING';

  @override
  String get communityTitle => 'Community';

  @override
  String get communityTabFollowing => 'Following';

  @override
  String get communityTabDiscover => 'Discover';

  @override
  String get communityFeaturedStory => 'FEATURED STORY';

  @override
  String get communityAllPets => 'All Pets';

  @override
  String get communityDogs => 'Dogs';

  @override
  String get communityCats => 'Cats';

  @override
  String get communityBirds => 'Birds';

  @override
  String get communityOthers => 'Others';

  @override
  String get mallTitle => 'Mall';

  @override
  String get mallSearch => 'Search products';

  @override
  String get mallAddToCart => 'Add to Cart';

  @override
  String get mallBuyNow => 'Buy Now';

  @override
  String get mallNearbyStores => 'Nearby Stores';

  @override
  String get mallCategories => 'Categories';

  @override
  String get mallViewAll => 'View All';

  @override
  String get mallTrending => 'Trending Now';

  @override
  String get mallComingSoon => 'COMING SOON';

  @override
  String get mallHeroBannerTitle => 'New\nPetPhone\nLaunch';

  @override
  String get mallHeroBannerDesc =>
      'Real-time health tracking\nand mood analysis.';

  @override
  String get mallPreorder => 'Pre-order Now';

  @override
  String mallReviews(int count) {
    return '$count reviews';
  }

  @override
  String get mallCategoryFood => 'Food';

  @override
  String get mallCategoryFoodCount => '1.2k Products';

  @override
  String get mallCategoryToys => 'Toys';

  @override
  String get mallCategoryToysCount => '850 Products';

  @override
  String get messageTitle => 'Messages';

  @override
  String get messageDirectMessages => 'Direct Messages';

  @override
  String messageFriendRequests(int count) {
    return '$count Friend Request(s)';
  }

  @override
  String messageFriendRequestDesc(String petName) {
    return '$petName\'s owner wants to be your friend';
  }

  @override
  String get messageView => 'View';

  @override
  String get messageSystemNotif => 'System Notification';

  @override
  String get messageSystemNotifDesc => 'Someone liked your post';

  @override
  String get messageInteraction => 'Interaction';

  @override
  String get messageInteractionDesc => 'Cooper received 12 likes';

  @override
  String get messageLoginPrompt => 'Log in to see messages';

  @override
  String get messageLoginSubtitle => 'Connect with other pet owners';

  @override
  String get messageBindPhone => 'Bind Phone Number';

  @override
  String get messageEmpty => 'No messages yet';

  @override
  String get messageEmptySubtitle => 'Start chatting with pet lovers!';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileMyPets => 'My Pets';

  @override
  String get profileAddNew => 'Add New';

  @override
  String get profileFollowers => 'FOLLOWERS';

  @override
  String get profileFollowing => 'FOLLOWING';

  @override
  String get profilePosts => 'POSTS';

  @override
  String profilePetParentSince(String year) {
    return 'Pet Parent since $year';
  }

  @override
  String get profileBoundDevices => 'Bound Devices';

  @override
  String get profileOrderHistory => 'Order History';

  @override
  String get profileMyPosts => 'My Posts';

  @override
  String get profileSettings => 'Settings';

  @override
  String get profileLogout => 'Log Out';

  @override
  String get profileGuestMode => 'Guest Mode';

  @override
  String get profileGuestSubtitle =>
      'Bind your phone number to unlock all features';

  @override
  String get profileLoginRegister => 'Log In / Register';

  @override
  String get profileVaccinated => 'VACCINATED';

  @override
  String get profileCheckupDue => 'CHECKUP DUE';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionService => 'Services';

  @override
  String get settingsSectionAccount => 'Account';

  @override
  String get settingsSectionNotification => 'Notifications';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsPassword => 'Password';

  @override
  String get settingsAccountManage => 'Account Management';

  @override
  String get settingsOrders => 'Orders';

  @override
  String get settingsReceiveMessage => 'Receive Messages';

  @override
  String get settingsNotificationPermission => 'Notification Permissions';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsTerms => 'Terms of Service';

  @override
  String get settingsLogout => 'Log Out';

  @override
  String get settingsLogoutTitle => 'Log Out';

  @override
  String get settingsLogoutContent => 'Are you sure you want to log out?';

  @override
  String get settingsLanguageChinese => '简体中文';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonBack => 'Back';

  @override
  String get commonSave => 'Save';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get bindDeviceTitle => 'Bind Device';

  @override
  String get bindDeviceSelectType => 'Select Device Type';

  @override
  String get bindDeviceKeyTracker => 'KeyTracker';

  @override
  String get bindDeviceKeyTrackerDesc => 'Pet tracker with real-time location';

  @override
  String get bindDevicePetPhone => 'PetPhone';

  @override
  String get bindDevicePetPhoneDesc => 'Pet phone for anytime calls';

  @override
  String get bindDeviceNext => 'Next';

  @override
  String get bindDeviceScanQr => 'Scan Device QR Code';

  @override
  String get bindDeviceScanHint =>
      'Align the QR code on the back of the device';

  @override
  String get bindDeviceManualInput => 'Enter code manually';

  @override
  String get bindDeviceSuccess => 'Device bound successfully!';
}
