# Zenify DevTools Extension

Official Flutter DevTools extension for Zenify - inspect scopes, queries, and dependencies in real-time.

## Features

### 🌳 Scope Inspector
- Interactive scope hierarchy visualization
- Dependency tracking
- Memory usage per scope
- Live updates on scope creation/disposal

### 💾 Query Cache Inspector
- List all cached queries
- View query data, status, and metadata
- Manual invalidation/refetch from DevTools
- Query timeline with fetch events
- Filter by key pattern or status

### 📊 Performance Metrics
- Widget rebuild counts
- Query fetch times and success rates
- Memory usage trends
- Scope lifecycle statistics
- Performance warnings

## Installation

The DevTools extension is automatically bundled with Zenify v1.7.0+. No separate installation needed!

## Usage

1. Add Zenify to your project:
   ```yaml
   dependencies:
     zenify: ^1.7.0
   ```

2. Run your app in debug mode:
   ```bash
   flutter run
   ```

3. Open Flutter DevTools (automatically opens in browser)

4. Look for the "Zenify" tab in the DevTools tabs

## Development

### Building the Extension

From the `extension/devtools` directory:

```bash
flutter pub get
flutter build web --release
```

The built extension will be in `build/web/`.

### Testing Locally

To test the extension during development:

```bash
flutter run -d chrome
```

## Architecture

- **Framework**: Built with `devtools_extensions` package
- **Platform**: Flutter web app
- **Communication**: Uses Dart VM Service Protocol to inspect running app
- **Integration**: Automatically discovered by DevTools when debugging

## Troubleshooting

### Extension Not Showing Up

1. Ensure you're running Zenify v1.7.0 or later
2. Make sure you're in debug mode (`flutter run`, not `flutter run --release`)
3. Try restarting DevTools
4. Check that `extension/devtools/config.yaml` exists in the Zenify package

### Connection Issues

The extension communicates with your running app via the Dart VM Service. If you see connection errors:

1. Ensure your app is running in debug mode
2. Check that DevTools can connect to your app normally
3. Try hot restarting your app

## Contributing

Found a bug or have a feature request? Please file an issue on the main Zenify repository:
https://github.com/sdegenaar/zenify/issues

## License

MIT License - same as the main Zenify package
