class Job {
  final String? id;
  final String jobTitle;
  final String company;
  final String location;
  final String experience;
  final String salary;
  final String? workMode;
  final String? jobType;
  final List<String> skills;
  final String? description;
  final String? postedDate;
  final String? applyUrl;

  Job({
    this.id,
    required this.jobTitle,
    required this.company,
    required this.location,
    required this.experience,
    required this.salary,
    this.workMode,
    this.jobType,
    this.skills = const [],
    this.description,
    this.postedDate,
    this.applyUrl,
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['_id'] ?? json['id'],
      jobTitle: json['job_title'] ?? json['title'] ?? 'Job Title',
      company: _extractCompanyName(json['company']),
      location: _extractLocation(json),
      experience: _extractExperience(json['experience']),
      salary: _extractSalary(json['salary']),
      workMode: json['work_mode'],
      jobType: json['job_type'],
      skills: _extractSkills(json['skills']),
      description: json['description'],
      postedDate: json['posted_date'],
      applyUrl: json['apply_url'],
    );
  }

  static String _extractCompanyName(dynamic company) {
    if (company == null) return 'Not specified';
    if (company is String) return company;
    if (company is Map<String, dynamic>) {
      return company['name'] ?? 'Not specified';
    }
    return 'Not specified';
  }

  static String _extractLocation(Map<String, dynamic> json) {
    if (json['location'] != null) {
      return json['location'].toString();
    }
    if (json['locations'] != null && json['locations'] is List) {
      final locations = json['locations'] as List;
      return locations.isNotEmpty ? locations.join(', ') : 'Not specified';
    }
    return 'Not specified';
  }

  static String _extractExperience(dynamic experience) {
    if (experience == null) return 'Not specified';
    if (experience is String) return experience;
    if (experience is Map<String, dynamic>) {
      final min = experience['min'];
      final max = experience['max'];
      if (min != null && max != null) {
        return '$min - $max years';
      } else if (min != null) {
        return 'More than $min years';
      } else if (max != null) {
        return 'Up to $max years';
      }
    }
    return 'Not specified';
  }

  static String _extractSalary(dynamic salary) {
    if (salary == null) return '';
    if (salary is String) return salary;
    if (salary is Map<String, dynamic>) {
      final min = salary['min'];
      final max = salary['max'];
      final currency = salary['currency'] ?? '';

      String salaryText = '';
      if (min != null && max != null) {
        salaryText = '$min - $max';
      } else if (min != null) {
        salaryText = 'From $min';
      } else if (max != null) {
        salaryText = 'Up to $max';
      }

      if (salaryText.isNotEmpty && currency.isNotEmpty) {
        salaryText += ' $currency';
      }
      return salaryText;
    }
    return '';
  }

  static List<String> _extractSkills(dynamic skills) {
    if (skills == null) return [];
    if (skills is List) {
      return skills.map((skill) => skill.toString()).toList();
    }
    if (skills is String) {
      return skills.split(',').map((s) => s.trim()).toList();
    }
    return [];
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'job_title': jobTitle,
      'company': company,
      'location': location,
      'experience': experience,
      'salary': salary,
      'work_mode': workMode,
      'job_type': jobType,
      'skills': skills,
      'description': description,
      'posted_date': postedDate,
      'apply_url': applyUrl,
    };
  }
}
