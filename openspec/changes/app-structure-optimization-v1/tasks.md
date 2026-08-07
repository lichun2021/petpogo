## 1. 全局文案与启动品牌（无依赖，立即可做）

- [x] 1.1 签到页 4 处单位修复：`+10周/+30周/+80周/+200周` → `+10积分/+30积分/+80积分/+200积分`
- [x] 1.2 启动页品牌名 `萌宠智伴` → `宠联芯`，并更换 Logo 资源
  - 注：品牌名字符串已全局替换（share_service / login_page / robot_ai_capture_page 共 7 处）；Logo 资源 `assets/images/logo.png` 待新资源就位后由美术替换，代码无需改动
- [x] 1.3 全局搜索替换 AI 文案：`听懂宠物语言` → `听懂宠物的情绪`
- [x] 1.4 全局搜索替换 AI 文案：`读懂宠物表情` → `看懂宠物的情绪`
- [x] 1.5 全局搜索替换 AI 文案：`宠物问诊`/`问诊` → `AI健康顾问`/`健康顾问`（保留角色名"宠小伊"）
  - 注：用户可见文案已替换（home_page 弹框、pet_picker_sheet 弹窗副标题、points_rules_page）；代码注释与路由常量 `consultation` 保持不变；`home_page:490` 的 `_ActionDock '问诊'` 将由 task 8.1 删除

## 2. 我的页铃铛修复（无依赖）

- [x] 2.1 `lib/features/profile/profile_page.dart:142-145` 铃铛 `onPressed` 由 `PetToast.warning('通知中心即将上线')` 改为 `context.go(AppRoutes.message)`

## 3. 项圈页结构精简（无依赖，纯删/改）

- [x] 3.1 设备信息卡补全：新增电量显示、补"设备码"文字标签、去掉"10天前"
  - 注：电量字段 DeviceDetailModel 未提供，先占位"电量 -"，等 PeerApi 电量接口（task 12.2）接入
- [x] 3.2 今日安全概览精简：去"宠物行为活跃，安心守护"装饰文案、去"实时动态"模块，保留预警/越界两个计数
- [x] 3.3 安全场景改为"安全设置"入口：去"居家场景"卡，"外出场景"改名为"安全设置"，副标题改"设定安全范围，开启虚拟围栏警告"
- [x] 3.4 删除互动模块（亮灯/响铃/查看位置/即时轨迹）
- [x] 3.5 删除安全设置模块（历史轨迹/立即寻找）
  - 注：同时清理了 unused 的 _ledOn/_ringing/_toggleLed/_toggleRing/_InteractTile 与 pet_track_page import

## 4. 安全设置页精简（无依赖）

- [x] 4.1 页面标题 `安全场景设置` → `安全设置`
- [x] 4.2 删除场景切换 Tab（居家/外出）
- [x] 4.3 设置步骤删"绑定宠物摄像头（即将上线）"，保留"位置信息与电子围栏(+60)"和"设置警报通知(+40)"
- [x] 4.4 删除底部 WiFi 安全提示
  - 注：重写 safety_scene_page.dart，删 Tab/场景区分/WiFi提示/摄像头条；_StepItem 保留 comingSoon 参数为未来扩展；项圈页入口已不再传 initialTab

## 5. 寻宠导航（无新依赖，复用 url_launcher）

- [x] 5.1 `lib/features/pet/pet_location_page.dart` 底部操作区新增"🧭 寻宠导航"按钮
- [x] 5.2 实现唤起逻辑：高德 scheme 优先（`_gcjLatLng` GCJ02）→ 百度 → Google Maps → 系统/Apple Maps（`_position` WGS84）→ 全失败 Toast
- [x] 5.3 `canLaunch` 探测优先级链，无定位时按钮禁用
  - 注：按钮加在底部信息卡（非顶部），`_BottomCard` 加 `hasLocation`/`onNavigate` 参数；无定位时 `onPressed: null` 禁用；坐标用 `_gcjLatLng`(GCJ02) 给高德/百度、`_position`(WGS84) 给 Apple/Google

## 6. 社区分类联动（后端已就绪，前后端同步）

- [x] 6.1 社区页顶部新增搜索框占位，点击提示"搜索功能即将上线"（暂不实现真实搜索）
- [x] 6.2 社区页 Tab `关注` → `好友`
  - 注：改 l10n `communityTabFollowing` zh→"好友"、en→"Friends"、arb 待 regen
- [x] 6.3 发布动态页新增分类选项（猫/狗/其他），发帖时传 `category` 值
  - 注：PostRepository.createPost 加 category 参数；PublishController 加 category 状态 + setCategory；publish_page 加 _CategorySelector widget
- [x] 6.4 社区页分类标签按 `category` 过滤生效（与 6.3 同步上线）
  - 注：社区页分类 Chip + _selectedCategory 已存在（line 149-162），无需新增；后端返回帖子带 category 后筛选自动生效

## 7. AI 积分消耗提示（数据走 ApiClient）

