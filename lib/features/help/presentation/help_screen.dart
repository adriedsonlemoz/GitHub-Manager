import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Ajuda')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
          children: const [
            _IntroCard(),
            SizedBox(height: 12),
            _HelpTopic(
              icon: Icons.verified_user_outlined,
              title: 'Conferir build: identidade e versão',
              children: [
                Text(
                  'Antes de enviar um ZIP, o GitHub Manager compara as pistas de identidade e a versão do projeto com o repositório aberto. O nome do ZIP é apenas uma pista; applicationId, pacote e metadados internos são mais confiáveis.',
                ),
                SizedBox(height: 10),
                Text(
                  'Se aparecer “A identidade parece compatível, mas não foi possível comparar as versões com segurança”, normalmente o projeto parece ser o correto, mas a versão do ZIP ou do repositório não foi encontrada em uma fonte reconhecida.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 10),
                _HelpBullet('Node/JavaScript: mantenha o campo "version" no package.json.'),
                _HelpBullet('Flutter: mantenha o campo "version" no pubspec.yaml.'),
                _HelpBullet('Android/Kotlin: use versionName e versionCode em app/build.gradle ou app/build.gradle.kts.'),
                _HelpBullet('Também são reconhecidos github-manager.json e arquivo VERSION.'),
                SizedBox(height: 8),
                Text(
                  'Depois de ajustar a fonte de versão, gere um novo ZIP e abra novamente Enviar build. O quadro de conferência mostrará a versão do projeto a enviar, e não a versão instalada do GitHub Manager.',
                ),
              ],
            ),
            SizedBox(height: 8),
            _HelpTopic(
              icon: Icons.cloud_upload_outlined,
              title: 'Envio de projetos',
              children: [
                Text(
                  'Enviar build sincroniza o conteúdo do ZIP com a branch selecionada. Arquivos antigos que não existem mais no ZIP também podem ser removidos do repositório.',
                ),
                SizedBox(height: 8),
                _HelpBullet('Confira projeto, versão, repositório e branch antes de confirmar.'),
                _HelpBullet('Uma regressão de versão é permitida, mas aparece como aviso.'),
                _HelpBullet('Divergências fortes de identidade exigem confirmação adicional.'),
                _HelpBullet('Se o ZIP for idêntico ao GitHub, o app evita criar commit desnecessário.'),
              ],
            ),
            SizedBox(height: 8),
            _HelpTopic(
              icon: Icons.key_outlined,
              title: 'Token GitHub e permissões',
              children: [
                Text(
                  'O token GitHub fica no armazenamento seguro do Android. Em Configurações > Ajuda e segurança você pode exibir, ocultar ou copiar a chave/token atual e também substituí-la.',
                ),
                SizedBox(height: 8),
                _HelpBullet('Não compartilhe o token em prints, mensagens ou repositórios.'),
                _HelpBullet('Tokens fine-grained precisam das permissões correspondentes ao recurso usado.'),
                _HelpBullet('Abra um repositório e use Diagnóstico do token para conferir permissões sem alterar dados.'),
              ],
            ),
            SizedBox(height: 8),
            _HelpTopic(
              icon: Icons.play_circle_outline_rounded,
              title: 'Builds, APKs e Releases',
              children: [
                Text(
                  'A área Builds acompanha o GitHub Actions. APKs podem vir de Artifacts de workflow ou de assets publicados em Releases; o aplicativo identifica a origem para evitar confusão.',
                ),
                SizedBox(height: 8),
                _HelpBullet('Se uma build falhar, abra os detalhes para ver job, etapa e diagnóstico.'),
                _HelpBullet('Use Copiar diagnóstico para compartilhar o erro sem procurar manualmente no log inteiro.'),
                _HelpBullet('Downloads iniciados podem ser acompanhados pela Central de Downloads.'),
              ],
            ),
            SizedBox(height: 8),
            _HelpTopic(
              icon: Icons.lock_outline_rounded,
              title: 'Secrets do repositório',
              children: [
                Text(
                  'Secrets do GitHub Actions são diferentes do token usado para conectar o aplicativo. Eles pertencem ao repositório e são enviados pela API do GitHub de forma criptografada.',
                ),
                SizedBox(height: 8),
                _HelpBullet('Use a área Secrets dentro do repositório para criar, substituir, importar ou excluir.'),
                _HelpBullet('O GitHub não devolve o valor de um Secret já salvo; o app mostra apenas os nomes existentes.'),
              ],
            ),
            SizedBox(height: 8),
            _HelpTopic(
              icon: Icons.build_circle_outlined,
              title: 'Quando algo não funcionar',
              children: [
                _HelpBullet('Atualize a tela e confirme se o aparelho está conectado à internet.'),
                _HelpBullet('Confira o token e as permissões do repositório.'),
                _HelpBullet('Em falhas de build, abra o diagnóstico antes de repetir a execução.'),
                _HelpBullet('Em falhas de envio, consulte a Central de Envios para ver etapa, HTTP, endpoint e opção de recuperação.'),
              ],
            ),
          ],
        ),
      );
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.help_center_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Guia do GitHub Manager',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Abra um tópico para entender o que cada área faz e como resolver os avisos mais comuns.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _HelpTopic extends StatelessWidget {
  const _HelpTopic({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          leading: Icon(icon),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );
}

class _HelpBullet extends StatelessWidget {
  const _HelpBullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('• '),
            Expanded(child: Text(text)),
          ],
        ),
      );
}
