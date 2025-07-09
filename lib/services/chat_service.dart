import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/message.dart';
import '../models/job.dart';
import 'auth_service.dart';

class ChatService extends ChangeNotifier {
  static const bool isProduction = false;
  static const String baseUrl = isProduction
      ? 'https://chatbot-server.jobmato.com'
      : 'http://127.0.0.1:8000'; // Local development server

  WebSocketChannel? _channel;
  final AuthService _authService;

  // State variables
  bool _isConnected = false;
  bool _isAuthenticated = false;
  bool _isTyping = false;
  bool _isStreaming = false;
  String? _sessionId;
  String? _userId;
  Message? _currentStreamingMessage;

  // Messages and pagination
  final List<Message> _messages = [];
  String _currentSearchQuery = '';
  String _potentialSearchQuery = '';
  bool _hasMoreJobs = false;
  int _currentPage = 1;
  int _totalJobs = 0;

  // Sessions
  final List<Map<String, dynamic>> _sessions = [];

  // Streaming message tracking
  final Map<String, String> _streamingMessageIds = {};

  // Getters
  bool get isConnected => _isConnected;
  bool get isAuthenticated => _isAuthenticated;
  bool get isTyping => _isTyping;
  bool get isStreaming => _isStreaming;
  String? get sessionId => _sessionId;
  String? get userId => _userId;
  Message? get currentStreamingMessage => _currentStreamingMessage;
  List<Message> get messages => List.unmodifiable(_messages);
  String get currentSearchQuery => _currentSearchQuery;
  bool get hasMoreJobs => _hasMoreJobs;
  int get currentPage => _currentPage;
  int get totalJobs => _totalJobs;
  List<Map<String, dynamic>> get sessions => List.unmodifiable(_sessions);

  ChatService(this._authService) {
    // Delay socket initialization to ensure auth service is ready
    Future.delayed(const Duration(milliseconds: 100), () {
      _initializeWebSocket();
    });
  }

  void _initializeWebSocket() {
    try {
      final token = _authService.token;
      debugPrint(
          '🔗 Initializing WebSocket with token: ${token?.substring(0, 20)}...');

      // Create WebSocket connection
      final wsUrl = Uri.parse('ws://127.0.0.1:8000/ws/chat');
      _channel = WebSocketChannel.connect(wsUrl);

      _setupWebSocketListeners();
    } catch (e) {
      debugPrint('WebSocket initialization error: $e');
      _isConnected = false;
      notifyListeners();
    }
  }

  void _setupWebSocketListeners() {
    _channel!.stream.listen(
      (data) {
        _handleWebSocketMessage(data);
      },
      onError: (error) {
        debugPrint('❌ WebSocket error: $error');
        _isConnected = false;
        _isAuthenticated = false;
        notifyListeners();
        // Attempt to reconnect after a delay
        Future.delayed(const Duration(seconds: 5), () {
          if (!_isConnected) {
            _initializeWebSocket();
          }
        });
      },
      onDone: () {
        debugPrint('🔌 WebSocket connection closed');
        _isConnected = false;
        _isAuthenticated = false;
        notifyListeners();
        // Attempt to reconnect after a delay
        Future.delayed(const Duration(seconds: 5), () {
          if (!_isConnected) {
            _initializeWebSocket();
          }
        });
      },
    );

    // Send authentication message once connected
    _sendAuthMessage();
  }

  void _sendAuthMessage() {
    final token = _authService.token ?? AuthService.defaultToken;
    final authMessage = {
      "event": "connect",
      "data": {
        "token": token,
      }
    };
    _sendMessage(authMessage);
  }

