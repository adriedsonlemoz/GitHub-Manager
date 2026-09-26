import 'package:flutter/material.dart';

class UpdateWhatsNewScreen extends StatelessWidget {
  const UpdateWhatsNewScreen({
    required this.versionLabel,
    required this.onContinue,
    super.key,
  });

  final String versionLabel;
  final Future<void> Function() onContinue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.new_releases_rounded,
                          color: scheme.onPrimaryContainer,
                          size: 30,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Novidades da atualização',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -.45,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'GitHub Manager $versionLabel',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Esta tela aparece somente no primeiro acesso depois de cada atualização.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                    ),
                    const SizedBox(height: 24),
                    const _UpdateItem(
                      icon: Icons.view_carousel_outlined,
                      title: 'Uma única janela nos Recentes',
                      description:
                          'A abertura do aplicativo, das notificações e o retorno após instalar uma atualização agora reutilizam a mesma tarefa do Android, evitando cartões duplicados em Aplicativos recentes.',
                    ),
                    const SizedBox(height: 12),
                    const _UpdateItem(
                      icon: Icons.install_mobile_outlined,
                      title: 'Retorno após instalar APK',
                      description:
                          'A instalação e a abertura de arquivos não forçam mais uma nova tarefa quando já existe uma Activity ativa do GitHub Manager.',
                    ),
                    const SizedBox(height: 12),
                    const _UpdateItem(
                      icon: Icons.notifications_active_outlined,
                      title: 'Notificações mais seguras',
                      description:
                          'Uploads e downloads reabrem explicitamente a tela principal existente, preservando a pilha e a entrada única do aplicativo nos Recentes.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('whats_new_continue'),
                  onPressed: () async => onContinue(),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Continuar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpdateItem extends StatelessWidget {
  const _UpdateItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: scheme.onPrimaryContainer, size: 22),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
