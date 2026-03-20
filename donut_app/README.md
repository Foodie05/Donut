# Vision PDF Reader

A modern macOS PDF reader integrated with Vision AI, built with Flutter.

## Features

- **Material Design 3**: Modern UI with NavigationRail and Tonal Elevation.
- **PDF Reading**: High-performance rendering using `pdfrx`.
- **Vision AI**: Analyze PDF pages using OpenAI-compatible Vision models.
- **Local Library**: Manage your PDF collection with local database (ObjectBox).
- **Responsive**: Optimized for macOS wide screens.

## Setup

> Run the following commands from the `donut_app/` directory.

1.  **Dependencies**:
    ```bash
    flutter pub get
    ```

2.  **Code Generation**:
    ```bash
    flutter pub run build_runner build --delete-conflicting-outputs
    ```

3.  **Run**:
    ```bash
    flutter run -d macos
    ```

## Configuration

1.  Go to **Settings**.
2.  Enter your **API Base URL** (e.g., `https://api.openai.com`).
3.  Enter your **API Key**.
4.  Toggle **Auto-Generate Summary** if desired.

## Architecture

- **State Management**: Riverpod
- **Database**: ObjectBox
- **PDF Engine**: pdfrx
- **Network**: Dio
