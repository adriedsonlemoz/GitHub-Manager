import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:github_manager/core/telemetry/app_telemetry_service.dart';
import 'package:github_manager/core/widgets/centered_notice.dart';

class ErrorTelemetryScreen extends StatefulWidget {
  const ErrorTelemetryScreen({super.key});

  @override
  State<ErrorTelemetryScreen> createState() => _ErrorTelemetryScreenState();
}

class _ErrorTelemetryScreenState extends State<ErrorTelemetryScreen> {
  final _service = AppTelemetryService.instance;
  bool _loading = true;
  bool _enabled = true;
  bool _busy = false;
  List<AppTelemetryEvent> _events = const [];
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final enabled = await _service.isEnabled();
      final events = await _service.readEvents(limit: 60);
      if (!mounted) return;
      setState(() {
        _enabled = enabled;
        _events = events;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  Future<void> _setEnabled(bool value) async {
    setState(() => _enabled = value);
    try {
      await _service.setEnabled(value);
      if (!mounted) return;
      showCenteredNotice(
        context,
        value
            ? 'Captura local de erros ativada.'
            : 'Captura local de erros desativada.',
      );
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() => _enabled = !value);
      await _service.recordError(
        source: 'settings.telemetry_toggle',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        showCenteredNotice(
          context,
          'Não foi possível salvar a preferência de telemetria.',
          kind: CenteredNoticeKind.error,
        );
      }
    }
  }

  Future<void> _copyReport() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final report = await _service.buildReport(limit: 100);
      await Clipboard.setData(ClipboardData(text: report));
      if (mounted) showCenteredNotice(context, 'Relatório de erros copiado.');
    } catch (error, stackTrace) {
      await _service.recordError(
        source: 'settings.telemetry_copy',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        showCenteredNotice(
          context,
          'Não foi possível copiar o relatório.',
          kind: CenteredNoticeKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportReport() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _service.exportReportToDownloads(limit: 100);
      if (mounted) {
        showCenteredNotice(
          context,
          'Relatório salvo em Downloads/GitHub Manager.',
        );
      }
    } catch (error, stackTrace) {
      await _service.recordError(
        source: 'settings.telemetry_export',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        showCenteredNotice(
          context,
          'Não foi possível exportar o relatório.',
          kind: CenteredNoticeKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    if (_events.isEmpty || _busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar registros?'),
        content: const Text(
          'Isso apaga somente o histórico local de erros e crashes capturados. '
          'Token, projetos, downloads e configurações não serão alterados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _service.clear();
      if (!mounted) return;
      setState(() => _events = const []);
      showCenteredNotice(context, 'Histórico de erros limpo.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fatalCount = _events.where((event) => event.fatal).length;
    final nativeCount = _events
        .where((event) => event.source == 'android.native')
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Erros e telemetria'),
        actions: [
          IconButton(
            onPressed: _loading || _busy ? null : _reload,
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
              children: [
                Card(
                  child: SwitchListTile(
                    secondary: const Icon(Icons.monitor_heart_outlined),
                    title: const Text('Captura local de erros'),
                    subtitle: const Text(
                      'Registra falhas do Flutter/Dart e o último crash nativo do Android. '
                      'Nada é enviado automaticamente para fora do aparelho.',
                    ),
                    value: _enabled,
                    onChanged: _busy ? null : _setEnabled,
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Resumo',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _Metric(label: 'Registros', value: '${_events.length}'),
                            _Metric(label: 'Falhas fatais', value: '$fatalCount'),
                            _Metric(label: 'Crashes Android', value: '$nativeCount'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'A captura mantém no máximo 120 registros e oculta padrões conhecidos de token, senha, API key e secret.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _copyReport,
                        icon: const Icon(Icons.copy_all_outlined),
                        label: const Text('Copiar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _exportReport,
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('Exportar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _busy || _events.isEmpty ? null : _clear,
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                        ),
                        child: const Icon(Icons.delete_outline_rounded),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Falhas recentes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                if (_loadError != null)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.error_outline_rounded),
                      title: const Text('Não foi possível ler a telemetria'),
                      subtitle: Text(_loadError.toString()),
                    ),
                  )
                else if (_events.isEmpty)
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.check_circle_outline_rounded),
                      title: Text('Nenhuma falha registrada'),
                      subtitle: Text(
                        'Quando ocorrer um erro capturável, ele aparecerá aqui no próximo acesso.',
                      ),
                    ),
                  )
                else
                  ..._events.map((event) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _TelemetryEventCard(event: event),
                      )),
              ],
            ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Text(
          '$label: $value',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
}

class _TelemetryEventCard extends StatelessWidget {
  const _TelemetryEventCard({required this.event});

  final AppTelemetryEvent event;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(
          event.fatal ? Icons.crisis_alert_rounded : Icons.error_outline_rounded,
          color: event.fatal ? scheme.error : scheme.primary,
        ),
        title: Text(
          event.message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text('${_formatDate(event.createdAt)} • ${event.source}'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          if (event.context.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(
                'Contexto: ${jsonEncode(event.context)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (event.stackTrace?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: SelectableText(
                event.stackTrace!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDate(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} '
        '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }
}
