# Build e assinatura oficial

O novo GitHub Manager possui identidade própria e definitiva.

## Identidade Android

- applicationId: `br.com.githubmanager.app`
- versão atual: `2.0.5+200019`
- build: Release AOT universal

## Secrets obrigatórios

Os dois workflows que geram APK restauram a mesma keystore através de:

- `KEYSTORE_BASE64`
- `KEYSTORE_PASSWORD`
- `KEY_ALIAS`
- `KEY_PASSWORD`

Não existem Secrets de teste no fluxo oficial. A chave oficial atual usa o alias `github_manager_release`.

## Certificado

O SHA-256 público do certificado oficial está em `android/release-signing.properties` e corresponde à nova keystore criada especificamente para GitHub Manager.
Depois da compilação, o GitHub Actions extrai o certificado do APK e compara com esse valor. Uma chave diferente faz a build falhar.

## Regra permanente

Nunca substituir a keystore oficial. Se os Secrets forem apagados do GitHub, recriá-los usando o backup original da mesma keystore.