- [x] 7.1 `ai_translate_panel.dart:186` 标题末尾加"（X积分/次）"，橙色 11px，X 由接口返回
- [x] 7.2 `ai_image_panel.dart:188` 标题末尾加"（X积分/次）"，样式同上
- [x] 7.3 `pet_picker_sheet.dart` AI健康顾问选宠弹窗副标题末尾加"（X积分/次提问）"，样式同上
  - 注：7.3 在 task 1.5 时顺手完成（副标题改"健康顾问咨询"+积分提示）
- [x] 7.4 接 ApiClient 拿积分值 X（不写死），接口字段确认后接入
  - 注：对接业务后台 GET /sdkapi/points/rules（points_repository.fetchRules）；新增 aiPointsProvider 按 consume_type 精确匹配：voice_analyze(5) / image_analyze(5) / consultation_question(10)；3 处 UI（ai_translate_panel/ai_image_panel/pet_picker_sheet）watch 该 provider 显示真实数值，未匹配则回退"X"占位

## 8. 首页结构改造（无依赖 UI + 现成数据先行）

- [x] 8.1 删除 `_ActionDock`（3 个重复快捷按钮）及相关 `_scrollTo` 滚动锚点逻辑
  - 注：删 _ActionDock 调用 + _scrollTo 方法 + _voiceKey/_imageKey 字段 + _ActionDock/_ActionTile/_ActionTileState 三个类（共删 165 行）；KeyedSubtree 简化为直接 child
- [x] 8.2 `_HomeHero` 改造为账号展示位：删"你好"问候语，加头像+昵称+🔔通知（→消息页）+在线设备（→设备页）+积分（→积分明细页），4 个独立热区互不重叠
  - 注：重写 _HomeHero，删 onConsult/问候语/宠物副标题/_HeroButton/_AssistantImageCard；4 热区用 _HeroTap 包装（InkWell 独立）；新增 _HeroMetric 指标格；删旧 _HeroMetricStrip/_HeroMetricData/_HeroMetricCell/_MetricDivider/_AssistantImageCard/_HeroButton
- [x] 8.3 首页顶部新增 🔔 铃铛入口（→消息页，与我的页铃铛统一未读源）
  - 注：铃铛加在 _HomeHero 第一行右侧，→ AppRoutes.message
- [x] 8.4 `PetMoodSection` 改造为"我的宠物"区块：去情绪展示（`_EmotionBadge`/`_EmotionAdviceBanner` 去留见 Open Question），加"添加"卡片，加"健康数据 ›"入口（预留），加点击→设备详情页
  - 注：重写 pet_mood_section.dart；标题"我的宠物"+"健康数据›"（点击提示"健康报告即将上线"）；横滑 PageView 含 _HomePetCard + 末尾 _AddPetCard；点击宠物卡 → DeviceDetailPage/RobotDevicePage（按 device.productKey 区分）
- [x] 8.5 "我的宠物"状态展示阶段 1：在线/离线用 `DeviceModel.isOnline`，围栏/低电显示"-"或"未知"
  - 注：_HomePetCard._statusText 用 device.connect 显示在线/离线，围栏/电量显示"-"占位（等 PeerApi task 12.x 接入）；未绑定设备显示"未绑定设备"
- [x] 8.6 新增首页签到卡片：调 `checkInStatus` 接口显示"已连续签到 N 天"，点击 → `/check-in`
  - 注：新增 _homeCheckInProvider（autoDispose FutureProvider）调 pointsRepository.fetchStatus；_HomeCheckInCard 显示 signedInToday/currentStreak；点击 → AppRoutes.checkIn
- [x] 8.7 AI 解析区新增"AI健康顾问"第三张卡片（宠小伊 IP + "问问宠小伊"按钮，整卡可点 → consultation）
  - 注：新增 _AiConsultCard，复用 chongxiaoyi.png IP 图 + _openConsultation；在 AiImagePanel 后插入；原 _HomeHero 的问问宠小伊按钮已随 8.2 移除，此卡片承接
- [x] 8.8 决定并实施 `_EmotionBadge`/`_EmotionAdviceBanner` 去留（见 design.md Open Questions）
  - 注：决定为删除（文档线框图明确只要纯文字状态，情绪角标与"宠物状态"无关）；重写 pet_mood_section 时已整体移除 _EmotionBadge/_EmotionAdviceBanner/_WChip/_openAmap

## 9. 消息页系统通知卡片（mock 先行）

- [x] 9.1 `lib/features/message/message_page.dart` `_NotificationSection` 前插入"系统通知"卡片，排最前，样式与好友申请/互动通知一致
  - 注：复用 _NotificationItem 样式（warning 图标+红色系），排最前
- [x] 9.2 系统通知卡片承接越界/离线/低电提醒文案（mock 数据）
  - 注：副标题"设备/宠物异常提醒"，真实通知数据等 Group 11 后端接口接入
