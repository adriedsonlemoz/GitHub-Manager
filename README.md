# GitHub Manager 2.0.0

Primeira versão oficial da nova geração do GitHub Manager em Flutter/Dart para Android.

## Identidade oficial

- versão: `2.0.0+200014`;
- applicationId definitivo: `br.com.githubmanager.app`;
- assinatura oficial própria e permanente;
- APK Release universal com `armeabi-v7a` e `arm64-v8a`;
- sem qualquer dependência de aplicativo, certificado ou versionamento anterior.

## Fluxo principal

A tela inicial lista os repositórios. Dentro de cada projeto ficam Arquivos, Builds, Commits, Bugs e Secrets.

O envio de ZIP é uma sincronização completa: arquivos atuais são atualizados, arquivos novos são adicionados e arquivos obsoletos que não existem mais no ZIP são removidos no mesmo commit.

## Downloads integrados

O app possui uma Central de Downloads própria:

- mostra downloads ativos e progresso;
- salva os arquivos concluídos na pasta pública `Downloads` do aparelho e mantém o histórico no app;
- baixa APKs dos GitHub Actions;
- identifica APK e oferece instalação pelo instalador do Android;
- baixa logs de builds;
- baixa o projeto/repositório em ZIP;
- permite cancelar e excluir downloads da própria pasta `Downloads`;
- exibe um botão flutuante enquanto existe download em andamento.

A instalação de APK é sempre iniciada explicitamente pelo usuário.

## Assinatura

Os workflows `Android APK` e `Android Release` usam os mesmos Secrets oficiais:

- `KEYSTORE_BASE64`
- `KEYSTORE_PASSWORD`
- `KEY_ALIAS`
- `KEY_PASSWORD`

O certificado público esperado fica fixado em `android/release-signing.properties`. Os workflows recusam APK assinado por outra chave.

A keystore e o arquivo `.env` nunca fazem parte deste repositório.

## Ajustes de interface

- tecnologias com identificação visual leve, sem pacote pesado de ícones;
- ações do projeto compactas: Enviar build, GitHub, Copiar link e APK;
- Secrets como item do projeto, com importação de arquivo visível e botões de colar;
- ZIP completo acessível pelo topo do projeto;
- diálogo de novo repositório centralizado e responsivo;
- token GitHub pode ser colado, exibido e copiado para backup nas Configurações;
- criação de token aponta para `https://github.com/settings/tokens/new`.
