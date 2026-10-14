import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:madebyhands/core/constants/product_categories.dart';
import 'package:madebyhands/core/constants/image_upload.dart';
import 'package:madebyhands/core/theme/app_theme.dart';
import 'package:madebyhands/features/admin/presentation/bloc/admin_bloc.dart';
import 'package:madebyhands/features/buyer/presentation/widgets/buyer_background.dart';
import 'package:madebyhands/features/creator/domain/entities/creator_product.dart';
import 'package:madebyhands/features/creator/domain/entities/creator_profile.dart';
import 'package:madebyhands/features/creator/domain/repositories/creator_repository.dart';
import 'package:madebyhands/features/creator/presentation/bloc/creator_bloc.dart';
import 'package:madebyhands/features/creator/presentation/pages/manage_bank_account_page.dart';
import 'package:madebyhands/init_dependencies.dart';

class AddProductPage extends StatefulWidget {
  final CreatorProfile profile;
  final CreatorProduct? initialProduct;
  const AddProductPage({super.key, required this.profile, this.initialProduct});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();

  /// True once we know this creator has not saved payout details yet. Only
  /// checked when listing a new product; a failed lookup shows nothing.
  bool _payoutDetailsMissing = false;

  // General Controllers
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;

  // Category Selection (Min 1, Max 2)
  final Set<String> _selectedCategories = {};

  // Optional Product Details
  late final TextEditingController _materialsController;
  late final TextEditingController _lengthController;
  late final TextEditingController _widthController;
  late final TextEditingController _heightController;
  String _dimensionUnit = 'cm';
  late final TextEditingController _weightValueController;
  String _weightUnit = 'g';
  late final TextEditingController _shippingController;

  static const _dimensionUnits = ['cm', 'mm'];
  static const _weightUnits = ['g', 'kg'];

  // Set only when an existing product's dimensions/weight were stored as
  // free text (before this structured input existed) and couldn't be parsed
  // back into number + unit — shown as a hint so the creator can re-enter it.
  String? _unparsedDimensionsHint;
  String? _unparsedWeightHint;

  /// Best-effort parse of an existing "12 x 8 x 5 cm" style string, for
  /// prefilling the structured fields when editing a product saved before
  /// this UI existed. Falls back to leaving the fields blank.
  static final _dimensionsPattern = RegExp(
    r'^\s*([\d.]+)\s*[x×X]\s*([\d.]+)\s*[x×X]\s*([\d.]+)\s*(cm|mm)?\s*$',
  );
  static final _weightPattern = RegExp(
    r'^\s*([\d.]+)\s*(kg|kilograms?|g|grams?)?\s*$',
    caseSensitive: false,
  );

  /// Combines the structured fields back into the single string the
  /// backend/schema has always stored, so nothing downstream needs to change.
  String get _composedDimensions {
    final l = _lengthController.text.trim();
    final w = _widthController.text.trim();
    final h = _heightController.text.trim();
    if (l.isEmpty || w.isEmpty || h.isEmpty) return '';
    return '$l x $w x $h $_dimensionUnit';
  }

  String get _composedWeight {
    final v = _weightValueController.text.trim();
    if (v.isEmpty) return '';
    return '$v $_weightUnit';
  }

  // Is it framed? (Only for 'Paintings, Drawing, Fine Art & Traditional Art')
  bool? _isFramed;

  final List<File> _imageFiles = [];
  final List<String> _existingImageUrls = [];

  // Customization
  bool _isCustomizable = false;
  final List<_CustomizationControllers> _customizationList = [];

