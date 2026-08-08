import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:bdj_studio_sample_pad/l10n/app_localizations.dart';
import 'package:bdj_studio_sample_pad/features/licensing/presentation/providers/license_providers.dart';
import 'package:bdj_studio_sample_pad/features/licensing/presentation/screens/activation_screen.dart';

class FakeLicenseNotifier extends StateNotifier<LicenseState> implements LicenseNotifier {
  FakeLicenseNotifier() : super(const LicenseState(loadingState: LicenseLoadingState.unlicensed));

  @override
  Future<void> activate(String licenseKey) async {}

  @override
  Future<void> deactivate() async {}

  @override
  Future<void> sync() async {}

  @override
  Future<String?> updateLicense(String licenseKey) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('ActivationScreen muestra textos SPP3 en español e inglés y nunca SPP2', (WidgetTester tester) async {
    final fakeNotifier = FakeLicenseNotifier();
    
    // Test Español
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          licenseProvider.overrideWith((ref) => fakeNotifier),
        ],
        child: const MaterialApp(
          locale: Locale('es'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('en'), Locale('es')],
          home: ActivationScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final textFieldEs = tester.widget<TextField>(find.byType(TextField));
    expect(textFieldEs.decoration?.labelText, equals('Llave de licencia SPP3'));
    expect(textFieldEs.decoration?.hintText, equals('Pega aquí tu licencia SPP3'));
    expect(textFieldEs.decoration?.helperText, equals('Ejemplo: SPP3.<payload>.<firma>'));
    expect(find.textContaining('SPP2'), findsNothing);

    // Test Inglés
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          licenseProvider.overrideWith((ref) => fakeNotifier),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('en'), Locale('es')],
          home: ActivationScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final textFieldEn = tester.widget<TextField>(find.byType(TextField));
    expect(textFieldEn.decoration?.labelText, equals('SPP3 license key'));
    expect(textFieldEn.decoration?.hintText, equals('Paste your SPP3 license here'));
    expect(textFieldEn.decoration?.helperText, equals('Example: SPP3.<payload>.<signature>'));
    expect(find.textContaining('SPP2'), findsNothing);
  });
}
