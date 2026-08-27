import 'package:flutter/material.dart';
import 'package:github_manager/features/home/domain/github_profile.dart';

class GitHubProfileDraft {
  const GitHubProfileDraft({
    required this.name,
    required this.email,
    required this.blog,
    required this.twitterUsername,
    required this.company,
    required this.location,
    required this.bio,
    required this.hireable,
  });

  final String name;
  final String email;
  final String blog;
  final String twitterUsername;
  final String company;
  final String location;
  final String bio;
  final bool hireable;
}

Future<GitHubProfileDraft?> showGitHubProfileEditDialog(
  BuildContext context,
  GitHubProfile profile,
) async {
  final name = TextEditingController(text: profile.name ?? '');
  final email = TextEditingController(text: profile.email ?? '');
  final blog = TextEditingController(text: profile.blog ?? '');
  final twitter = TextEditingController(text: profile.twitterUsername ?? '');
  final company = TextEditingController(text: profile.company ?? '');
  final location = TextEditingController(text: profile.location ?? '');
  final bio = TextEditingController(text: profile.bio ?? '');
  var hireable = profile.hireable;

  try {
    return await showDialog<GitHubProfileDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final screen = MediaQuery.sizeOf(context);
          final maxHeight = screen.height * .88 < 760.0 ? screen.height * .88 : 760.0;
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 520, maxHeight: maxHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 8, 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          foregroundImage: profile.avatarUrl.isEmpty
                              ? null
                              : NetworkImage(profile.avatarUrl),
                          child: profile.avatarUrl.isEmpty
                              ? const Icon(Icons.person_outline_rounded)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Editar perfil GitHub',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              Text(
                                '@${profile.login}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          tooltip: 'Fechar',
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: name,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Nome',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: bio,
                            minLines: 2,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Bio',
                              prefixIcon: Icon(Icons.notes_rounded),
                              alignLabelWithHint: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'E-mail público',
                              prefixIcon: Icon(Icons.mail_outline_rounded),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: blog,
                            keyboardType: TextInputType.url,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Site',
                              prefixIcon: Icon(Icons.link_rounded),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: twitter,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Usuário do X / Twitter',
                              prefixIcon: Icon(Icons.alternate_email_rounded),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: company,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Empresa',
                              prefixIcon: Icon(Icons.business_outlined),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: location,
                            decoration: const InputDecoration(
                              labelText: 'Localização',
                              prefixIcon: Icon(Icons.location_on_outlined),
                            ),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: hireable,
                            onChanged: (value) => setDialogState(() => hireable = value),
                            title: const Text('Disponível para contratação'),
                          ),
                          Container(
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Login e foto não podem ser alterados por esta API do GitHub. '
                              'A foto exibida aqui acompanha a imagem configurada na sua conta GitHub.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () => Navigator.pop(
                            dialogContext,
                            GitHubProfileDraft(
                              name: name.text,
                              email: email.text,
                              blog: blog.text,
                              twitterUsername: twitter.text,
                              company: company.text,
                              location: location.text,
                              bio: bio.text,
                              hireable: hireable,
                            ),
                          ),
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Salvar'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  } finally {
    name.dispose();
    email.dispose();
    blog.dispose();
    twitter.dispose();
    company.dispose();
    location.dispose();
    bio.dispose();
  }
}
