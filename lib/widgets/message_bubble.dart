import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/message.dart';
import '../services/chat_service.dart';
import '../utils/app_theme.dart';
import 'job_card.dart';
import 'collapsible_job_card.dart';
import 'upload_prompt_card.dart';
import 'streaming_text.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final VoidCallback? onLoadMore;
  final ChatService? chatService;

  const MessageBubble({
    super.key,
    required this.message,
    this.onLoadMore,
    this.chatService,
  });

  @override
  Widget build(BuildContext context) {
    // Special handling for upload prompt - display as standalone card
    if (message.type == MessageType.uploadPrompt && chatService != null) {
      return UploadPromptCard(chatService: chatService!);
    }

    final isUser = message.sender == MessageSender.user;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _buildAvatar(false),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              child: Column(
                crossAxisAlignment:
                    isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: isUser ? AppTheme.primaryGradient : null,
                      color: isUser ? null : Colors.white,
                      borderRadius: BorderRadius.circular(20).copyWith(
                        bottomLeft: isUser
                            ? const Radius.circular(20)
                            : const Radius.circular(4),
                        bottomRight: isUser
                            ? const Radius.circular(4)
                            : const Radius.circular(20),
                      ),
                      border: isUser
                          ? null
                          : Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _buildMessageContent(),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            _buildAvatar(true),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(bool isUser) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: isUser ? AppTheme.primaryGradient : AppTheme.accentGradient,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          isUser ? 'U' : 'JM',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageContent() {
    final isUser = message.sender == MessageSender.user;
    final textColor = isUser ? Colors.white : Colors.black87;

    switch (message.type) {
      case MessageType.jobCard:
        if (message.jobs != null && message.jobs!.isNotEmpty) {
          // Check if this should be collapsible (for chat history) or normal (for new messages)
          // We'll use collapsible only if the message content suggests it's from history
          // or if there are many jobs that would clutter the chat
          bool shouldUseCollapsible = _shouldUseCollapsibleJobCard();

          if (shouldUseCollapsible) {
            return CollapsibleJobCard(
              content: message.content,
              jobs: message.jobs!,
              hasMore: message.hasMore,
              totalJobs: message.totalJobs,
              onLoadMore: onLoadMore,
              isUser: isUser,
              textColor: textColor,
            );
          } else {
            // Show normal job cards for new messages
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.content,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                ...message.jobs!.map((job) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: JobCard(job: job),
                    )),
                if (message.hasMore && onLoadMore != null) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: ElevatedButton(
                      onPressed: onLoadMore,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Load More Jobs'),
                    ),
                  ),
                ],
              ],
            );
          }
        } else {
          return Text(
            message.content,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
            ),
          );
        }

      case MessageType.resumeUpload:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: isUser ? Colors.white : AppTheme.accentColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message.content,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (message.metadata?['availableOptions'] != null) ...[
              const SizedBox(height: 8),
              Text(
                'Available options:',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              ...((message.metadata!['availableOptions'] as List)
                  .map((option) => Padding(
                        padding: const EdgeInsets.only(left: 16, top: 2),
                        child: Text(
                          '• $option',
                          style: TextStyle(color: textColor),
                        ),
                      ))),
            ],
          ],
        );

      case MessageType.uploadPrompt:
        // For upload prompts, we return the special card instead of regular bubble
        if (chatService != null) {
          return UploadPromptCard(chatService: chatService!);
        } else {
          return Text(
            message.content,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
            ),
          );
        }

      case MessageType.resumeUploadRequired:
        // For resume upload required messages, show upload button
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isUser ? Colors.white.withOpacity(0.1) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: isUser ? null : Border.all(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.upload_file,
                      color: isUser ? Colors.white : AppTheme.primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message.content,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (chatService != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Trigger file picker directly
                            if (chatService != null) {
                              chatService!.showUploadPrompt();
                            }
                          },
                          icon: const Icon(Icons.upload_file, size: 20),
                          label: const Text('Upload Resume'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () {
                          // Send a message to skip resume upload
                          chatService!.sendMessage(
                              'I prefer to skip uploading my resume for now. Please continue with general assistance.');
                        },
                        child: Text(
                          'Skip for now',
                          style: TextStyle(
                            color: textColor.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Supported formats: PDF, DOC, DOCX (Max 10MB)',
                    style: TextStyle(
                      color: textColor.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );

      case MessageType.markdown:
        // For markdown messages, use markdown rendering even during streaming
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isUser ? Colors.white.withOpacity(0.1) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: isUser ? null : Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: MarkdownBody(
                  data: message.content,
                  styleSheet: MarkdownStyleSheet(
                    h1: TextStyle(
                      color: textColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                    h2: TextStyle(
                      color: textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                    h3: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                    p: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      height: 1.5,
                    ),
                    strong: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                    em: TextStyle(
                      color: textColor,
                      fontStyle: FontStyle.italic,
                    ),
                    listBullet: TextStyle(
                      color: textColor,
                      fontSize: 16,
                    ),
                    code: TextStyle(
                      color: isUser ? Colors.white : AppTheme.primaryColor,
                      backgroundColor: isUser
                          ? Colors.white.withOpacity(0.2)
                          : Colors.grey.shade200,
                      fontSize: 14,
                      fontFamily: 'monospace',
                    ),
                    codeblockDecoration: BoxDecoration(
                      color: isUser
                          ? Colors.white.withOpacity(0.1)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    blockquote: TextStyle(
                      color: textColor.withOpacity(0.8),
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                    ),
                    blockquoteDecoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: AppTheme.primaryColor,
                          width: 4,
                        ),
                      ),
                    ),
                  ),
                  onTapLink: (text, href, title) {
                    if (href != null) {
                      launchUrl(Uri.parse(href));
                    }
                  },
                ),
              ),
              // Show typing indicator for streaming README content
              if (chatService?.isStreaming == true &&
                  chatService?.currentStreamingMessage?.id == message.id)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isUser ? Colors.white : AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Generating response...',
                        style: TextStyle(
                          color: textColor.withOpacity(0.6),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );

      case MessageType.error:
        return Row(
          children: [
            Icon(
              Icons.error_outline,
              color: isUser ? Colors.white : AppTheme.errorColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message.content,
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        );

      default:
        return StreamingText(
          text: _formatTextContent(message.content),
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            height: 1.4,
          ),
          isStreaming: chatService?.isStreaming == true &&
              chatService?.currentStreamingMessage?.id == message.id,
          wordDelay: const Duration(milliseconds: 80),
        );
    }
  }

  String _formatTextContent(String content) {
    // Basic text formatting
    return content
        .replaceAll('**', '') // Remove markdown bold
        .replaceAll('*', ''); // Remove markdown italic
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return DateFormat('HH:mm').format(timestamp);
    } else {
      return DateFormat('MMM dd, HH:mm').format(timestamp);
    }
  }

  bool _shouldUseCollapsibleJobCard() {
    // For now, let's show normal job cards for new messages
    // and only use collapsible for loaded chat history
    // We can detect loaded history by checking if chatService is in a loading state
    // or if the message timestamp is significantly older

    final now = DateTime.now();
    final messageAge = now.difference(message.timestamp);

    // Use collapsible only if message is from chat history (older than 2 minutes)
    // This assumes new messages arrive within 2 minutes of being sent
    return messageAge.inMinutes > 2;
  }
}
