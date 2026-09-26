# GitHub Manager 2.0.102+200116

## Objetivo

Unificar a apresentação de APKs vindos de GitHub Releases e GitHub Actions Artifacts para que ambos pareçam partes da mesma página, sem remover as diferenças funcionais entre uma publicação permanente e uma saída temporária de workflow.

## Mudanças

- card de Artifact passa a usar o mesmo cabeçalho de versão do card de Release;
- metadados e botões ficam na mesma hierarquia visual;
- remove da listagem o nome bruto como título quando uma versão pode ser extraída;
- remove o aviso técnico de classificação inferida e o buildType redundante;
- mostra variante compacta quando detectável;
- detecta versões já publicadas, mostra **Publicado** e bloqueia publicação duplicada;
- download de Artifact pode usar a Release equivalente e tenta preservar a variante;
- corrige parser de versão para ignorar versionCode/sufixos de APK;
- tela de novidades e histórico de Configurações atualizados.

## Identidade

- versionName: `2.0.102`
- versionCode: `200116`
- package/applicationId: `br.com.githubmanager.app`