  void _handleWebSocketMessage(dynamic data) {
    try {
      String messageStr;
      if (data is String) {
        messageStr = data;
      } else {
        messageStr = json.encode(data);
      }

      final message = json.decode(messageStr);
      final event = message['event'];
      final payload = message['data'] ?? {};

      debugPrint('📨 Received WebSocket message: $event');

      switch (event) {
        case 'auth_status':
          _handleAuthStatus(payload);
          break;
        case 'session_status':
          _handleSessionStatus(payload);
          break;
        case 'receive_message':
          _handleReceivedMessage(payload);
          break;
        case 'typing_status':
          _handleTypingStatus(payload);
          break;
        case 'user_sessions':
          _handleUserSessions(payload);
          break;
        case 'session_loaded':
          _handleSessionLoaded(payload);
          break;
        case 'session_deleted':
          _handleSessionDeleted(payload);
          break;
        case 'session_title_updated':
          _handleSessionTitleUpdated(payload);
          break;
        case 'error':
          _handleError(payload);
          break;
        default:
          debugPrint('📨 Unknown event: $event');
      }
    } catch (e) {
      debugPrint('❌ Error parsing WebSocket message: $e');
      debugPrint('❌ Raw message: $data');
    }
  }

  void _handleAuthStatus(Map<String, dynamic> payload) {
    debugPrint('🔐 Authentication status: $payload');
    if (payload['status'] == 'success') {
      _isAuthenticated = true;
      _isConnected = true;
      _userId = payload['username'];
      debugPrint('✅ Authentication successful');
    } else {
      _isAuthenticated = false;
      debugPrint('❌ Authentication failed: ${payload['message']}');
    }
    notifyListeners();
  }

  void _handleSessionStatus(Map<String, dynamic> payload) {
    debugPrint('📋 Session status: $payload');
    if (payload['session_id'] != null) {
      _sessionId = payload['session_id'];
    }
    notifyListeners();
  }

  void _handleTypingStatus(Map<String, dynamic> payload) {
    debugPrint('📝 Typing status: $payload');
    _isTyping = payload['isTyping'] ?? false;
    notifyListeners();
  }

  void _handleError(Map<String, dynamic> payload) {
    debugPrint('❌ Server error: $payload');
    _addErrorMessage('Sorry, I encountered an error: ${payload['message']}');
  }

  void _handleUserSessions(Map<String, dynamic> payload) {
    debugPrint('📋 User sessions received: $payload');
    if (payload['sessions'] != null) {
      _sessions.clear();
      _sessions.addAll(List<Map<String, dynamic>>.from(payload['sessions']));
      debugPrint('📋 Updated sessions list: ${_sessions.length} sessions');
      notifyListeners();
    }
  }

  void _handleSessionLoaded(Map<String, dynamic> payload) {
    debugPrint('📂 Session loaded: $payload');
    if (payload['sessionId'] != null) {
      _sessionId = payload['sessionId'];
      _loadChatHistory(payload['messages'] ?? []);
      // Refresh sessions to update active indicator
      fetchSessions();
      // Notify listeners to update UI with new session
      notifyListeners();
    }
  }

  void _handleSessionDeleted(Map<String, dynamic> payload) {
    debugPrint('🗑️ Session deleted: $payload');
    if (payload['success'] == true) {
      if (payload['sessionId'] == _sessionId) {
        _clearMessages();
        _sessionId = null;
      }
      fetchSessions();
    }
  }

  void _handleSessionTitleUpdated(Map<String, dynamic> payload) {
    debugPrint('✏️ Session title updated: $payload');
    if (payload['success'] == true) {
      fetchSessions();
    }
  }

