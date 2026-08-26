# GitHub Manager 2.0.17 (200031)

## Tela inicial

- O topo de `Meus repositórios` e `Acompanhados` agora usa fundo sólido, igual ao detalhe do repositório.
- Conteúdo rolado não aparece mais por trás do título.
- O título usa reticências quando necessário.
- `GitHub`, `Copiar link` e `Fork` ganharam botões visuais mais claros com ícones e borda.

## Acompanhados

Foi corrigida uma regressão introduzida quando o modo somente leitura foi implementado.

Antes, a opção `Arquivos` era escondida por completo nos repositórios acompanhados. Agora:

- `Arquivos` volta a aparecer;
- pastas podem ser abertas normalmente;
- arquivos podem ser visualizados;
- o editor abre em modo somente leitura;
- não existe botão de salvar;
- não existe mensagem de commit;
- não existe upload;
- não existe criação de arquivo;
- não existe exclusão;
- o repositório externo continua protegido contra alterações.

## Validação

- Estrutura Dart verificada.
- Rotas com `readOnly` revisadas.
- Workflows YAML validados.
- pubspec.yaml, AndroidManifest.xml e JSON validados.
- Versionamento sincronizado.
- ZIP final testado quanto à integridade.

A compilação final deve ser confirmada pelo GitHub Actions.
