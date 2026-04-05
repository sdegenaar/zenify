import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

class _TestService {
  final String label;
  _TestService(this.label);
}

class _OtherService {}

void main() {
  setUp(() => Zen.init());
  tearDown(() => Zen.reset());

  // ══════════════════════════════════════════════════════════
  // Ref<T> basics
  // ══════════════════════════════════════════════════════════
  group('Ref<T> basics', () {
    test('default Ref has null tag and null scope', () {
      final ref = Ref<_TestService>();
      expect(ref.tag, isNull);
      expect(ref.scope, isNull);
    });

    test('Ref with tag stores tag', () {
      final ref = Ref<_TestService>(tag: 'premium');
      expect(ref.tag, 'premium');
    });

    test('toString includes type and no parens for null tag', () {
      final ref = Ref<_TestService>();
      expect(ref.toString(), contains('_TestService'));
      expect(ref.toString(), isNot(contains('(')));
    });

    test('toString includes tag when present', () {
      final ref = Ref<_TestService>(tag: 'vip');
      expect(ref.toString(), contains('vip'));
    });

    test('equality: two Refs with same type and tag are equal', () {
      final a = Ref<_TestService>(tag: 'x');
      final b = Ref<_TestService>(tag: 'x');
      expect(a, b);
    });

    test('equality: two Refs with different tags are not equal', () {
      final a = Ref<_TestService>(tag: 'x');
      final b = Ref<_TestService>(tag: 'y');
      expect(a, isNot(b));
    });

    test('equality: same instance is equal to itself', () {
      final ref = Ref<_TestService>();
      expect(ref, ref);
    });

    test('hashCode is consistent', () {
      final a = Ref<_TestService>(tag: 'h');
      final b = Ref<_TestService>(tag: 'h');
      expect(a.hashCode, b.hashCode);
    });
  });

  // ══════════════════════════════════════════════════════════
  // put / find / exists / findOrNull
  // ══════════════════════════════════════════════════════════
  group('Ref<T>.put and find', () {
    test('put registers instance and find returns it', () {
      final ref = Ref<_TestService>();
      ref.put(_TestService('hello'));
      final found = ref.find();
      expect(found.label, 'hello');
    });

    test('call() is a shorthand for find()', () {
      final ref = Ref<_TestService>();
      ref.put(_TestService('calltest'));
      expect(ref().label, 'calltest');
    });

    test('find throws when not registered', () {
      final ref = Ref<_OtherService>();
      expect(() => ref.find(), throwsA(anything));
    });

    test('findOrNull returns null when not registered', () {
      final ref = Ref<_OtherService>();
      expect(ref.findOrNull(), isNull);
    });

    test('findOrNull returns instance when registered', () {
      final ref = Ref<_TestService>();
      ref.put(_TestService('nullable'));
      expect(ref.findOrNull(), isNotNull);
    });

    test('exists returns false before registration', () {
      expect(Ref<_OtherService>().exists(), false);
    });

    test('exists returns true after registration', () {
      final ref = Ref<_TestService>();
      ref.put(_TestService('existing'));
      expect(ref.exists(), true);
    });
  });

  // ══════════════════════════════════════════════════════════
  // Tagged refs
  // ══════════════════════════════════════════════════════════
  group('Ref<T> with tag', () {
    test('tagged ref does not conflict with untagged ref', () {
      final plain = Ref<_TestService>();
      final tagged = Ref<_TestService>(tag: 'special');
      plain.put(_TestService('plain'));
      tagged.put(_TestService('special'));
      expect(plain.find().label, 'plain');
      expect(tagged.find().label, 'special');
    });

    test('different tags resolve to different instances', () {
      final a = Ref<_TestService>(tag: 'a');
      final b = Ref<_TestService>(tag: 'b');
      a.put(_TestService('A'));
      b.put(_TestService('B'));
      expect(a.find().label, 'A');
      expect(b.find().label, 'B');
    });
  });

  // ══════════════════════════════════════════════════════════
  // delete
  // ══════════════════════════════════════════════════════════
  group('Ref<T>.delete', () {
    test('delete removes the instance', () {
      final ref = Ref<_TestService>();
      ref.put(_TestService('gone'));
      expect(ref.exists(), true);
      ref.delete();
      expect(ref.exists(), false);
    });

    test('delete returns true when instance existed', () {
      final ref = Ref<_TestService>();
      ref.put(_TestService('exists'));
      expect(ref.delete(), true);
    });

    test('delete returns false when instance did not exist', () {
      final ref = Ref<_OtherService>();
      expect(ref.delete(), false);
    });
  });

  // ══════════════════════════════════════════════════════════
  // putLazy
  // ══════════════════════════════════════════════════════════
  group('Ref<T>.putLazy', () {
    test('putLazy registers factory and resolves on first access', () {
      final ref = Ref<_TestService>();
      ref.putLazy(() => _TestService('lazy'));
      expect(ref.exists(), true);
      expect(ref.find().label, 'lazy');
    });

    test('putLazy factory is called only once', () {
      final ref = Ref<_TestService>();
      int calls = 0;
      ref.putLazy(() {
        calls++;
        return _TestService('once');
      });
      ref.find();
      ref.find();
      expect(calls, 1);
    });
  });
}
