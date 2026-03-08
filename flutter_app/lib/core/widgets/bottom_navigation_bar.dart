import 'package:flutter/material.dart';

class EsnafBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const EsnafBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          label: 'Anasayfa',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.list_alt_outlined),
          label: 'Ürünler',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.point_of_sale_outlined),
          label: 'Hızlı Satış',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.pause_circle_outline),
          label: 'Bekleyen Satışlar',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'Hesabım',
        ),
      ],
    );
  }
}