  void _loadChatHistory(List<dynamic> messages) {
    debugPrint('📜 Loading chat history: ${messages.length} messages');
    _clearMessages();

    for (var msgData in messages) {
      try {
        final message = Message.fromJson(msgData);
        _messages.add(message);

        // If this is a job card message, update pagination state
        if (message.type == MessageType.jobCard && message.metadata != null) {
          // Don't update search query from history to avoid conflicts
          // Just update pagination info if it's the most recent job search
          if (_messages.length <= 2 ||
              (_messages.isNotEmpty && _messages.last.id == message.id)) {
            _hasMoreJobs = message.metadata!['hasMore'] ?? false;
            _totalJobs = message.metadata!['total'] ??
                message.metadata!['totalJobs'] ??
                0;
            _currentPage = message.metadata!['currentPage'] ??
                message.metadata!['page'] ??
                1;

            // Only set search query if we don't have one
            if (_currentSearchQuery.isEmpty) {
              String? searchQuery = message.metadata!['searchQuery'] ??
                  message.metadata!['originalQuery'] ??
                  message.metadata!['query'];
              if (searchQuery?.isNotEmpty == true) {
                _currentSearchQuery = searchQuery!;
              }
            }
          }
        }

        debugPrint(
            '✅ Loaded message: ${message.sender.name} (${message.type.name}) - "${message.content.substring(0, message.content.length > 50 ? 50 : message.content.length)}..."');
      } catch (e) {
        debugPrint('❌ Failed to parse message: $e');
        debugPrint('❌ Message data: $msgData');
      }
    }

    debugPrint('📋 Total messages loaded: ${_messages.length}');
    debugPrint(
        '📄 Job search state after history load: hasMore=$_hasMoreJobs, page=$_currentPage, total=$_totalJobs, query="$_currentSearchQuery"');
    notifyListeners();
  }

  void _handleReceivedMessage(Map<String, dynamic> data) {
    debugPrint('💬 Received message: $data');
    final message = Message.fromJson(data);
    final isPartial = data['metadata']?['partial'] == true;

    // Handle real streaming from backend
    if (message.sender == MessageSender.assistant && isPartial) {
      _handleStreamingMessage(message);
    } else if (message.sender == MessageSender.assistant && !isPartial) {
      // Final message - complete the streaming
      _completeStreamingMessage(message);
    } else {
      // User message or non-streaming message
      _messages.add(message);
      notifyListeners();
    }

    // Handle job search pagination
    if (message.type == MessageType.jobCard && message.metadata != null) {
      // Try multiple possible field names for the search query
      String? newSearchQuery = message.metadata!['searchQuery'] ??
          message.metadata!['originalQuery'] ??
          message.metadata!['query'] ??
          message.metadata!['searchParams']?['query'] ??
          '';

      // If no search query found in metadata, try potential search query first, then last user message
      if (newSearchQuery?.isEmpty == true) {
        if (_potentialSearchQuery.isNotEmpty) {
          newSearchQuery = _potentialSearchQuery;
          debugPrint('🔍 Using potential search query: $newSearchQuery');
        } else if (_messages.length >= 2) {
          // Look for the last user message (the one before this response)
          for (int i = _messages.length - 2; i >= 0; i--) {
            if (_messages[i].sender == MessageSender.user) {
              newSearchQuery = _messages[i].content;
              break;
            }
          }
        }
      }

      if (newSearchQuery?.isNotEmpty == true) {
        _currentSearchQuery = newSearchQuery!;
      }

      _hasMoreJobs = message.metadata!['hasMore'] ?? false;
      _totalJobs =
          message.metadata!['total'] ?? message.metadata!['totalJobs'] ?? 0;

      if (message.metadata!['isFollowUp'] == true) {
        _currentPage =
            message.metadata!['currentPage'] ?? message.metadata!['page'] ?? 1;
      } else {
        _currentPage = 1;
      }

      debugPrint(
          'Job search state: hasMore=$_hasMoreJobs, page=$_currentPage, total=$_totalJobs, query="$_currentSearchQuery"');
    }

    _isTyping = false;
  }

  void _handleStreamingMessage(Message message) {
    // Use backend id for streaming!
    String streamingId = message.id;

    int index = _messages.indexWhere((m) => m.id == streamingId);
    if (index != -1) {
      // Update existing streaming message
      _messages[index] = message;
      _currentStreamingMessage = message;
      notifyListeners();
    } else {
      // Add new streaming message
      _messages.add(message);
      _currentStreamingMessage = message;
      notifyListeners();
    }
  }

