/// ════════════════════════════════════════════════════════
///  View 层标准写法示例（给开发团队参考）
///
///  规则：
///    ✅ View 只调用 Controller 方法
///    ✅ 导航用 AppRoutes 常量
///    ✅ 错误 / 加载 从 state 读，不在 View 里 try/catch
///    ❌ 不在 View 里直接调 Repository / ApiClient
///    ❌ 不在 View 里硬编码路由字符串
/// ════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../controller/pet_controller.dart';
import '../data/models/pet_model.dart';
import '../../../core/router/app_routes.dart';

/// ConsumerStatefulWidget：能同时管理本地 UI 状态 + 监听 Riverpod 状态
class AddPetPageMvc extends ConsumerStatefulWidget {
  const AddPetPageMvc({super.key});

  @override
  ConsumerState<AddPetPageMvc> createState() => _AddPetPageMvcState();
}

class _AddPetPageMvcState extends ConsumerState<AddPetPageMvc> {
  final _nameCtrl = TextEditingController();
  String _type = 'cat';

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pet = PetModel(
      id: '',              // 由服务端生成
      name: _nameCtrl.text.trim(),
      type: _type,
      emoji: _type == 'cat' ? '🐱' : '🐶',
    );

    // ── 调用 Controller，不关心 API 细节 ──────────────
    final result = await ref
        .read(petControllerProvider.notifier)
        .addPet(pet);

    // ── 根据结果决定 UI 行为 ──────────────────────────
    if (!mounted) return;
    result.when(
      success: (_) {
        // ✅ 使用 AppRoutes 常量跳转，不硬编码
        context.go(AppRoutes.profile);
      },
      failure: (err) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err.userMessage)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // ── 监听 Controller 状态（isLoading）──────────────
    final state = ref.watch(petControllerProvider);

    // ── 监听 errorMessage，弹出后自动清除 ─────────────
    ref.listen(petControllerProvider, (_, next) {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.errorMessage!)));
        ref.read(petControllerProvider.notifier).clearError();
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('添加宠物')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: '宠物名字'),
            ),
            const SizedBox(height: 24),
            // 提交按钮 — 从 state.isLoading 控制，不需要本地 bool
            ElevatedButton(
              onPressed: state.isLoading ? null : _submit,
              child: state.isLoading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('完成添加'),
            ),
          ],
        ),
      ),
    );
  }
}
