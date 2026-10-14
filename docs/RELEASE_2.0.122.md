# GitHub Manager 2.0.122+200136

Data: 14/10/2026. VersionCode Android: 200136.

## O que mudou

- **Identificação de projeto ampliada:** repositórios e ZIPs de site estático/portfólio agora podem ser reconhecidos como **Site estático**, com heurísticas para `index.html`, `styles.css`, `app.js`, `README.md`, `vercel.json`, `netlify.toml`, `_headers` e `_redirects`.
- **Nome do projeto web:** quando não há metadado mais forte, o app pode inferir o nome por `README.md` (primeiro `# título`) ou `<title>` do `index.html`, sem sobrescrever metadados explícitos.
- **Tecnologias do repositório:** projetos web estáticos passam a exibir melhor as tecnologias detectadas, incluindo **Web**, **HTML**, **CSS**, **JavaScript** e **Vercel** quando aplicável.
- **Resumo da execução em Builds:** Evento, Branch, Tempo e Etapas agora cabem em **quatro cartões na mesma linha** quando houver largura suficiente. Em telas menores, continua responsivo.
- **Rótulos mais curtos no resumo:** o cartão usa formas compactas como `Push • t1`, `Tempo` e resumo reduzido de etapas para diminuir quebras e melhorar leitura no celular.
- **Downloads de APK:** preservadas as otimizações da 2.0.121 para velocidade mais estável, menos repaints e retomada automática limitada em falhas transitórias.

## Compatibilidade e limites

- A detecção continua **heurística**: não substitui metadados explícitos quando eles existem.
- Não houve compilação Flutter/Gradle local neste ambiente porque `flutter`/`dart` não estavam disponíveis.
- Recomenda-se validar no GitHub Actions e em aparelho Android a nova densidade visual do resumo das execuções e a detecção de projetos web.
