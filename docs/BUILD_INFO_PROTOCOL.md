# Protocolo opcional de identidade de Build

O GitHub Actions **sempre** atribui um número de execução (`run_number`) independente de `versionName`/`versionCode`. O GitHub Manager não deve confundir os campos.

A partir da 2.0.116, o workflow `GitHub Manager Android APK` gera `dist/build-info.json` e o publica como artifact **separado** `build-info-<run_id>` na mesma execução do APK.

Exemplo ilustrativo:

```json
{
  "schema": 1,
  "run_id": 123456789,
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "version_name": "2.0.116",
  "version_code": 200130,
  "application_id": "br.com.githubmanager.app",
  "apks": [
    {
      "file_name": "GitHub-Manager-2.0.116-200130-universal-release.apk",
      "abi": "universal",
      "size_bytes": 12345678,
      "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    }
  ]
}
```

O arquivo é lido **somente quando a seleção de APK é aberta**. O leitor valida `schema`, `run_id` e SHA do commit contra a execução recebida do GitHub, limita o artifact ZIP e limita a entrada JSON, e desconsidera metadados inválidos sem bloquear o download.

**Limites de confiança:** a informação é declarada pelo workflow daquele repositório, não uma autenticação criptográfica independente do APK. O hash somente é confirmado após comparar com bytes do APK; esta versão não realiza essa comparação automaticamente. A escolha de ABI antes do download é estimada por nome ou por metadados declarados. Depois do download, o app confere estrutura ZIP Android e inspeciona ABIs de bibliotecas nativas. Não há confirmação de assinatura, `minSdk` ou atualização instalada nesta etapa.

Nenhum workflow de outro repositório foi alterado. Quem quiser suportar o protocolo pode publicar um artifact ZIP contendo `build-info.json` com os campos acima e mesmo `run_id`/commit da execução.
