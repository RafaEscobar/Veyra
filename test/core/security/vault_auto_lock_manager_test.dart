import 'package:flutter_test/flutter_test.dart';
import 'package:veyra/core/security/vault_auto_lock_manager.dart';

void main() {
  testWidgets('locks after inactivity and activity restarts the timeout', (
    tester,
  ) async {
    int locks = 0;
    final VaultAutoLockManager manager = VaultAutoLockManager(
      timeout: const Duration(seconds: 30),
      onLock: () async => locks++,
    );

    manager.activate();
    await tester.pump(const Duration(seconds: 20));
    manager.registerActivity();
    await tester.pump(const Duration(seconds: 20));
    expect(locks, 0);

    await tester.pump(const Duration(seconds: 10));
    expect(locks, 1);
    expect(manager.isActive, isFalse);
    manager.dispose();
  });

  testWidgets('brief calls resume safely and long interruptions lock', (
    tester,
  ) async {
    DateTime now = DateTime.utc(2026, 9, 29, 12);
    int locks = 0;
    final VaultAutoLockManager manager = VaultAutoLockManager(
      timeout: const Duration(seconds: 30),
      now: () => now,
      onLock: () async => locks++,
    );

    manager.activate();
    manager.movedToBackground();
    now = now.add(const Duration(seconds: 10));
    manager.resumed();
    await tester.pump();
    expect(locks, 0);

    manager.movedToBackground();
    now = now.add(const Duration(seconds: 31));
    manager.resumed();
    await tester.pump();
    expect(locks, 1);
    manager.dispose();
  });

  testWidgets('detached lifecycle locks immediately', (tester) async {
    int locks = 0;
    final VaultAutoLockManager manager = VaultAutoLockManager(
      timeout: const Duration(seconds: 30),
      onLock: () async => locks++,
    )..activate();

    await manager.detached();

    expect(locks, 1);
    manager.dispose();
  });
}
