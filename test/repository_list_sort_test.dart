import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/features/repositories/domain/github_repository.dart';
import 'package:github_manager/features/repositories/domain/repository_list_sort.dart';

void main() {
  GitHubRepository repository({
    required int id,
    required String name,
    required int sizeKb,
    required DateTime updatedAt,
  }) =>
      GitHubRepository(
        id: id,
        name: name,
        fullName: 'owner/$name',
        isPrivate: false,
        isArchived: false,
        defaultBranch: 'main',
        updatedAt: updatedAt,
        htmlUrl: 'https://github.com/owner/$name',
        sizeKb: sizeKb,
      );

  final alpha = repository(
    id: 1,
    name: 'alpha',
    sizeKb: 100,
    updatedAt: DateTime.utc(2026, 9, 10),
  );
  final beta = repository(
    id: 2,
    name: 'beta',
    sizeKb: 900,
    updatedAt: DateTime.utc(2026, 9, 12),
  );
  final gamma = repository(
    id: 3,
    name: 'gamma',
    sizeKb: 400,
    updatedAt: DateTime.utc(2026, 9, 11),
  );

  test('fixed repositories stay before normal sorting', () {
    final result = sortRepositories(
      [alpha, beta, gamma],
      sort: RepositorySort.sizeDesc,
      favoriteIds: {alpha.id},
    );

    expect(result.map((item) => item.id), [alpha.id, beta.id, gamma.id]);
  });

  test('size sorting works in both directions', () {
    expect(
      sortRepositories(
        [alpha, beta, gamma],
        sort: RepositorySort.sizeDesc,
      ).map((item) => item.id),
      [beta.id, gamma.id, alpha.id],
    );
    expect(
      sortRepositories(
        [alpha, beta, gamma],
        sort: RepositorySort.sizeAsc,
      ).map((item) => item.id),
      [alpha.id, gamma.id, beta.id],
    );
  });

  test('recent sorting keeps newest first', () {
    final result = sortRepositories(
      [alpha, beta, gamma],
      sort: RepositorySort.updatedDesc,
    );

    expect(result.map((item) => item.id), [beta.id, gamma.id, alpha.id]);
  });
}
