import 'package:flutter_test/flutter_test.dart';
import 'package:madebyhands/features/creator/presentation/models/creator_onboarding_draft.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('creator onboarding draft survives an account switch', () async {
    SharedPreferences.setMockInitialValues({});
    const draft = CreatorOnboardingDraft(
      name: 'Suhani Studio',
      bio: 'Handmade art',
      location: 'Bhubaneswar',
      story: 'A creator story',
      state: 'Odisha',
      pendingSocialLink: 'instagram.com/suhani',
      socialLinks: ['https://example.com'],
      profileImagePath: '/tmp/profile.jpg',
      portfolioImagePaths: ['/tmp/banner.jpg'],
      exhibitionImagePaths: ['/tmp/exhibition.jpg'],
    );

    await CreatorOnboardingDraftStore.save('user-1', draft);
    final restored = await CreatorOnboardingDraftStore.load('user-1');

    expect(restored?.name, 'Suhani Studio');
    expect(restored?.state, 'Odisha');
    expect(restored?.socialLinks, ['https://example.com']);
    expect(restored?.portfolioImagePaths, ['/tmp/banner.jpg']);

    await CreatorOnboardingDraftStore.clear('user-1');
    expect(await CreatorOnboardingDraftStore.load('user-1'), isNull);
  });

  test('completed creator profile status is cached', () async {
    SharedPreferences.setMockInitialValues({});

    expect(await CreatorProfileCompletionStore.load('user-1'), isNull);
    await CreatorProfileCompletionStore.save('user-1', isCompleted: true);
    expect(await CreatorProfileCompletionStore.load('user-1'), isTrue);
  });
}