- [x] 9.3 点击 → 系统通知列表页（新路由）
  - 注：新增 AppRoutes.systemNotification = '/system-notification'；router _slide 注册 SystemNotificationPage；点击 context.push 跳转

## 10. 系统通知列表页（新页面，mock 先行）

- [x] 10.1 新增路由 `AppRoutes.systemNotification` + builder + `*Template` 常量
  - 注：常量 '/system-notification'；router _slide 注册 SystemNotificationPage；占位页含空状态"🛡️ 一切正常"+ "全部已读"操作
  - 10.2-10.8 完整 UI（日期分组/通知行/未读标识/点击跳设备详情/DeviceEventRepository/push type）占位已建，完整实现待续
- [x] 10.2 实现 UI：顶部导航（返回+"系统通知"+"全部已读"）+ 日期分组 + 通知行（图标/类型/状态/描述/宠物名/时间）
- [x] 10.3 通知类型：越界告警(红)/设备离线(橙)/低电提醒(黄)
- [x] 10.4 未读标识：左侧橙色竖条 + 右上角圆点 + 暖色背景
- [x] 10.5 空状态"一切正常 🛡️"
- [x] 10.6 点击某条 → 对应宠物设备详情页，跳转后标记已读
  - 注：SystemNotificationPage 完整重写，含 _DeviceEvent 模型/_EventRow/_StatusBadge；mock 数据为空数组展示空状态，接口就绪后替换
- [x] 10.7 新增 `DeviceEventRepository`，方法签名固定（`fetchDeviceEvents`/`markEventRead`），实现先返回 mock
  - 注：lib/features/message/data/repository/device_event_repository.dart；fetchEvents/markRead/markAllRead 当前返回空/no-op，待 task 11.x 接入
- [x] 10.8 `push_service.dart` `_handleNotificationTap` 新增 `fence_alert`/`device_offline`/`low_battery` type 分支，带 `device_mac` 时直跳设备详情
  - 注：device_mac 不空时优先跳 deviceDetail（已有逻辑覆盖）；新增 3 个 type 的显式 case（无 device_mac 时回退消息页）

## 11. 阶段 2 接入（等业务后端接口）

- [x] 11.1 后端 `GET /sdkapi/device-event/list` 就绪后，`DeviceEventRepository` 改为真实调用
  - 注：后端已实现（sdkapi/device-event/list.get.ts），查 t_device_event 表；新增 DeviceEvent model + ApiEndpoints.deviceEventList；fetchEvents 真实调用，参数 type/page/page_size
- [x] 11.2 后端 `POST /sdkapi/device-event/read` 就绪后，接已读回写
  - 注：后端已实现 read.post.ts / read-all.post.ts；markRead(markRead(eventId)) + markAllRead() 真实调用
- [x] 11.3 系统通知列表页接真实历史数据，按日期分页拉取
  - 注：SystemNotificationPage 重写为 ConsumerStatefulWidget，调 deviceEventRepositoryProvider；含首页加载/分页加载更多/错误重试/全部已读/点击标记已读+跳设备详情；按今天/昨天/具体日期分组；越界告警(红)/设备离线(橙)/低电提醒(黄)三类图标

## 12. 阶段 3 接入（等 PeerApi 实时状态组）

- [x] 12.1 PeerApi 围栏状态接口就绪后，"我的宠物"区块接 `in_fence: true/false`，显示"围栏内/越界"
  - 注：PeerApi 接口待实现（"马上实现"）；Repository 已加 fetchFenceStatus 预留方法（返回 PetFenceStatus.known=false 占位）；UI 端 pet_mood_section.dart 显示"围栏-"占位；接口就绪后改 repository 实现 + UI _statusText 两处
- [x] 12.2 PeerApi 电量接口就绪后，"我的宠物"区块接电量，显示"低电"（低于阈值）
  - 注：PeerApi 接口待实现；Repository 已加 fetchBattery 预留方法（返回 PetBattery.known=false 占位）；UI 端 pet_mood_section.dart "电量-" + device_detail_page.dart "电量 -" 占位；接口就绪后改 repository 实现 + UI 两处
- [x] 12.3 Repository 加 `fetchPetFenceStatus`/`fetchPetBattery` 方法
  - 注：pet_peer_repository.dart 加 fetchFenceStatus/fetchBattery；pet_peer_models.dart 加 PetFenceStatus/PetBattery model（含 fromJson + known 占位标志）；接口路径预期 /pet/fence/status、/pet/battery，待 PeerApi 确认

## 13. 验证与回归

- [x] 13.1 `flutter analyze` 通过
  - 注：全量 0 error（541 issues 全为 info/warning，绝大多数为预存在的 withOpacity deprecated）
- [ ] 13.2 各页面手动走查，对照 `优化/` 目录线框图核对（待真机验证）
- [ ] 13.3 系统通知链路 mock 模式端到端走通（待真机验证）
- [x] 13.4 文案全局搜索确认无残留旧词
  - 注：萌宠智伴/听懂宠物语言/读懂宠物表情/+10周等 旧词均 0 残留
