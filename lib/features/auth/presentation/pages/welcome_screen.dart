import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:madebyhands/core/constants/feature_flags.dart';
import 'package:madebyhands/core/theme/app_theme.dart';
import 'package:madebyhands/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:madebyhands/features/buyer/presentation/pages/buyer_privacy_policy_page.dart';
import 'package:madebyhands/features/buyer/presentation/pages/buyer_terms_and_conditions_page.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _termsAccepted = true; // Pre-ticked checkbox by default

  final List<OnboardingData> _onboardingPages = [
    OnboardingData(
      title: 'Crafted with Soul',
      subtitle:
          'Discover unique handmade pieces that carry the spirit of the artist who made them.',
      imageUrl:
          'https://images.unsplash.com/photo-1578749556568-bc2c40e68b61?q=80&w=1000&auto=format&fit=crop',
      color: AppColors.primary,
    ),
    OnboardingData(
      title: 'Stories in Every Thread',
      subtitle:
          'Connect with independent Indian artisans and support traditional craftsmanship.',
      imageUrl:
          'https://images.unsplash.com/photo-1610701596007-11502861dcfa?q=80&w=1000&auto=format&fit=crop',
      color: AppColors.accent,
    ),
    OnboardingData(
      title: 'Experience Authenticity',
      subtitle:
          'A marketplace built for creators, by people who value the beauty of the handmade.',
      imageUrl:
          'https://images.unsplash.com/photo-1513364776144-60967b0f800f?q=80&w=1000&auto=format&fit=crop',
      color: AppColors.primaryDark,
    ),
  ];

  void _handleLogin() {
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please accept the Terms and Conditions and Privacy Policy to continue login.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    context.read<AuthBloc>().add(AuthGoogleSignInRequested());
  }

  void _handleTestBuyerLogin() {
    context.read<AuthBloc>().add(AuthTestBuyerSignInRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        },
        builder: (context, state) {
          return Stack(
            children: [
              // Background Image with crossfade
              AnimatedSwitcher(
                duration: 800.ms,
                child: Container(
                  key: ValueKey(_currentPage),
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(
                        _onboardingPages[_currentPage].imageUrl,
                      ),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black.withValues(alpha: 0.35),
                        BlendMode.darken,
                      ),
                    ),
                  ),
                ),
              ),

              // Glassmorphic Gradient Overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.2),
                      AppColors.background.withValues(alpha: 0.95),
                      AppColors.background,
                    ],
                    stops: const [0.0, 0.4, 0.7, 0.85],
                  ),
                ),
              ),

              // Main content scrolls on short screens instead of overflowing.
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildHeader(),
                          Column(
                            children: [
                              const SizedBox(height: 24),
                              _buildPages(context),
                              _buildFooter(state),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 20, 30, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              'MADEBYHANDS',
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.montserrat(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ).animate().fadeIn(duration: 800.ms).slideX(begin: -0.2),
          ),
          if (_currentPage < _onboardingPages.length - 1)
            TextButton(
              onPressed: () =>
                  _pageController.jumpToPage(_onboardingPages.length - 1),
              child: const Text(
                'Skip',
                style: TextStyle(color: Colors.white70),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPages(BuildContext context) {
    return SizedBox(
      height: 230,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _currentPage = index),
        itemCount: _onboardingPages.length,
        itemBuilder: (context, index) {
          final page = _onboardingPages[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  page.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                )
                    .animate(key: ValueKey('title_$index'))
                    .fadeIn(delay: 200.ms)
                    .slideY(begin: 0.2),
                const SizedBox(height: 16),
                Text(
                  page.subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.mutedText,
                    fontSize: 16,
                    height: 1.5,
                  ),
                )
                    .animate(key: ValueKey('sub_$index'))
                    .fadeIn(delay: 400.ms)
                    .slideY(begin: 0.2),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFooter(AuthState state) {
    final isLastPage = _currentPage == _onboardingPages.length - 1;
    final isLoading = state is AuthLoading;
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SmoothPageIndicator(
                controller: _pageController,
                count: _onboardingPages.length,
                effect: const ExpandingDotsEffect(
                  activeDotColor: AppColors.primary,
                  dotColor: AppColors.outline,
                  dotHeight: 8,
                  dotWidth: 8,
                  spacing: 10,
                ),
              ),
              if (!isLastPage)
                FloatingActionButton(
                  heroTag: null,
                  onPressed: () => _pageController.nextPage(
                    duration: 600.ms,
                    curve: Curves.easeInOut,
                  ),
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                    size: 20,
                  ),
                ).animate().scale().fadeIn(),
            ],
          ),
          if (isLastPage) ...[
            const SizedBox(height: 20),
            if (kGoogleSignInEnabled)
              FilledButton.icon(
                onPressed: isLoading ? null : _handleLogin,
                icon: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Image.asset(
                        'assets/images/icon_google.png',
                        height: 24,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.login),
                      ),
                label: const Text('Continue with Google'),
              ).animate().slideY(begin: 0.5).fadeIn()
            else
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Sign-in is temporarily unavailable. Please check back shortly.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.mutedText, fontSize: 13),
                ),
              ),
            // TEMPORARY, for the payment gateway's review: a guest buyer
            // sign-in that skips Google and role selection.
            if (kTestBuyerLoginEnabled) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: isLoading ? null : _handleTestBuyerLogin,
                icon: const Icon(Icons.shopping_bag_outlined, size: 20),
                label: const Text('Continue as test buyer'),
              ),
              const SizedBox(height: 6),
              const Text(
                'For testing only. Opens the store as a guest buyer, with no '
                'Google account needed.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.mutedText, fontSize: 11.5),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  height: 24,
                  width: 24,
                  child: Checkbox(
                    value: _termsAccepted,
                    activeColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    onChanged: (val) =>
                        setState(() => _termsAccepted = val ?? false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'By joining, you agree to our ',
                        style: TextStyle(
                          color: _termsAccepted
                              ? AppColors.mutedText
                              : Colors.red.shade700,
                          fontSize: 12,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const BuyerTermsAndConditionsPage(),
                          ),
                        ),
                        child: const Text(
                          'Terms and Conditions',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      Text(
                        ' and ',
                        style: TextStyle(
                          color: _termsAccepted
                              ? AppColors.mutedText
                              : Colors.red.shade700,
                          fontSize: 12,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const BuyerPrivacyPolicyPage(),
                          ),
                        ),
                        child: const Text(
                          'Privacy Policy',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class OnboardingData {
  final String title;
  final String subtitle;
  final String imageUrl;
  final Color color;

  OnboardingData({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.color,
  });
}
