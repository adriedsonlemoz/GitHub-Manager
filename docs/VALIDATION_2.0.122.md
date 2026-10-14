# Validação 2.0.122

## Ajustes realizados

- Identificação local de ZIP: novo tipo **Site estático**.
- Identificação remota de repositório: novo reconhecimento de portfólio/site estático e heurística de nome por `README.md` / `index.html`.
- Tela de detalhes da execução: resumo reorganizado para até 4 cartões na mesma linha.
- Versionamento sincronizado para `2.0.122+200136`.

## Verificações locais feitas

- Revisão manual dos arquivos alterados.
- Inclusão/ajuste de testes de contrato e testes de detecção:
  - `test/static_web_project_detection_test.dart`
  - `test/repository_project_name_resolution_test.dart`
  - `test/repository_run_details_visual_contract_test.dart`
- Conferência estrutural das referências de versão e notas.

## Pendências

- `flutter analyze` não executado localmente (SDK indisponível).
- `flutter test` não executado localmente (SDK indisponível).
- Build Android/APK não executado localmente.
- Recomenda-se validar na CI e em aparelho a nova compactação do resumo e a identificação de projetos web.
