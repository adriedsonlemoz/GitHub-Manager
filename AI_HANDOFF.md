# GitHub Manager — handoff

Estado atual: `2.0.0+200014`, primeira versão oficial da nova geração.

## Arquitetura

Flutter/Dart Android local-first, sem backend obrigatório. GitHub é acessado diretamente pelo aparelho.

## Identidade definitiva

- applicationId: `br.com.githubmanager.app`
- assinatura própria e permanente;
- Secrets: `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`;
- certificado público pinado em `android/release-signing.properties`;
- Android APK e Android Release usam a mesma assinatura.

## Recursos principais

- lista e CRUD de repositórios;
- metadados de projeto, versão e tecnologias;
- navegação/edição/upload de arquivos;
- ZIP com sincronização completa e remoção de arquivos obsoletos;
- Actions: executar, acompanhar, cancelar, reexecutar, jobs/etapas/logs;
- artifacts/APK;
- Commits;
- Bugs via GitHub Issues sem reformulação adicional;
- GitHub Secrets com sealed box;
- configurações, perfil GitHub, Groq/API local e tema;
- Central de Downloads integrada com publicação na pasta pública Downloads;
- download do projeto em ZIP;
- instalação de APK iniciada pelo usuário via FileProvider/instalador Android.

## Segurança

Nunca incluir keystore, `.env`, tokens ou key.properties no ZIP/repositório.
