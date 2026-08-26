# Gradle Wrapper

A configuração está fixada em `android/gradle/wrapper/gradle-wrapper.properties`.

Esta entrega não fabricou manualmente `gradle-wrapper.jar`, pois o ambiente de geração não possui Flutter/Gradle nem acesso binário externo. Para manter a cadeia confiável, use:

```bash
./tool/bootstrap_gradle_wrapper.sh
```

O script cria um projeto Android temporário com **o SDK Flutter instalado**, copia apenas `gradlew`, `gradlew.bat` e `gradle-wrapper.jar` oficiais e apaga o temporário. A CI executa o mesmo processo antes de builds Android quando os binários ainda não estiverem versionados.

Depois de gerar e validar, esses três arquivos podem ser versionados normalmente.