  @override
  void initState() {
    super.initState();
    final p = widget.initialProduct;
    if (p == null) _checkPayoutDetails();
    _nameController = TextEditingController(text: p?.name);
    _descriptionController = TextEditingController(text: p?.description);
    _priceController = TextEditingController(text: p?.price.round().toString());
    _stockController = TextEditingController(text: p?.stock.toString());
    _materialsController = TextEditingController(text: p?.materials);
    _shippingController = TextEditingController(text: p?.shippingInfo);

    final dimensionsMatch = p == null ? null : _dimensionsPattern.firstMatch(p.dimensions);
    _lengthController = TextEditingController(text: dimensionsMatch?.group(1) ?? '');
    _widthController = TextEditingController(text: dimensionsMatch?.group(2) ?? '');
    _heightController = TextEditingController(text: dimensionsMatch?.group(3) ?? '');
    final parsedDimensionUnit = dimensionsMatch?.group(4)?.toLowerCase();
    if (parsedDimensionUnit != null && _dimensionUnits.contains(parsedDimensionUnit)) {
      _dimensionUnit = parsedDimensionUnit;
    }
    if (p != null && p.dimensions.isNotEmpty && dimensionsMatch == null) {
      _unparsedDimensionsHint = p.dimensions;
    }

    final weightMatch = p == null ? null : _weightPattern.firstMatch(p.weight.trim());
    _weightValueController = TextEditingController(text: weightMatch?.group(1) ?? '');
    final parsedWeightUnit = weightMatch?.group(2)?.toLowerCase();
    if (parsedWeightUnit != null) {
      _weightUnit = parsedWeightUnit.startsWith('k') ? 'kg' : 'g';
    }
    if (p != null && p.weight.isNotEmpty && weightMatch == null) {
      _unparsedWeightHint = p.weight;
    }
    _isFramed = p?.isFramed;

    if (p != null) {
      _existingImageUrls.addAll(p.images);
      _isCustomizable = p.isCustomizable;

      if (p.categories.isNotEmpty) {
        _selectedCategories.addAll(p.categories);
      } else if (p.category.isNotEmpty) {
        _selectedCategories.addAll(
          p.category.split(', ').map((e) => e.trim()).where((e) => e.isNotEmpty),
        );
      }

      for (var c in p.customizations) {
        final controllers = _CustomizationControllers();
        controllers.nameController.text = c.name;
        controllers.descController.text = c.description;
        controllers.priceController.text = c.additionalPrice.round().toString();
        controllers.isMultipleSelection = c.isMultipleSelection;
        controllers.existingImageUrls.addAll(c.images);
        if (c.options.isNotEmpty) {
          controllers.options.clear();
          for (var opt in c.options) {
            controllers.options.add(TextEditingController(text: opt));
          }
        }
        _customizationList.add(controllers);
      }
    }
    // Always refetch (not just when empty) so a category the admin added or
    // deleted since the last time this bloc loaded is reflected here too —
    // the admin categories collection is the single source of truth.
    context.read<AdminBloc>().add(AdminCategoriesRequested());
  }

  bool get _isEditing => widget.initialProduct != null;

  // Admin's categories collection is the single source of truth — no
  // hardcoded fallback list here. A product's already-selected categories
  // (e.g. one an admin has since deleted) stay selectable so editing an
  // existing listing doesn't silently drop them.
  List<String> get _categoryOptions {
    final options = [...context.read<AdminBloc>().state.categories];
    for (final selected in _selectedCategories) {
      if (!options.contains(selected)) options.add(selected);
    }
    return options;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _materialsController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _weightValueController.dispose();
    _shippingController.dispose();
    for (var c in _customizationList) {
      c.dispose();
    }
    super.dispose();
  }

  void _addCustomizationBlock() {
    if (_customizationList.length < 5) {
      setState(() {
        _customizationList.add(_CustomizationControllers());
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 5 customization categories allowed.'),
        ),
      );
    }
  }

  void _removeCustomizationBlock(int index) {
    setState(() {
      _customizationList[index].dispose();
      _customizationList.removeAt(index);
    });
  }

  static const _minProductPhotos = 2;
  static const _maxProductPhotos = 6;

  int get _totalProductPhotos => _existingImageUrls.length + _imageFiles.length;

