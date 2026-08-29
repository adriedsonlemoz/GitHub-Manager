import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppMainNavigation extends StatelessWidget {
  const AppMainNavigation({super.key, this.selectedIndex});
  final int? selectedIndex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      child: NavigationBar(
        height: 64,
        selectedIndex: selectedIndex ?? 0,
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/');
              break;
            case 1:
              context.go('/downloads');
              break;
            case 2:
              context.go('/profile');
              break;
            case 3:
              context.go('/?section=followed');
              break;
            case 4:
              context.go('/settings');
              break;
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder_rounded), label: 'Projetos'),
          NavigationDestination(icon: Icon(Icons.download_outlined), selectedIcon: Icon(Icons.download_rounded), label: 'Downloads'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Perfil'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups_rounded), label: 'Acomp.'),
          NavigationDestination(icon: Icon(Icons.tune_rounded), selectedIcon: Icon(Icons.tune_rounded), label: 'Opções'),
        ],
      ),
    );
  }
}
