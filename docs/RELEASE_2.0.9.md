# GitHub Manager 2.0.9 (200023)

## Repositórios

- Adicionado menu inferior com `Meus repositórios` e `Acompanhados`.
- É possível adicionar quantos repositórios externos quiser usando URL do GitHub ou `owner/repo`.
- Repositórios acompanhados ficam armazenados localmente e são abertos em modo somente leitura.
- Repositórios acompanhados permitem baixar o ZIP do projeto, consultar Builds/Commits e acessar APKs/artifacts.
- A tela de APKs/artifacts também consulta Releases públicas, permitindo baixar APKs publicados oficialmente por outros desenvolvedores.

## Builds

- Atualização automática a cada 6 segundos não substitui mais a tela inteira pelo loading.
- A lista permanece visível e somente status, duração e indicadores são atualizados.
- O detalhe da execução também preserva jobs/steps visíveis durante o refresh.
- Adicionada exclusão permanente de uma execução do GitHub Actions com confirmação.

## APKs e artifacts

- Adicionada exclusão permanente individual de artifact com confirmação.
- Adicionada ação `Excluir APKs anteriores`, que preserva o APK artifact mais recente e remove os anteriores.
- Releases públicas aparecem na mesma área para repositórios externos.

## Interface

- Popup `Editar repositório` reformulado, mais compacto e organizado.
- Versão e branch agora usam cards/badges visuais no mesmo padrão das tecnologias.
- Repositórios acompanhados recebem identificação visual `Acompanhado`.

## Validação

- Estrutura dos Dart modificados verificada.
- YAML dos workflows validado.
- JSON de identidade validado.
- Sincronização de versão validada.
- ZIP final testado quanto à integridade.

O ambiente desta preparação não possui Flutter/Dart instalados; a compilação final deve ser confirmada pelo GitHub Actions.
