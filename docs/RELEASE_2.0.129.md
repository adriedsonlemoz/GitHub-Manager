# GitHub Manager 2.0.129+200143

Data: 15/10/2026. versionCode Android: 200143.

## Novidade

No detalhe do repositório, o botão **Play** mantém o pop-up de auditoria de publicação. O rodapé agora oferece **Copiar relatório** ao lado de **Fechar**.

O texto copiado inclui: repositório, branch, detecção do projeto Android, completude da árvore do GitHub, aviso de que a avaliação é parcial, contagens de estados, observações, lista integral de verificações técnicas e pendências da Play Console, com estado, descrição e caminho/evidência sempre que disponíveis.

O botão de cópia só é habilitado após a análise concluir com sucesso. Ao copiar, o botão mostra **Copiado** e um aviso na janela. Se ocorrer erro, a janela informa que não foi possível copiar. Uma nova análise limpa o estado anterior. A cópia é local, sem enviar o conteúdo para terceiros.

## Mantido

Nenhuma mudança no motor de auditoria, em `targetSdk`/API 36, downloads de APK, credenciais, assinatura ou publicação. O relatório continua uma checagem parcial e não garante aprovação na Google Play.

## Verificação

Testes de formatação e contrato foram adicionados. Rodar `flutter analyze`, `flutter test` e build Android no GitHub Actions; Flutter SDK não disponível no ambiente local.
