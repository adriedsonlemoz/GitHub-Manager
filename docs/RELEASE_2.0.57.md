# GitHub Manager 2.0.57

Versão: `2.0.57+200071`

## Renomear repositório

- adiciona validação local e no serviço para impedir nomes inválidos antes do PATCH;
- mostra prévia do novo `github.com/owner/nome`;
- verifica conflito com repositório já existente quando a rede permite;
- mantém confirmação pós-falha ambígua para não reportar falso erro quando o GitHub já concluiu o rename;
- atualiza cache de repositórios e referências em Acompanhados;
- invalida caches de permissões e informações do projeto ligados ao nome antigo;
- na tela de detalhes, navega diretamente para a nova rota após sucesso;
- adiciona testes unitários das regras de nome.
