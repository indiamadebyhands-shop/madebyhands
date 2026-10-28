class UserEntity {
  final String uid;
  final String email;
  final String name;
  final String phone;
  final String role; // 'buyer', 'creator', 'admin', 'super_admin', 'manager'
  /// Marketplace accounts available to this login. [role] is the account
  /// currently being used; legacy documents are migrated from [role].
  final List<String> roles;
  final bool isVerified;
  final bool isSuspended;
  final int creatorModerationLevel;
  final String creatorModerationReason;

  UserEntity({
    required this.uid,
    required this.email,
    required this.name,
    this.phone = '',
    required this.role,
    List<String>? roles,
    this.isVerified = false,
    this.isSuspended = false,
    this.creatorModerationLevel = 0,
    this.creatorModerationReason = '',
  }) : roles = List.unmodifiable(
         roles ??
             (role.toLowerCase().trim() == 'buyer'
                 ? const ['buyer']
                 : role.toLowerCase().trim() == 'creator' ||
                       role.toLowerCase().trim() == 'seller'
                 ? const ['creator']
                 : const <String>[]),
       );

  static const List<String> presetSuperAdminEmails = [
    'adhirajjain364@gmail.com',
    'mayankjaisw8673@gmail.com',
    'suhanimahajan2810@gmail.com',
    'majumdarpayal50@gmail.com',
    'reshob.rc12345@gmail.com',
  ];

  String get _normalizedRole => role.toLowerCase().trim();

  bool get _isPresetAdminEmail =>
      presetSuperAdminEmails.contains(email.toLowerCase().trim());

  /// Super admins have full access including payouts and platform fees.
  bool get isSuperAdmin =>
      _normalizedRole == 'super_admin' ||
      (_normalizedRole == 'admin' && _isPresetAdminEmail);

  /// Managers (and legacy 'admin' accounts) run day-to-day operations.
  bool get isManager =>
      _normalizedRole == 'manager' ||
      (_normalizedRole == 'admin' && !_isPresetAdminEmail);

  bool get isAdminOrManager => isSuperAdmin || isManager;

  bool get isCreator =>
      _normalizedRole == 'creator' || _normalizedRole == 'seller';

  bool get isBuyer => _normalizedRole == 'buyer';

  bool get hasBuyerRole =>
      isBuyer || roles.any((value) => value.toLowerCase().trim() == 'buyer');

  bool get hasCreatorRole =>
      isCreator ||
      roles.any((value) {
        final normalized = value.toLowerCase().trim();
        return normalized == 'creator' || normalized == 'seller';
      });

  String get roleDisplay {
    if (isSuperAdmin) return 'Super Admin';
    if (isManager) return 'Manager';
    if (isCreator) return 'Creator';
    return 'Buyer';
  }
}
