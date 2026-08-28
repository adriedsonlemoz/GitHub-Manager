import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/widgets/app_main_navigation.dart';
import 'package:github_manager/features/home/presentation/home_providers.dart';
import 'package:github_manager/features/home/presentation/github_profile_edit_dialog.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(githubProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Meu perfil')),
      bottomNavigationBar: const AppMainNavigation(selectedIndex: 2),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Não foi possível carregar o perfil.')),
        data: (data) => ListView(padding: const EdgeInsets.all(20), children: [
          Center(child: CircleAvatar(radius: 42, foregroundImage: data.avatarUrl.isEmpty ? null : NetworkImage(data.avatarUrl), child: data.avatarUrl.isEmpty ? const Icon(Icons.person_rounded, size: 42) : null)),
          const SizedBox(height: 14),
          Center(
            child: Text(
              (data.name?.trim().isNotEmpty ?? false) ? data.name! : data.login,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          const SizedBox(height: 6),
          Center(child: Text('@${data.login}')),
          const SizedBox(height: 20),
          FilledButton.tonalIcon(onPressed: () async { final draft=await showGitHubProfileEditDialog(context,data); if(draft!=null){ await ref.read(githubProfileRepositoryProvider).updateProfile(
                    name: draft.name,
                    email: draft.email,
                    blog: draft.blog,
                    twitterUsername: draft.twitterUsername,
                    company: draft.company,
                    location: draft.location,
                    bio: draft.bio,
                    hireable: draft.hireable,
                  ); ref.invalidate(githubProfileProvider); } }, icon: const Icon(Icons.edit_outlined), label: const Text('Editar perfil')),
        ]),
      ),
    );
  }
}
