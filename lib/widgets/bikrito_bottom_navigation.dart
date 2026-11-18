import 'package:flutter/material.dart';

const _navRed = Color(0xFFD83B3B);
const _navMuted = Color(0xFF858585);

class BikritoBottomBar extends StatelessWidget {
  const BikritoBottomBar({
    super.key,
    required this.selectedIndex,
    required this.t,
    required this.onNavigate,
  });

  final int selectedIndex;
  final String Function(String, String) t;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) => BottomAppBar(
    height: 70,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    color: Colors.white,
    elevation: 10,
    shape: const CircularNotchedRectangle(),
    notchMargin: 7,
    child: Row(
      children: [
        Expanded(
          child: _NavItem(
            icon: Icons.home_rounded,
            label: t('Home', 'হোম'),
            selected: selectedIndex == 0,
            onTap: () => onNavigate(0),
          ),
        ),
        Expanded(
          child: _NavItem(
            icon: Icons.inventory_2_outlined,
            label: t('Products', 'পণ্য'),
            selected: selectedIndex == 1,
            onTap: () => onNavigate(1),
          ),
        ),
        const SizedBox(width: 66),
        Expanded(
          child: _NavItem(
            icon: Icons.receipt_long_rounded,
            label: t('Reports', 'রিপোর্ট'),
            selected: selectedIndex == 2,
            onTap: () => onNavigate(2),
          ),
        ),
        Expanded(
          child: _NavItem(
            icon: Icons.menu_rounded,
            label: t('Menu', 'মেনু'),
            selected: selectedIndex == 3,
            onTap: () => onNavigate(3),
          ),
        ),
      ],
    ),
  );
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
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: SizedBox(
      height: 60,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 21, color: selected ? _navRed : _navMuted),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? _navRed : _navMuted,
              fontSize: 10,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}
