# Validação 2.0.116

- Origem: código-fonte 2.0.115+200129.
- Revisão estática local de fluxo, testes e YAML; o SDK Flutter/Dart não está disponível neste ambiente.
- CI e Android APK devem rodar no GitHub Actions para confirmar análise, testes e compilação.
- Validar APK arm64, universal, sem ABI no nome, variações e releases desvinculadas da execução.
- Validar manifesto ausente, ZIP inválido, ID/commit divergentes e erros de rede sem bloquear seleção.
- Validar diagnósticos com e sem arquivo/linha, navegação para commit fixo e notificações existentes.