  Future<void> _pickImages() async {
    final remaining = _maxProductPhotos - _totalProductPhotos;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum $_maxProductPhotos photos allowed.')),
      );
      return;
    }
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(
      imageQuality: kImageQuality,
      maxWidth: kProductImageMaxSide,
      maxHeight: kProductImageMaxSide,
    );
    if (pickedFiles.isEmpty) return;
    final accepted = pickedFiles.take(remaining).toList();
    setState(() {
      _imageFiles.addAll(accepted.map((f) => File(f.path)));
    });
    if (pickedFiles.length > accepted.length && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Only added $remaining of ${pickedFiles.length} photos — maximum $_maxProductPhotos per product.',
          ),
        ),
      );
    }
  }

  /// A comparable fingerprint of the customization blocks, used to detect
  /// edits.
  static String _customizationSignature(
    bool isCustomizable,
    Iterable<(String, String, num, bool, List<String>, int)> blocks,
  ) => isCustomizable ? blocks.map((b) => b.toString()).join('|') : '';

  void _submit() {
    FocusScope.of(context).unfocus();
    if (_totalProductPhotos < _minProductPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least $_minProductPhotos product photos.')),
      );
      return;
    }
    if (_totalProductPhotos > _maxProductPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Remove some photos — maximum $_maxProductPhotos allowed.')),
      );
      return;
    }
    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one category.')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final categories = _selectedCategories.toList();
    final customizations = <CustomizationInput>[
      if (_isCustomizable)
        for (final c in _customizationList)
          CustomizationInput(
            name: c.nameController.text.trim(),
            description: c.descController.text.trim(),
            additionalPrice: double.tryParse(c.priceController.text) ?? 0,
            imageFiles: List.of(c.imageFiles),
            existingImageUrls: List.of(c.existingImageUrls),
            isMultipleSelection: c.isMultipleSelection,
            options: c.options
                .map((option) => option.text.trim())
                .where((option) => option.isNotEmpty)
                .toList(),
          ),
    ];
    final isFramed = _selectedCategories.contains(kPaintingCategory) ? _isFramed : null;
    final price = double.parse(_priceController.text);
    final stock = int.parse(_stockController.text);

    final initial = widget.initialProduct;
    if (initial != null) {
      final before = _customizationSignature(
        initial.isCustomizable,
        initial.customizations.map(
          (c) => (c.name, c.description, c.additionalPrice.round(), c.isMultipleSelection, c.options, c.images.length),
        ),
      );
      final after = _customizationSignature(
        _isCustomizable,
        customizations.map(
          (c) => (
            c.name,
            c.description,
            c.additionalPrice.round(),
            c.isMultipleSelection,
            c.options,
            c.existingImageUrls.length + c.imageFiles.length,
          ),
        ),
      );
      final hasChanges =
          initial.name != _nameController.text.trim() ||
          initial.description != _descriptionController.text.trim() ||
          !listEquals(initial.categories, categories) ||
          initial.price.round() != price.round() ||
          initial.stock != stock ||
          initial.materials != _materialsController.text.trim() ||
          initial.dimensions != _composedDimensions ||
          initial.weight != _composedWeight ||
          initial.shippingInfo != _shippingController.text.trim() ||
          initial.isCustomizable != _isCustomizable ||
          initial.isFramed != isFramed ||
          before != after ||
          _imageFiles.isNotEmpty ||
          !listEquals(initial.images, _existingImageUrls);
      if (!hasChanges) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No changes to save.')),
        );
        return;
      }
    }

    context.read<CreatorBloc>().add(
      CreatorSaveProduct(
        productId: initial?.id,
        input: ProductInput(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          newImageFiles: List.of(_imageFiles),
          existingImageUrls: List.of(_existingImageUrls),
          categories: categories,
          price: price.roundToDouble(),
          stock: stock,
          materials: _materialsController.text.trim(),
          dimensions: _composedDimensions,
          weight: _composedWeight,
          shippingInfo: _shippingController.text.trim(),
          creatorUid: widget.profile.uid,
          creatorName: widget.profile.businessName.trim().isNotEmpty
              ? widget.profile.businessName.trim()
              : widget.profile.name,
          isCustomizable: _isCustomizable,
          isFramed: isFramed,
          customizations: customizations,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BuyerBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            _isEditing ? 'Edit product' : 'Add new product',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF8B261D),
            ),
          ),
          iconTheme: const IconThemeData(color: Color(0xFF8B261D)),
        ),
      body: BlocConsumer<CreatorBloc, CreatorState>(
        listenWhen: (previous, current) =>
            previous.actionId != current.actionId &&
            current.action == CreatorAction.saveProduct &&
            current.actionStatus != CreatorActionStatus.inProgress,
        listener: (context, state) {
          final success = state.actionStatus == CreatorActionStatus.success;
          final payoutReminder = success && _payoutDetailsMissing && !_isEditing
              ? ' Add your payout details (Profile → Payout details) to receive payouts.'
              : '';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: payoutReminder.isEmpty
                  ? const Duration(seconds: 4)
                  : const Duration(seconds: 8),
              content: Text(
                (state.actionMessage ??
                        (success ? 'Product saved.' : 'Could not save the product.')) +
                    payoutReminder,
              ),
              backgroundColor: success ? null : Colors.red.shade700,
            ),
          );
          if (success) Navigator.pop(context);
        },
        buildWhen: (previous, current) =>
            previous.isRunning(CreatorAction.saveProduct) !=
            current.isRunning(CreatorAction.saveProduct),
        builder: (context, state) {
          final saving = state.isRunning(CreatorAction.saveProduct);
          return Stack(
            children: [
              AbsorbPointer(
                absorbing: saving,
                child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24.0,
              24.0,
              24.0,
              MediaQuery.of(context).viewInsets.bottom + 24.0,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_payoutDetailsMissing) ...[
                    _buildPayoutWarning(),
                    const SizedBox(height: 24),
                  ],
                  _buildSectionTitle('Product photos * (2–6)'),
                  const SizedBox(height: 10),
                  _buildProductImagePicker(),
                  const SizedBox(height: 6),
                  Text(
                    '$_totalProductPhotos of $_maxProductPhotos photos added — minimum $_minProductPhotos required.',
                    style: const TextStyle(fontSize: 12, color: AppColors.mutedText),
                  ),
                  const SizedBox(height: 30),

                  _buildSectionTitle('General Information'),
                  const SizedBox(height: 15),
                  _buildGeneralInfoFields(),
                  const SizedBox(height: 30),

                  _buildCustomizationToggle(),
                  if (_isCustomizable) ...[
                    const SizedBox(height: 20),
                    _buildCustomizationSection(),
                  ],

                  const SizedBox(height: 30),
                  _buildSectionTitle('Product Details *'),
                  const SizedBox(height: 15),
                  _buildProductDetailsFields(),

                  const SizedBox(height: 50),
                  FilledButton(
                    onPressed: saving ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF8B261D),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_isEditing ? 'Save & send for review' : 'Submit for review'),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
                ),
              ),
              if (saving)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x66FFFFFF),
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xFF8B261D)),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ),
    );
  }

  Future<void> _checkPayoutDetails() async {
    final result = await serviceLocator<CreatorRepository>()
        .getCreatorBankAccount(widget.profile.uid);
    if (!mounted) return;
    result.fold(
      (_) {},
      (account) => setState(() => _payoutDetailsMissing = account == null),
    );
  }

  Widget _buildPayoutWarning() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.account_balance_outlined, color: Colors.orange, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Add your payout details to get paid. You can list this '
                  'product now, but we cannot send you earnings from your '
                  'sales until your bank account or UPI details are added.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ManageBankAccountPage(profile: widget.profile),
                  ),
                );
                if (mounted) _checkPayoutDetails();
              },
              child: const Text('Add payout details'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF8B261D),
      ),
    );
  }

  Widget _buildProductImagePicker() {
    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (_totalProductPhotos < _maxProductPhotos) _buildAddImageButton(_pickImages),
          ..._existingImageUrls.asMap().entries.map(
                (e) => _buildExistingImageItem(
                  e.key,
                  e.value,
                  (idx) => setState(() => _existingImageUrls.removeAt(idx)),
                ),
              ),
          ..._imageFiles.asMap().entries.map(
                (e) => _buildImageItem(
                  e.key,
                  e.value,
                  (idx) => setState(() => _imageFiles.removeAt(idx)),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildExistingImageItem(
    int index,
    String url,
    Function(int) onRemove,
  ) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: GestureDetector(
            onTap: () => _showProductImagePreviewDialog(
              context,
              imageUrl: url,
              title: 'Product Photo ${index + 1}',
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.network(
                url,
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                cacheWidth: 360,
                errorBuilder: (_, _, _) => const SizedBox(
                  width: 120,
                  height: 120,
                  child: Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 5,
          right: 5,
          child: GestureDetector(
            onTap: () => onRemove(index),
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

  Widget _buildAddImageButton(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppColors.outline),
        ),
        child: const Icon(
          Icons.add_a_photo_outlined,
          color: AppColors.mutedText,
        ),
      ),
    );
  }

  Widget _buildImageItem(int index, File file, Function(int) onRemove) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: GestureDetector(
            onTap: () => _showProductImagePreviewDialog(
              context,
              imageFile: file,
              title: 'Product Photo ${index + 1}',
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: kIsWeb
                  ? Image.network(
                      file.path,
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => const Icon(
                        Icons.broken_image,
                        color: Colors.grey,
                      ),
                    )
                  : Image.file(
                      file,
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => const Icon(
                        Icons.broken_image,
                        color: Colors.grey,
                      ),
                    ),
            ),
          ),
        ),
        Positioned(
          top: 5,
          right: 5,
          child: GestureDetector(
            onTap: () => onRemove(index),
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

  Widget _buildGeneralInfoFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Product Name *',
            prefixIcon: Icon(Icons.shopping_bag_outlined),
          ),
          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 15),
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: 'Description *',
            alignLabelWithHint: true,
          ),
          maxLines: 4,
          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Price (₹) *',
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(7),
                ],
                validator: (v) {
                  final price = int.tryParse(v ?? '');
                  if (price == null) return 'Required';
                  if (price < 1) return 'Must be at least ₹1';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: TextFormField(
                controller: _stockController,
                decoration: const InputDecoration(
                  labelText: 'Stock *',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildCategorySelectionSection(),
      ],
    );
  }

  Widget _buildCategorySelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Category *',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_selectedCategories.length}/2 Selected',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Select 1 or 2 categories for your product (Maximum 2).',
          style: TextStyle(fontSize: 12, color: AppColors.mutedText),
        ),
        const SizedBox(height: 12),

        if (_selectedCategories.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedCategories.map((cat) {
              return Chip(
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                side: const BorderSide(color: AppColors.primary),
                label: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: Text(
                    cat,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                deleteIcon:
                    const Icon(Icons.cancel, size: 18, color: AppColors.primary),
                onDeleted: () {
                  setState(() {
                    _selectedCategories.remove(cat);
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],

        InkWell(
          onTap: _showCategorySelectionMenu,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outline),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _selectedCategories.isEmpty
                        ? 'Tap to select categories'
                        : 'Choose/change categories...',
                    style: const TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 14,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_drop_down_circle_outlined,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showCategorySelectionMenu() {
    final categoryOptions = _categoryOptions;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              height: MediaQuery.of(context).size.height * 0.75,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Select categories *',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_selectedCategories.length}/2 selected',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.mutedText,
                            ),
                          ),
                        ],
                      ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(modalContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(),
                  Expanded(
                    child: ListView.separated(
                      itemCount: categoryOptions.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final category = categoryOptions[index];
                        final isSelected =
                            _selectedCategories.contains(category);

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          title: Text(
                            category,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.text,
                              fontSize: 14,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check_circle,
                                  color: AppColors.primary,
                                )
                              : const Icon(
                                  Icons.radio_button_unchecked,
                                  color: AppColors.mutedText,
                                ),
                          onTap: () {
                            if (isSelected) {
                              setState(() {
                                _selectedCategories.remove(category);
                              });
                              setModalState(() {});
                            } else {
                              if (_selectedCategories.length >= 2) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Maximum 2 categories allowed per product. Deselect a category first.',
                                    ),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              } else {
                                setState(() {
                                  _selectedCategories.add(category);
                                });
                                setModalState(() {});
                              }
                            }
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(modalContext),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCustomizationToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Product Customization *'),
        const SizedBox(height: 5),
        const Text(
          'Is this product customizable?',
          style: TextStyle(fontSize: 14, color: AppColors.mutedText),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ChoiceChip(
                label: 'No',
                isSelected: !_isCustomizable,
                onSelected: (v) => setState(() {
                  _isCustomizable = false;
                  for (final block in _customizationList) {
                    block.dispose();
                  }
                  _customizationList.clear();
                }),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _ChoiceChip(
                label: 'Yes',
                isSelected: _isCustomizable,
                onSelected: (v) => setState(() {
                  _isCustomizable = true;
                  if (_customizationList.isEmpty) _addCustomizationBlock();
                }),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCustomizationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Define Customizations (Max 5)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _customizationList.length,
          separatorBuilder: (_, _) => const SizedBox(height: 15),
          itemBuilder: (context, index) {
            return _CustomizationBlock(
              controllers: _customizationList[index],
              onDelete: () => _removeCustomizationBlock(index),
              showDelete: true,
            );
          },
        ),
        const SizedBox(height: 15),
        if (_customizationList.length < 5)
          OutlinedButton.icon(
            onPressed: _addCustomizationBlock,
            icon: const Icon(Icons.add),
            label: const Text('Add More Customizations'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(45),
            ),
          ),
      ],
    );
  }

  Widget _buildProductDetailsFields() {
    final showIsFramedOption = _selectedCategories.contains(kPaintingCategory);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _materialsController,
          decoration: const InputDecoration(
            labelText: 'Materials *',
            prefixIcon: Icon(Icons.layers_outlined),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
        const SizedBox(height: 15),
        const Text(
          'Dimensions (L × W × H) *',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _lengthController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                decoration: const InputDecoration(
                  hintText: 'L',
                  prefixIcon: Icon(Icons.straighten),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Req.' : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _widthController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                decoration: const InputDecoration(hintText: 'W'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Req.' : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _heightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                decoration: const InputDecoration(hintText: 'H'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Req.' : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _dimensionUnit,
                items: _dimensionUnits
                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _dimensionUnit = v);
                },
                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8)),
              ),
            ),
          ],
        ),
        if (_unparsedDimensionsHint != null) ...[
          const SizedBox(height: 4),
          Text(
            'Previously entered: "$_unparsedDimensionsHint" — please re-enter above.',
            style: const TextStyle(fontSize: 11, color: AppColors.mutedText),
          ),
        ],
        const SizedBox(height: 15),
        const Text('Weight', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _weightValueController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                decoration: const InputDecoration(
                  hintText: 'e.g. 250',
                  prefixIcon: Icon(Icons.monitor_weight_outlined),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                initialValue: _weightUnit,
                items: _weightUnits
                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _weightUnit = v);
                },
                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8)),
              ),
            ),
          ],
        ),
        if (_unparsedWeightHint != null) ...[
          const SizedBox(height: 4),
          Text(
            'Previously entered: "$_unparsedWeightHint" — please re-enter above.',
            style: const TextStyle(fontSize: 11, color: AppColors.mutedText),
          ),
        ],
        const SizedBox(height: 15),
        TextFormField(
          controller: _shippingController,
          decoration: const InputDecoration(
            labelText: 'Estimated shipping timeline *',
            hintText: 'e.g. Dispatches in 2–3 working days',
            prefixIcon: Icon(Icons.schedule_outlined),
          ),
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Add an estimated shipping timeline'
              : null,
        ),
        if (showIsFramedOption) ...[
          const SizedBox(height: 20),
          const Text(
            'Is it framed?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Select whether this artwork comes framed.',
            style: TextStyle(fontSize: 12, color: AppColors.mutedText),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ChoiceChip(
                  label: 'No',
                  isSelected: _isFramed == false,
                  onSelected: (v) => setState(() => _isFramed = false),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _ChoiceChip(
                  label: 'Yes',
                  isSelected: _isFramed == true,
                  onSelected: (v) => setState(() => _isFramed = true),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final ValueChanged<bool> onSelected;

  const _ChoiceChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onSelected(true),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF8B261D) : const Color(0xFFFAF6EE),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF8B261D)
                : const Color(0xFF8B261D).withValues(alpha: 0.3),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.text,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomizationBlock extends StatefulWidget {
  final _CustomizationControllers controllers;
  final VoidCallback onDelete;
  final bool showDelete;

  const _CustomizationBlock({
    required this.controllers,
    required this.onDelete,
    required this.showDelete,
  });

  @override
  State<_CustomizationBlock> createState() => _CustomizationBlockState();
}

class _CustomizationBlockState extends State<_CustomizationBlock> {
  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(
      imageQuality: kImageQuality,
      maxWidth: kProductImageMaxSide,
      maxHeight: kProductImageMaxSide,
    );
    if (pickedFiles.isNotEmpty) {
      setState(() {
        widget.controllers.imageFiles.addAll(
          pickedFiles
              .take(4 - widget.controllers.imageFiles.length)
              .map((f) => File(f.path)),
        );
      });
    }
  }

  void _addOption() {
    if (widget.controllers.options.length < 5) {
      setState(() {
        widget.controllers.options.add(TextEditingController());
      });
    }
  }

  void _removeOption(int index) {
    setState(() {
      widget.controllers.options[index].dispose();
      widget.controllers.options.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Customization',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.primary,
                ),
              ),
              if (widget.showDelete)
                IconButton(
                  onPressed: widget.onDelete,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                    size: 20,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: widget.controllers.nameController,
            decoration: const InputDecoration(
              labelText: 'Name *',
              hintText: 'e.g. Colour, Engraving text',
            ),
            validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: widget.controllers.descController,
            decoration:
                const InputDecoration(labelText: 'Short Description *'),
            maxLines: 2,
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: widget.controllers.priceController,
            decoration: const InputDecoration(
              labelText: 'Additional price (₹) *',
              helperText: 'Enter 0 if this option is free.',
              prefixIcon: Icon(Icons.add),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 20),
          const Text(
            'Selection Type',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ChoiceChip(
                  label: 'Pick one',
                  isSelected: !widget.controllers.isMultipleSelection,
                  onSelected: (_) => setState(
                    () => widget.controllers.isMultipleSelection = false,
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _ChoiceChip(
                  label: 'Pick several',
                  isSelected: widget.controllers.isMultipleSelection,
                  onSelected: (_) => setState(
                    () => widget.controllers.isMultipleSelection = true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          const Text(
            'Options buyers can choose from (max 5) *',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Buyers pick from these — they can\'t type their own, e.g. A4, A5, Canvas.',
            style: TextStyle(fontSize: 12, color: AppColors.mutedText),
          ),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.controllers.options.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: widget.controllers.options[index],
                      validator: (value) {
                        final anyFilled = widget.controllers.options.any(
                          (option) => option.text.trim().isNotEmpty,
                        );
                        return index == 0 && !anyFilled ? 'Add at least one option' : null;
                      },
                      decoration: InputDecoration(
                        labelText: 'Option ${index + 1}',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: widget.controllers.options.length == 1
                        ? null
                        : () => _removeOption(index),
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                  ),
                ],
              );
            },
          ),
          if (widget.controllers.options.length < 5)
            TextButton.icon(
              onPressed: _addOption,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Option'),
            ),
          const SizedBox(height: 15),
          const Text(
            'Category Images (Max 4, Optional)',
            style: TextStyle(fontSize: 12, color: AppColors.mutedText),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 80,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                if (widget.controllers.imageFiles.length +
                        widget.controllers.existingImageUrls.length <
                    4)
                  GestureDetector(
                    onTap: _pickImages,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.outline),
                      ),
                      child: const Icon(
                        Icons.add_a_photo_outlined,
                        size: 20,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ),
                ...widget.controllers.existingImageUrls
                    .asMap()
                    .entries
                    .map((e) => _buildExistingMiniImage(e.key, e.value)),
                ...widget.controllers.imageFiles
                    .asMap()
                    .entries
                    .map((e) => _buildMiniImage(e.key, e.value)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExistingMiniImage(int index, String url) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: GestureDetector(
            onTap: () => _showProductImagePreviewDialog(
              context,
              imageUrl: url,
              title: 'Customization Image ${index + 1}',
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                url,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                cacheWidth: 240,
                errorBuilder: (_, _, _) => const SizedBox(
                  width: 80,
                  height: 80,
                  child: Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: () => setState(
              () => widget.controllers.existingImageUrls.removeAt(index),
            ),
            child: const CircleAvatar(
              radius: 10,
              backgroundColor: Colors.red,
              child: Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniImage(int index, File file) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: GestureDetector(
            onTap: () => _showProductImagePreviewDialog(
              context,
              imageFile: file,
              title: 'Customization Image ${index + 1}',
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: kIsWeb
                  ? Image.network(
                      file.path,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => const Icon(
                        Icons.broken_image,
                        color: Colors.grey,
                      ),
                    )
                  : Image.file(
                      file,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => const Icon(
                        Icons.broken_image,
                        color: Colors.grey,
                      ),
                    ),
            ),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: () => setState(
              () => widget.controllers.imageFiles.removeAt(index),
            ),
            child: const CircleAvatar(
              radius: 10,
              backgroundColor: Colors.red,
              child: Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _CustomizationControllers {
  final nameController = TextEditingController();
  final descController = TextEditingController();
  final priceController = TextEditingController();
  bool isMultipleSelection = false;
  final List<TextEditingController> options = [];
  final List<File> imageFiles = [];
  final List<String> existingImageUrls = [];

  _CustomizationControllers() {
    options.add(TextEditingController());
  }

  void dispose() {
    nameController.dispose();
    descController.dispose();
    priceController.dispose();
    for (var o in options) {
      o.dispose();
    }
  }
}

void _showProductImagePreviewDialog(
  BuildContext context, {
  String? imageUrl,
  File? imageFile,
  required String title,
}) {
  showDialog(
    context: context,
    builder: (dialogCtx) {
      return Dialog(
        backgroundColor: Colors.black.withOpacity(0.9),
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
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image,
                            color: Colors.white,
                            size: 64,
                          ),
                        )
                      : imageFile != null
                          ? (kIsWeb
                              ? Image.network(
                                  imageFile.path,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.broken_image,
                                    color: Colors.white,
                                    size: 64,
                                  ),
                                )
                              : Image.file(
                                  imageFile,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.broken_image,
                                    color: Colors.white,
                                    size: 64,
                                  ),
                                ))
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
