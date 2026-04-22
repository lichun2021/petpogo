import 'package:flutter/material.dart';
import '../../shared/theme/app_colors.dart';
import '../../app.dart' show AppL10nX;

class MallPage extends StatelessWidget {
  const MallPage({super.key});

  static const _products = [
    _ProductData(name: 'Premium Leather Collar', price: '\$45.00', rating: 4.9, reviews: 128, emoji: '🦮'),
    _ProductData(name: 'Organic Salmon Bites',   price: '\$18.50', rating: 4.7, reviews: 340, emoji: '🐟'),
    _ProductData(name: 'Cloud-9 Plush Bed',      price: '\$89.00', rating: 5.0, reviews: 95,  emoji: '🛏️'),
    _ProductData(name: 'Auto-Feed Smart V2',     price: '\$129.99', rating: 4.8, reviews: 212, emoji: '⏰'),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          // ── AppBar 固定 ─────────────────────────────
          SliverAppBar(
            pinned: true,          // 固定顶部
            floating: false,
            backgroundColor: AppColors.surface.withOpacity(0.95),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            shadowColor: Colors.transparent,
            title: Row(
              children: [
                Icon(Icons.pets_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 6),
                Text('PetPogo',
                    style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 22,
                        fontWeight: FontWeight.w800, color: AppColors.primary)),
              ],
            ),
            actions: [
              IconButton(icon: Icon(Icons.search_rounded, color: AppColors.onSurfaceVariant), onPressed: () {}),
              IconButton(icon: Icon(Icons.shopping_cart_outlined, color: AppColors.onSurfaceVariant), onPressed: () {}),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: CircleAvatar(radius: 16,
                    backgroundColor: AppColors.surfaceContainerHighest,
                    child: Icon(Icons.person_rounded, size: 18, color: AppColors.onSurfaceVariant)),
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                _HeroBanner(l10n: l10n),

                const SizedBox(height: 32),

                // ── 分类标题 ─────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.mallCategories,
                        style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 24,
                            fontWeight: FontWeight.w800, letterSpacing: -0.4, color: AppColors.onSurface)),
                    Text(l10n.mallViewAll,
                        style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13,
                            fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ],
                ),

                const SizedBox(height: 16),
                _CategoriesGrid(l10n: l10n),
                const SizedBox(height: 32),

                // ── Trending ────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.mallTrending,
                        style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 24,
                            fontWeight: FontWeight.w800, letterSpacing: -0.4, color: AppColors.onSurface)),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.surfaceContainerLow, shape: BoxShape.circle),
                      child: Icon(Icons.filter_list_rounded, size: 18, color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                ..._products.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _ProductCard(product: p, l10n: l10n),
                )),

                const SizedBox(height: 16),

                Text(l10n.mallNearbyStores,
                    style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 24,
                        fontWeight: FontWeight.w800, letterSpacing: -0.4, color: AppColors.onSurface)),

                const SizedBox(height: 16),
                _NearbyStoresRow(),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  final dynamic l10n;
  const _HeroBanner({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: AppColors.primaryGradient,
        boxShadow: [BoxShadow(color: AppColors.primaryGlow, blurRadius: 32, offset: const Offset(0, 12))],
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xCCa83206), Colors.transparent],
                  begin: Alignment.centerLeft, end: Alignment.centerRight,
                ),
              ),
            ),
          ),
          const Positioned(right: -10, bottom: -10,
              child: Text('🐱📱', style: TextStyle(fontSize: 100))),
          Positioned(
            left: 24, top: 24, bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.tertiaryContainer, borderRadius: BorderRadius.circular(999)),
                  child: Text(l10n.mallComingSoon,
                      style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 9, fontWeight: FontWeight.w900,
                          letterSpacing: 1.5, color: AppColors.onTertiaryFixed)),
                ),
                const SizedBox(height: 10),
                Text(l10n.mallHeroBannerTitle,
                    style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 26, fontWeight: FontWeight.w800,
                        letterSpacing: -0.8, color: AppColors.onPrimary, height: 1.15)),
                const SizedBox(height: 8),
                Text(l10n.mallHeroBannerDesc,
                    style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11,
                        color: AppColors.onPrimary.withOpacity(0.8), height: 1.4)),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(999)),
                  child: Text(l10n.mallPreorder,
                      style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                          fontWeight: FontWeight.w700, color: AppColors.primary)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoriesGrid extends StatelessWidget {
  final dynamic l10n;
  const _CategoriesGrid({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _CategoryCard(
          label: l10n.mallCategoryFood, count: l10n.mallCategoryFoodCount,
          icon: Icons.restaurant_rounded, bgColor: AppColors.surfaceContainerLow, iconColor: AppColors.primary,
        )),
        const SizedBox(width: 12),
        Expanded(child: _CategoryCard(
          label: l10n.mallCategoryToys, count: l10n.mallCategoryToysCount,
          icon: Icons.smart_toy_rounded, bgColor: AppColors.secondaryContainer, iconColor: AppColors.secondary,
        )),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String label, count;
  final IconData icon;
  final Color bgColor, iconColor;

  const _CategoryCard({required this.label, required this.count, required this.icon, required this.bgColor, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 20,
                      fontWeight: FontWeight.w900, letterSpacing: -0.3, color: AppColors.onSurface)),
                  Text(count, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11, color: AppColors.onSurfaceVariant)),
                ],
              ),
              Icon(icon, color: iconColor, size: 32),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 60,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.white.withOpacity(0.4)),
            child: Center(child: Icon(icon, color: iconColor.withOpacity(0.6), size: 40)),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final _ProductData product;
  final dynamic l10n;
  const _ProductCard({required this.product, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 40, spreadRadius: -8, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
            child: Center(child: Text(product.emoji, style: const TextStyle(fontSize: 40))),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 15,
                        fontWeight: FontWeight.w700, color: AppColors.onSurface), maxLines: 2),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.star_rounded, color: AppColors.tertiaryFixed, size: 14),
                    const SizedBox(width: 3),
                    Text(product.rating.toString(),
                        style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                            fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                    Text(' (${l10n.mallReviews(product.reviews)})',
                        style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11, color: AppColors.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(product.price,
                        style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 18,
                            fontWeight: FontWeight.w800, color: AppColors.primary)),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NearbyStoresRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: const [
          _StoreCard(name: '聚宠生活馆', desc: 'Premium grooming, daycare, and a curated selection of organic pet treats.',
              distance: '1.2 km', rating: '4.9', tags: ['Grooming', 'Cafe'],
              bgColor: AppColors.secondaryContainer, textColor: AppColors.onSecondaryContainer, emoji: '🏪'),
          SizedBox(width: 16),
          _StoreCard(name: 'Paw-some Retreat', desc: 'Specialized spa treatments for small breeds and sensory play areas.',
              distance: '3.5 km', rating: '4.6', tags: ['Spa', 'Training'],
              bgColor: AppColors.surfaceContainerHigh, textColor: AppColors.onSurface, emoji: '🛁'),
          SizedBox(width: 16),
          _StoreCard(name: 'Pet Paradise', desc: 'One-stop shop for all your pet needs. Food, toys, and accessories.',
              distance: '5.0 km', rating: '4.4', tags: ['Shop', 'Food'],
              bgColor: AppColors.surfaceContainerLow, textColor: AppColors.onSurface, emoji: '🌿'),
        ],
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  final String name, desc, distance, rating, emoji;
  final List<String> tags;
  final Color bgColor, textColor;

  const _StoreCard({required this.name, required this.desc, required this.distance,
    required this.rating, required this.tags, required this.bgColor,
    required this.textColor, required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: bgColor, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 20, spreadRadius: -5)],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 130, color: bgColor.withOpacity(0.6),
            child: Stack(
              children: [
                Center(child: Text(emoji, style: const TextStyle(fontSize: 64))),
                Positioned(
                  bottom: 12, left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(999)),
                    child: Text('$distance away',
                        style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 10,
                            fontWeight: FontWeight.w700, color: AppColors.secondary)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(name,
                          style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 15,
                              fontWeight: FontWeight.w800, color: textColor))),
                      Row(children: [
                        Icon(Icons.star_rounded, size: 12, color: AppColors.tertiary),
                        const SizedBox(width: 2),
                        Text(rating, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11,
                            fontWeight: FontWeight.w700, color: textColor)),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11,
                          color: textColor.withOpacity(0.75), height: 1.5)),
                  const SizedBox(height: 8),
                  Row(
                    children: tags.map((t) => Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.4), borderRadius: BorderRadius.circular(999)),
                      child: Text(t, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 9,
                          fontWeight: FontWeight.w700, letterSpacing: 0.8, color: textColor)),
                    )).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductData {
  final String name, price, emoji;
  final double rating;
  final int reviews;
  const _ProductData({required this.name, required this.price, required this.emoji, required this.rating, required this.reviews});
}
