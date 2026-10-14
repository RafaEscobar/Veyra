import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veyra/app/app.dart';
import 'package:veyra/core/errors/app_exception.dart';
import 'package:veyra/core/security/vault_session.dart';
import 'package:veyra/core/storage/secure_storage_service.dart';
import 'package:veyra/features/authentication/domain/entities/auth_lock_state.dart';
import 'package:veyra/features/authentication/domain/repositories/authentication_repository.dart';
import 'package:veyra/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:veyra/features/recovery/domain/entities/recovery_info.dart';
import 'package:veyra/features/recovery/domain/repositories/recovery_repository.dart';
import 'package:veyra/features/vault/application/vault_temporary_cleaner.dart';
import 'package:veyra/features/vault/domain/entities/vault_item.dart';
import 'package:veyra/features/vault/domain/repositories/vault_repository.dart';

void main() {
  testWidgets('starts on the welcome route', (WidgetTester tester) async {
    await tester.pumpWidget(
      VeyraApp(
        themeModeStorage: InMemoryThemeModeStorage(),
        onboardingRepository: FakeOnboardingRepository(),
        authenticationRepository: FakeAuthenticationRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Veyra'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('debug-error-logs')),
      findsOneWidget,
    );
  });

  testWidgets('opens debug error logs beside the theme control', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      VeyraApp(
        themeModeStorage: InMemoryThemeModeStorage(),
        onboardingRepository: FakeOnboardingRepository(),
        authenticationRepository: FakeAuthenticationRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('debug-error-logs')));
    await tester.pumpAndSettle();

    expect(find.text('Logs de errores'), findsOneWidget);
    expect(
      find.text('No se han registrado errores en esta ejecución.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'partial restore without security config never exposes vault metadata',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        VeyraApp(
          themeModeStorage: InMemoryThemeModeStorage(),
          onboardingRepository: FakeOnboardingRepository(),
          authenticationRepository: FakeAuthenticationRepository(),
          vaultRepository: FakeVaultRepository(
            counts: <VaultItemType, int>{
              VaultItemType.image: 4,
              VaultItemType.video: 3,
              VaultItemType.file: 2,
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('start-onboarding')), findsOne);
      expect(find.text('Mi bóveda'), findsNothing);
      expect(find.text('4 elementos'), findsNothing);
    },
  );

  testWidgets('toggles and persists the selected theme', (
    WidgetTester tester,
  ) async {
    final InMemoryThemeModeStorage storage = InMemoryThemeModeStorage();
    await tester.pumpWidget(
      VeyraApp(
        themeModeStorage: storage,
        onboardingRepository: FakeOnboardingRepository(),
        authenticationRepository: FakeAuthenticationRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(_brightnessOf(tester), Brightness.light);

    await tester.tap(find.byKey(const ValueKey<String>('theme-toggle')));
    await tester.pumpAndSettle();

    expect(_brightnessOf(tester), Brightness.dark);
    expect(storage.value, ThemeMode.dark);
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  });

  testWidgets('completes the initial onboarding flow', (
    WidgetTester tester,
  ) async {
    final FakeOnboardingRepository repository = FakeOnboardingRepository();
    await tester.pumpWidget(
      VeyraApp(
        themeModeStorage: InMemoryThemeModeStorage(),
        onboardingRepository: repository,
        authenticationRepository: FakeAuthenticationRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('start-onboarding')));
    await tester.pumpAndSettle();

    for (final int digit in <int>[1, 2, 3, 4]) {
      await tester.tap(find.byKey(ValueKey<String>('pin-$digit')));
    }
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('continue-create-pin')));
    await tester.pumpAndSettle();

    for (final int digit in <int>[1, 2, 3, 4]) {
      await tester.tap(find.byKey(ValueKey<String>('pin-$digit')));
    }
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('continue-confirm-pin')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('question-pet_name')));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('continue-security-question')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('security-answer')),
      '  Mi   Perro  ',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('security-answer-confirmation')),
      'mi perro',
    );
    await tester.tap(find.byKey(const ValueKey<String>('finish-onboarding')));
    await tester.pumpAndSettle();

    expect(find.text('Tu bóveda está lista'), findsOneWidget);
    expect(repository.completed, isTrue);
    expect(repository.pin, '1234');
    expect(repository.normalizedAnswer, 'mi perro');
    expect(repository.questionId, 'pet_name');
  });

  testWidgets('skips onboarding when setup already exists', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      VeyraApp(
        themeModeStorage: InMemoryThemeModeStorage(),
        onboardingRepository: FakeOnboardingRepository(completed: true),
        authenticationRepository: FakeAuthenticationRepository(),
        recoveryRepository: FakeRecoveryRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mi bóveda'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('start-onboarding')),
      findsNothing,
    );
  });

  testWidgets('unlocks a configured vault with the correct PIN', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      VeyraApp(
        themeModeStorage: InMemoryThemeModeStorage(),
        onboardingRepository: FakeOnboardingRepository(completed: true),
        authenticationRepository: FakeAuthenticationRepository(),
        recoveryRepository: FakeRecoveryRepository(),
        vaultRepository: FakeVaultRepository(
          counts: <VaultItemType, int>{
            VaultItemType.image: 24,
            VaultItemType.video: 8,
            VaultItemType.file: 14,
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final int digit in <int>[1, 2, 3, 4]) {
      await tester.tap(find.byKey(ValueKey<String>('pin-$digit')));
    }
    await tester.pumpAndSettle();

    expect(find.text('Mi bóveda'), findsOneWidget);
    expect(find.text('Imágenes'), findsOneWidget);
    expect(find.text('Videos'), findsOneWidget);
    expect(find.text('Archivos'), findsOneWidget);
    expect(find.text('24 elementos'), findsOneWidget);
    expect(find.text('8 elementos'), findsOneWidget);
    expect(find.text('14 elementos'), findsOneWidget);
  });

  testWidgets('navigates from the vault home to every category', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      VeyraApp(
        themeModeStorage: InMemoryThemeModeStorage(),
        onboardingRepository: FakeOnboardingRepository(completed: true),
        authenticationRepository: FakeAuthenticationRepository(),
        recoveryRepository: FakeRecoveryRepository(),
        vaultRepository: FakeVaultRepository(),
      ),
    );
    await tester.pumpAndSettle();

    for (final int digit in <int>[1, 2, 3, 4]) {
      await tester.tap(find.byKey(ValueKey<String>('pin-$digit')));
    }
    await tester.pumpAndSettle();

    const Map<String, String> emptyTitles = <String, String>{
      'images': 'No tienes imágenes ocultas',
      'videos': 'No tienes videos ocultos',
      'files': 'No tienes archivos ocultos',
    };
    for (final MapEntry<String, String> entry in emptyTitles.entries) {
      await tester.tap(find.byKey(ValueKey<String>('category-${entry.key}')));
      await tester.pumpAndSettle();

      expect(find.text(entry.value), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    expect(find.text('Mi bóveda'), findsOneWidget);
  });

  testWidgets('changes and persists the theme from the vault home', (
    WidgetTester tester,
  ) async {
    final InMemoryThemeModeStorage storage = InMemoryThemeModeStorage();
    await tester.pumpWidget(
      VeyraApp(
        themeModeStorage: storage,
        onboardingRepository: FakeOnboardingRepository(completed: true),
        authenticationRepository: FakeAuthenticationRepository(),
        recoveryRepository: FakeRecoveryRepository(),
        vaultRepository: FakeVaultRepository(),
      ),
    );
    await tester.pumpAndSettle();

    for (final int digit in <int>[1, 2, 3, 4]) {
      await tester.tap(find.byKey(ValueKey<String>('pin-$digit')));
    }
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('theme-toggle')));
    await tester.pumpAndSettle();

    final BuildContext context = tester.element(find.text('Mi bóveda'));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(storage.value, ThemeMode.dark);
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  });

  testWidgets('opens recovery only when the user requests it', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      VeyraApp(
        themeModeStorage: InMemoryThemeModeStorage(),
        onboardingRepository: FakeOnboardingRepository(completed: true),
        authenticationRepository: FakeAuthenticationRepository(),
        recoveryRepository: FakeRecoveryRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recuperar acceso'), findsNothing);
    await tester.tap(find.byKey(const ValueKey<String>('forgot-pin')));
    await tester.pumpAndSettle();

    expect(find.text('Recuperar acceso'), findsOneWidget);
  });

  testWidgets('recovers access and returns to unlock with confirmation', (
    WidgetTester tester,
  ) async {
    final FakeRecoveryRepository recoveryRepository = FakeRecoveryRepository();
    await tester.pumpWidget(
      VeyraApp(
        themeModeStorage: InMemoryThemeModeStorage(),
        onboardingRepository: FakeOnboardingRepository(completed: true),
        authenticationRepository: FakeAuthenticationRepository(),
        recoveryRepository: recoveryRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('forgot-pin')));
    await tester.pumpAndSettle();
    expect(
      find.text('¿Cuál era el nombre de tu primera mascota?'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('recovery-answer')),
      '  Mi   Perro ',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('verify-recovery-answer')),
    );
    await tester.pumpAndSettle();

    for (final int digit in <int>[5, 6, 7, 8]) {
      await tester.tap(find.byKey(ValueKey<String>('pin-$digit')));
    }
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('continue-recovery-pin')),
    );
    await tester.pumpAndSettle();

    for (final int digit in <int>[5, 6, 7, 8]) {
      await tester.tap(find.byKey(ValueKey<String>('pin-$digit')));
    }
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('save-recovery-pin')));
    await tester.pumpAndSettle();

    expect(find.text('Mi bóveda'), findsOneWidget);
    expect(find.text('NIP actualizado correctamente.'), findsOneWidget);
    expect(recoveryRepository.normalizedAnswer, 'mi perro');
    expect(recoveryRepository.newPin, '5678');
  });

  testWidgets('shows the remaining time for a persisted lockout', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      VeyraApp(
        themeModeStorage: InMemoryThemeModeStorage(),
        onboardingRepository: FakeOnboardingRepository(completed: true),
        authenticationRepository: FakeAuthenticationRepository(
          lockState: AuthLockState(
            failedAttempts: 5,
            lockUntil: DateTime.now().toUtc().add(const Duration(seconds: 30)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('lockout-message')),
      findsOneWidget,
    );
    expect(find.textContaining('Demasiados intentos'), findsOneWidget);
  });

  testWidgets('auto-lock clears the session, temporaries, and nested route', (
    WidgetTester tester,
  ) async {
    final VaultSession session = VaultSession();
    final FakeTemporaryCleaner cleaner = FakeTemporaryCleaner();
    await tester.pumpWidget(
      VeyraApp(
        themeModeStorage: InMemoryThemeModeStorage(),
        onboardingRepository: FakeOnboardingRepository(completed: true),
        authenticationRepository: SessionAuthenticationRepository(session),
        recoveryRepository: FakeRecoveryRepository(),
        vaultRepository: FakeVaultRepository(),
        vaultSession: session,
        temporaryCleaner: cleaner,
        autoLockTimeout: const Duration(seconds: 10),
      ),
    );
    await tester.pumpAndSettle();
    await _enterPin(tester);

    final BuildContext vaultContext = tester.element(find.text('Imágenes'));
    unawaited(
      Navigator.of(vaultContext).push<void>(
        MaterialPageRoute<void>(
          builder: (context) => const Scaffold(
            body: SizedBox(key: ValueKey<String>('viewer-route-probe')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('viewer-route-probe')),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();

    expect(session.isUnlocked, isFalse);
    expect(cleaner.clearCount, 1);
    expect(find.text('Introduce tu NIP'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('viewer-route-probe')),
      findsNothing,
    );
  });

  testWidgets('brief lifecycle interruption keeps the vault open', (
    WidgetTester tester,
  ) async {
    final VaultSession session = VaultSession();
    final FakeTemporaryCleaner cleaner = FakeTemporaryCleaner();
    await tester.pumpWidget(
      VeyraApp(
        themeModeStorage: InMemoryThemeModeStorage(),
        onboardingRepository: FakeOnboardingRepository(completed: true),
        authenticationRepository: SessionAuthenticationRepository(session),
        recoveryRepository: FakeRecoveryRepository(),
        vaultRepository: FakeVaultRepository(),
        vaultSession: session,
        temporaryCleaner: cleaner,
        autoLockTimeout: const Duration(seconds: 10),
      ),
    );
    await tester.pumpAndSettle();
    await _enterPin(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 5));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(session.isUnlocked, isTrue);
    expect(find.byKey(const ValueKey<String>('category-images')), findsOne);
    expect(cleaner.clearCount, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 10));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(session.isUnlocked, isFalse);
    expect(cleaner.clearCount, 1);
    expect(find.text('Introduce tu NIP'), findsOneWidget);
  });

  testWidgets('closing the app destroys the unlocked vault session', (
    WidgetTester tester,
  ) async {
    final VaultSession session = VaultSession();
    await tester.pumpWidget(
      VeyraApp(
        themeModeStorage: InMemoryThemeModeStorage(),
        onboardingRepository: FakeOnboardingRepository(completed: true),
        authenticationRepository: SessionAuthenticationRepository(session),
        recoveryRepository: FakeRecoveryRepository(),
        vaultRepository: FakeVaultRepository(),
        vaultSession: session,
      ),
    );
    await tester.pumpAndSettle();
    await _enterPin(tester);
    expect(session.isUnlocked, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(session.isUnlocked, isFalse);
  });
}

Future<void> _enterPin(WidgetTester tester) async {
  for (final int digit in <int>[1, 2, 3, 4]) {
    await tester.tap(find.byKey(ValueKey<String>('pin-$digit')));
  }
  await tester.pumpAndSettle();
}

Brightness _brightnessOf(WidgetTester tester) {
  final BuildContext context = tester.element(find.text('Veyra'));
  return Theme.of(context).brightness;
}

final class InMemoryThemeModeStorage implements ThemeModeStorage {
  ThemeMode? value;

  @override
  Future<ThemeMode?> readThemeMode() async => value;

  @override
  Future<void> writeThemeMode(ThemeMode themeMode) async {
    value = themeMode;
  }
}

final class FakeOnboardingRepository implements OnboardingRepository {
  FakeOnboardingRepository({this.completed = false});

  bool completed;
  String? pin;
  String? normalizedAnswer;
  String? questionId;

  @override
  Future<void> complete({
    required String pin,
    required String normalizedRecoveryAnswer,
    required String securityQuestionId,
  }) async {
    this.pin = pin;
    normalizedAnswer = normalizedRecoveryAnswer;
    questionId = securityQuestionId;
    completed = true;
  }

  @override
  Future<bool> isCompleted() async => completed;
}

final class FakeAuthenticationRepository implements AuthenticationRepository {
  FakeAuthenticationRepository({
    this.correctPin = '1234',
    this.lockState = const AuthLockState(failedAttempts: 0, lockUntil: null),
  });

  final String correctPin;
  final AuthLockState lockState;

  @override
  Future<AuthLockState> getLockState() async {
    return lockState;
  }

  @override
  Future<void> unlock(String pin) async {
    if (pin != correctPin) {
      throw const WrongPinException(failedAttempts: 1);
    }
  }
}

final class SessionAuthenticationRepository
    implements AuthenticationRepository {
  SessionAuthenticationRepository(this.session);

  final VaultSession session;

  @override
  Future<AuthLockState> getLockState() async =>
      const AuthLockState(failedAttempts: 0, lockUntil: null);

  @override
  Future<void> unlock(String pin) async {
    session.open(Uint8List.fromList(List<int>.filled(32, 7)));
  }
}

final class FakeTemporaryCleaner implements VaultTemporaryCleaner {
  int clearCount = 0;

  @override
  Future<void> clear() async => clearCount++;
}

final class FakeRecoveryRepository implements RecoveryRepository {
  String? normalizedAnswer;
  String? newPin;

  @override
  void cancel() {}

  @override
  Future<RecoveryInfo> getInfo() async {
    return const RecoveryInfo(
      questionPrompt: '¿Cuál era el nombre de tu primera mascota?',
      failedAttempts: 0,
      lockUntil: null,
    );
  }

  @override
  Future<void> replacePin(String newPin) async {
    this.newPin = newPin;
  }

  @override
  Future<void> verifyAnswer(String normalizedAnswer) async {
    this.normalizedAnswer = normalizedAnswer;
  }
}

final class FakeVaultRepository implements VaultRepository {
  FakeVaultRepository({Map<VaultItemType, int>? counts})
    : _counts = counts ?? <VaultItemType, int>{};

  final Map<VaultItemType, int> _counts;

  @override
  Future<int> countByType(VaultItemType type) async => _counts[type] ?? 0;

  @override
  Future<bool> deleteById(String id) async => false;

  @override
  Future<VaultItem?> getById(String id) async => null;

  @override
  Future<List<VaultItem>> getItemsByType(VaultItemType type) async {
    return <VaultItem>[];
  }

  @override
  Future<void> insert(VaultItem item) async {}

  @override
  Future<bool> update(VaultItem item) async => false;
}
