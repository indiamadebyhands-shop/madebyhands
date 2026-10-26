import 'package:flutter_test/flutter_test.dart';
import 'package:madebyhands/features/auth/data/models/user_model.dart';

void main() {
  group('buyer and creator accounts on one login', () {
    test('legacy buyer documents remain valid without a roles field', () {
      final user = UserModel.fromJson(const {
        'uid': 'user-1',
        'email': 'user@example.com',
        'name': 'User',
        'role': 'buyer',
      });

      expect(user.isBuyer, isTrue);
      expect(user.hasBuyerRole, isTrue);
      expect(user.hasCreatorRole, isFalse);
      expect(user.roles, ['buyer']);
    });

    test('one user can own both roles while creator is active', () {
      final user = UserModel.fromJson(const {
        'uid': 'user-1',
        'email': 'user@example.com',
        'name': 'User',
        'role': 'creator',
        'roles': ['buyer', 'creator'],
      });

      expect(user.isCreator, isTrue);
      expect(user.hasBuyerRole, isTrue);
      expect(user.hasCreatorRole, isTrue);
      expect(user.toJson()['roles'], ['buyer', 'creator']);
    });

    test('unsupported values cannot become marketplace roles', () {
      final user = UserModel.fromJson(const {
        'uid': 'user-1',
        'email': 'user@example.com',
        'name': 'User',
        'role': 'buyer',
        'roles': ['buyer', 'admin', 'manager'],
      });

      expect(user.roles, ['buyer']);
      expect(user.isAdminOrManager, isFalse);
    });
  });
}
