import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  setUp(() {
    ZenMutation.activeMutations.value = 0;
  });

  test('anyMutating is true while mutations are active', () async {
    expect(ZenMutation.anyMutating, false);

    final mutation = ZenMutation<String, void>(
      mutationFn: (_) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return 'done';
      },
    );

    final future = mutation.mutate(null);
    
    // allow microtasks to run so it updates state
    await Future.delayed(Duration.zero);
    
    expect(ZenMutation.anyMutating, true);
    expect(ZenMutation.activeMutations.value, 1);

    final mutation2 = ZenMutation<String, void>(
      mutationFn: (_) async {
        await Future.delayed(const Duration(milliseconds: 150));
        return 'done2';
      },
    );

    final future2 = mutation2.mutate(null);
    await Future.delayed(Duration.zero);

    expect(ZenMutation.activeMutations.value, 2);
    expect(ZenMutation.anyMutating, true);

    await future;
    expect(ZenMutation.activeMutations.value, 1);
    expect(ZenMutation.anyMutating, true);

    await future2;
    expect(ZenMutation.activeMutations.value, 0);
    expect(ZenMutation.anyMutating, false);
  });
}
