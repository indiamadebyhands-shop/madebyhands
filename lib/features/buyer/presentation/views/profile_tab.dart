import 'package:flutter/material.dart';
import 'package:madebyhands/features/auth/domain/entities/user_entity.dart';
import 'package:madebyhands/features/buyer/presentation/pages/about_madebyhands_page.dart';
import 'package:madebyhands/features/buyer/presentation/theme/buyer_theme.dart';
import 'package:madebyhands/features/buyer/presentation/widgets/buyer_background.dart';
import 'package:madebyhands/features/buyer/presentation/widgets/buyer_heading.dart';

class ProfileTab extends StatelessWidget {
  final UserEntity user;
  final VoidCallback onOrders;
  final VoidCallback onAddresses;
  final VoidCallback onSupport;
  final VoidCallback onAccount;
  final VoidCallback onCreatorMode;
  final VoidCallback onLogout;

  const ProfileTab({
    super.key,
    required this.user,
    required this.onOrders,
    required this.onAddresses,
    required this.onSupport,
    required this.onAccount,
    required this.onCreatorMode,
    required this.onLogout,
  });

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Log out?'),
            content: const Text(
              'You can sign back in with your Google account.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Log out'),
              ),
            ],
          ),
        ) ??
        false;
    if (shouldLogout) onLogout();
  }

  @override
  Widget build(BuildContext context) {
    final initial = user.name.trim().isEmpty
        ? 'B'
        : user.name.trim()[0].toUpperCase();

    return BuyerBackground(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          const BuyerPageHeader(title: 'Your profile'),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: BuyerColors.blush,
                      shape: BoxShape.circle,
                      border: Border.all(color: BuyerColors.gold, width: 1.1),
                    ),
                    child: BuyerHeading(
                      initial,
                      size: 24,
                      color: BuyerColors.maroon,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BuyerHeading(
                          user.name.isEmpty ? 'Buyer' : user.name,
                          size: 18,
                          color: BuyerColors.ink,
                          weight: FontWeight.w700,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          user.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: BuyerColors.body,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _ProfileTile(
            icon: Icons.manage_accounts_outlined,
            title: 'Account settings',
            subtitle: 'Update your name, phone or delete your account',
            onTap: onAccount,
          ),
          _ProfileTile(
            icon: Icons.receipt_long_outlined,
            title: 'My orders',
            subtitle: 'Track your orders and refunds',
            onTap: onOrders,
          ),
          _ProfileTile(
            icon: Icons.location_on_outlined,
            title: 'Saved addresses',
            subtitle: 'Manage delivery locations',
            onTap: onAddresses,
          ),
          _ProfileTile(
            icon: Icons.support_agent_outlined,
            title: 'Help & support',
            subtitle: 'Raise a ticket and chat with our team',
            onTap: onSupport,
          ),
          _ProfileTile(
            icon: Icons.info_outline,
            title: 'About MadeByHands',
            subtitle: 'Our mission, terms & privacy policy',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AboutMadeByHandsPage()),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onCreatorMode,
            icon: const Icon(Icons.swap_horiz_rounded, size: 18),
            label: const Text('Switch accounts'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _confirmLogout(context),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: BuyerColors.blush,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: BuyerColors.maroon),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    ),
  );
}
