# 宠物分享功能使用指南

## 概述

参考硬件分享逻辑，为宠物添加了完整的分享功能，支持邀请他人共同管理宠物。

## 已实现的功能

### 1. 数据模型 (lib/features/pet/data/models/pet_share_model.dart)

- **PetShareModel**: 宠物分享记录模型
  - 分享状态: pending(待接受) / accept(已接受) / refuse(已拒绝)
  - 包含分享口令、接收者邮箱、创建时间、失效时间等

- **PetMemberModel**: 宠物成员模型
  - 成员类型: 2=管理员 / 3=成员
  - 包含用户信息、加入时间等

- **PetSharePageTurn**: 分页信息模型

### 2. Repository层 (lib/features/pet/data/repository/pet_share_repository.dart)

对接后端 `/pet/share/*` API，提供以下方法:

#### 分享管理
- `createShare()`: 创建宠物分享，返回口令
  - 支持指定用户分享(传email)
  - 支持匿名分享(不传email，任何人可凭口令接受)
  - 可设置权限类型(管理员/成员)

- `acceptShare()`: 接受宠物分享
- `refuseShare()`: 拒绝宠物分享
- `deleteShare()`: 删除/取消分享

#### 列表查询
- `fetchMyShareList()`: 我分享的列表
- `fetchSharedWithMeList()`: 分享给我的列表(已接受)

#### 成员管理
- `fetchMembers()`: 查询宠物共享成员列表
- `removeMember()`: 移除宠物共享成员

### 3. UI页面 (lib/features/pet/pet_members_page.dart)

**PetMembersPage** - 宠物成员管理页面，功能包括:

- 展示宠物的所有共享成员
- 支持生成分享链接(集成业务分享系统)
- 支持移除成员
- 下拉刷新成员列表
- 空状态提示
- 分享底部弹窗，支持复制链接和微信分享

### 4. 路由配置

已在 `app_router.dart` 中添加路由:

```dart
// 路由常量
AppRoutes.petMembers(petId)
AppRoutes.petMembersTemplate

// 跳转示例
context.push(
  AppRoutes.petMembers(petId),
  extra: {
    'petName': '小花',
    'petAvatar': 'https://...',
  },
);
```

## 使用示例

### 1. 在宠物列表页点击"成员管理"按钮

**已实现** ✅

在 `pet_list_page.dart` 的宠物卡片上已添加"成员管理"图标按钮（蓝色人群图标）：

```dart
// 宠物卡片上有三个操作按钮：
// 1. 成员管理（蓝色人群图标）
// 2. 编辑（橙色编辑图标）
// 3. 删除（红色删除图标）

_IconBtn(
  icon: Icons.group_outlined,
  color: const Color(0xFF60A5FA),
  onTap: () => _openMembers(context),
),
```

点击后会跳转到 `PetMembersPage`，展示该宠物的共享成员列表。

### 2. 在宠物详情页添加"成员管理"入口（待实现）

```dart
// 在宠物详情页(pet_detail_page.dart)的操作菜单中添加
ListTile(
  leading: Icon(Icons.group_rounded),
  title: Text('成员管理'),
  onTap: () {
    context.push(
      AppRoutes.petMembers(petId),
      extra: {
        'petName': pet.name,
        'petAvatar': pet.avatar,
      },
    );
  },
)
```

### 2. 直接调用Repository创建分享

```dart
// 指定用户分享
final order = await ref.read(petShareRepositoryProvider).createShare(
  petId: 123,
  email: 'friend@example.com',
  type: 3, // 3=成员, 2=管理员
);

// 匿名分享(生成口令供任何人使用)
final order = await ref.read(petShareRepositoryProvider).createShare(
  petId: 123,
  // 不传email
);
```

### 3. 接受分享

```dart
// 通过口令接受分享
await ref.read(petShareRepositoryProvider).acceptShare(order);
```

### 4. 查询分享列表

```dart
// 我分享给别人的
final myShares = await ref.read(petShareRepositoryProvider)
  .fetchMyShareList(pageNo: 1, pageSize: 20);

// 别人分享给我的(已接受)
final sharedWithMe = await ref.read(petShareRepositoryProvider)
  .fetchSharedWithMeList(pageNo: 1, pageSize: 20);
```

## 集成业务分享系统

宠物分享已集成到现有的分享系统(`ShareRepository`)，流程如下:

1. 调用 `PetShareRepository.createShare()` 生成口令
2. 将口令传给 `ShareRepository.createShare()` 生成分享链接
3. 展示分享弹窗，用户可复制链接或微信分享
4. 接收者打开链接 → `ShareLandingPage` → 解析 `type=pet` → 调用 `PetShareRepository.acceptShare()`

## API对接说明

### 后端接口 (参考 PeerPet.md)

所有接口通过 `PeerApiClient` 调用，Content-Type 为 `application/x-www-form-urlencoded`:

- `POST /pet/share/add` - 发起分享
- `POST /pet/share/accept` - 接受分享
- `POST /pet/share/refuse` - 拒绝分享
- `GET /pet/share/mylist` - 我分享的列表
- `GET /pet/share/withme` - 分享给我的列表
- `POST /pet/share/del` - 删除分享

### 成员管理接口(待后端确认)

以下接口在文档中未明确，参考设备分享接口添加:

- `POST /pet/share/members` - 查询成员列表
- `POST /pet/share/member/remove` - 移除成员

**注**: 如果后端接口路径或参数不同，需在 `pet_share_repository.dart` 中调整。

## 错误处理

Repository 层会抛出异常，UI 层使用 `PetToast` 展示错误:

```dart
try {
  await repo.createShare(petId: petId);
} catch (e) {
  if (mounted) {
    PetToast.error(context, '生成分享失败，请重试');
  }
}
```

常见错误码 (参考 PeerPet.md):
- `1010`: token不存在 → 提示登录
- `12007`: 口令过期 → 重新获取
- `12016`: 错误的口令
- `17807`: 宠物不存在
- `17819`: 不是宠物拥有者
- `17821`: 已发送过分享邀请
- `17822`: 分享记录不存在

## 待完成工作

1. **在宠物详情页添加入口**: 在 `pet_detail_page.dart` 中添加"成员管理"按钮
2. **处理分享落地页**: 在 `share_landing_page.dart` 中添加 `type=pet` 的处理逻辑
3. **确认成员管理接口**: 与后端确认 `/pet/share/members` 和 `/pet/share/member/remove` 接口
4. **UI优化**: 根据实际宠物数据调整显示样式
5. **权限控制**: 确认只有宠物主人才能看到"成员管理"入口

## 文件清单

```
lib/features/pet/
├── data/
│   ├── models/
│   │   └── pet_share_model.dart          # 新增：分享数据模型
│   └── repository/
│       └── pet_share_repository.dart     # 新增：分享Repository
└── pet_members_page.dart                 # 新增：成员管理页面

lib/core/router/
├── app_routes.dart                       # 修改：添加petMembers路由常量
└── app_router.dart                       # 修改：添加路由配置
```

## 参考资料

- 硬件分享实现: `lib/features/device/device_members_page.dart`
- 硬件分享Repository: `lib/features/device/data/repository/device_repository.dart`
- 后端API文档: `PeerPet.md`
- 项目架构说明: `CLAUDE.md`
