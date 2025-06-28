import 'job.dart';

enum MessageType { text, jobCard, resumeUpload, error, typing, uploadPrompt }

enum MessageSender { user, assistant }

class Message {
  final String id;
  final String content;
  final MessageSender sender;
  final MessageType type;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;
  final List<Job>? jobs;
  final bool hasMore;
  final int? totalJobs;
  final int? currentPage;

  Message({
    required this.id,
    required this.content,
    required this.sender,
    this.type = MessageType.text,
    required this.timestamp,
    this.metadata,
    this.jobs,
    this.hasMore = false,
    this.totalJobs,
    this.currentPage,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      content: json['content'] ?? '',
      sender: json['sender'] == 'user'
          ? MessageSender.user
          : MessageSender.assistant,
      type: _parseMessageType(json['type']),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      metadata: json['metadata'],
      jobs: json['metadata']?['jobs'] != null
          ? (json['metadata']['jobs'] as List)
              .map((job) => Job.fromJson(job))
              .toList()
          : null,
      hasMore: json['metadata']?['hasMore'] ?? false,
      totalJobs: json['metadata']?['total'] ?? json['metadata']?['totalJobs'],
      currentPage:
          json['metadata']?['page'] ?? json['metadata']?['currentPage'],
    );
  }

  static MessageType _parseMessageType(String? type) {
    switch (type) {
      case 'job_card':
        return MessageType.jobCard;
      case 'resume_upload_success':
        return MessageType.resumeUpload;
      case 'upload_prompt':
        return MessageType.uploadPrompt;
      case 'error':
        return MessageType.error;
      default:
        return MessageType.text;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'sender': sender == MessageSender.user ? 'user' : 'assistant',
      'type': type.toString().split('.').last,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }

  Message copyWith({
    String? id,
    String? content,
    MessageSender? sender,
    MessageType? type,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
    List<Job>? jobs,
    bool? hasMore,
    int? totalJobs,
    int? currentPage,
  }) {
    return Message(
      id: id ?? this.id,
      content: content ?? this.content,
      sender: sender ?? this.sender,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
      jobs: jobs ?? this.jobs,
      hasMore: hasMore ?? this.hasMore,
      totalJobs: totalJobs ?? this.totalJobs,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}
