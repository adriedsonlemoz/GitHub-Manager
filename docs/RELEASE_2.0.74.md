# GitHub Manager 2.0.74

Versão: `2.0.74+200088`
Data: 2026-09-23

## Envio para a branch escolhida

- Ao enviar uma nova versão, o usuário escolhe explicitamente a branch de destino.
- A branch padrão continua pré-selecionada na primeira vez.
- A última branch usada é lembrada localmente por repositório.
- Branches protegidas recebem identificação visual antes da confirmação.
- A leitura de versão, package e `applicationId` do repositório usa a branch selecionada, evitando comparar um ZIP destinado a `dev` contra `main`.

## Builds globais

- Nova aba **Builds** no menu inferior.
- Reúne as execuções recentes do GitHub Actions de todos os projetos acessíveis pela conta.
- Ordena as execuções pela data mais recente e mostra projeto, workflow, número da run, branch e situação.
- Filtros: Todas, Executando, Sucesso e Falhou.
- A consulta é feita em lotes para evitar uma explosão de chamadas simultâneas à API.
- Projetos sem GitHub Actions simplesmente não geram entradas na lista.

## Projetos sem workflow

- A ausência de workflow de APK é informada já na conferência quando puder ser confirmada com segurança e não é mais apresentada como erro depois de um upload concluído.
- O estado final passa a ser **Projeto atualizado • Sem workflow de build**.
- A detecção de ausência de workflow ocorre antes da espera longa por uma run quando possível; erro de rede/API não é convertido em falso "sem workflow".
- O novo preflight **Enviar nova versão** exige Contents, sem obrigar Actions para projetos que apenas armazenam código/scripts.
- Quando existe workflow de APK, **Iniciar build após o envio** fica marcado por padrão e pode ser desativado; sem workflow confirmado, a build fica automaticamente desabilitada.
- Workflows existentes continuam protegidos contra remoção acidental durante a sincronização do ZIP.

## Navegação

O menu inferior passa a ter cinco áreas:

1. Projetos
2. Builds
3. Downloads
4. Perfil
5. Opções

**Acompanhados** passa a ser uma seção interna de Projetos por meio do seletor **Meus projetos / Acompanhados**.

## Validação

Foram atualizados testes para cobrir:

- leitura de metadados na branch escolhida;
- upload concluído sem workflow de APK;
- manutenção do estado de build pendente para workflows existentes porém com problema de gatilho;
- separação entre permissão de sincronização (Contents) e permissão de Actions;
- detecção direta de projeto sem workflow antes de consultar runs do Actions.
