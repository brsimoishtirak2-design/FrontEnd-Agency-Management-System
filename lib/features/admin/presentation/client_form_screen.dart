import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/agency_client.dart';
import '../../../shared/widgets/app_section_label.dart';
import '../data/admin_clients_providers.dart';

/// Dual-mode form for creating OR editing a client.
///
/// Pass `initialClient` to enter edit mode (controllers pre-filled,
/// AppBar shows "Edit Client", submit button shows "Save Changes",
/// submit calls updateClient instead of createClient).
///
/// Fields:
///   - Name (required)
///   - Company name, Industry (optional)
///   - Website (optional, validated as full http/https URL)
///   - Notes (optional)
///   - Social media — curated channels (Instagram, Facebook, TikTok)
class ClientFormScreen extends ConsumerStatefulWidget {
  final AgencyClient? initialClient;

  const ClientFormScreen({super.key, this.initialClient});

  @override
  ConsumerState<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends ConsumerState<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _industryController = TextEditingController();
  final _websiteController = TextEditingController();
  final _notesController = TextEditingController();
  final _instagramController = TextEditingController();
  final _facebookController = TextEditingController();
  final _tiktokController = TextEditingController();

  bool _isSubmitting = false;
  /// Local file path of a freshly picked logo waiting to be uploaded
  /// after the client save succeeds. Null when the user hasn't picked
  /// a new image (the existing logo URL on `widget.initialClient.logo`
  /// is what's shown in that case).
  String? _pickedLogoPath;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));

    final initial = widget.initialClient;
    if (initial != null) {
      _nameController.text = initial.name;
      _companyNameController.text = initial.companyName ?? '';
      _industryController.text = initial.industry ?? '';
      _websiteController.text = initial.website ?? '';
      _notesController.text = initial.notes ?? '';
      _instagramController.text = initial.instagramUrl ?? '';
      _facebookController.text = initial.facebookUrl ?? '';
      _tiktokController.text = initial.tiktokUrl ?? '';
    }
  }

  bool get _isEditing => widget.initialClient != null;

  @override
  void dispose() {
    _nameController.dispose();
    _companyNameController.dispose();
    _industryController.dispose();
    _websiteController.dispose();
    _notesController.dispose();
    _instagramController.dispose();
    _facebookController.dispose();
    _tiktokController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (_isSubmitting) return false;
    if (_nameController.text.trim().isEmpty) return false;
    return true;
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;
    setState(() => _pickedLogoPath = path);
  }

  void _clearPickedLogo() {
    setState(() => _pickedLogoPath = null);
  }

  String? _validateWebsite(String? v) {
    final text = v?.trim() ?? '';
    if (text.isEmpty) return null;
    if (text.length > 255) return 'Max 255 characters.';
    final uri = Uri.tryParse(text);
    if (uri == null ||
        !uri.hasScheme ||
        !uri.isAbsolute ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return 'Must be a full URL (https://...)';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    try {
      // Build social_media map — only non-empty channels.
      final social = <String, dynamic>{};
      final ig = _instagramController.text.trim();
      final fb = _facebookController.text.trim();
      final tt = _tiktokController.text.trim();
      if (ig.isNotEmpty) social['instagram'] = ig;
      if (fb.isNotEmpty) social['facebook'] = fb;
      if (tt.isNotEmpty) social['tiktok'] = tt;
      final socialMedia = social.isEmpty ? null : social;

      String? trimOrNull(TextEditingController c) {
        final t = c.text.trim();
        return t.isEmpty ? null : t;
      }

      final repo = ref.read(adminClientsRepositoryProvider);

      if (_isEditing) {
        final initial = widget.initialClient!;
        // toJsonForUpdate uses the model's status field — preserve current.
        final draft = AgencyClient(
          id: initial.id,
          name: _nameController.text.trim(),
          companyName: trimOrNull(_companyNameController),
          status: initial.status,
          branches: null,
          industry: trimOrNull(_industryController),
          website: trimOrNull(_websiteController),
          socialMedia: socialMedia,
          notes: trimOrNull(_notesController),
        );

        var updated =
            await repo.updateClient(initial.id, draft.toJsonForUpdate());

        // Upload the new logo file (if the user picked one) on top of
        // the just-saved client. Failures here surface as a snackbar
        // but the client save itself stays committed.
        final pickedLogo = _pickedLogoPath;
        if (pickedLogo != null) {
          updated = await repo.uploadClientLogo(
            clientId: updated.id,
            filePath: pickedLogo,
          );
        }

        ref.invalidate(adminClientsListProvider);
        ref.invalidate(adminClientWithBranchesProvider(initial.id));

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Client "${updated.name}" updated.'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );

        context.pop();
      } else {
        // id and status are placeholders — toJsonForCreate strips both.
        final draft = AgencyClient(
          id: 0,
          name: _nameController.text.trim(),
          companyName: trimOrNull(_companyNameController),
          status: 'active',
          branches: null,
          industry: trimOrNull(_industryController),
          website: trimOrNull(_websiteController),
          socialMedia: socialMedia,
          notes: trimOrNull(_notesController),
        );

        var newClient = await repo.createClient(draft);

        // Upload the picked logo (if any) on the freshly created
        // client. We don't roll back the create on logo failure; the
        // user can re-try via Edit.
        final pickedLogo = _pickedLogoPath;
        if (pickedLogo != null) {
          newClient = await repo.uploadClientLogo(
            clientId: newClient.id,
            filePath: pickedLogo,
          );
        }

        ref.invalidate(adminClientsListProvider);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Client "${newClient.name}" created.'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );

        context.pop();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      String displayMessage = e.message;
      if (e.isValidationError && e.validationErrors != null) {
        final firstErrors = e.validationErrors!.entries
            .map((entry) => '${entry.key}: ${entry.value.first}')
            .take(3)
            .join('\n');
        displayMessage = firstErrors;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(displayMessage),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Could not update client: $e'
                : 'Could not create client: $e',
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Client' : 'New Client'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ----- Logo (optional) -----
                Center(
                  child: _LogoPicker(
                    pickedFilePath: _pickedLogoPath,
                    existingUrl: widget.initialClient?.logo,
                    onPick: _isSubmitting ? null : _pickLogo,
                    onClearPicked:
                        _isSubmitting ? null : _clearPickedLogo,
                  ),
                ),
                const SizedBox(height: 24),

                // ----- Identity -----
                AppSectionLabel('Name *'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [LengthLimitingTextInputFormatter(200)],
                  decoration: const InputDecoration(
                    hintText: 'e.g. Cafe Aroma',
                  ),
                  validator: (v) {
                    final text = v?.trim() ?? '';
                    if (text.isEmpty) return 'Name is required.';
                    if (text.length > 200) return 'Max 200 characters.';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                AppSectionLabel('Company name'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _companyNameController,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [LengthLimitingTextInputFormatter(200)],
                  decoration: const InputDecoration(
                    hintText: 'Optional. Legal entity name.',
                  ),
                ),
                const SizedBox(height: 16),

                AppSectionLabel('Industry'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _industryController,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [LengthLimitingTextInputFormatter(100)],
                  decoration: const InputDecoration(
                    hintText: 'e.g. Restaurants, Retail, Tech',
                  ),
                ),
                const SizedBox(height: 16),

                // ----- Web presence -----
                AppSectionLabel('Website'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _websiteController,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [LengthLimitingTextInputFormatter(255)],
                  decoration: const InputDecoration(
                    hintText: 'https://example.com',
                  ),
                  validator: _validateWebsite,
                ),
                const SizedBox(height: 16),

                AppSectionLabel('Notes'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _notesController,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    hintText: 'Optional. Anything to remember.',
                  ),
                ),
                const SizedBox(height: 16),

                // ----- Social media -----
                AppSectionLabel('Social media (optional)'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _instagramController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: '@handle or full URL',
                    prefixIcon: Icon(Icons.camera_alt_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _facebookController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: 'Page URL or username',
                    prefixIcon: Icon(Icons.thumb_up_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _tiktokController,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    hintText: '@handle or full URL',
                    prefixIcon: Icon(Icons.music_note_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _canSubmit ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(_isEditing ? 'Save Changes' : 'Create Client'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular logo preview + tap-to-pick / change / remove controls.
///
/// Display priority:
///   1. A freshly-picked file (`pickedFilePath`) — shown via FileImage.
///   2. Otherwise the existing `existingUrl` on the client — NetworkImage.
///   3. Otherwise a placeholder (camera icon) inviting the user to add one.
class _LogoPicker extends StatelessWidget {
  final String? pickedFilePath;
  final String? existingUrl;
  final VoidCallback? onPick;
  final VoidCallback? onClearPicked;

  const _LogoPicker({
    required this.pickedFilePath,
    required this.existingUrl,
    required this.onPick,
    required this.onClearPicked,
  });

  @override
  Widget build(BuildContext context) {
    final hasPicked = pickedFilePath != null;
    final hasExisting = existingUrl != null && existingUrl!.isNotEmpty;
    final hasAny = hasPicked || hasExisting;

    Widget avatar;
    if (hasPicked) {
      avatar = CircleAvatar(
        radius: 48,
        backgroundColor: AppTheme.slate100,
        backgroundImage: FileImage(File(pickedFilePath!)),
      );
    } else if (hasExisting) {
      avatar = CircleAvatar(
        radius: 48,
        backgroundColor: AppTheme.slate100,
        backgroundImage: NetworkImage(existingUrl!),
        onBackgroundImageError: (_, _) {},
      );
    } else {
      avatar = Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.slate100,
          border: Border.all(
            color: AppTheme.slate200,
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Icon(
          Icons.add_a_photo_outlined,
          color: AppTheme.slate500,
          size: 28,
        ),
      );
    }

    return Column(
      children: [
        InkWell(
          onTap: onPick,
          customBorder: const CircleBorder(),
          child: avatar,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.image_outlined, size: 16),
              label: Text(hasAny ? 'Change logo' : 'Add logo'),
            ),
            if (hasPicked) ...[
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: onClearPicked,
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Cancel'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.slate500,
                ),
              ),
            ],
          ],
        ),
        Text(
          'Optional · JPG / PNG / WEBP / SVG · max 2 MB',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.slate500,
              ),
        ),
      ],
    );
  }
}

