# Guia: identificação do projeto e envio de ZIP

## O que o GitHub Manager compara

A confirmação usa a **branch de destino**, lê a versão e os metadados existentes no GitHub e inspeciona o ZIP selecionado. São operações independentes: uma versão reconhecida no ZIP **não** garante uma versão conhecida no repositório.

- Identidade forte: `applicationId` Android e pacote declarado, quando ambos estão disponíveis para comparação.
- Identidade secundária: nome de projeto em metadados internos; nome do arquivo ZIP e nome do repositório são apenas pistas.
- Versão: `github-manager.json`, `app_identity.json`, `pubspec.yaml`, `package.json`, Gradle, `project.godot`, `pyproject.toml`, `Cargo.toml`, `VERSION` ou `manager.sh`, quando reconhecidos.
- O nome visual de um app Android pode vir do atributo `android:label` de `app/src/main/AndroidManifest.xml` (ou `android/app/src/main/AndroidManifest.xml` para Flutter), resolvido a partir de `res/values/strings.xml` quando necessário. Esse rótulo **não** serve como identidade forte.

## Nome não identificado ou nome do repositório mostrado no lugar do projeto

Crie opcionalmente `app_identity.json` na raiz, com conteúdo como:

```json
{
  "displayName": "Câmera da Casa",
  "version": "1.2.3"
}
```

Em projeto Flutter, ajuste `name` e `version` em `pubspec.yaml`; em Android, confirme `android:label` no Manifest e sua referência no `strings.xml`. O nome da conta/repositório GitHub não precisa corresponder ao nome de exibição do aplicativo. Não altere `applicationId` para fazer o aviso desaparecer.

## Versão no GitHub não identificada

1. Confira se a **branch selecionada** contém arquivos. Repositório vazio não possui versão anterior.
2. Confira se a branch tem um arquivo interno de versão reconhecido. No Flutter, use `version: 1.2.3+123` em `pubspec.yaml`.
3. Se a consulta falhou, valide conexão, branch e permissões de acesso à API. O diagnóstico deve distinguir falha de consulta de ausência de versão.
4. Após publicar os metadados, reabra a confirmação para obter nova análise. O nome do ZIP é apenas uma pista, não prova a versão.

## Confirmar envio

Na confirmação compacta aparecem o repositório, a branch, a versão atual → ZIP, a prévia de novos/alterados/removidos e os avisos. Se houver arquivos removidos, abra **Ver arquivos**. A seção **Detalhes técnicos e diagnóstico** reúne os demais metadados e explicações de workflow. **Diagnosticar / Como corrigir** mostra orientações específicas e permite copiar o relatório sem credenciais.

Identificadores fortes incompatíveis continuam exigindo confirmação separada. Workflows preexistentes permanecem protegidos contra remoção implícita; os pré-checks de permissão são mantidos.

## Validação manual

- Nome explicitamente declarado deve prevalecer sobre Manifest, mesmo se já existir versão no ZIP.
- Android literal `android:label` e referência `@string/app_name` devem ser reconhecidos, mas referência sem recursos deve usar fallback.
- Testar branch remota vazia, versão desconhecida, API indisponível, identidade divergente e regressão de versão.
- Testar prévia com arquivos removidos, seleção de branch, checkbox de build, rolagem em tela pequena e opção de copiar o diagnóstico.
