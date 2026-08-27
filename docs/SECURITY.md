# Segurança

## Credenciais
GitHub token, Secrets e chaves de APIs: `flutter_secure_storage`; nunca SQLite, SharedPreferences, logs ou clipboard automático.

## Logs
Sanitizar Authorization/Bearer, token, api_key, password e secret. Não depender só da sanitização: código chamador não deve enviar credenciais ao logger.

Diagnósticos de Secrets podem registrar somente nome, operação, HTTP, endpoint, código técnico e mensagem sanitizada da API. O valor do Secret nunca é incluído.

## ZIP
Na implementação: rejeitar caminhos absolutos e `../`, normalizar entradas, limitar tamanho compactado/descompactado e número de arquivos, detectar compressão suspeita, nunca executar conteúdo, usar diretório temporário privado e apagar tudo no `finally`.

## Rede
HTTPS por padrão; cleartext Android desativado.

## Assinatura
Keystore não é commitado. GitHub Actions recebe apenas os quatro Secrets de assinatura e remove os arquivos temporários no final.


## ZIP local

Path traversal, caminhos absolutos, symlinks, ZIP inválido, arquivos individuais acima de 95 MB, mais de 5.000 arquivos e expansão acima de 500 MB são bloqueados antes do envio. Downloads são preparados em diretório temporário privado, publicados na pasta pública Downloads pelo Android e o temporário é apagado no `finally`. URLs temporárias assinadas do GitHub não são persistidas.
