import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../services/chat_service.dart';

class UploadPromptCard extends StatelessWidget {
  final ChatService chatService;
  final VoidCallback? onSkip;

  const UploadPromptCard({
    Key? key,
    required this.chatService,
    this.onSkip,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                Colors.blue.shade50,
                Colors.indigo.shade50,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.upload_file,
                      color: Colors.blue.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Upload Your Resume',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Get personalized job recommendations',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Upload your resume to get better job matches and personalized career advice. I can analyze your skills and suggest relevant opportunities.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _handleUpload(context),
                      icon: const Icon(Icons.upload, size: 20),
                      label: const Text('Upload Resume'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _handleSkip(context),
                      icon: const Icon(Icons.skip_next, size: 20),
                      label: const Text('Skip for now'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Supported formats: PDF, DOC, DOCX (Max 10MB)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleUpload(BuildContext context) async {
    try {
      debugPrint('📁 Starting file picker...');

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        allowMultiple: false,
        withData: kIsWeb, // Load data on web, don't on mobile
        withReadStream: false, // Don't create read stream
      );

      debugPrint('📁 File picker result: ${result?.files.length ?? 0} files');

      if (result != null && result.files.isNotEmpty) {
        PlatformFile platformFile = result.files.first;
        debugPrint(
            '📁 Selected file: ${platformFile.name}, size: ${platformFile.size}${kIsWeb ? '' : ', path: ${platformFile.path}'}');

        // Check file size (10MB limit)
        if (platformFile.size > 10 * 1024 * 1024) {
          debugPrint('❌ File too large: ${platformFile.size} bytes');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.error, color: Colors.white),
                    SizedBox(width: 8),
                    Text('File size must be less than 10MB'),
                  ],
                ),
                backgroundColor: Colors.red.shade600,
              ),
            );
          }
          return;
        }

        debugPrint('✅ File validation passed, proceeding with upload');

        // Show loading indicator
        if (context.mounted) {
          _showUploadingDialog(context, platformFile.name);
        }

        // Handle file upload based on platform
        bool success = false;
        if (kIsWeb) {
          // Web platform - use bytes
          debugPrint('🌐 Web platform detected, using bytes for upload');
          if (platformFile.bytes != null) {
            debugPrint(
                '📄 File bytes available: ${platformFile.bytes!.length} bytes');
            success = await chatService.uploadResumeBytes(
              platformFile.bytes!,
              platformFile.name,
            );
          } else {
            debugPrint('❌ File bytes are null on web');
            if (context.mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.error, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Could not read file data. Please try again.'),
                    ],
                  ),
                  backgroundColor: Colors.red.shade600,
                ),
              );
            }
            return;
          }
        } else {
          // Mobile platform - use file path
          debugPrint('📱 Mobile platform detected, using file path for upload');
          if (platformFile.path == null) {
            debugPrint('❌ File path is null on mobile');
            if (context.mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.error, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Could not access file. Please try again.'),
                    ],
                  ),
                  backgroundColor: Colors.red.shade600,
                ),
              );
            }
            return;
          }

          File file = File(platformFile.path!);
          if (!await file.exists()) {
            debugPrint('❌ File does not exist: ${platformFile.path}');
            if (context.mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.error, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Selected file not found. Please try again.'),
                    ],
                  ),
                  backgroundColor: Colors.red.shade600,
                ),
              );
            }
            return;
          }

          success = await chatService.uploadResume(file);
        }

        // Close loading dialog
        if (context.mounted) {
          Navigator.of(context).pop();

          if (success) {
            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                        'Resume "${platformFile.name}" uploaded successfully!'),
                  ],
                ),
                backgroundColor: Colors.green.shade600,
                duration: const Duration(seconds: 3),
              ),
            );

            // Send a message to indicate resume was uploaded
            chatService.sendMessage(
                'I have uploaded my resume. Please analyze it and provide feedback.');
          } else {
            // Error message will be shown by the chat service
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.error, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Failed to upload resume. Please try again.'),
                  ],
                ),
                backgroundColor: Colors.red.shade600,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('❌ File picker error: $e');
      if (context.mounted) {
        // Close any open dialogs
        Navigator.of(context, rootNavigator: true).pop();

        String errorMessage = 'Failed to select file';
        if (e.toString().contains('permission')) {
          errorMessage =
              'Permission denied. Please allow file access in settings.';
        } else if (e.toString().contains('cancelled')) {
          errorMessage = 'File selection was cancelled';
        } else {
          errorMessage = 'Failed to select file: ${e.toString()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(errorMessage)),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _handleSkip(BuildContext context) {
    // Send a message to continue without resume
    chatService.sendMessage(
        'I prefer to skip uploading my resume for now. Please continue with general job search.');

    if (onSkip != null) {
      onSkip!();
    }

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.info, color: Colors.white),
            SizedBox(width: 8),
            Text('Continuing without resume upload'),
          ],
        ),
        backgroundColor: Colors.blue.shade600,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showUploadingDialog(BuildContext context, String fileName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Uploading $fileName...'),
              const SizedBox(height: 8),
              const Text(
                'Please wait while we process your resume',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        );
      },
    );
  }
}
