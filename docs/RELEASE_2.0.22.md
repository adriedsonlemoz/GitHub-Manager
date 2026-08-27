# GitHub Manager 2.0.22 (200036)

Evolução do envio de projetos e acompanhamento de builds.

- cria a **Central de Envios** com histórico, progresso, etapa, arquivo atual, commit, workflow e logs copiáveis;
- o painel `Enviando build` pode ser minimizado e o usuário pode continuar navegando pelo aplicativo;
- adiciona indicador flutuante global para reabrir envios ativos de qualquer tela;
- persiste o histórico e restaura sincronizações encerradas como `Interrompido`, com opção de tentar novamente;
- grava o histórico de envios de forma serializada e por arquivo temporário, reduzindo risco de JSON parcial em encerramentos;
- se a interrupção ocorreu após o commit, na etapa de build, a nova tentativa reaproveita o commit e não reenvia o ZIP;
- serializa envios em fila para evitar várias mutações concorrentes na API do GitHub;
- ignora tentativa duplicada do mesmo ZIP/repositório enquanto o envio anterior estiver ativo;
- calcula o SHA Git de cada arquivo e reutiliza blobs idênticos já presentes no repositório, reduzindo chamadas e atrasos em projetos grandes;
- preserva `Executar build` quando o ZIP não contém alterações, usando o commit atual sem reenviar o projeto;
- adiciona acesso à Central de Envios pela tela do projeto e Configurações;
- adiciona testes do modelo persistido, fila sequencial, deduplicação e build sem alterações;
- adiciona um banner **VERSÃO DE TESTE** com fundo vermelho e letras brancas, usando a versão canônica de `github-manager.json`;
- versão atualizada para `2.0.22+200036`.
