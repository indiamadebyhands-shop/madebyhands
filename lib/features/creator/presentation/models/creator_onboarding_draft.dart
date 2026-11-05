import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CreatorOnboardingDraft {
  final String name;
  final String bio;
  final String location;
  final String story;
  final String state;
  final String pendingSocialLink;
  final List<String> socialLinks;
  final String? profileImagePath;
  final List<String> portfolioImagePaths;
  final List<String> exhibitionImagePaths;

  const CreatorOnboardingDraft({
    required this.name,
    required this.bio,
    required this.location,
    required this.story,
    required this.state,
    required this.pendingSocialLink,
    required this.socialLinks,
    required this.profileImagePath,
    required this.portfolioImagePaths,
    required this.exhibitionImagePaths,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'bio': bio,
    'location': location,
    'story': story,
    'state': state,
    'pendingSocialLink': pendingSocialLink,
    'socialLinks': socialLinks,
    'profileImagePath': profileImagePath,
    'portfolioImagePaths': portfolioImagePaths,
    'exhibitionImagePaths': exhibitionImagePaths,
  };

  factory CreatorOnboardingDraft.fromJson(Map<String, dynamic> json) {
    List<String> strings(String key) =>
        (json[key] as List? ?? const []).whereType<String>().toList();

    return CreatorOnboardingDraft(
      name: json['name'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      location: json['location'] as String? ?? '',
      story: json['story'] as String? ?? '',
      state: json['state'] as String? ?? '',
      pendingSocialLink: json['pendingSocialLink'] as String? ?? '',
      socialLinks: strings('socialLinks'),
      profileImagePath: json['profileImagePath'] as String?,
      portfolioImagePaths: strings('portfolioImagePaths'),
      exhibitionImagePaths: strings('exhibitionImagePaths'),
    );
  }
}

class CreatorOnboardingDraftStore {
  static String _key(String uid) => 'creator_onboarding_draft_$uid';

  static Future<void> save(String uid, CreatorOnboardingDraft draft) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key(uid), jsonEncode(draft.toJson()));
  }

  static Future<CreatorOnboardingDraft?> load(String uid) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_key(uid));
    if (encoded == null || encoded.isEmpty) return null;
    try {
      return CreatorOnboardingDraft.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
    } on FormatException {
      await clear(uid);
      return null;
    } on TypeError {
      await clear(uid);
      return null;
    }
  }

  static Future<void> clear(String uid) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key(uid));
  }
}

class CreatorProfileCompletionStore {
  static String _key(String uid) => 'creator_profile_completed_$uid';

  static Future<bool?> load(String uid) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.containsKey(_key(uid))
        ? preferences.getBool(_key(uid))
        : null;
  }

  static Future<void> save(String uid, {required bool isCompleted}) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_key(uid), isCompleted);
  }
}
