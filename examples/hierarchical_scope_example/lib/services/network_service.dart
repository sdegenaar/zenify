class NetworkService {
  bool _isInitialized = false;

  // Initialize the network service
  void initialize() {
    if (_isInitialized) return;

    // Set up any configuration, connections, etc.
    _isInitialized = true;
  }

  // Clean up resources when service is no longer needed
  void shutdown() {
    // Close any open connections, cancel subscriptions, etc.
    _isInitialized = false;
  }

  // Check if service is initialized
  bool get isInitialized => _isInitialized;

  // Simulate network requests
  Future<Map<String, dynamic>> get(String endpoint) async {
    // Ensure service is initialized
    if (!_isInitialized) {
      initialize();
    }

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Mock responses
    switch (endpoint) {
      case '/profile':
        return {
          'id': '1',
          'username': 'user',
          'email': 'user@example.com',
          'fullName': 'John Doe',
        };
      default:
        throw Exception('Unknown endpoint: $endpoint');
    }
  }

  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> data) async {
    // Ensure service is initialized
    if (!_isInitialized) {
      initialize();
    }

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Mock responses
    switch (endpoint) {
      case '/login':
        final username = data['username'];
        final password = data['password'];

        if (username == 'user' && password == 'pass') {
          return {
            'success': true,
            'token': 'mock_token_12345',
          };
        } else {
          return {
            'success': false,
            'error': 'Invalid credentials',
          };
        }
      case '/logout':
        return {
          'success': true,
        };
      default:
        throw Exception('Unknown endpoint: $endpoint');
    }
  }
}