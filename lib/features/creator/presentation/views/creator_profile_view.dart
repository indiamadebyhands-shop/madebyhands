import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:madebyhands/features/auth/domain/entities/user_entity.dart';
import 'package:madebyhands/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:madebyhands/features/creator/domain/entities/creator_profile.dart';
import 'package:madebyhands/features/creator/presentation/pages/creator_onboarding_page.dart';
import 'package:madebyhands/features/creator/presentation/pages/creator_verification_page.dart';
import 'package:madebyhands/features/creator/presentation/pages/manage_bank_account_page.dart';
import 'package:madebyhands/features/creator/presentation/pages/privacy_policy_page.dart';
import 'package:madebyhands/features/creator/presentation/pages/terms_and_conditions_page.dart';

class CreatorProfileView extends StatefulWidget {
  final CreatorProfile profile;
  final UserEntity user;

  const CreatorProfileView({super.key, required this.profile, required this.user});

  @override
  State<CreatorProfileView> createState() => _CreatorProfileViewState();
}

class _CreatorProfileViewState extends State<CreatorProfileView> {
  void _push(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    return ListView(
      padding: const EdgeInsets.all(20.0),
      children: [
        const SizedBox(height: 10),
        _buildProfileCard(profile),
        const SizedBox(height: 24),
        _buildActionItem(
          icon: Icons.edit_outlined,
          title: 'Edit creator profile',
          subtitle: 'Update bio, craft category, story, links and banner',
          onTap: () => _push(
            CreatorOnboardingPage(user: widget.user, existingProfile: profile),
          ),
        ),
        if (!profile.isVerified && !profile.isUnderReview)
          _buildActionItem(
            icon: Icons.verified_user_outlined,
            title: 'Get verified',
            subtitle: 'Submit your documents to start selling',
            onTap: () => _push(CreatorVerificationPage(profile: profile)),
          ),
        _buildActionItem(
          icon: Icons.account_balance_outlined,
          title: 'Payout details',
          subtitle: 'Bank account and UPI used for your earnings',
          onTap: () => _push(ManageBankAccountPage(profile: profile)),
        ),
        _buildActionItem(
          icon: Icons.description_outlined,
          title: 'Terms & conditions',
          subtitle: 'Read artisan platform terms and rules',
          onTap: () => _push(const TermsAndConditionsPage()),
        ),
        _buildActionItem(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy policy',
          subtitle: 'How we protect your data',
          onTap: () => _push(const PrivacyPolicyPage()),
        ),
        _buildActionItem(
          icon: Icons.delete_forever_outlined,
          title: 'Delete account',
          subtitle: 'Permanently delete your creator account, products and studio data',
          badgeColor: Colors.red,
          onTap: () => _confirmAccountDeletion(profile),
        ),
        const SizedBox(height: 30),
        ElevatedButton.icon(
          onPressed: () => context.read<AuthBloc>().add(
            AuthSignUpWithRoleRequested(
              uid: widget.user.uid,
              email: widget.user.email,
              name: widget.user.name,
              phone: widget.user.phone,
              role: 'buyer',
            ),
          ),
          icon: const Icon(Icons.swap_horiz_rounded),
          label: const Text('Switch accounts'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8B261D),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => context.read<AuthBloc>().add(AuthLogoutRequested()),
          icon: const Icon(Icons.logout, color: Color(0xFF8B261D)),
          label: const Text('Log out', style: TextStyle(color: Color(0xFF8B261D))),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFF8B261D)),
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildProfileCard(CreatorProfile profile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF6EE).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFF8B261D), width: 1.0),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 46,
            backgroundColor: const Color(0xFFF2DEDD),
            backgroundImage: profile.profileImage.isNotEmpty
                ? NetworkImage(profile.profileImage)
                : null,
            child: profile.profileImage.isEmpty
                ? const Icon(Icons.person, size: 46, color: Color(0xFF8B261D))
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            profile.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8B261D),
            ),
          ),
          if (profile.location.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              profile.location,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF8A8F82), fontSize: 13),
            ),
          ],
          const SizedBox(height: 6),
          _VerificationBadge(profile: profile),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? badgeColor,
  }) {
    return Card(
      elevation: 1,
      color: const Color(0xFFFAF6EE).withValues(alpha: 0.95),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: (badgeColor ?? const Color(0xFF8B261D)).withValues(alpha: 0.3),
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: badgeColor ?? const Color(0xFF8B261D)),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: badgeColor ?? const Color(0xFF8B261D),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Color(0xFF8A8F82)),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          size: 20,
          color: Color(0xFF8B261D),
        ),
        onTap: onTap,
      ),
    );
  }

  Future<void> _confirmAccountDeletion(CreatorProfile profile) async {
    final reasonController = TextEditingController();
    final reasonFormKey = GlobalKey<FormState>();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFFFAF6EE),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Permanently Delete Account?',
                style: TextStyle(color: Colors.red, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Form(
          key: reasonFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your studio profile, products, payout details and notifications will be permanently deleted. '
                'Finish or reject any open orders first. This cannot be undone.\n\n'
                'For security you may be asked to sign in again before deleting.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: reasonController,
                autofocus: true,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Why are you leaving? *',
                  hintText: 'Help us improve MadeByHands',
                ),
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Please tell us why' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (!reasonFormKey.currentState!.validate()) return;
              Navigator.pop(dialogCtx, reasonController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Permanently Delete'),
          ),
        ],
      ),
    );

    if (reason != null && mounted) {
      context.read<AuthBloc>().add(
        AuthDeleteAccountRequested(profile.uid, reason: reason),
      );
    }
  }
}

class _VerificationBadge extends StatelessWidget {
  final CreatorProfile profile;

  const _VerificationBadge({required this.profile});

  @override
  Widget build(BuildContext context) {
    final (String label, Color color) = profile.isVerified
        ? ('Verified', Colors.green.shade700)
        : profile.isUnderReview
        ? ('Under review', Colors.orange.shade800)
        : profile.isVerificationRejected
        ? ('Verification rejected', Colors.red)
        : ('Not verified', Colors.red);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
