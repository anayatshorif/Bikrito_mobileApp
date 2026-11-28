import 'package:flutter/material.dart';

const _navRed = Color(0xFFD83B3B);
const _navMuted = Color(0xFF858585);

class BikritoBottomBar extends StatelessWidget {
  const BikritoBottomBar({
    super.key,
    required this.selectedIndex,
    required this.t,
    required this.onNavigate,
    this.showSaleButton = true,
  });

  final int selectedIndex;
  final String Function(String, String) t;
  final ValueChanged<int> onNavigate;
  final bool showSaleButton;

  @override
  Widget build(BuildContext context) {
    final navItems = [
      _NavItem(
        icon: Icons.home_rounded,
        label: t('Home', 'হোম'),
        selected: selectedIndex == 0,
        onTap: () => onNavigate(0),
        compact: showSaleButton,
      ),
      _NavItem(
        icon: Icons.inventory_2_outlined,
        label: t('Products', 'পণ্য'),
        selected: selectedIndex == 1,
        onTap: () => onNavigate(1),
        compact: showSaleButton,
      ),
      _NavItem(
        icon: Icons.local_shipping_outlined,
        label: t('Orders', 'অর্ডার'),
        selected: selectedIndex == 2,
        onTap: () => onNavigate(2),
        compact: showSaleButton,
      ),
      _NavItem(
        icon: Icons.hourglass_bottom_rounded,
        label: t('Due', 'বাকি'),
        selected: selectedIndex == 3,
        onTap: () => onNavigate(3),
        compact: showSaleButton,
      ),
      _NavItem(
        icon: Icons.receipt_long_rounded,
        label: t('Reports', 'রিপোর্ট'),
        selected: selectedIndex == 4,
        onTap: () => onNavigate(4),
        compact: showSaleButton,
      ),
      _NavItem(
        icon: Icons.menu_rounded,
        label: t('Menu', 'মেনু'),
        selected: selectedIndex == 5,
        onTap: () => onNavigate(5),
        compact: showSaleButton,
      ),
    ];

    Widget navGroup(Iterable<Widget> items) =>
        Row(children: items.map((item) => Expanded(child: item)).toList());

    return BottomAppBar(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.white,
      elevation: 10,
      shape: showSaleButton ? const CircularNotchedRectangle() : null,
      notchMargin: 7,
      child: showSaleButton
          ? Row(
              children: [
                Expanded(child: navGroup(navItems.take(3))),
                const SizedBox(width: 74),
                Expanded(child: navGroup(navItems.skip(3))),
              ],
            )
          : navGroup(navItems),
    );
  }
}

class BikritoSaleButton extends StatelessWidget {
  const BikritoSaleButton({
    super.key,
    required this.t,
    required this.onPressed,
  });

  final String Function(String, String) t;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: const Offset(0, 20),
    child: SizedBox(
      width: 70,
      height: 70,
      child: FloatingActionButton(
        heroTag: 'bikrito-new-sale',
        onPressed: onPressed,
        backgroundColor: _navRed,
        foregroundColor: Colors.white,
        elevation: 5,
        shape: const CircleBorder(),
        tooltip: t('New sale', 'নতুন বিক্রি'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.point_of_sale_rounded, size: 25),
            const SizedBox(height: 2),
            Text(
              t('Sale', 'বিক্রি'),
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  static const _duration = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: SizedBox(
      height: 60,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: selected ? 1 : 0),
        duration: _duration,
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 21 + value * 2,
              color: Color.lerp(_navMuted, _navRed, value),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color.lerp(_navMuted, _navRed, value),
                fontSize: compact ? 8 : 10,
                fontWeight: FontWeight.lerp(
                  FontWeight.w500,
                  FontWeight.w700,
                  value,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
