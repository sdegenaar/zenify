import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  // ══════════════════════════════════════════════════════════
  // ZenMutationAction enum
  // ══════════════════════════════════════════════════════════
  group('ZenMutationAction', () {
    test('has all expected values', () {
      expect(ZenMutationAction.values, hasLength(4));
      expect(
          ZenMutationAction.values,
          containsAll([
            ZenMutationAction.create,
            ZenMutationAction.update,
            ZenMutationAction.delete,
            ZenMutationAction.custom,
          ]));
    });
  });

  // ══════════════════════════════════════════════════════════
  // ZenMutationJob construction
  // ══════════════════════════════════════════════════════════
  group('ZenMutationJob construction', () {
    test('stores all fields correctly', () {
      final ts = DateTime(2024, 1, 15, 12, 0, 0);
      final job = ZenMutationJob(
        id: 'job-1',
        mutationKey: 'createUser',
        action: ZenMutationAction.create,
        payload: {'name': 'Alice'},
        createdAt: ts,
        retryCount: 2,
      );
      expect(job.id, 'job-1');
      expect(job.mutationKey, 'createUser');
      expect(job.action, ZenMutationAction.create);
      expect(job.payload, {'name': 'Alice'});
      expect(job.createdAt, ts);
      expect(job.retryCount, 2);
    });

    test('defaults retryCount to 0', () {
      final job = ZenMutationJob(
        id: 'j',
        mutationKey: 'k',
        action: ZenMutationAction.update,
        createdAt: DateTime.now(),
      );
      expect(job.retryCount, 0);
    });

    test('defaults payload to empty map', () {
      final job = ZenMutationJob(
        id: 'j',
        mutationKey: 'k',
        action: ZenMutationAction.delete,
        createdAt: DateTime.now(),
      );
      expect(job.payload, isEmpty);
    });
  });

  // ══════════════════════════════════════════════════════════
  // ZenMutationJob serialization
  // ══════════════════════════════════════════════════════════
  group('ZenMutationJob.toJson', () {
    test('serializes id and mutationKey', () {
      final job = ZenMutationJob(
        id: 'abc',
        mutationKey: 'deletePost',
        action: ZenMutationAction.delete,
        createdAt: DateTime(2024, 6, 1),
      );
      final json = job.toJson();
      expect(json['id'], 'abc');
      expect(json['mutationKey'], 'deletePost');
    });

    test('serializes action as index', () {
      final job = ZenMutationJob(
        id: 'id',
        mutationKey: 'k',
        action: ZenMutationAction.custom,
        createdAt: DateTime.now(),
      );
      final json = job.toJson();
      expect(json['action'], ZenMutationAction.custom.index);
    });

    test('serializes payload', () {
      final job = ZenMutationJob(
        id: 'id',
        mutationKey: 'k',
        action: ZenMutationAction.update,
        payload: {'field': 'value', 'count': 5},
        createdAt: DateTime.now(),
      );
      final json = job.toJson();
      expect(json['payload'], {'field': 'value', 'count': 5});
    });

    test('serializes createdAt as ISO8601', () {
      final ts = DateTime.utc(2024, 3, 15, 10, 30, 0);
      final job = ZenMutationJob(
        id: 'id',
        mutationKey: 'k',
        action: ZenMutationAction.create,
        createdAt: ts,
      );
      final json = job.toJson();
      expect(json['createdAt'], ts.toIso8601String());
    });

    test('serializes retryCount', () {
      final job = ZenMutationJob(
        id: 'id',
        mutationKey: 'k',
        action: ZenMutationAction.create,
        createdAt: DateTime.now(),
        retryCount: 3,
      );
      expect(job.toJson()['retryCount'], 3);
    });
  });

  group('ZenMutationJob.fromJson', () {
    test('deserializes all fields', () {
      final ts = DateTime.utc(2024, 5, 20, 8, 0, 0);
      final json = {
        'id': 'job-99',
        'mutationKey': 'updateProfile',
        'action': ZenMutationAction.update.index,
        'payload': {'avatar': 'url'},
        'createdAt': ts.toIso8601String(),
        'retryCount': 1,
      };
      final job = ZenMutationJob.fromJson(json);
      expect(job.id, 'job-99');
      expect(job.mutationKey, 'updateProfile');
      expect(job.action, ZenMutationAction.update);
      expect(job.payload, {'avatar': 'url'});
      expect(job.createdAt.toIso8601String(), ts.toIso8601String());
      expect(job.retryCount, 1);
    });

    test('fromJson handles missing retryCount (defaults to 0)', () {
      final json = {
        'id': 'id',
        'mutationKey': 'k',
        'action': 0,
        'payload': <String, dynamic>{},
        'createdAt': DateTime.now().toIso8601String(),
        // retryCount omitted
      };
      final job = ZenMutationJob.fromJson(json);
      expect(job.retryCount, 0);
    });

    test('round-trip toJson → fromJson preserves all data', () {
      final original = ZenMutationJob(
        id: 'rt-1',
        mutationKey: 'syncData',
        action: ZenMutationAction.custom,
        payload: {'key': 'val', 'num': 42},
        createdAt: DateTime.utc(2025, 1, 1),
        retryCount: 5,
      );
      final roundTripped = ZenMutationJob.fromJson(original.toJson());
      expect(roundTripped.id, original.id);
      expect(roundTripped.mutationKey, original.mutationKey);
      expect(roundTripped.action, original.action);
      expect(roundTripped.payload, original.payload);
      expect(roundTripped.retryCount, original.retryCount);
    });

    test('all ZenMutationAction values survive round-trip', () {
      for (final action in ZenMutationAction.values) {
        final job = ZenMutationJob(
          id: 'id',
          mutationKey: 'k',
          action: action,
          createdAt: DateTime.now(),
        );
        final rt = ZenMutationJob.fromJson(job.toJson());
        expect(rt.action, action);
      }
    });
  });
}
