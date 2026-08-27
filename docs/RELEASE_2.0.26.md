# GitHub Manager 2.0.26+200040

## GitHub Secrets

- aceita PAT fine-grained (`github_pat_...`) e clássico (`ghp_...`);
- assistente diferencia permissões e destaca `Secrets: Read and write` para fine-grained e `repo` para clássico;
- TXT/ENV aceita `NOME=valor`, `NOME: valor` e `export NOME=valor`;
- detecta nomes duplicados após normalização;
- valida 48 KB por Secret antes de criptografar;
- valida o limite final de 100 Secrets considerando substituições;
- prévia identifica `Criar` ou `Substituir`;
- importação em lote não para no primeiro erro;
- resultado individual mostra sucesso/falha e diagnóstico técnico sanitizado;
- erros da API preservam HTTP, endpoint e mensagem do GitHub quando disponíveis;
- valores de Secrets nunca entram no relatório copiável;
- limite preventivo de arquivo de importação reduz risco de consumo excessivo de memória;
- testes dedicados cobrem parser, limites, lote parcial, payload criptografado e exclusão.

## Compatibilidade validada

O formato de quatro Secrets usado para assinatura Android (`KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`) é reconhecido pelo parser e fica dentro dos limites individuais do GitHub. Nenhum valor real ou keystore é incluído neste projeto.
