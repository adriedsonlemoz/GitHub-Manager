# GitHub Manager 2.0.80

Versão: `2.0.80+200094`
Data: 2026-09-24

## Alterações

- **Branch de destino** na confirmação final agora possui a ação **Alterar**.
- Ao trocar a branch, o GitHub Manager recarrega versão/metadados do repositório e verifica novamente o workflow de APK antes de confirmar.
- ZIPs e repositórios Shell/Termux reconhecem versão em `MANIFEST.json` e em variáveis `*VERSION=` do `manager.sh`.
- Se não houver fonte interna confiável, uma versão presente no nome do ZIP é mostrada somente como pista: `x.y.z • pelo nome do ZIP`.
- A versão inferida do nome não participa da comparação de versão segura; `MANIFEST.json`, `manager.sh`, `VERSION`, `package.json`, `pubspec.yaml`, Gradle e `github-manager.json` continuam sendo fontes internas preferenciais.

## Testes adicionados/atualizados

- contrato do diálogo de envio com retorno tipado e solicitação de troca de branch;
- recálculo do fluxo após troca de branch;
- detecção do Termux Manager por `MANIFEST.json`;
- fallback de versão por `manager.sh`;
- fallback visual pelo nome do ZIP.
