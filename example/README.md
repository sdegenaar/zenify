# 🌟 Zenify Quickstart & Demos

A lightweight, robust reactive state management, hierarchical dependency injection, and asynchronous caching library for Flutter.

---

## ⚡ 3-Step Quickstart Counter

Here is the canonical Zenify pattern in under 30 lines:

```dart
// 1. Controller: State & logic with auto-cleanup
class CounterController extends ZenController {
  final count = 0.obs();
  void increment() => count.value++;
  void decrement() => count.value = (count.value - 1).clamp(0, 999);
}

// 2. Module: Encapsulates dependency injection
class CounterModule extends ZenModule {
  @override
  void register(ZenScope scope) {
    scope.put<CounterController>(CounterController());
  }
}

// 3. View: Auto-resolves controller and binds reactively
class CounterPage extends ZenView<CounterController> {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context, CounterController controller) {
    return Scaffold(
      body: Center(
        child: ZenObserver(() => Text('${controller.count.value}')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: controller.increment,
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

---

## 🚀 Running the Examples

### Minimal Standalone Example
Run the single-file counter example directly:
```bash
cd example
flutter run -t example.dart
```

### Full Interactive Showcase
Run the complete gallery app featuring all 7 categorized demo suites:
```bash
cd example
flutter run
```

---

## 📂 Modular Demos Directory

All feature demonstrations and case studies are organized into modular directories under [`lib/demos/`](lib/demos/):

| Category | Path | Description | Key Topics |
| :--- | :--- | :--- | :--- |
| **01. Counter** | [`lib/demos/01_counter/`](lib/demos/01_counter/) | Minimal 3-step reactive counter | `ZenModule`, `ZenController`, `ZenView`, `ZenObserver`, `ZenUpdater` |
| **02. Reactivity** | [`lib/demos/02_reactivity/`](lib/demos/02_reactivity/) | Core observable state & side-effects | `RxInt`, `RxString`, `RxList`, granular `ZenObserver`, `ever`, `once`, `debounce`, `interval` workers |
| **03. Effects** | [`lib/demos/03_effects/`](lib/demos/03_effects/) | Structured asynchronous lifecycle | `ZenEffect`, `ZenEffectBuilder`, loading/success/error state binding |
| **04. Scopes & DI** | [`lib/demos/04_scopes_and_di/`](lib/demos/04_scopes_and_di/) | Hierarchical scoping & zero-config DI | Canonical `go_router` `ShellRoute` nested inheritance & standard `Navigator` flat scopes |
| **05. ZenQuery** | [`lib/demos/05_zen_query/`](lib/demos/05_zen_query/) | Complete async query & caching suite | Query caching, automated invalidation, optimistic updates, infinite scrolling, stream queries |
| **06. Offline & Sync** | [`lib/demos/06_offline_and_sync/`](lib/demos/06_offline_and_sync/) | Offline-first architecture & persistence | `SharedPreferencesStorage` (`ZenStorage`), mutation queue replay, network status simulation |
| **07. Case Studies** | [`lib/demos/07_case_studies/`](lib/demos/07_case_studies/) | Full real-world production apps | Todo CRUD with persistent storage; Enterprise Multi-Module E-Commerce store |

---

## 💡 Advanced Architecture Highlights

### Zero-Config Hierarchical Scopes (`go_router` `ShellRoute`)
```dart
ShellRoute(
  builder: (context, state, child) => ZenRoute(
    moduleBuilder: () => DepartmentModule(),
    scopeName: 'DepartmentScope',
    page: child, // Nested routes automatically inherit DepartmentScope!
  ),
  routes: [
    GoRoute(
      path: '/department/:id',
      builder: (context, state) => const DepartmentDetailPage(),
    ),
  ],
)
```

### Smart Query Caching & Mutations
```dart
class FeedController extends ZenController {
  late final postsQuery = createQuery<List<Post>>(
    key: ['posts'],
    fetcher: () => api.fetchPosts(),
    staleTime: const Duration(minutes: 5),
  );

  late final addPostMutation = createMutation<Post, String>(
    key: ['addPost'],
    mutationFn: (title) => api.createPost(title),
    onSuccess: (newPost, _) {
      invalidateQueries([['posts']]);
    },
  );
}
```

---

## 🛠 Project Structure

```text
example/
├── example.dart                 # Standalone minimal runnable counter example
├── pubspec.yaml                 # Unified dependencies for all showcase demos
├── README.md                    # Demos overview and documentation
└── lib/
    ├── main.dart                # Showcase catalog hub & theme switcher
    ├── shared/                  # Shared UI components, themes, and mock services
    └── demos/                   # Categorized feature demos & case studies
        ├── 01_counter/
        ├── 02_reactivity/
        ├── 03_effects/
        ├── 04_scopes_and_di/
        ├── 05_zen_query/
        ├── 06_offline_and_sync/
        └── 07_case_studies/
```
