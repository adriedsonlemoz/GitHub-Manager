# GitHub Manager 2.0.23 (200037)

## Envios resistentes ao segundo plano

- serviço Android em primeiro plano durante sincronizações de projeto;
- notificação persistente com projeto, repositório, etapa e progresso;
- o FlutterEngine principal fica preservado enquanto o serviço está ativo, permitindo continuar o envio ao remover a interface dos recentes;
- a notificação abre novamente o GitHub Manager no mesmo processo quando disponível;
- permissões Android de foreground service/data sync declaradas explicitamente.

## Checkpoints e retomada

- o ZIP aprovado ganha uma cópia privada temporária em `ApplicationSupport/upload_queue`, removida após conclusão;
- blobs já enviados são persistidos por caminho e SHA Git;
- após reinício do processo, o envio ativo é retomado automaticamente pela cópia privada ou pelo ZIP original;
- blobs já enviados são reaproveitados sem novo POST para a API;
- quando o commit já foi criado, a retomada segue diretamente para a verificação/disparo da build;
- o commit é persistido antes de iniciar a etapa de Actions, reduzindo a janela de reenvio desnecessário;
- se o ZIP tiver sido removido, o envio é marcado como interrompido com diagnóstico específico.

## Central de Envios

- cards e diálogo exibem o estado do checkpoint;
- texto de segundo plano diferencia remoção dos recentes de encerramento real do processo;
- restauração do histórico ganhou sincronização de inicialização para testes e retomada determinística.

## Testes

- serialização do checkpoint;
- restauração automática de envio ativo;
- reaproveitamento dos blobs persistidos ao retomar;
- continuidade da build após restauração.

Versão: `2.0.23+200037`.
