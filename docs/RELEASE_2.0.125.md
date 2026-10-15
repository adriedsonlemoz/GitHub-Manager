# GitHub Manager 2.0.125+200139

Data: 15/10/2026. Android versionCode: 200139.

## Funcionalidade

- Verificação por `applicationId` do aplicativo instalado, quando os metadados do repositório permitem identificar o pacote.
- Consulta nativa via `getPackageInfo`, com `versionName` e `longVersionCode`; Android 11+ tratado com cautela devido a package visibility.
- Status dinâmico no detalhe de cada repositório: Instalar, Atualizar, Atualizado, Mais recente no aparelho, Sem APK ou Não foi possível verificar.
- Compara versões semanticamente, com `versionCode` apenas quando ambos os lados o informam. Aviso quando a versão remota veio de arquivo/tag sem versionCode confirmado.
- O botão APK mantém a escolha de ARM64/ARM32/x86/Universal e o download direto. Antes de baixar uma versão igual/mais antiga, pede confirmação.
- Informações são verificadas ao abrir o repositório e ao atualizar a tela; não executa instalação silenciosa.

## Limitações

A versão do APK em Releases ou Artifacts pode ser estimada pelo nome. Android 11+ pode ocultar aplicativos e não oferece prova confiável de desinstalação sem visibilidade apropriada. Não se usa QUERY_ALL_PACKAGES. A instalação depende de autorização do Android e assinatura compatível.
