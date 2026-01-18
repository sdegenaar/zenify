import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zenify/zenify.dart';

import 'api.dart';
import 'storage.dart';
import 'feed_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enable Debug Logging
  ZenConfig.configure(level: ZenLogLevel.debug);

  // 1. Initialize Zenify with Persistence
  await Zen.init(
    storage: PreferenceStorage(),
    mutationHandlers: {
      'create_post': (payload) async {
        await MockApi.createPost(Post.fromJson(payload));
      },
      'like_post': (payload) async {
        final post = Post.fromJson(payload);
        await MockApi.likePost(post.id, post.isLiked);
      },
      'delete_post': (payload) async {
        final post = Post.fromJson(payload);
        await MockApi.deletePost(post.id);
      },
    },
  );

  // 2. Setup Network Simulator
  // This allows us to toggle offline mode easily in the simulator
  final networkSimulator = NetworkSimulator();
  Zen.setNetworkStream(networkSimulator.stream);

  runApp(OfflineApp(networkSimulator: networkSimulator));
}

/// Helper to simulate network conditions
class NetworkSimulator {
  final _controller = StreamController<bool>.broadcast();
  final isSimulatedOffline = false.obs();
  List<ConnectivityResult> _lastConnectivity = [ConnectivityResult.wifi];

  NetworkSimulator() {
    // Listen to real changes
    Connectivity().onConnectivityChanged.listen((results) {
      _lastConnectivity = results;
      _emit();
    });

    // Listen to manual toggle (reactive!)
    isSimulatedOffline.addListener(_emit);
  }

  Stream<bool> get stream => _controller.stream;

  void toggle() {
    isSimulatedOffline.value = !isSimulatedOffline.value;
  }

  void _emit() {
    if (isSimulatedOffline.value) {
      _controller.add(false); // Forced Offline
    } else {
      final isOnline = !_lastConnectivity.contains(ConnectivityResult.none);
      _controller.add(isOnline);
    }
  }
}

class OfflineApp extends StatelessWidget {
  final NetworkSimulator networkSimulator;
  const OfflineApp({super.key, required this.networkSimulator});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zenify Offline Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      ),
      home: FeedPage(networkSimulator: networkSimulator),
    );
  }
}

class FeedPage extends ZenView<FeedController> {
  final NetworkSimulator networkSimulator;
  const FeedPage({super.key, required this.networkSimulator});

  @override
  FeedController Function()? get createController =>
      () => FeedController();

  @override
  Widget build(BuildContext context) {
    // Note: ZenView provides 'controller' automatically

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar.large(
            title: const Text('Zen Feed'),
            actions: [
              // Simulation Toggle
              Obx(
                () => Row(
                  // Use Obx for reactivity
                  children: [
                    Text(
                      networkSimulator.isSimulatedOffline.value
                          ? 'Simulating Offline'
                          : 'Live Network',
                    ),
                    Switch(
                      value: networkSimulator.isSimulatedOffline.value,
                      onChanged: (_) => networkSimulator.toggle(),
                      activeThumbColor: Colors.orangeAccent,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Status Indicator
              StreamBuilder<bool>(
                stream: networkSimulator.stream, // Listen to simulated stream
                initialData: true,
                builder: (context, snapshot) {
                  final isOnline = snapshot.data ?? true;
                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Chip(
                      avatar: Icon(
                        isOnline ? Icons.wifi : Icons.wifi_off,
                        color: isOnline
                            ? Colors.greenAccent
                            : Colors.orangeAccent,
                        size: 16,
                      ),
                      label: Text(isOnline ? 'On' : 'Off'),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      visualDensity: VisualDensity.compact,
                      side: BorderSide.none,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
        body: ZenQueryBuilder(
          query: controller.postsQuery,
          builder: (context, posts) {
            if (posts.isEmpty) {
              return const Center(child: Text('No posts yet'));
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              itemCount: posts.length,
              itemBuilder: (context, index) =>
                  PostCard(post: posts[index], controller: controller),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')), // Fix signature
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddPostDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('New Post'),
      ),
    );
  }

  void _showAddPostDialog(BuildContext context) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Post'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            hintText: 'What needs to be done?',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              controller.addPost(textController.text, context);
              Navigator.pop(dialogContext);
            },
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }
}

class PostCard extends StatelessWidget {
  final Post post;
  final FeedController controller; // Required now

  const PostCard({super.key, required this.post, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(child: Text(post.title[0].toUpperCase())),
        title: Text(
          post.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(post.body),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                post.isLiked ? Icons.favorite : Icons.favorite_border,
                color: post.isLiked ? Colors.redAccent : null,
              ),
              onPressed: () => controller.toggleLike(post),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => controller.deletePost(post),
            ),
          ],
        ),
      ),
    );
  }
}
