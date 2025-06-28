import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import '../models/message.dart';
import '../utils/app_theme.dart';
import '../widgets/message_bubble.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/session_sidebar.dart';
import '../widgets/job_card.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();

    // Initialize chat service after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatService = Provider.of<ChatService>(context, listen: false);
      // The chat service is already initialized in the constructor
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final chatService = Provider.of<ChatService>(context, listen: false);
    chatService.sendMessage(message);
    _messageController.clear();

    // Scroll to bottom after sending
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.work_outline, color: Colors.white),
            const SizedBox(width: 8),
            const Text('JobMato Assistant'),
            const Spacer(),
            Consumer<ChatService>(
              builder: (context, chatService, child) {
                return Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: chatService.isConnected
                        ? AppTheme.accentColor
                        : AppTheme.errorColor,
                    shape: BoxShape.circle,
                  ),
                );
              },
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
          ),
        ),
      ),
      drawer: const SessionSidebar(),
      body: Column(
        children: [
          // Connection Status Banner
          Consumer<ChatService>(
            builder: (context, chatService, child) {
              if (!chatService.isConnected) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  color: AppTheme.errorColor,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.warning, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      const Text(
                        'Disconnected - Attempting to reconnect...',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          // Messages Area
          Expanded(
            child: Consumer<ChatService>(
              builder: (context, chatService, child) {
                if (chatService.messages.isEmpty) {
                  return _buildWelcomeMessage();
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: chatService.messages.length +
                      (chatService.isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == chatService.messages.length) {
                      return const TypingIndicator();
                    }

                    final message = chatService.messages[index];
                    return MessageBubble(
                      message: message,
                      chatService: chatService,
                      onLoadMore: chatService.hasMoreJobs
                          ? () => chatService.loadMoreJobs()
                          : null,
                    );
                  },
                );
              },
            ),
          ),

          // Input Area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(
                  color: Colors.grey.shade300,
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // File Upload Button
                  IconButton(
                    onPressed: _showUploadOptions,
                    icon: const Icon(Icons.attach_file),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.accentColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Message Input
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText:
                            'Ask me about jobs, career advice, resume tips...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Send Button
                  Consumer<ChatService>(
                    builder: (context, chatService, child) {
                      return IconButton(
                        onPressed: chatService.isConnected &&
                                chatService.isAuthenticated
                            ? _sendMessage
                            : null,
                        icon: const Icon(Icons.send),
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.work_outline,
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome to JobMato Assistant! 👋',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'I\'m here to help you with job searching, career advice, resume analysis, and project suggestions.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'What can I help you with today?',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Quick Action Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildQuickActionChip('Find jobs', Icons.search),
                _buildQuickActionChip('Resume analysis', Icons.description),
                _buildQuickActionChip('Career advice', Icons.lightbulb),
                _buildQuickActionChip('Project ideas', Icons.code),
                _buildUploadPromptChip(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionChip(String label, IconData icon) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: () {
        _messageController.text = label;
        _sendMessage();
      },
      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
      labelStyle: const TextStyle(color: AppTheme.primaryColor),
    );
  }

  Widget _buildUploadPromptChip() {
    return Consumer<ChatService>(
      builder: (context, chatService, child) {
        return ActionChip(
          avatar: const Icon(Icons.upload_file, size: 18),
          label: const Text('Upload Resume'),
          onPressed: () {
            chatService.showUploadPrompt();
          },
          backgroundColor: AppTheme.accentColor.withOpacity(0.1),
          labelStyle: const TextStyle(color: AppTheme.accentColor),
        );
      },
    );
  }

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Upload Resume',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              ListTile(
                leading:
                    const Icon(Icons.description, color: AppTheme.primaryColor),
                title: const Text('Upload PDF/Word Document'),
                subtitle: const Text('Supported formats: PDF, DOC, DOCX'),
                onTap: () {
                  Navigator.pop(context);
                  _uploadResume();
                },
              ),
              const SizedBox(height: 16),
              Text(
                'File size limit: 10MB',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }

  void _uploadResume() {
    // TODO: Implement file picker and upload
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Resume upload feature coming soon!'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }
}
