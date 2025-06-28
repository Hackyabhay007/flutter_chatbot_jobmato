import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/message.dart';
import '../models/job.dart';
import '../utils/app_theme.dart';
import 'job_card.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final VoidCallback? onLoadMore;

  const MessageBubble({
    super.key,
    required this.message,
    this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
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
            if (message.jobs != null && message.jobs!.isNotEmpty) ...[
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
                    child: Text(
                      'Load More Jobs (${_getNextPageRange()})',
                    ),
                  ),
                ),
              ],
            ],
          ],
        );

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
        return Text(
          _formatTextContent(message.content),
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            height: 1.4,
          ),
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

  String _getNextPageRange() {
    if (message.currentPage == null || message.totalJobs == null) {
      return '';
    }

    final nextPage = message.currentPage! + 1;
    final nextPageStart = nextPage * 10 + 1;
    final nextPageEnd = (nextPage + 1) * 10;
    final actualEnd =
        nextPageEnd > message.totalJobs! ? message.totalJobs! : nextPageEnd;

    return '$nextPageStart-$actualEnd of ${message.totalJobs}';
  }
}