  void _completeStreamingMessage(Message finalMessage) {
    String streamingId = finalMessage.id;
    int index = _messages.indexWhere((m) => m.id == streamingId);
    if (index != -1) {
      _messages[index] = finalMessage;
      debugPrint('✅ Completed streaming message: $streamingId');
    } else {
      _messages.add(finalMessage);
      debugPrint('📝 Added final message: ${finalMessage.id}');
    }
    _isStreaming = false;
    _currentStreamingMessage = null;
    notifyListeners();
  }

  String? _getStreamingMessageId(String? agent) {
    return _streamingMessageIds[agent ?? 'unknown'];
  }

  void _addErrorMessage(String errorText) {
    final message = Message(
      id: const Uuid().v4(),
      content: errorText,
      sender: MessageSender.assistant,
      type: MessageType.error,
      timestamp: DateTime.now(),
    );
    _messages.add(message);
    _isTyping = false;
    notifyListeners();
  }

  void _sendMessage(Map<String, dynamic> message) {
    if (_channel != null) {
      try {
        final messageStr = json.encode(message);
        _channel!.sink.add(messageStr);
        debugPrint('📤 Sent WebSocket message: ${message['event']}');
      } catch (e) {
        debugPrint('❌ Error sending WebSocket message: $e');
      }
    } else {
      debugPrint('❌ WebSocket channel not available');
    }
  }

  // Public methods
  void sendMessage(String content) {
    if (!_isConnected || !_isAuthenticated || content.trim().isEmpty) {
      return;
    }

    // Store potential search query (if this looks like a job search)
    String trimmedContent = content.trim().toLowerCase();
    if (trimmedContent.contains('job') ||
        trimmedContent.contains('position') ||
        trimmedContent.contains('role') ||
        trimmedContent.contains('work') ||
        trimmedContent.contains('career') ||
        trimmedContent.contains('developer') ||
        trimmedContent.contains('engineer') ||
        trimmedContent.contains('analyst') ||
        trimmedContent.contains('manager') ||
        trimmedContent.contains('search') ||
        trimmedContent.contains('find')) {
      // This might be a job search query, store it as potential search query
      _potentialSearchQuery = content.trim();
      debugPrint('🔍 Potential search query detected: $_potentialSearchQuery');
    }

    // Add user message
    final userMessage = Message(
      id: const Uuid().v4(),
      content: content,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    );
    _messages.add(userMessage);

    // Set typing status
    _isTyping = true;
    notifyListeners();

    // Send message via WebSocket
    final messageData = {
      "event": "send_message",
      "data": {
        "message": content,
      }
    };
    _sendMessage(messageData);
  }

  void loadMoreJobs() {
    if (!_hasMoreJobs || _currentSearchQuery.isEmpty) {
      debugPrint(
          '❌ Cannot load more jobs - hasMore: $_hasMoreJobs, query: $_currentSearchQuery');
      return;
    }

    debugPrint(
        '📄 Loading more jobs for query: $_currentSearchQuery, page: ${_currentPage + 1}');

    final messageData = {
      "event": "load_more_jobs",
      "data": {
        "page": _currentPage + 1,
        "searchQuery": _currentSearchQuery,
      }
    };
    _sendMessage(messageData);
  }

  void fetchSessions() {
    if (!_isConnected || !_isAuthenticated) return;

    final messageData = {"event": "get_user_sessions", "data": {}};
    _sendMessage(messageData);
  }

  void loadSession(String sessionId) {
    if (!_isConnected || !_isAuthenticated) {
      debugPrint(
          '❌ Cannot load session - connected: $_isConnected, authenticated: $_isAuthenticated');
      return;
    }

    debugPrint('📂 Loading session: $sessionId');
    final messageData = {
      "event": "load_session",
      "data": {
        "sessionId": sessionId,
      }
    };
    _sendMessage(messageData);
  }

  void deleteSession(String sessionId) {
    if (!_isConnected || !_isAuthenticated) return;

    final messageData = {
      "event": "delete_session",
      "data": {
        "sessionId": sessionId,
      }
    };
    _sendMessage(messageData);
  }

