import 'package:flutter/material.dart';
import '../models/job.dart';
import '../utils/app_theme.dart';
import 'job_card.dart';

class CollapsibleJobCard extends StatefulWidget {
  final String content;
  final List<Job> jobs;
  final bool hasMore;
  final int? totalJobs;
  final VoidCallback? onLoadMore;
  final bool isUser;
  final Color textColor;

  const CollapsibleJobCard({
    super.key,
    required this.content,
    required this.jobs,
    this.hasMore = false,
    this.totalJobs,
    this.onLoadMore,
    required this.isUser,
    required this.textColor,
  });

  @override
  State<CollapsibleJobCard> createState() => _CollapsibleJobCardState();
}

class _CollapsibleJobCardState extends State<CollapsibleJobCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main content text
        Text(
          widget.content,
          style: TextStyle(
            color: widget.textColor,
            fontSize: 16,
          ),
        ),

        const SizedBox(height: 12),

        // Job summary card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.isUser
                ? Colors.white.withOpacity(0.1)
                : AppTheme.primaryColor.withOpacity(0.05),
            border: Border.all(
              color: widget.isUser
                  ? Colors.white.withOpacity(0.3)
                  : AppTheme.primaryColor.withOpacity(0.2),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with job count and expand button
              Row(
                children: [
                  Icon(
                    Icons.work_outline,
                    color: widget.isUser ? Colors.white : AppTheme.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isExpanded
                          ? 'Job Results (${widget.jobs.length}${widget.totalJobs != null ? ' of ${widget.totalJobs}' : ''})'
                          : 'Found ${widget.jobs.length} job${widget.jobs.length == 1 ? '' : 's'}${widget.totalJobs != null ? ' of ${widget.totalJobs} total' : ''}',
                      style: TextStyle(
                        color: widget.textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                    icon: Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color:
                          widget.isUser ? Colors.white : AppTheme.primaryColor,
                    ),
                    label: Text(
                      _isExpanded ? 'Hide Jobs' : 'Load Jobs',
                      style: TextStyle(
                        color: widget.isUser
                            ? Colors.white
                            : AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                    ),
                  ),
                ],
              ),

              // Preview of first job when collapsed
              if (!_isExpanded && widget.jobs.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.isUser
                        ? Colors.white.withOpacity(0.1)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: widget.isUser
                          ? Colors.white.withOpacity(0.2)
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.jobs.first.jobTitle,
                        style: TextStyle(
                          color: widget.textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.jobs.first.company,
                        style: TextStyle(
                          color: widget.textColor.withOpacity(0.8),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.jobs.first.location,
                        style: TextStyle(
                          color: widget.textColor.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                      if (widget.jobs.length > 1) ...[
                        const SizedBox(height: 8),
                        Text(
                          '+${widget.jobs.length - 1} more job${widget.jobs.length - 1 == 1 ? '' : 's'}',
                          style: TextStyle(
                            color: widget.isUser
                                ? Colors.white
                                : AppTheme.primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              // All jobs when expanded
              if (_isExpanded) ...[
                const SizedBox(height: 12),
                ...widget.jobs.map((job) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: JobCard(job: job),
                    )),

                // Load more button
                if (widget.hasMore && widget.onLoadMore != null) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: ElevatedButton(
                      onPressed: widget.onLoadMore,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.isUser
                            ? Colors.white
                            : AppTheme.primaryColor,
                        foregroundColor: widget.isUser
                            ? AppTheme.primaryColor
                            : Colors.white,
                      ),
                      child: Text(
                        'Load More Jobs (${_getNextPageRange()})',
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _getNextPageRange() {
    if (widget.totalJobs == null) return '';
    final currentCount = widget.jobs.length;
    final nextPageStart = currentCount + 1;
    final nextPageEnd = currentCount + 10; // Assuming 10 jobs per page
    final maxEnd =
        widget.totalJobs! < nextPageEnd ? widget.totalJobs! : nextPageEnd;
    return '$nextPageStart-$maxEnd of ${widget.totalJobs}';
  }
}
