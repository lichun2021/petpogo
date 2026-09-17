# PetPogo 设计 Token（暖棕粉红主主题）

> 新建页面 / 组件时，颜色、间距、字体、图标一律从本表取 token，**禁止硬编码任意色值**（`Color(0x…)` 只允许出现在 `lib/shared/theme/color_schemes.dart`）。
> 本表可作为 system prompt 追加给 AI，让其生成页面时复用这些 token。
> 回归测试 `test/theme/no_hardcoded_colors_test.dart` 会扫描 `lib/features` 与 `lib/shared/widgets` 中的字面色值。

代码入口：
- 颜色：`AppColors.*`（`lib/shared/theme/app_colors.dart`，随主题切换）
- 间距 / 尺寸 / 圆角 / 图标：`AppSpacing` `AppSize` `AppRadius` `AppIconSize`（`lib/shared/theme/app_tokens.dart`）
- 文字样式：`Theme.of(context).textTheme.*`、`AppTheme.monoData()`

---

## 一、页面基底

| Token | Dart | 色值 | 用途 |
| --- | --- | --- | --- |
| `surface-page` | `AppColors.surfacePage` | `#F7F3EE` | 页面主背景（暖白 / 米白） |
| `surface-card` | `AppColors.surfaceCard` | `#FFFFFF` | 卡片面（`surfaceContainerLow` = `#FFFDFB` 为暖调变体） |
| `surface-sunken` | `AppColors.surfaceSunken` | `#F1EAE0` | 输入框、凹陷区、底栏基底 |
| `border-subtle` | `AppColors.borderSubtle` | `#E4D9CC` | 常规 1px 描边 / 分隔线 |

## 二、品牌与操作色（全 App 主操作唯一色）

| Token | Dart | 色值 | 用途 |
| --- | --- | --- | --- |
| `brand-primary` | `AppColors.brandPrimary` | `#C0564B` | 底栏激活 / 主按钮 / 强调 / 选中 / 加载指示器 |
| `brand-primary-strong` | `AppColors.brandPrimaryStrong` | `#9E3F36` | 主按钮按压 / 深强调文字 / 高优先级标题 |
| `brand-primary-soft` | `AppColors.brandPrimarySoft` | `#F4DAD3` | 强调浅底、选中浅底、图标垫底 |

> 规则：品牌强调、主要操作、底栏激活**只准用 `brandPrimary`**。不再出现砖橙红、深红棕各管各。

## 三、状态色（每种语义一个值；不能只靠颜色，必须配文字或图标）

| Token | Dart | 色值 | 用途 |
| --- | --- | --- | --- |
| `status-online` | `AppColors.statusOnline` | `#6F9B6A` | 在线 / 成功 / 平稳（柔和灰绿，弃用亮草绿） |
| `status-online-strong` | `AppColors.statusOnlineStrong` | `#4E7350` | 在线深文字 / 深图标 / 发送按钮 |
| `status-online-soft` | `AppColors.statusOnlineSoft` | `#E4EEE2` | 在线浅底（标签） |
| `status-alert` | `AppColors.statusAlert` | `#C2410C` | 高优先级异常 / 告警 / 未上报 / 危险 / 解绑等破坏性操作 |
| `status-alert-soft` | `AppColors.statusAlertSoft` | `#FBE3D8` | 告警浅底、概率标签 |
| `status-warning` | `AppColors.statusWarning` | `#C98A2E` | 警示 / 提醒但非危险（如数字宠"清洁"指标，需与 alert/brand 色相明显区分） |
| `status-warning-soft` | `AppColors.statusWarningSoft` | `#F5E6C8` | 警示浅底 |
| `status-neutral` | `AppColors.statusNeutral` | `#8A7B6E` | 中性提示 / 次要操作 / 未激活（替代蓝灰） |

> 规则：告警色相（≈18°，朱红）与品牌色相（≈6°，珊瑚红）**必须相差 ≥ 10°**，否则告警与品牌强调在视觉上无法区分；`test/theme/token_semantics_test.dart` 会校验。
> 规则：暖色主题下**禁止出现蓝 / 蓝灰**冷色。"管理共享"等次要按钮用 `statusNeutral`；"在线"用 `statusOnline`；围栏 / 地图 / 问诊异常用 `statusAlert`。

## 四、文字色

| Token | Dart | 色值 | 用途 |
| --- | --- | --- | --- |
| `text-primary` | `AppColors.textPrimary` | `#3A2E2A` | 标题、正文、主图标 |
| `text-secondary` | `AppColors.textSecondary` | `#7A6A60` | 说明、次级操作 |
| `text-tertiary` | `AppColors.textTertiary` | `#A79A8D` | 时间、来源、低优先级 |
| `text-on-brand` | `AppColors.textOnBrand` | `#FFFFFF` | 品牌 / 深底上的文字、图标 |

## 五、Material 角色映射（旧调用点自动落到新值）

