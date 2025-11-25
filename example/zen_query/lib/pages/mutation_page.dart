import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';
import '../controllers/mutation_controller.dart';
import '../models/models.dart';

/// Demonstrates ZenMutation features:
/// - Creating, updating, and deleting data
/// - Optimistic updates
/// - Mutation lifecycle callbacks (onMutate, onSuccess, onError, onSettled)
/// - Query invalidation after mutations
/// - Loading and error states
class MutationPage extends ZenView<MutationController> {
  const MutationPage({super.key});

  @override
  MutationController Function()? get createController =>
      () => MutationController();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInfoCard(),
        const SizedBox(height: 16),
        _buildCurrentPostSection(),
        const SizedBox(height: 16),
        _buildCreatePostSection(),
        const SizedBox(height: 16),
        _buildUpdatePostSection(),
        const SizedBox(height: 16),
        _buildDeletePostSection(),
        const SizedBox(height: 16),
        _buildLikePostSection(),
        const SizedBox(height: 16),
        _buildMutationStatusSection(),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Row(
              children: [
                Icon(Icons.edit, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'ZenMutation Basics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'This tab demonstrates mutation operations:\n'
              '• Create, Update, Delete operations\n'
              '• Optimistic updates for better UX\n'
              '• Lifecycle callbacks (onMutate, onSuccess, onError)\n'
              '• Automatic query invalidation\n'
              '• Loading and error state management',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPostSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Current Post',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ZenQueryBuilder<Post>(
          query: controller.currentPostQuery,
          builder: (context, post) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(child: Text('${post.id}')),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Post #${post.id} • ${post.createdAt.toString().split('.').first}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(post.content),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.favorite, size: 20, color: Colors.red),
                        const SizedBox(width: 4),
                        Text('${post.likes} likes'),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
          loading: () => const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCreatePostSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create New Post',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller.contentController,
              decoration: const InputDecoration(
                labelText: 'Content',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            Obx(() {
              return ElevatedButton.icon(
                onPressed: controller.createMutation.isLoading.value
                    ? null
                    : controller.createPost,
                icon: controller.createMutation.isLoading.value
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: Text(
                  controller.createMutation.isLoading.value
                      ? 'Creating...'
                      : 'Create Post',
                ),
              );
            }),
            Obx(() {
              if (controller.createMutation.isError) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Error: ${controller.createMutation.error.value}',
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                );
              }
              if (controller.createMutation.isSuccess) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '✓ Post created successfully!',
                    style:
                        TextStyle(color: Colors.green.shade700, fontSize: 12),
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdatePostSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Update Current Post',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Updates use optimistic UI - changes appear instantly!',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.updateTitleController,
              decoration: const InputDecoration(
                labelText: 'New Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Obx(() {
              return ElevatedButton.icon(
                onPressed: controller.updateMutation.isLoading.value
                    ? null
                    : controller.updatePost,
                icon: controller.updateMutation.isLoading.value
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.edit),
                label: Text(
                  controller.updateMutation.isLoading.value
                      ? 'Updating...'
                      : 'Update Post (Optimistic)',
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDeletePostSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Delete Post',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Deleting invalidates queries and loads the next post',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Obx(() {
              return ElevatedButton.icon(
                onPressed: controller.deleteMutation.isLoading.value
                    ? null
                    : controller.deletePost,
                icon: controller.deleteMutation.isLoading.value
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete),
                label: Text(
                  controller.deleteMutation.isLoading.value
                      ? 'Deleting...'
                      : 'Delete Post',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLikePostSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Like Post',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Likes update optimistically with rollback on error',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Obx(() {
              return ElevatedButton.icon(
                onPressed: controller.likeMutation.isLoading.value
                    ? null
                    : controller.likePost,
                icon: controller.likeMutation.isLoading.value
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.favorite),
                label: Text(
                  controller.likeMutation.isLoading.value
                      ? 'Liking...'
                      : 'Like Post ❤️',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink,
                  foregroundColor: Colors.white,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMutationStatusSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(() {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mutation Status',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              _buildMutationStatus(
                'Create',
                controller.createMutation.status.value,
                controller.createMutation.isLoading.value,
              ),
              _buildMutationStatus(
                'Update',
                controller.updateMutation.status.value,
                controller.updateMutation.isLoading.value,
              ),
              _buildMutationStatus(
                'Delete',
                controller.deleteMutation.status.value,
                controller.deleteMutation.isLoading.value,
              ),
              _buildMutationStatus(
                'Like',
                controller.likeMutation.status.value,
                controller.likeMutation.isLoading.value,
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildMutationStatus(
      String name, ZenMutationStatus status, bool isLoading) {
    Color statusColor;
    switch (status) {
      case ZenMutationStatus.loading:
        statusColor = Colors.blue;
        break;
      case ZenMutationStatus.success:
        statusColor = Colors.green;
        break;
      case ZenMutationStatus.error:
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$name Mutation', style: const TextStyle(fontSize: 14)),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                status.toString().split('.').last,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
