# 设备解绑流程优化

## 修改日期: 2026-07-07

## 问题

之前的设备解绑流程直接解绑设备，没有先解绑宠物，可能导致：
- 宠物数据残留
- 宠物与设备关联关系不一致
- 后续操作异常

## 解决方案

修改设备解绑流程为两步操作：
1. **先解绑宠物** - 调用 `/pet/info/del` 删除宠物
2. **再解绑设备** - 调用 `/user/device/unbind` 解绑设备

## 修改文件

### 1. 设备列表页 (`device_list_page.dart`)

**位置**: 设备卡片的"解绑设备"操作

**修改前**:
```dart
await ref.read(deviceRepositoryProvider).unbindDevice(device.mac);
```

**修改后**:
```dart
// 1. 先解绑宠物（如果有）
try {
  await ref.read(petPeerRepositoryProvider)
    .deletePet(deviceId: device.deviceId);
} catch (e) {
  // 如果宠物不存在或已解绑，忽略错误继续解绑设备
  debugPrint('[设备解绑] 宠物解绑跳过: $e');
}

// 2. 再解绑设备
await ref.read(deviceRepositoryProvider).unbindDevice(device.mac);
```

### 2. 设备详情页 (`device_detail_page.dart`)

**位置**: 设备详情页的"解绑设备"按钮

**修改前**:
```dart
await ref.read(deviceRepositoryProvider).unbindDevice(widget.mac);
```

**修改后**:
```dart
// 1. 先解绑宠物（如果有）
try {
  // 先查询宠物信息获取 petId
  final pet = await ref.read(petPeerRepositoryProvider)
    .fetchPetInfo(mac: widget.mac);
  if (pet.petId.isNotEmpty) {
    await ref.read(petPeerRepositoryProvider)
      .deletePet(petId: pet.petId);
    debugPrint('[设备解绑] 宠物已解绑: ${pet.petName}');
  }
} catch (e) {
  // 如果宠物不存在或已解绑，忽略错误继续解绑设备
  debugPrint('[设备解绑] 宠物解绑跳过: $e');
}

// 2. 再解绑设备
await ref.read(deviceRepositoryProvider).unbindDevice(widget.mac);
```

## 实现细节

### 错误处理

使用 try-catch 包裹宠物解绑操作，即使宠物解绑失败也继续解绑设备：

**原因**:
- 设备可能本来就没有绑定宠物
- 宠物可能已经被删除
- 避免因宠物解绑失败而阻止设备解绑

### API 接口

**宠物删除接口**: `POST /pet/info/del`

参数（二选一）:
- `petId`: 宠物ID
- `deviceId`: 设备ID

**设备解绑接口**: `POST /user/device/unbind`

参数:
- `mac`: 设备MAC地址

## 测试场景

1. **正常场景**: 设备有绑定宠物
   - ✅ 先删除宠物
   - ✅ 再解绑设备
   - ✅ 设备列表和宠物列表都更新

2. **边界场景**: 设备没有绑定宠物
   - ✅ 宠物删除失败（忽略错误）
   - ✅ 继续解绑设备
   - ✅ 设备列表更新

3. **异常场景**: 宠物API失败
   - ✅ 捕获异常（不影响后续流程）
   - ✅ 继续解绑设备
   - ✅ 打印调试日志

## 日志输出

成功删除宠物:
```
[设备解绑] 宠物已解绑: 小花
```

宠物不存在或已删除:
```
[设备解绑] 宠物解绑跳过: Exception: [iPet] 宠物不存在
```

## 向后兼容

✅ 与现有代码完全兼容
✅ 不影响没有宠物的设备解绑
✅ 保持原有的用户体验

## 相关文档

- `CLAUDE.md` - 项目架构说明
- `PET_FEATURE_UPDATE.md` - 宠物功能更新总结
