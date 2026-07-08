import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/pressable.dart';
import '../device/data/models/device_product_model.dart';
import '../device/data/repository/device_repository.dart';
import 'scan_qr_page.dart';
import 'robot_wifi_setup_page.dart';
import 'package:petpogo_app/shared/theme/app_fonts.dart';

/// 选择要绑定的设备类型。
///
/// 设计：从 `/device/product/list` 拉取产品目录，按每个产品的
/// [DeviceProductType.bindFlow] 路由到对应的绑定页面。新增产品时
/// 只需在 `DeviceProductType.bindFlow` 加一行映射，本页无需改动。
class SelectDevicePage extends ConsumerStatefulWidget {
  const SelectDevicePage({super.key});

  @override
  ConsumerState<SelectDevicePage> createState() => _SelectDevicePageState();
}

class _SelectDevicePageState extends ConsumerState<SelectDevicePage> {
  List<DeviceProductModel> _products = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      // 优先用 deviceListProvider 已缓存的目录（首页进来一般已加载）
      final cached = ref.read(deviceListProvider).products;
      if (cached.isNotEmpty) {
        if (mounted) setState(() { _products = cached; _loading = false; });
        return;
      }
      final fresh = await ref.read(deviceRepositoryProvider).fetchProducts();
      if (mounted) setState(() { _products = fresh; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onTapProduct(DeviceProductModel product) {
    HapticFeedback.mediumImpact();
    final flow = product.type.bindFlow;
    switch (flow) {
      case BindFlow.scanQr:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ScanQrPage(productKey: product.productKey),
          ),
        );
        break;
      case BindFlow.wifiSetup:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RobotWifiSetupPage(productKey: product.productKey),
          ),
        );
        break;
      case BindFlow.manual:
        // 未识别类型，统一走扫码兜底（手动输入 MAC）
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ScanQrPage(productKey: product.productKey),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('绑定设备',
            style: TextStyle(
                fontFamily: AppFonts.primary,
                fontWeight: FontWeight.w700,
                fontSize: 18)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
          : _products.isEmpty
              ? _buildEmpty()
              : _buildList(),
    );
  }

  Widget _buildEmpty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded,
                  size: 56, color: AppColors.onSurfaceVariant),
              const SizedBox(height: 14),
              Text('产品目录加载失败',
                  style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 15,
                      color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _loadProducts, child: const Text('重试')),
            ],
          ),
        ),
      );

  Widget _buildList() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('选择设备类型',
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AppColors.onSurface)),
          const SizedBox(height: 6),
          Text('不同设备配网方式不同，请选择对应类型',
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 14,
                  color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 28),
          // ── 动态产品列表 ──
          ..._products.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _ProductCard(
                  product: p,
                  onTap: () => _onTapProduct(p),
                ).animate().fadeIn().slideY(begin: 0.1),
              )),
          const Spacer(),
          // 提示
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              Icon(Icons.info_outline_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(
                      _products.map((p) => '${p.displayName}：${_flowHint(p.type.bindFlow)}').join('\n'),
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 13,
                          color: AppColors.onSurfaceVariant,
                          height: 1.6))),
            ]),
          ).animate().fadeIn(delay: 200.ms),
        ],
      ),
    );
  }

  String _flowHint(BindFlow flow) {
    switch (flow) {
      case BindFlow.scanQr:
        return '扫设备背面二维码绑定';
      case BindFlow.wifiSetup:
        return '填写 WiFi 后让设备扫码配网';
      case BindFlow.manual:
        return '手动输入 MAC 绑定';
    }
  }
}

/// 单个产品卡片 —— 图标/配色/标签全部从产品类型推导，不再硬编码。
class _ProductCard extends StatelessWidget {
  final DeviceProductModel product;
  final VoidCallback onTap;
  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final type = product.type;
    final isCollar = type == DeviceProductType.collar;
    final isRobot = type == DeviceProductType.robot;
    final accent = isCollar
        ? AppColors.secondary
        : isRobot
            ? AppColors.primary
            : AppColors.onSurfaceVariant;

    return PressableButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              accent.withValues(alpha: isCollar ? 0.4 : 0.25),
              AppColors.surfaceContainerLowest,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: AppColors.cardShadow, blurRadius: 20, spreadRadius: -4),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              // 图标（按类型选）
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                    color: accent.withValues(alpha: isCollar ? 0.35 : 0.3),
                    borderRadius: BorderRadius.circular(16)),
                child: Center(child: _buildIcon(type, accent)),
              ),
              const SizedBox(width: 14),
              // 名称 + 描述
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(product.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontFamily: AppFonts.primary,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.onSurface)),
                      ),
                      const SizedBox(width: 6),
                      _FlowTag(flow: type.bindFlow),
                    ]),
                    const SizedBox(height: 3),
                    Text(_desc(type),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: AppFonts.primary,
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant,
                            height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 13, color: AppColors.onSurfaceVariant),
            ]),
            const SizedBox(height: 14),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: _features(type)
                  .map((f) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(f,
                            style: TextStyle(
                                fontFamily: AppFonts.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSurface)),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(DeviceProductType type, Color color) {
    switch (type) {
      case DeviceProductType.collar:
        return Stack(alignment: Alignment.center, children: [
          Icon(Icons.circle_outlined, color: color.withValues(alpha: 0.5), size: 32),
          Icon(Icons.pets_rounded, color: color, size: 16),
        ]);
      case DeviceProductType.robot:
        return Icon(Icons.smart_toy_rounded, color: color, size: 30);
      case DeviceProductType.unknown:
        return Icon(Icons.memory_rounded, color: color, size: 28);
    }
  }

  String _desc(DeviceProductType type) {
    switch (type) {
      case DeviceProductType.collar:
        return '给宠物佩戴，实时 GPS 定位 + 健康监测';
      case DeviceProductType.robot:
        return '放置家中，互动陪伴 + 远程监控';
      case DeviceProductType.unknown:
        return '智能设备';
    }
  }

  List<String> _features(DeviceProductType type) {
    switch (type) {
      case DeviceProductType.collar:
        return ['实时定位', '走失预警', '活动轨迹', '健康监测'];
      case DeviceProductType.robot:
        return ['远程互动', 'AI 陪伴', '视频监控', '定位'];
      case DeviceProductType.unknown:
        return ['智能设备'];
    }
  }
}

/// 流程标签（扫码绑定 / WiFi 配网 / 手动）
class _FlowTag extends StatelessWidget {
  final BindFlow flow;
  const _FlowTag({required this.flow});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (flow) {
      BindFlow.scanQr => ('扫码绑定', AppColors.secondary),
      BindFlow.wifiSetup => ('WiFi 配网', AppColors.primary),
      BindFlow.manual => ('手动绑定', AppColors.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          softWrap: false,
          maxLines: 1,
          style: TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }
}