| `AppColors.*` | 落到 |
| --- | --- |
| `primary` / `primaryDim` / `primaryContainer` | `brandPrimary` / `brandPrimaryStrong` / `brandPrimarySoft` |
| `secondary` / `secondaryContainer` / `onSecondaryContainer` | `statusOnline` / `statusOnlineSoft` / `statusOnlineStrong` |
| `tertiary` / `tertiaryContainer` | `statusNeutral` / `surfaceSunken` |
| `error` / `errorContainer` | `statusAlert` / `statusAlertSoft` |
| `surface` / `surfaceContainerLowest` / `surfaceContainer` | `surfacePage` / `surfaceCard` / `surfaceSunken` |
| `onSurface` / `onSurfaceVariant` / `outline` / `outlineVariant` | `textPrimary` / `textSecondary` / `textTertiary` / `borderSubtle` |
| `success` / `online` / `star`（已 `@Deprecated`） | `statusOnline` / `statusOnline` / `brandPrimary` |

新代码请直接用语义名（右列）。

## 六、间距 / 圆角 / 尺寸（4dp 栅格：4, 8, 12, 16, 20, 24, 32, 40, 48）

| Token | Dart | 值 | 用途 |
| --- | --- | ---: | --- |
| `screen-horizontal` | `AppSpacing.screenHorizontal` / `AppSpacing.screen` | 20dp | 页面左右边距 |
| `section-gap` | `AppSpacing.sectionGap` | 24dp | 区块之间 |
| `content-gap` | `AppSpacing.contentGap` | 12dp | 卡片 / 行内模块间 |
| `icon-gap` | `AppSpacing.iconGap` | 8dp | 图标与文字 |
| `touch-min` | `AppSize.touchMin` | 44dp | 所有可点击目标最小尺寸 |
| `tabbar-height` | `AppSize.tabBarHeight` | 64dp | 底栏高度（不含安全区） |
| `radius-card` | `AppRadius.card` / `AppRadius.cardRadius` | 18dp | 常规信息卡 |
| `radius-control` | `AppRadius.control` / `AppRadius.controlRadius` | 12dp | 按钮、输入框 |
| `radius-pill` | `AppRadius.pill` / `AppRadius.pillRadius` | 999dp | 标签、小状态、胶囊按钮 |

> 规则：只用栅格值，**禁止任意边距**。
> 规则（按钮圆角）：**全宽主操作按钮**（宽度撑满、高度 ≥ 48，如登录 / 保存 / 绑定成功）用 `radius-pill`；**表单内、列表内、并排的小按钮**用 `radius-control`。不要出现 14 / 16 / 18 / 20 等中间值。
> 规则（品牌色用量）：`brandPrimary` 是**强调色不是填充色**。每屏最多一处大面积品牌色块（hero / 主按钮）；列表卡、歌单卡、分类卡等重复元素用 `surfaceSunken` / 封面图 + 深色遮罩，品牌色只出现在图标、徽标、选中态等小件上。
> 规则（信息层级）：积分说明、时间、来源等元信息用 `textTertiary`，不用品牌色；列表右侧 chevron 用 `textTertiary`。

## 七、字体

| 层级 | textTheme 槽位 | 规格 |
| --- | --- | --- |
| 页面标题 | `titleLarge` | 22sp / 700 |
| 区块标题 | `titleSmall` | 14sp / 700 |
| 列表标题 | `labelLarge` | 13sp / 600 |
| 正文说明 | `bodyMedium` | 14sp / 400 |
| 数据 / 时间 / 数字 | `AppTheme.monoData()` | 等宽 500–700，限短数据 |

字体族：Plus Jakarta Sans + 中文回退（`AppFonts.fallback`）。
> 规则：同一层级字重字号全 App 一致；**禁止缩小字号解决溢出**，用换行或 `maxLines` + 省略号。

## 八、图标

| 项目 | 规范 |
| --- | --- |
| 风格 | Material Rounded / Outlined 线性图标，不切换实心变体 |
| 尺寸 | 底栏 `AppIconSize.tabBar` 19dp；顶部 `AppIconSize.topBar` 16dp；卡片 `AppIconSize.card` 16dp |
| 线宽（记录用） | `AppIconStroke.regular` 1.7 / `alert` 1.9 / `smallNode` 2.0 |
| 填充 | 默认不实心，颜色继承语义 token；仅徽标、状态点允许实心 |

> 规则：图标必须与语义色绑定（告警图标用 `statusAlert`）。

## 九、动效

- 页面切换：淡入 + 轻微上移，200–250ms ease-out
- 卡片按压：缩放 0.98，150ms（见 `lib/shared/widgets/pressable.dart`）
- 加载：环形指示器用 `brandPrimary`（已由 `progressIndicatorTheme` 提供）

## 十、功能入口分层（"我的"页六宫格等）

| 层级 | 图标垫 / 图标 | 适用 |
| --- | --- | --- |
| 核心资产 | `brandPrimarySoft` / `brandPrimary` | 我的宠物、我的设备 |
| 内容与活动 | `surfaceSunken` / `statusNeutral` | 帖子、音乐、签到、会员 |

同一网格内只允许这两层，不引入第三种颜色；需要提醒时用 `statusAlert` 徽标而不是改图标色。性别、品种等**属性标签**一律 `surfaceSunken` + `textSecondary`，靠符号 / 文字区分，不占用状态色。

## 十一、错误提示

- 面向用户的错误一律经 `ErrorPresenter.describe(error)`（`lib/shared/utils/error_presenter.dart`）转成设计文案，禁止直接显示 `e.toString()`。
- 原始错误文本是否附带显示由 `assets/config/app_flags.json` 的 `showRawError` 控制，与 debug / release 无关；`showRawErrorToggle` 决定设置页是否露出运行时开关。