  void updateSessionTitle(String sessionId, String title) {
    if (!_isConnected || !_isAuthenticated) return;

    final messageData = {
      "event": "update_session_title",
      "data": {
        "sessionId": sessionId,
        "title": title,
      }
    };
    _sendMessage(messageData);
  }

  void createNewSession() {
    if (!_isConnected || !_isAuthenticated) return;

    debugPrint('🆕 Creating new chat session...');

    // Clear current session state
    clearCurrentSession();

    // Emit create new chat event
    final messageData = {"event": "create_new_chat", "data": {}};
    _sendMessage(messageData);

    // Refresh sessions after a delay
    Future.delayed(const Duration(milliseconds: 1000), () {
      fetchSessions();
    });
  }

  void clearCurrentSession() {
    _clearMessages();
    _sessionId = null;
    _currentSearchQuery = '';
    _potentialSearchQuery = '';
    _hasMoreJobs = false;
    _currentPage = 1;
    _totalJobs = 0;
    notifyListeners();
  }

  void _clearMessages() {
    debugPrint('🗑️ Clearing ${_messages.length} messages');
    _messages.clear();
    notifyListeners();
  }

  // File upload method
  Future<bool> uploadResume(File file) async {
    try {
      debugPrint('📄 Starting resume upload: ${file.path}');

      // Get authentication token
      final token = _authService.token ?? AuthService.defaultToken;

      // Create multipart request
      var request =
          http.MultipartRequest('POST', Uri.parse('$baseUrl/upload-resume'));

      // Add headers
      request.headers['Authorization'] = 'Bearer $token';

      // Add form fields
      request.fields['session_id'] = _sessionId ?? 'default';
      request.fields['token'] = token;

      // Add file
      var multipartFile = await http.MultipartFile.fromPath(
        'resume',
        file.path,
        filename: file.path.split('/').last,
      );
      request.files.add(multipartFile);

      debugPrint('📤 Sending upload request to $baseUrl/upload-resume');
      debugPrint('📋 Session ID: ${_sessionId ?? 'default'}');
      debugPrint('📁 File: ${file.path.split('/').last}');

      // Send request
      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      debugPrint('📡 Upload response status: ${response.statusCode}');
      debugPrint('📄 Upload response body: $responseBody');

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(responseBody);
        if (jsonResponse['success'] == true) {
          debugPrint('✅ Resume uploaded successfully');

          // Add success message to chat
          final successMessage = Message(
            id: const Uuid().v4(),
            content: jsonResponse['message'] ??
                'Resume uploaded successfully! I can now provide better job recommendations based on your profile.',
            sender: MessageSender.assistant,
            type: MessageType.resumeUpload,
            timestamp: DateTime.now(),
          );
          _messages.add(successMessage);
          notifyListeners();

          return true;
        } else {
          debugPrint('❌ Upload failed: ${jsonResponse['error']}');
          _addErrorMessage('Upload failed: ${jsonResponse['error']}');
          return false;
        }
      } else {
        debugPrint('❌ Upload failed with status: ${response.statusCode}');
        _addErrorMessage(
            'Upload failed: Server returned status ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Resume upload error: $e');
      _addErrorMessage('Upload failed: ${e.toString()}');
      return false;
    }
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  // Reconnection method
  void reconnect() {
    if (_channel != null && !_isConnected) {
      _initializeWebSocket();
    }
  }

  // Ping method for connection health
  void ping() {
    if (_isConnected && _isAuthenticated) {
      final messageData = {"event": "ping", "data": {}};
      _sendMessage(messageData);
    }
  }

  // Show upload prompt
  void showUploadPrompt() {
    final uploadPromptMessage = Message(
      id: const Uuid().v4(),
      content:
          'Upload your resume to get personalized job recommendations and career advice.',
      sender: MessageSender.assistant,
      type: MessageType.uploadPrompt,
      timestamp: DateTime.now(),
    );
    _messages.add(uploadPromptMessage);
    notifyListeners();
  }
}
