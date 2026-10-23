import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:madebyhands/core/constants/image_upload.dart';
import 'package:madebyhands/features/auth/domain/entities/user_entity.dart';
import 'package:madebyhands/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:madebyhands/features/buyer/presentation/widgets/buyer_background.dart';
import 'package:madebyhands/features/creator/domain/entities/creator_profile.dart';
import 'package:madebyhands/features/creator/presentation/bloc/creator_bloc.dart';

class CreatorOnboardingPage extends StatefulWidget {
  final UserEntity user;
  final CreatorProfile? existingProfile;

  const CreatorOnboardingPage({
    super.key,
    required this.user,
    this.existingProfile,
  });

  @override
  State<CreatorOnboardingPage> createState() => _CreatorOnboardingPageState();
}

class _CreatorOnboardingPageState extends State<CreatorOnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _locationController = TextEditingController();
  final _socialController = TextEditingController();
  final _storyController = TextEditingController();

  File? _profileImage;
  final List<File> _portfolioImages = [];
  final List<String> _existingPortfolioUrls = [];

  final List<File> _exhibitionImages = [];
  final List<String> _existingExhibitionPictureUrls = [];
  static const int _maxExhibitionPictures = 10;

  int get _totalExhibitionPictures =>
      _existingExhibitionPictureUrls.length + _exhibitionImages.length;

  String? _selectedState;

  static const List<String> _indianStatesAndUTs = [
    'Andaman and Nicobar Islands',
    'Andhra Pradesh',
    'Arunachal Pradesh',
    'Assam',
    'Bihar',
    'Chandigarh',
    'Chhattisgarh',
    'Dadra and Nagar Haveli and Daman and Diu',
    'Delhi',
    'Goa',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jammu and Kashmir',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Ladakh',
    'Lakshadweep',
    'Madhya Pradesh',
    'Maharashtra',
    'Manipur',
    'Meghalaya',
    'Mizoram',
    'Nagaland',
    'Odisha',
    'Puducherry',
    'Punjab',
    'Rajasthan',
    'Sikkim',
    'Tamil Nadu',
    'Telangana',
    'Tripura',
    'Uttar Pradesh',
    'Uttarakhand',
    'West Bengal',
  ];

  final List<String> _socialLinks = [];
  @override
  void initState() {
    super.initState();
    final p = widget.existingProfile;
    _nameController.text = p?.name ?? widget.user.name;
    _bioController.text = p?.bio ?? '';
    _locationController.text = p?.location ?? '';
    _storyController.text = p?.story ?? '';

    if (p != null) {
      if (p.state.isNotEmpty && _indianStatesAndUTs.contains(p.state)) {
        _selectedState = p.state;
      }
      _socialLinks.addAll(p.socialLinks);
      _existingPortfolioUrls.addAll(p.portfolio);
      _existingExhibitionPictureUrls.addAll(p.exhibitionPictures);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _socialController.dispose();
    _storyController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: kImageQuality,
      maxWidth: kProfileImageMaxSide,
      maxHeight: kProfileImageMaxSide,
    );
    if (pickedFile != null && mounted) {
      final croppedFile = await showDialog<File>(
        context: context,
        builder: (_) => _ImageCropPreviewDialog(
          imageFile: File(pickedFile.path),
          aspectRatio: 1.0,
          isCircle: true,
          title: 'Crop Profile Picture',
        ),
      );
      if (croppedFile != null) {
        setState(() => _profileImage = croppedFile);
      }
    }
  }

  int get _totalPortfolioImages =>
      _existingPortfolioUrls.length + _portfolioImages.length;

  Future<void> _pickPortfolioImage() async {
    if (_totalPortfolioImages >= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Maximum 1 banner image allowed. Remove current image to replace.',
          ),
        ),
      );
      return;
    }
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: kImageQuality,
      maxWidth: kProfileImageMaxSide,
      maxHeight: kProfileImageMaxSide,
    );
    if (pickedFile != null && mounted) {
      final croppedFile = await showDialog<File>(
        context: context,
        builder: (_) => _ImageCropPreviewDialog(
          imageFile: File(pickedFile.path),
          aspectRatio: 16 / 9,
          title: 'Crop Banner Image',
        ),
      );
      if (croppedFile != null) {
        setState(() => _portfolioImages.add(croppedFile));
      }
    }
  }

  Future<void> _pickExhibitionImage() async {
    final remaining = _maxExhibitionPictures - _totalExhibitionPictures;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 10 exhibition pictures allowed.'),
        ),
      );
      return;
    }
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: kImageQuality,
      maxWidth: kProfileImageMaxSide,
      maxHeight: kProfileImageMaxSide,
    );
    if (pickedFile != null && mounted) {
      final croppedFile = await showDialog<File>(
        context: context,
        builder: (_) => _ImageCropPreviewDialog(
          imageFile: File(pickedFile.path),
          aspectRatio: 1.0,
          title: 'Crop Exhibition Picture',
        ),
      );
      if (croppedFile != null) {
        setState(() => _exhibitionImages.add(croppedFile));
      }
    }
  }

  static final RegExp _domainPattern = RegExp(
    r'^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)+$',
  );

  /// True only for something that is actually a link (a real domain, with or
  /// without a scheme/path) — not arbitrary free text.
  bool _isValidLink(String raw) {
    if (raw.contains(' ')) return false;
    final candidate = raw.contains('://') ? raw : 'https://$raw';
    final uri = Uri.tryParse(candidate);
    if (uri == null || uri.host.isEmpty) return false;
    return _domainPattern.hasMatch(uri.host);
  }

  void _addSocialLink() {
    final raw = _socialController.text.trim();
    if (raw.isEmpty) return;
    if (!_isValidLink(raw)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid link, e.g. instagram.com/yourshop'),
        ),
      );
      return;
    }
    final normalized = raw.contains('://') ? raw : 'https://$raw';
    if (_socialLinks.contains(normalized)) {
      _socialController.clear();
      return;
    }
    setState(() {
      _socialLinks.add(normalized);
      _socialController.clear();
    });
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState!.validate()) {
      context.read<CreatorBloc>().add(
            CreatorSubmitOnboarding(
              uid: widget.user.uid,
              name: _nameController.text.trim(),
              profileImageFile: _profileImage,
              bio: _bioController.text.trim(),
              location: _locationController.text.trim(),
              state: _selectedState ?? '',
              socialLinks: List.of(_socialLinks),
              portfolioImageFiles: List.of(_portfolioImages),
              exhibitionImageFiles: List.of(_exhibitionImages),
              story: _storyController.text.trim(),
              existingProfileImageUrl: widget.existingProfile?.profileImage,
              existingPortfolioUrls: List.of(_existingPortfolioUrls),
              existingExhibitionPictureUrls:
                  List.of(_existingExhibitionPictureUrls),
            ),
          );
    }
  }

  ImageProvider? _getProfileImageProvider() {
    if (_profileImage != null) {
      if (kIsWeb) {
        return NetworkImage(_profileImage!.path);
      } else {
        return FileImage(_profileImage!);
      }
    }
    if (widget.existingProfile != null && widget.existingProfile!.profileImage.isNotEmpty) {
      return NetworkImage(widget.existingProfile!.profileImage);
    }
    return null;
  }

  Widget _buildFileImageWidget(
    File file, {
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
  }) {
    if (kIsWeb) {
      return Image.network(
        file.path,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image, color: Colors.grey),
      );
    } else {
      return Image.file(
        file,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image, color: Colors.grey),
      );
    }
  }

  void _showImagePreviewDialog({
    String? imageUrl,
    File? imageFile,
    required String title,
  }) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.black.withValues(alpha: 0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(dialogCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.65,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: imageUrl != null
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stack) => const Icon(
                              Icons.broken_image,
                              color: Colors.white,
                              size: 64,
                            ),
                          )
                        : imageFile != null
                            ? _buildFileImageWidget(
                                imageFile,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.contain,
                              )
                            : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.existingProfile != null;

    return BuyerBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            isEditMode ? 'Edit Creator Profile' : 'Creator Onboarding',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF8B261D),
            ),
          ),
          iconTheme: const IconThemeData(color: Color(0xFF8B261D)),
          actions: [
            if (!isEditMode)
              IconButton(
                onPressed: () =>
                    context.read<AuthBloc>().add(AuthLogoutRequested()),
                icon: const Icon(Icons.logout, color: Color(0xFF8B261D)),
              ),
          ],
        ),
      body: BlocConsumer<CreatorBloc, CreatorState>(
        listenWhen: (previous, current) =>
            previous.actionId != current.actionId &&
            current.action == CreatorAction.saveProfile &&
            current.actionStatus != CreatorActionStatus.inProgress,
        listener: (context, state) {
          final messenger = ScaffoldMessenger.of(context);
          if (state.actionStatus == CreatorActionStatus.failure) {
            messenger.showSnackBar(
              SnackBar(content: Text(state.actionMessage ?? 'Could not save your profile.')),
            );
            return;
          }
          messenger.showSnackBar(
            SnackBar(
              content: Text(isEditMode ? 'Profile updated.' : 'Welcome to MadeByHands!'),
            ),
          );
          if (isEditMode) Navigator.pop(context);
        },
        buildWhen: (previous, current) =>
            previous.isRunning(CreatorAction.saveProfile) !=
            current.isRunning(CreatorAction.saveProfile),
        builder: (context, state) {
          final saving = state.isRunning(CreatorAction.saveProfile);
          return AbsorbPointer(
            absorbing: saving,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24.0,
                16.0,
                24.0,
                MediaQuery.of(context).viewInsets.bottom + 24.0,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _OnboardingHeader(isEditMode: isEditMode),
                    const SizedBox(height: 30),
                    _buildProfileImagePicker(),
                    const SizedBox(height: 30),
                    _buildFormFields(),
                    const SizedBox(height: 30),
                    _buildExhibitionPicturesSection(),
                    const SizedBox(height: 30),
                    _buildSocialLinksSection(),
                    const SizedBox(height: 30),
                    _buildPortfolioSection(),
                    const SizedBox(height: 50),
                    FilledButton(
                      onPressed: saving ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF8B261D),
                        foregroundColor: Colors.white,
                      ),
                      child: saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(isEditMode ? 'Save profile changes' : 'Launch my studio'),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
    );
  }

  Widget _buildProfileImagePicker() {
    final hasImage = _profileImage != null ||
        (widget.existingProfile != null && widget.existingProfile!.profileImage.isNotEmpty);

    return Column(
      children: [
        const Center(
          child: Text(
            'Profile Picture',
            style: TextStyle(color: Color(0xFF8A8F82), fontSize: 12),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Stack(
            children: [
              GestureDetector(
                onTap: hasImage
                    ? () {
                        if (_profileImage != null) {
                          _showImagePreviewDialog(
                            imageFile: _profileImage,
                            title: 'Profile Picture',
                          );
                        } else if (widget.existingProfile != null &&
                            widget.existingProfile!.profileImage.isNotEmpty) {
                          _showImagePreviewDialog(
                            imageUrl: widget.existingProfile!.profileImage,
                            title: 'Profile Picture',
                          );
                        }
                      }
                    : _pickProfileImage,
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor:
                      const Color(0xFF8B261D).withValues(alpha: 0.1),
                  backgroundImage: _getProfileImageProvider(),
                  child: !hasImage
                      ? const Icon(Icons.person,
                          size: 60, color: Color(0xFF8B261D))
                      : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: CircleAvatar(
                  backgroundColor: const Color(0xFF8B261D),
                  radius: 20,
                  child: IconButton(
                    onPressed: _pickProfileImage,
                    icon: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Artisan/Studio Name *', prefixIcon: Icon(Icons.storefront)),
          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _locationController,
          decoration: const InputDecoration(
            labelText: 'Complete Address *',
            hintText: 'House/Street, Locality, City, PIN Code',
            prefixIcon: Icon(Icons.location_on_outlined),
            alignLabelWithHint: true,
          ),
          maxLines: 3,
          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          initialValue: _selectedState,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'State / Union Territory *',
            prefixIcon: Icon(Icons.map_outlined),
          ),
          hint: const Text('Select State or Union Territory'),
          items: _indianStatesAndUTs.map((state) {
            return DropdownMenuItem<String>(
              value: state,
              child: Text(state),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedState = value;
            });
          },
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _bioController,
          decoration: const InputDecoration(labelText: 'Short Bio *', alignLabelWithHint: true),
          maxLines: 3,
          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _storyController,
          decoration: const InputDecoration(labelText: 'Your Creator Story *', hintText: 'Tell us your inspiration...', alignLabelWithHint: true),
          maxLines: 5,
          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
        ),
      ],
    );
  }

  Widget _buildExhibitionPicturesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Exhibition Pictures',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8B261D),
              ),
            ),
            Text(
              '$_totalExhibitionPictures/$_maxExhibitionPictures',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8A8F82),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Showcase photos of your studio, past exhibitions, or craft displays (max 10).',
          style: TextStyle(fontSize: 12, color: Color(0xFF8A8F82)),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              if (_totalExhibitionPictures < _maxExhibitionPictures)
                _buildAddExhibitionButton(),
              ..._existingExhibitionPictureUrls.asMap().entries.map(
                    (e) => _buildExistingExhibitionItem(e.key, e.value),
                  ),
              ..._exhibitionImages.asMap().entries.map(
                    (e) => _buildExhibitionItem(e.key, e.value),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddExhibitionButton() {
    return GestureDetector(
      onTap: _pickExhibitionImage,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: const Color(0xFFFAF6EE),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: const Color(0xFF8B261D).withValues(alpha: 0.3),
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, color: Color(0xFF8A8F82)),
            SizedBox(height: 4),
            Text(
              'Add Photo',
              style: TextStyle(fontSize: 11, color: Color(0xFF8A8F82)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExistingExhibitionItem(int index, String url) {
    return Padding(
      padding: const EdgeInsets.only(left: 12.0),
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => _showImagePreviewDialog(
              imageUrl: url,
              title: 'Exhibition Picture ${index + 1}',
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.network(
                url,
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                cacheWidth: 360,
                errorBuilder: (_, _, _) => Container(
                  width: 120,
                  height: 120,
                  color: const Color(0xFFEAE7DC),
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
          ),
          Positioned(
            top: 5,
            right: 5,
            child: GestureDetector(
              onTap: () => setState(
                () => _existingExhibitionPictureUrls.removeAt(index),
              ),
              child: const CircleAvatar(
                radius: 12,
                backgroundColor: Colors.red,
                child: Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExhibitionItem(int index, File file) {
    return Padding(
      padding: const EdgeInsets.only(left: 12.0),
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => _showImagePreviewDialog(
              imageFile: file,
              title: 'Exhibition Picture ${index + 1}',
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: _buildFileImageWidget(file, width: 120, height: 120),
            ),
          ),
          Positioned(
            top: 5,
            right: 5,
            child: GestureDetector(
              onTap: () => setState(() => _exhibitionImages.removeAt(index)),
              child: const CircleAvatar(
                radius: 12,
                backgroundColor: Colors.red,
                child: Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialLinksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Social Links', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF8B261D))),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _socialController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  hintText: 'e.g. instagram.com/yourshop',
                  prefixIcon: Icon(Icons.link),
                ),
                onFieldSubmitted: (_) => _addSocialLink(),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filled(
              onPressed: _addSocialLink,
              icon: const Icon(Icons.add, color: Colors.white),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF8B261D),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: _socialLinks.map((link) => Chip(
            label: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(link, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
            ),
            onDeleted: () => setState(() => _socialLinks.remove(link)),
            deleteIconColor: Colors.red,
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildPortfolioSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Banner', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF8B261D))),
        const SizedBox(height: 10),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              if (_totalPortfolioImages < 1) _buildAddPortfolioButton(),
              ..._existingPortfolioUrls.asMap().entries.map(
                    (e) => _buildExistingPortfolioItem(e.key, e.value),
                  ),
              ..._portfolioImages.asMap().entries.map(
                    (e) => _buildPortfolioItem(e.key, e.value),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddPortfolioButton() {
    return GestureDetector(
      onTap: _pickPortfolioImage,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: const Color(0xFFFAF6EE),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFF8B261D).withValues(alpha: 0.3)),
        ),
        child: const Icon(Icons.add_a_photo_outlined, color: Color(0xFF8A8F82)),
      ),
    );
  }

  Widget _buildExistingPortfolioItem(int index, String url) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: GestureDetector(
            onTap: () => _showImagePreviewDialog(
              imageUrl: url,
              title: 'Banner Picture ${index + 1}',
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.network(
                url,
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                cacheWidth: 360,
                errorBuilder: (_, _, _) => Container(
                  width: 120,
                  height: 120,
                  color: const Color(0xFFEAE7DC),
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 5,
          right: 5,
          child: GestureDetector(
            onTap: () => setState(() => _existingPortfolioUrls.removeAt(index)),
            child: const CircleAvatar(
              radius: 12,
              backgroundColor: Colors.red,
              child: Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPortfolioItem(int index, File file) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: GestureDetector(
            onTap: () => _showImagePreviewDialog(
              imageFile: file,
              title: 'Banner Picture ${index + 1}',
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: _buildFileImageWidget(file, width: 120, height: 120),
            ),
          ),
        ),
        Positioned(
          top: 5,
          right: 5,
          child: GestureDetector(
            onTap: () => setState(() => _portfolioImages.removeAt(index)),
            child: const CircleAvatar(
              radius: 12,
              backgroundColor: Colors.red,
              child: Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _OnboardingHeader extends StatelessWidget {
  final bool isEditMode;

  const _OnboardingHeader({this.isEditMode = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isEditMode ? 'Update Your Studio Profile' : 'Complete your Artisan Profile',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF8B261D)),
        ),
        const SizedBox(height: 8),
        Text(
          isEditMode
              ? 'Keep your craft story, links, and banner up to date.'
              : 'Tell the world about your craft and story.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF8A8F82)),
        ),
      ],
    );
  }
}

class _ImageCropPreviewDialog extends StatefulWidget {
  final File imageFile;
  final double aspectRatio;
  final bool isCircle;
  final String title;

  const _ImageCropPreviewDialog({
    required this.imageFile,
    required this.aspectRatio,
    this.isCircle = false,
    required this.title,
  });

  @override
  State<_ImageCropPreviewDialog> createState() =>
      _ImageCropPreviewDialogState();
}

class _ImageCropPreviewDialogState extends State<_ImageCropPreviewDialog> {
  final TransformationController _transformationController =
      TransformationController();
  ui.Image? _decodedSourceImage;
  bool _isCropping = false;
  double _activeCropW = 0.0;
  double _activeCropH = 0.0;
  double _activeViewportW = 0.0;
  double _activeViewportH = 0.0;

  @override
  void initState() {
    super.initState();
    _loadSourceImage();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadSourceImage() async {
    try {
      final bytes = await XFile(widget.imageFile.path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _decodedSourceImage = frame.image;
        });
      }
    } catch (_) {
      try {
        final bytes = await widget.imageFile.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        if (mounted) {
          setState(() {
            _decodedSourceImage = frame.image;
          });
        }
      } catch (_) {}
    }
  }

  void _resetPosition() {
    _transformationController.value = Matrix4.identity();
  }

  Future<void> _saveAndConfirmCrop(
    double cropW,
    double cropH,
    double viewportW,
    double viewportH,
  ) async {
    if (_decodedSourceImage == null) return;
    setState(() => _isCropping = true);

    try {
      final srcImage = _decodedSourceImage!;
      final double srcW = srcImage.width.toDouble();
      final double srcH = srcImage.height.toDouble();
      final double imageRatio = srcW / srcH;

      double baseW, baseH;
      if (imageRatio > widget.aspectRatio) {
        baseH = cropH;
        baseW = cropH * imageRatio;
      } else {
        baseW = cropW;
        baseH = cropW / imageRatio;
      }

      final Matrix4 transform = _transformationController.value;
      final double scale = transform.getMaxScaleOnAxis();
      final double tx = transform.storage[12];
      final double ty = transform.storage[13];

      final double u = ((viewportW - cropW) / 2.0 - tx) / scale -
          (viewportW - baseW) / 2.0;
      final double v = ((viewportH - cropH) / 2.0 - ty) / scale -
          (viewportH - baseH) / 2.0;

      final double deltaU = cropW / scale;
      final double deltaV = cropH / scale;

      final double normX = (u / baseW).clamp(0.0, 1.0);
      final double normY = (v / baseH).clamp(0.0, 1.0);
      final double normW = (deltaU / baseW).clamp(0.0, 1.0);
      final double normH = (deltaV / baseH).clamp(0.0, 1.0);

      final double srcCropX = normX * srcW;
      final double srcCropY = normY * srcH;
      final double srcCropW = (normW * srcW).clamp(1.0, srcW - srcCropX);
      final double srcCropH = (normH * srcH).clamp(1.0, srcH - srcCropY);

      final double outW = widget.aspectRatio == 1.0 ? 1080.0 : 1920.0;
      final double outH = widget.aspectRatio == 1.0 ? 1080.0 : 1080.0;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      canvas.drawImageRect(
        srcImage,
        Rect.fromLTWH(srcCropX, srcCropY, srcCropW, srcCropH),
        Rect.fromLTWH(0, 0, outW, outH),
        Paint()..filterQuality = FilterQuality.high,
      );

      final picture = recorder.endRecording();
      final croppedUiImage =
          await picture.toImage(outW.toInt(), outH.toInt());
      final byteData =
          await croppedUiImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Crop failed');
      final pngBytes = byteData.buffer.asUint8List();

      if (kIsWeb) {
        final xFile = XFile.fromData(
          pngBytes,
          mimeType: 'image/png',
          name: 'cropped_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        final croppedFile = File(xFile.path);
        if (mounted) {
          Navigator.pop(context, croppedFile);
        }
      } else {
        final tempDir = Directory.systemTemp;
        final croppedFile = File(
          '${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        await croppedFile.writeAsBytes(pngBytes);

        if (mounted) {
          Navigator.pop(context, croppedFile);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isCropping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCircle = widget.isCircle;

    return BuyerBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF8B261D)),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.title,
            style: const TextStyle(
              color: Color(0xFF8B261D),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 20),
              child: Text(
                'Pan and zoom the image to fit inside the crop frame.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8A8F82), fontSize: 13),
              ),
            ),
            Expanded(
              child: ClipRect(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const double padding = 24.0;
                    final double maxW = constraints.maxWidth - (padding * 2);
                    final double maxH = constraints.maxHeight - (padding * 2);
                    double cropW, cropH;
                    if (maxW / maxH > widget.aspectRatio) {
                      cropH = maxH;
                      cropW = maxH * widget.aspectRatio;
                    } else {
                      cropW = maxW;
                      cropH = maxW / widget.aspectRatio;
                    }
                    _activeCropW = cropW;
                    _activeCropH = cropH;
                    _activeViewportW = constraints.maxWidth;
                    _activeViewportH = constraints.maxHeight;

                    final cropRect = Rect.fromCenter(
                      center: Offset(
                        constraints.maxWidth / 2,
                        constraints.maxHeight / 2,
                      ),
                      width: cropW,
                      height: cropH,
                    );

                    double imageRatio = widget.aspectRatio;
                    if (_decodedSourceImage != null) {
                      imageRatio = _decodedSourceImage!.width /
                          _decodedSourceImage!.height;
                    }

                    double baseW, baseH;
                    if (imageRatio > widget.aspectRatio) {
                      baseH = cropH;
                      baseW = cropH * imageRatio;
                    } else {
                      baseW = cropW;
                      baseH = cropW / imageRatio;
                    }

                    final double marginH = (constraints.maxWidth - cropW) / 2;
                    final double marginV = (constraints.maxHeight - cropH) / 2;

                    return Stack(
                      children: [
                        Positioned.fill(
                          child: InteractiveViewer(
                            transformationController:
                                _transformationController,
                            minScale: 1.0,
                            maxScale: 4.0,
                            boundaryMargin: EdgeInsets.symmetric(
                              horizontal: marginH,
                              vertical: marginV,
                            ),
                            clipBehavior: Clip.none,
                            child: Center(
                              child: SizedBox(
                                width: baseW,
                                height: baseH,
                                child: _buildCropFileImageWidget(
                                  widget.imageFile,
                                  width: baseW,
                                  height: baseH,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _CropOverlayMaskPainter(
                                cropRect: cropRect,
                                isCircle: isCircle,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 16.0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _resetPosition,
                      icon: const Icon(
                        Icons.refresh,
                        color: Color(0xFF8B261D),
                        size: 18,
                      ),
                      label: const Text(
                        'Reset Position',
                        style: TextStyle(
                          color: Color(0xFF8B261D),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF8B261D)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: (_isCropping || _decodedSourceImage == null)
                          ? null
                          : () {
                              _saveAndConfirmCrop(
                                _activeCropW,
                                _activeCropH,
                                _activeViewportW,
                                _activeViewportH,
                              );
                            },
                      icon: _isCropping
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check, size: 18),
                      label: const Text(
                        'Save',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF8B261D),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCropFileImageWidget(
    File file, {
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
  }) {
    if (kIsWeb) {
      return Image.network(
        file.path,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image, color: Colors.grey),
      );
    } else {
      return Image.file(
        file,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image, color: Colors.grey),
      );
    }
  }
}

class _CropOverlayMaskPainter extends CustomPainter {
  final Rect cropRect;
  final bool isCircle;

  _CropOverlayMaskPainter({
    required this.cropRect,
    this.isCircle = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maskPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    if (isCircle) {
      maskPath.addOval(cropRect);
    } else {
      maskPath.addRRect(
        RRect.fromRectAndRadius(cropRect, const Radius.circular(16.0)),
      );
    }

    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;

    canvas.drawPath(maskPath, paint);

    final borderPaint = Paint()
      ..color = const Color(0xFF8B261D)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    if (isCircle) {
      canvas.drawOval(cropRect, borderPaint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(cropRect, const Radius.circular(16.0)),
        borderPaint,
      );

      final gridPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      final x1 = cropRect.left + cropRect.width / 3;
      final x2 = cropRect.left + (cropRect.width / 3) * 2;
      final y1 = cropRect.top + cropRect.height / 3;
      final y2 = cropRect.top + (cropRect.height / 3) * 2;

      canvas.drawLine(
        Offset(x1, cropRect.top),
        Offset(x1, cropRect.bottom),
        gridPaint,
      );
      canvas.drawLine(
        Offset(x2, cropRect.top),
        Offset(x2, cropRect.bottom),
        gridPaint,
      );
      canvas.drawLine(
        Offset(cropRect.left, y1),
        Offset(cropRect.right, y1),
        gridPaint,
      );
      canvas.drawLine(
        Offset(cropRect.left, y2),
        Offset(cropRect.right, y2),
        gridPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
