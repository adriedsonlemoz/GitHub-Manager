# GitHub Manager 2.0.54

Versão: `2.0.54+200068`

## Correção principal

- elimina o travamento permanente na tela do logo/splash;
- `runApp()` agora ocorre imediatamente após `WidgetsFlutterBinding.ensureInitialized()`;
- leitura do tema salvo é feita somente depois do primeiro frame, com timeout;
- WorkManager e notificações também inicializam depois do primeiro frame, com timeout e falha isolada;
- falha ou lentidão de plugin nativo não impede mais a interface Flutter de aparecer;
- inicialização de notificações passa a usar o ícone monocromático `ic_stat_github_manager`.

## Mantido

A splash branca e o ícone com área segura da 2.0.53 permanecem inalterados.
