import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/message.dart';
import '../models/job.dart';
import 'auth_service.dart';

class ChatService extends ChangeNotifier {
  static const String baseUrl =
      'http://localhost:5003'; // Local development server

  IO.Socket? _socket;
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
      _initializeSocket();
    });
  }

  void _initializeSocket() {
    try {
      final token = _authService.token;
      debugPrint(
          '🔗 Initializing socket with token: ${token?.substring(0, 20)}...');

      _socket = IO.io(baseUrl, <String, dynamic>{
        'transports': ['websocket', 'polling'],
        'timeout': 60000,
        'query': {'token': token ?? AuthService.defaultToken},
      });

      _setupSocketListeners();
      _socket!.connect();
    } catch (e) {
      debugPrint('Socket initialization error: $e');
    }
  }

  void _setupSocketListeners() {
    // Connection events
    _socket!.on('connect', (_) {
      debugPrint('🔌 Connected to server');
      _isConnected = true;
      notifyListeners();
    });

    _socket!.on('disconnect', (_) {
      debugPrint('🔌 Disconnected from server');
      _isConnected = false;
      _isAuthenticated = false;
      notifyListeners();
    });

    // Authentication events
    _socket!.on('auth_status', (data) {
      debugPrint('🔐 Authentication status: $data');
      if (data['authenticated'] == true) {
        _isAuthenticated = true;
        _userId = data['userId'];
        _initializeChat();
      } else {
        _isAuthenticated = false;
      }
      notifyListeners();
    });

    _socket!.on('auth_error', (data) {
      debugPrint('❌ Authentication error: $data');
      _isAuthenticated = false;
      notifyListeners();
    });

    // Session events
    _socket!.on('session_status', (data) {
      debugPrint('📋 Session status: $data');
      if (data['connected'] == true) {
        _sessionId = data['sessionId'];
      }
      notifyListeners();
    });

    _socket!.on('init_response', (data) {
      debugPrint('🚀 Chat initialized: $data');
    });

    // Message events
    _socket!.on('receive_message', (data) {
      debugPrint('💬 Received message: $data');
      _handleReceivedMessage(data);
    });

    // Typing events
    _socket!.on('typing_status', (data) {
      debugPrint('📝 Typing status: $data');
      _isTyping = data['isTyping'] ?? false;
      notifyListeners();
    });

    // Error events
    _socket!.on('error', (data) {
      debugPrint('❌ Socket error: $data');
      _addErrorMessage('Sorry, I encountered an error: ${data['message']}');
    });

    // Session management events
    _socket!.on('user_sessions', (data) {
      debugPrint('📋 User sessions received: $data');
      if (data['sessions'] != null) {
        _sessions.clear();
        _sessions.addAll(List<Map<String, dynamic>>.from(data['sessions']));
        notifyListeners();
      }
    });

    _socket!.on('session_loaded', (data) {
      debugPrint('📂 Session loaded: $data');
      if (data['sessionId'] != null) {
        _sessionId = data['sessionId'];
        _loadChatHistory(data['messages'] ?? []);
      }
    });

    _socket!.on('session_deleted', (data) {
      debugPrint('🗑️ Session deleted: $data');
      if (data['success'] == true) {
        if (data['sessionId'] == _sessionId) {
          _clearMessages();
          _sessionId = null;
        }
        fetchSessions();
      }
    });

    _socket!.on('session_title_updated', (data) {
      debugPrint('✏️ Session title updated: $data');
      if (data['success'] == true) {
        fetchSessions();
      }
    });

    _socket!.on('chat_history', (data) {
      debugPrint('📜 Chat history: $data');
      if (data['messages'] != null) {
        _loadChatHistory(data['messages']);
      }
    });

    _socket!.on('session_cleared', (data) {
      debugPrint('🗑️ Session cleared: $data');
      _clearMessages();
    });

    _socket!.on('new_chat_created', (data) {
      debugPrint('🆕 New chat created: $data');
      if (data['sessionId'] != null) {
        _sessionId = data['sessionId'];
        _clearMessages();
        notifyListeners();
      }
    });
  }

  void _handleReceivedMessage(Map<String, dynamic> data) {
    final message = Message.fromJson(data);

    // Start streaming simulation for assistant messages
    if (message.sender == MessageSender.assistant) {
      _simulateStreamingMessage(message);
    } else {
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

  void _simulateStreamingMessage(Message originalMessage) {
    // Create initial empty streaming message with unique ID
    final streamingMessage = originalMessage.copyWith(
      content: '',
      id: 'streaming_${DateTime.now().millisecondsSinceEpoch}',
    );

    _messages.add(streamingMessage);
    _isStreaming = true;
    _currentStreamingMessage = streamingMessage;
    notifyListeners();

    debugPrint('🌊 Starting streaming for message: ${streamingMessage.id}');

    // Simulate word-by-word streaming
    _animateMessageContent(originalMessage.content, streamingMessage);
  }

  void _animateMessageContent(String fullContent, Message message) async {
    final words = fullContent.split(' ');
    String currentContent = '';

    for (int i = 0; i < words.length; i++) {
      // Check if streaming should continue
      if (!_isStreaming || _currentStreamingMessage?.id != message.id) {
        debugPrint('🛑 Streaming stopped or message changed');
        break;
      }

      currentContent += words[i];
      if (i < words.length - 1) currentContent += ' ';

      // Update the message content
      int index = -1;
      for (int j = 0; j < _messages.length; j++) {
        if (_messages[j].id == message.id) {
          index = j;
          break;
        }
      }

      if (index != -1) {
        try {
          final updatedMessage = message.copyWith(content: currentContent);
          _messages[index] = updatedMessage;
          // Update the reference to the current message
          if (_currentStreamingMessage?.id == message.id) {
            _currentStreamingMessage = updatedMessage;
          }
          notifyListeners();
          debugPrint(
              '📝 Streaming progress: ${i + 1}/${words.length} words - "${words[i]}"');
        } catch (e) {
          debugPrint('❌ Error updating streaming message: $e');
          break;
        }
      } else {
        debugPrint(
            '❌ Message not found in list, stopping streaming. Looking for ID: ${message.id}');
        debugPrint(
            '📋 Current messages: ${_messages.map((m) => m.id).toList()}');
        break;
      }

      // Delay between words (60ms for faster streaming)
      await Future.delayed(const Duration(milliseconds: 60));
    }

    // Streaming complete - ensure final content is set
    if (_isStreaming && _currentStreamingMessage?.id == message.id) {
      int index = -1;
      for (int j = 0; j < _messages.length; j++) {
        if (_messages[j].id == message.id) {
          index = j;
          break;
        }
      }

      if (index != -1) {
        _messages[index] = message.copyWith(content: fullContent);
      }

      _isStreaming = false;
      _currentStreamingMessage = null;
      notifyListeners();
      debugPrint('✅ Streaming completed for message: ${message.id}');
    }
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

  void _initializeChat() {
    _socket!.emit('init_chat', {'sessionId': _sessionId});

    // Fetch sessions after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      fetchSessions();
    });
  }

  void _loadChatHistory(List<dynamic> messages) {
    _clearMessages();

    for (var msgData in messages) {
      final message = Message.fromJson(msgData);
      _messages.add(message);
    }

    notifyListeners();
  }

  void _clearMessages() {
    _messages.clear();
    notifyListeners();
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

    // Send message via socket
    _socket!.emit('send_message', {'message': content});
  }

  void loadMoreJobs() {
    if (!_hasMoreJobs || _currentSearchQuery.isEmpty) {
      debugPrint(
          '❌ Cannot load more jobs - hasMore: $_hasMoreJobs, query: $_currentSearchQuery');
      return;
    }

    debugPrint(
        '📄 Loading more jobs for query: $_currentSearchQuery, page: ${_currentPage + 1}');

    _socket!.emit('load_more_jobs', {
      'page': _currentPage + 1,
      'searchQuery': _currentSearchQuery,
    });
  }

  void fetchSessions() {
    if (!_isConnected || !_isAuthenticated) return;

    _socket!.emit('get_user_sessions');
  }

  void loadSession(String sessionId) {
    if (!_isConnected || !_isAuthenticated) return;

    _socket!.emit('load_session', {'sessionId': sessionId});
  }

  void deleteSession(String sessionId) {
    if (!_isConnected || !_isAuthenticated) return;

    _socket!.emit('delete_session', {'sessionId': sessionId});
  }

  void updateSessionTitle(String sessionId, String title) {
    if (!_isConnected || !_isAuthenticated) return;

    _socket!.emit('update_session_title', {
      'sessionId': sessionId,
      'title': title,
    });
  }

  void createNewSession() {
    if (!_isConnected || !_isAuthenticated) return;

    debugPrint('🆕 Creating new chat session...');

    // Clear current session state
    clearCurrentSession();

    // Emit create new chat event
    _socket!.emit('create_new_chat', {});

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
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  // Reconnection method
  void reconnect() {
    if (_socket != null && !_isConnected) {
      _socket!.connect();
    }
  }

  // Ping method for connection health
  void ping() {
    if (_isConnected && _isAuthenticated) {
      _socket!.emit('ping');
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
