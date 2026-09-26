part of 'settings_screen.dart';

class _InstalledVersionCard extends StatelessWidget {
  const _InstalledVersionCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<String>(
      future: InstalledVersionBanner.versionLabel,
      builder: (context, snapshot) {
        final version = snapshot.data ?? 'Carregando…';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Icons.verified_outlined,
                  size: 20,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'GitHub Manager instalado',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      version,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChangeNote extends StatelessWidget {
  const _ChangeNote({required this.version, required this.text});

  final String version;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'v$version',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
      );
}

class _IntegrationCard extends StatelessWidget {
  const _IntegrationCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(status, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.primary)),
                    const SizedBox(height: 4),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

class _IntegrationLoadingCard extends StatelessWidget {
  const _IntegrationLoadingCard({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 12),
              Text(title),
            ],
          ),
        ),
      );
}

class _DeviceInformationCard extends StatefulWidget {
  const _DeviceInformationCard();

  @override
  State<_DeviceInformationCard> createState() => _DeviceInformationCardState();
}

class _DeviceInformationCardState extends State<_DeviceInformationCard> {
  late final Future<AndroidDeviceInfo> _future = PlatformActions.getAndroidDeviceInfo();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: FutureBuilder<AndroidDeviceInfo>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 12),
                  Text('Lendo informações do Android…'),
                ],
              ),
            );
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const ListTile(
              leading: Icon(Icons.phone_android_outlined),
              title: Text('Informações do aparelho indisponíveis'),
              subtitle: Text('Não foi possível consultar a arquitetura neste momento.'),
            );
          }
          final info = snapshot.data!;
          final maker = info.manufacturer.trim();
          final model = info.model.trim();
          final deviceName = maker.isEmpty || model.toLowerCase().startsWith(maker.toLowerCase())
              ? model
              : '$maker $model';
          final primary = info.primaryAbi;
          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.phone_android_rounded, color: scheme.primary),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        deviceName.isEmpty ? 'Aparelho Android' : deviceName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _DeviceInfoLine(label: 'Android', value: '${info.androidRelease} (API ${info.sdkInt})'),
                _DeviceInfoLine(label: 'Arquitetura principal', value: primary),
                _DeviceInfoLine(
                  label: 'Arquiteturas suportadas',
                  value: info.supportedAbis.isEmpty ? 'Não informado' : info.supportedAbis.join(', '),
                ),
                _DeviceInfoLine(label: 'Suporte a 64 bits', value: info.supports64Bit ? 'Sim' : 'Não'),
                const SizedBox(height: 7),
                Text(
                  'Esses dados vêm do próprio Android e são usados apenas para recomendar o APK compatível. Nenhuma permissão especial é necessária.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DeviceInfoLine extends StatelessWidget {
  const _DeviceInfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 138,
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );
}
