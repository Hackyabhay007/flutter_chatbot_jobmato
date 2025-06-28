# JobMato Flutter Chatbot

A beautiful Flutter chat application that integrates with the JobMato AI Assistant backend. This app provides a mobile-first experience for job searching, career advice, resume analysis, and project suggestions.

## Features

### 🎯 Core Chat Functionality
- **Real-time messaging** with Socket.IO integration
- **Beautiful UI** with Material Design 3
- **Typing indicators** and connection status
- **Message persistence** and session management
- **Auto-scroll** to latest messages

### 💼 Job Search & Career
- **Smart job search** with detailed job cards
- **Load more jobs** pagination
- **Job filtering** by experience, location, salary
- **Internship search** support
- **Apply directly** through job URLs

### 📄 Resume & Career Tools
- **Resume upload** support (PDF, DOC, DOCX)
- **Resume analysis** with AI insights
- **Career advice** personalized recommendations
- **Project suggestions** for skill development

### 🗂️ Session Management
- **Multiple chat sessions** with persistent history
- **Session creation, editing, and deletion**
- **Session titles** and metadata
- **Quick session switching**

### 🎨 User Experience
- **Dark/Light theme** support
- **Responsive design** for all screen sizes
- **Smooth animations** and transitions
- **Offline support** with connection recovery
- **Quick action chips** for common queries

## Prerequisites

- Flutter SDK (3.0.0 or higher)
- Dart SDK (3.0.0 or higher)
- Android Studio / VS Code with Flutter extensions
- JobMato backend server running

## Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd flutter_chatbot
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure backend URL**
   
   Edit `lib/services/chat_service.dart` and update the `baseUrl`:
   ```dart
   static const String baseUrl = 'http://your-server-url:5003';
   ```
   
   For local development:
   ```dart
   static const String baseUrl = 'http://localhost:5003';  // For emulator
   static const String baseUrl = 'http://10.0.2.2:5003';  // For Android emulator
   static const String baseUrl = 'http://YOUR_IP:5003';   // For physical device
   ```

4. **Update authentication token** (optional)
   
   In `lib/services/auth_service.dart`, update the `defaultToken` with your JWT token:
   ```dart
   static const String defaultToken = 'your-jwt-token-here';
   ```

5. **Run the app**
   ```bash
   flutter run
   ```

## Backend Setup

Make sure your JobMato backend server is running with the following endpoints:

- **Socket.IO server** on port 5003
- **Authentication** with JWT tokens
- **Session management** APIs
- **File upload** endpoint for resumes

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   ├── message.dart         # Message model
│   └── job.dart             # Job model
├── services/                # Business logic
│   ├── auth_service.dart    # Authentication
│   └── chat_service.dart    # Chat & Socket.IO
├── screens/                 # UI screens
│   ├── splash_screen.dart   # Loading screen
│   └── chat_screen.dart     # Main chat interface
├── widgets/                 # Reusable widgets
│   ├── message_bubble.dart  # Chat message display
│   ├── job_card.dart        # Job listing card
│   ├── typing_indicator.dart # Typing animation
│   └── session_sidebar.dart # Session management
└── utils/
    └── app_theme.dart       # Theme configuration
```

## Configuration

### Theme Customization

Edit `lib/utils/app_theme.dart` to customize colors and styling:

```dart
static const Color primaryColor = Color(0xFF4F46E5);
static const Color secondaryColor = Color(0xFF7C3AED);
static const Color accentColor = Color(0xFF10B981);
```

### Socket.IO Configuration

The app connects to Socket.IO with the following events:

- `connect` / `disconnect` - Connection status
- `auth_status` - Authentication state
- `send_message` / `receive_message` - Chat messages
- `typing_status` - Typing indicators
- `load_more_jobs` - Job pagination
- Session management events

### Authentication

Currently uses a hardcoded JWT token for demo purposes. For production:

1. Implement proper login screen
2. Add token refresh logic
3. Handle authentication errors
4. Secure token storage

## Features in Detail

### Chat Interface

- **Message bubbles** with user/assistant distinction
- **Job cards** with detailed information
- **Load more** functionality for job results
- **Error handling** with user-friendly messages
- **Connection status** indicators

### Session Management

- **Create new sessions** for different conversations
- **Edit session titles** for better organization
- **Delete sessions** with confirmation
- **Session persistence** across app restarts
- **Active session** highlighting

### Job Search

- **Comprehensive job cards** showing:
  - Job title and company
  - Location and experience requirements
  - Salary information (when available)
  - Skills and job type
  - Application links
  - Posted date

### Resume Features

- **File upload** with progress tracking
- **Format validation** (PDF, DOC, DOCX)
- **Size limits** (10MB max)
- **Upload feedback** and error handling

## Development

### Running in Debug Mode

```bash
flutter run --debug
```

### Building for Release

```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release
```

### Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage
```

## Troubleshooting

### Common Issues

1. **Connection Failed**
   - Check backend server is running
   - Verify correct IP address for physical devices
   - Ensure firewall allows connections

2. **Socket.IO Issues**
   - Check Socket.IO version compatibility
   - Verify authentication token format
   - Check server logs for errors

3. **Build Errors**
   - Run `flutter clean && flutter pub get`
   - Check Flutter SDK version
   - Verify all dependencies are compatible

### Debug Tips

- Enable debug logging in `chat_service.dart`
- Use Flutter Inspector for UI debugging
- Check device logs for Socket.IO events
- Monitor network traffic for API calls

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions:
- Check the troubleshooting section
- Review backend server logs
- Create an issue in the repository 