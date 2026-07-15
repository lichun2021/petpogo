import 'package:flutter_test/flutter_test.dart';
import 'package:petpogo_app/core/router/app_routes.dart';

void main() {
  test('login returnTo preserves the full pet share route', () {
    final share = AppRoutes.shareLanding(
      code: 'pet+code/123',
      type: 'pet',
    );
    final login = AppRoutes.loginWithReturnTo(share);

    expect(Uri.parse(login).path, AppRoutes.login);
    expect(Uri.parse(login).queryParameters['returnTo'], share);
    expect(Uri.parse(share).queryParameters['code'], 'pet+code/123');
    expect(Uri.parse(share).queryParameters['type'], 'pet');
  });

  test('pet list has a dedicated route', () {
    expect(AppRoutes.petList, '/pet-list');
  });
}
