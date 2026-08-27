# GitHub Manager 2.0.21 (200035)

Correções de segurança e confiabilidade nos fluxos de envio e build.

- corrige falso bloqueio quando nome/metadados do ZIP incluem a versão, como `Social-Lite-0.1.1` para o repositório `Social-Lite`;
- versão desconhecida passa a ser um estado explícito de aviso, sem ser tratada como versão mais nova;
- identidade forte prioriza `applicationId`, pacote e metadados; nome do ZIP é apenas uma pista e nunca bloqueia sozinho;
- remove dependência fixa de `android-apk.yml` no build manual;
- workflows APK são identificados pelo conteúdo de `jobs` e `workflow_dispatch`, mantendo nome/caminho apenas como prioridade de busca;
- mantém a checagem por SHA e a segunda verificação antes de `workflow_dispatch` para evitar build duplicada;
- Release Assets passam a usar endpoint autenticado por `asset_id`, compatível com repositórios privados;
- downloads ativos persistem e reaparecem como `Interrompido` após encerramento do aplicativo, com opção de repetir;
- CI passa a reprovar formatação divergente em vez de alterá-la silenciosamente;
- remove o identificador antigo `AL.Sistemas` do logger;
- restringe o `FileProvider` externo à pasta `Download/GitHub/`;
- adiciona testes da trava de projeto, análise estrutural de workflows e corrida/duplicidade do fluxo de build.
