/// 我的订单页
///
/// ⚠️ 后端暂未提供订单查询接口（/sdkapi/plan/order 只能创建，不能查询列表）。
/// 当前页面为占位空态。后端补「订单列表」接口后，在此接入。
///
/// 预期接口（待后端提供）：
///   GET /sdkapi/orders?page=&limit= → { list: [{ orderId, planId, planName, amount, status, createdAt, paidAt }], page, limit }
library;

import 'package:flutter/material.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_fonts.dart';

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          color: AppColors.onSurface,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('我的订单',
            style: TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: const _EmptyOrders(),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 64,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.3)),
            const SizedBox(height: 14),
            Text('暂无订单',
                style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface)),
            const SizedBox(height: 6),
            Text('订单功能即将上线',
                style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
