part of '../home.dart';

class AccessReport {
  const AccessReport({
    this.id,
    required this.title,
    this.location = '',
    this.locationId,
    this.googlePlaceId,
    required this.detail,
    required this.category,
    required this.icon,
    this.photoBytes = const [],
    this.detections = const [],
    this.aiAnalysisCompleted = false,
    this.aiAnalysisStatus = 'not_started',
    this.confirmations = 0,
  });

  final String? id;
  final String title;
  final String location;
  final String? locationId;

  /// Google place being contributed to when it isn't a NavAble place yet.
  final String? googlePlaceId;
  final String detail;
  final String category;
  final IconData icon;
  final List<Uint8List> photoBytes;
  final List<Map<String, dynamic>> detections;
  final bool aiAnalysisCompleted;
  final String aiAnalysisStatus;
  final int confirmations;

  AccessReport copyWith({
    String? id,
    String? title,
    String? location,
    String? locationId,
    String? detail,
    String? category,
    IconData? icon,
    List<Uint8List>? photoBytes,
    List<Map<String, dynamic>>? detections,
    bool? aiAnalysisCompleted,
    String? aiAnalysisStatus,
    int? confirmations,
  }) {
    return AccessReport(
      id: id ?? this.id,
      title: title ?? this.title,
      location: location ?? this.location,
      locationId: locationId ?? this.locationId,
      googlePlaceId: googlePlaceId,
      detail: detail ?? this.detail,
      category: category ?? this.category,
      icon: icon ?? this.icon,
      photoBytes: photoBytes ?? this.photoBytes,
      detections: detections ?? this.detections,
      aiAnalysisCompleted: aiAnalysisCompleted ?? this.aiAnalysisCompleted,
      aiAnalysisStatus: aiAnalysisStatus ?? this.aiAnalysisStatus,
      confirmations: confirmations ?? this.confirmations,
    );
  }
}

enum SubmissionStatus { pending, approved, rejected }

class AccessibilitySubmission {
  const AccessibilitySubmission({
    required this.title,
    required this.submittedOn,
    required this.status,
    required this.statusDetail,
    required this.icon,
  });

  final String title;
  final String submittedOn;
  final SubmissionStatus status;
  final String statusDetail;
  final IconData icon;
}
