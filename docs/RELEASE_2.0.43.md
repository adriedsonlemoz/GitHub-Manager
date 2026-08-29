# GitHub Manager 2.0.45+200059

- Corrige a API pública do `RepositoryGitService` após a divisão interna por responsabilidades.
- Acompanhados passa a aceitar cache parcial imediatamente e não depende de todas as consultas de rede para renderizar.
- Refresh de Acompanhados é deduplicado e referências confirmadas como indisponíveis deixam de provocar carregamento repetido.
- Erros reais de Acompanhados são propagados para a interface em vez de virar lista vazia ou loading indefinido.
- Configurações mostra a versão instalada em área própria e mantém separadamente as três últimas novidades.
- `repositories_screen.dart` teve ações separadas em arquivo próprio para reduzir concentração de responsabilidades.
