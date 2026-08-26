# GitHub Manager 2.0.11 (200025)

## Acompanhados — desempenho

- Corrigido o carregamento lento quando existem vários repositórios acompanhados.
- Metadados dos acompanhados são mantidos em cache local para a lista abrir imediatamente depois do primeiro carregamento.
- A atualização dos repositórios externos passa a ser paralela em vez de consultar cada repositório sequencialmente.
- Cards de acompanhados não fazem mais consultas extras para descobrir versão/tecnologias enquanto a lista está sendo exibida.
- Ao abrir um acompanhado, os dados já armazenados são usados primeiro; informações adicionais são carregadas progressivamente.
- A tela de um acompanhado não consulta GitHub Actions/artifacts automaticamente apenas para montar o cabeçalho.

## Adicionar acompanhado

- Adicionado botão `Colar URL` diretamente no campo de endereço.
- Continua aceitando URL completa do GitHub ou `owner/repo`.

## Fork

- Adicionado botão `Fork` nos repositórios acompanhados.
- Também existe ação Fork dentro do detalhe do repositório externo.
- O fork usa a API oficial do GitHub e cria uma cópia na conta conectada.
- Depois do pedido, `Meus repositórios` é atualizado para a cópia aparecer.
- O original acompanhado continua somente leitura.

## Notificações

- Corrigido o conflito de dependências que impedia `flutter pub get` na 2.0.10.
- `flutter_local_notifications` foi atualizado para 20.1.0, compatível com a dependência `xml 7.x` usada pelo GitHub Manager.
- As chamadas de inicialização e exibição foram atualizadas para a API 20.x.
- Mantido o monitor de builds em segundo plano.

## Base preservada

Mantém exclusão de runs/artifacts, Releases públicas, refresh sem piscar a tela, Central de Downloads, sincronização completa, ZIP idêntico e demais correções anteriores.

## Validação

- Estrutura Dart verificada.
- Workflows YAML validados.
- pubspec.yaml válido.
- AndroidManifest.xml válido.
- JSON de identidade válido.
- Sincronização de versão validada.
- ZIP final testado quanto à integridade.

A resolução completa das dependências e a compilação final precisam ser confirmadas pelo GitHub Actions.
