import 'package:madebyhands/features/auth/domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  UserModel({
    required super.uid,
    required super.email,
    required super.name,
    super.phone = '',
    required super.role,
    super.isVerified = false,
    super.isSuspended = false,
    super.creatorModerationLevel = 0,
    super.creatorModerationReason = '',
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      role: json['role'] as String? ?? 'buyer',
      isVerified: json['isVerified'] as bool? ?? false,
      isSuspended: json['isSuspended'] as bool? ?? false,
      creatorModerationLevel:
          (json['creatorModerationLevel'] as num?)?.toInt() ?? 0,
      creatorModerationReason: json['creatorModerationReason'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'phone': phone,
      'role': role,
      'isVerified': isVerified,
      'isSuspended': isSuspended,
      'creatorModerationLevel': creatorModerationLevel,
      'creatorModerationReason': creatorModerationReason,
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    String? phone,
    String? role,
    bool? isVerified,
    bool? isSuspended,
    int? creatorModerationLevel,
    String? creatorModerationReason,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      isVerified: isVerified ?? this.isVerified,
      isSuspended: isSuspended ?? this.isSuspended,
      creatorModerationLevel:
          creatorModerationLevel ?? this.creatorModerationLevel,
      creatorModerationReason:
          creatorModerationReason ?? this.creatorModerationReason,
    );
  }
}
