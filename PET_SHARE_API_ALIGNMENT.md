# 宠物分享API对齐说明

## 修改日期: 2026-07-07

## 对齐的接口

### `/pet/share/members` - 查询宠物共享成员列表

根据 `PeerPet.md` 文档，该接口的实际响应格式为：

```json
{
  "code": 0,
  "info": {
    "owner": {
      "userId": 1215113377705000960,
      "account": "18616717926@qq.com",
      "name": "宠友7926",
      "role": "owner"
    },
    "members": [
      {
        "userId": 1215184034045075456,
        "account": "user@example.com",
        "name": "张三",
        "permission": 3,
        "shareId": 1219527580735262721,
        "joinTime": 1779869643201
      }
    ],
    "totalCount": 2
  },
  "tip": "响应成功"
}
```

## 修改内容

### 1. Repository层 (`pet_share_repository.dart`)

**修改前**:
- 假设返回的是成员列表数组
- 直接映射为 `PetMemberModel`

**修改后**:
- 正确解析 `info.owner` 和 `info.members`
- Owner 的 `type` 设置为 `'1'`
- Members 的 `type` 从 `permission` 字段获取
- 字段映射：
  - `name` → `userName`
  - `account` → `userEmail`
  - `permission` → `type`

```dart
Future<List<PetMemberModel>> fetchMembers(int petId) async {
  final res = await _peer.post<Map<String, dynamic>>(
    '/pet/share/members',
    params: {'petId': petId},
    fromInfo: (d) => d as Map<String, dynamic>,
  );

  final info = res.info;
  if (info == null) return [];

  final members = <PetMemberModel>[];

  // 添加 owner
  final owner = info['owner'] as Map<String, dynamic>?;
  if (owner != null) {
    members.add(PetMemberModel(
      userId: owner['userId']?.toString() ?? '',
      userName: owner['name']?.toString() ?? '',
      userEmail: owner['account']?.toString(),
      type: '1', // owner
      joinTime: null,
    ));
  }

  // 添加 members
  final membersList = info['members'] as List<dynamic>?;
  if (membersList != null) {
    for (final m in membersList) {
      if (m is Map<String, dynamic>) {
        members.add(PetMemberModel(
          userId: m['userId']?.toString() ?? '',
          userName: m['name']?.toString() ?? '',
          userEmail: m['account']?.toString(),
          type: m['permission']?.toString() ?? '3',
          joinTime: m['joinTime'] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  (m['joinTime'] as num).toInt())
              : null,
        ));
      }
    }
  }

  return members;
}
```

### 2. 数据模型 (`pet_share_model.dart`)

**修改前**:
- `type`: `2=管理员, 3=成员`
- 没有 `isOwner` 判断

**修改后**:
- `type`: `1=owner, 2=管理员, 3=成员`
- 新增 `isOwner` getter
- 更新 `roleLabel` 支持显示"主人"
- `fromJson` 兼容多种字段名：
  - `userName` / `name`
  - `userEmail` / `account`
  - `type` / `permission`

```dart
class PetMemberModel {
  final String type; // 1=owner, 2=管理员, 3=成员
  
  bool get isOwner => type == '1';
  bool get isAdmin => type == '2';
  bool get isMember => type == '3';

  String get roleLabel {
    switch (type) {
      case '1':
        return '主人';
      case '2':
        return '管理员';
      case '3':
        return '成员';
      default:
        return '成员';
    }
  }
}
```

### 3. UI页面 (`pet_members_page.dart`)

**修改前**:
- 只判断 `isAdmin`
- 所有成员都显示移除按钮

**修改后**:
- 判断 `isOwner`、`isAdmin`、`isMember`
- Owner 显示星形图标和橙色配色
- Owner 不显示移除按钮（自己不能移除自己）

```dart
final bool isOwner = member.isOwner;
final bool isAdmin = member.isAdmin;

// 角色配色
final Color roleColor = isOwner
    ? AppColors.primary
    : isAdmin
        ? const Color(0xFF60A5FA)
        : AppColors.onSurfaceVariant;
        
final IconData roleIcon = isOwner
    ? Icons.star_rounded
    : isAdmin
        ? Icons.admin_panel_settings_rounded
        : Icons.person_rounded;

// 移除按钮（主人不显示）
if (!isOwner) { ... }
```

## 接口参数

### 请求
- **Method**: POST
- **Path**: `/pet/share/members`
- **Content-Type**: `application/x-www-form-urlencoded`
- **Headers**: `token: <用户token>`
- **Body**: `petId: <宠物ID>` (Long)

### 响应字段说明

#### owner 对象
| 字段 | 类型 | 说明 |
|------|------|------|
| userId | Long | 用户ID |
| account | String | 账号(邮箱) |
| name | String | 用户昵称 |
| role | String | 固定值 "owner" |

#### members 数组
| 字段 | 类型 | 说明 |
|------|------|------|
| userId | Long | 成员用户ID |
| account | String | 成员账号(邮箱) |
| name | String | 成员昵称 |
| permission | Integer | 权限类型: 3=成员 |
| shareId | Long | 分享记录ID |
| joinTime | Long | 加入时间(毫秒时间戳) |

#### 根级别字段
| 字段 | 类型 | 说明 |
|------|------|------|
| totalCount | Integer | 总成员数 (owner + members) |

## 错误码

| code | tip | 说明 |
|------|-----|------|
| 0 | 响应成功 | 请求成功 |
| 1003 | 参数错误 | petId参数缺失或为空 |
| 1021 | 宠物不存在 | 宠物已删除或不存在 |
| 17804 | 无权限操作 | 当前用户既非owner也非已接受分享的成员 |
| 1023 | 用户不存在 | owner用户信息异常 |

## 权限说明

**可以查询成员列表的用户**:
- 宠物的 owner（主人）
- 已接受分享的成员

**不能查询的情况**:
- 非owner且非已接受分享的成员 → 返回错误码 17804

## 测试建议

1. **正常情况**: 作为owner查询
   - 返回自己(owner) + 所有已接受的成员
   - totalCount = 1 + members.length

2. **边界情况**: 没有分享成员
   - 返回自己(owner)
   - members = []
   - totalCount = 1

3. **权限测试**: 非owner/非成员查询
   - 返回错误码 17804

4. **UI显示测试**:
   - Owner显示星形图标和"主人"标签
   - Owner不显示移除按钮
   - 成员显示人形图标和"成员"标签
   - 成员显示移除按钮

## 相关文档

- `PeerPet.md` - 后端API文档
- `PET_SHARE_USAGE.md` - 宠物分享使用指南
- `PET_FEATURE_UPDATE.md` - 宠物功能更新总结
