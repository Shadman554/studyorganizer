// lib/services/study_guide_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/study_guide_model.dart';

class StudyGuideService {
  static const String _storageKey = 'study_guides';
  
  // Save a study guide
  Future<void> saveStudyGuide(StudyGuide guide) async {
    final prefs = await SharedPreferences.getInstance();
    final guides = await getStudyGuides();
    
    // Check if guide with same ID exists and replace it
    final existingIndex = guides.indexWhere((g) => g.id == guide.id);
    if (existingIndex >= 0) {
      guides[existingIndex] = guide;
    } else {
      guides.add(guide);
    }
    
    // Save the updated list
    await prefs.setString(_storageKey, jsonEncode(guides.map((g) => g.toJson()).toList()));
  }
  
  // Get all study guides
  Future<List<StudyGuide>> getStudyGuides() async {
    final prefs = await SharedPreferences.getInstance();
    final guidesJson = prefs.getString(_storageKey);
    
    if (guidesJson == null) {
      return [];
    }
    
    try {
      final List<dynamic> decoded = jsonDecode(guidesJson);
      return decoded.map((item) => StudyGuide.fromJson(item)).toList();
    } catch (e) {
      print('Error loading study guides: $e');
      return [];
    }
  }
  
  // Get study guides for a specific lecture
  Future<List<StudyGuide>> getStudyGuidesForLecture(String lectureId) async {
    final guides = await getStudyGuides();
    return guides.where((guide) => guide.lectureId == lectureId).toList();
  }
  
  // Delete a study guide
  Future<void> deleteStudyGuide(String guideId) async {
    final prefs = await SharedPreferences.getInstance();
    final guides = await getStudyGuides();
    
    guides.removeWhere((guide) => guide.id == guideId);
    await prefs.setString(_storageKey, jsonEncode(guides.map((g) => g.toJson()).toList()));
  }
  
  // Clear all study guides
  Future<void> clearAllStudyGuides() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
