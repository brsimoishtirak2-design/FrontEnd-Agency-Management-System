import 'package:flutter/material.dart';

/// AppBar with a built-in search-mode toggle.
///
/// Two states:
///   - **Default**: standard title + actions; a search-icon trailing
///     action enters search mode.
///   - **Search**: back-arrow leading, inline TextField in the title
///     slot, optional clear-X action when text is non-empty, and a
///     `search_off` action that also exits search mode.
///
/// Two modes for driving the field text:
///   - **Uncontrolled** (default — `query` is null): the widget owns
///     its TextEditingController. `initialQuery` seeds it once. Useful
///     for ad-hoc usage where no external state is involved.
///   - **Controlled** (`query` non-null): the parent owns the truth.
///     The widget syncs its controller text from `widget.query` on
///     every build via didUpdateWidget. If `query` is non-empty when
///     it arrives (initial build OR external change), the widget
///     auto-enters search mode. Externally clearing `query` to ''
///     leaves the bar in search mode (with an empty field) so the
///     user can keep typing or tap exit explicitly.
///
/// In both modes the caller wires `onChanged` (and optionally
/// `onSubmitted`) to receive user input; debouncing is the caller's
/// concern.
class SearchAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final List<Widget>? actions;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback? onSubmitted;
  final String initialQuery;

  /// When non-null, the widget operates in controlled mode and the
  /// internal controller text is kept in sync with this value.
  final String? query;

  const SearchAppBar({
    super.key,
    required this.title,
    this.showBackButton = true,
    this.actions,
    this.hintText = 'Search...',
    required this.onChanged,
    this.onSubmitted,
    this.initialQuery = '',
    this.query,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<SearchAppBar> createState() => _SearchAppBarState();
}

class _SearchAppBarState extends State<SearchAppBar> {
  late bool _isSearching;
  late final TextEditingController _controller;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // In controlled mode prefer widget.query; otherwise fall back to
    // the uncontrolled initialQuery seed.
    final initial = widget.query ?? widget.initialQuery;
    _controller = TextEditingController(text: initial);
    _isSearching = initial.isNotEmpty;
    _controller.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(SearchAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controlled = widget.query;
    if (controlled == null) return;
    if (controlled == _controller.text) return;
    // Sync controller to parent's truth and place cursor at end so
    // continued typing flows naturally.
    _controller.text = controlled;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
    // If query arrives non-empty while we were not in search mode
    // (e.g., returning to a tab with a previously-applied filter),
    // auto-enter search. Don't auto-EXIT when controlled clears to
    // '' — leave the user in search mode so they can keep typing or
    // tap exit explicitly.
    if (controlled.isNotEmpty && !_isSearching) {
      _isSearching = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _enterSearch() {
    setState(() => _isSearching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _exitSearch() {
    final hadQuery = _controller.text.isNotEmpty;
    _controller.clear();
    _focus.unfocus();
    if (hadQuery) widget.onChanged('');
    setState(() => _isSearching = false);
  }

  void _clearQuery() {
    if (_controller.text.isEmpty) return;
    _controller.clear();
    widget.onChanged('');
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    if (_isSearching) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Close search',
          onPressed: _exitSearch,
        ),
        title: TextField(
          controller: _controller,
          focusNode: _focus,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted == null
              ? null
              : (_) => widget.onSubmitted!(),
          decoration: InputDecoration(
            hintText: widget.hintText,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            isDense: true,
            filled: false,
          ),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Clear',
              onPressed: _clearQuery,
            ),
          IconButton(
            icon: const Icon(Icons.search_off),
            tooltip: 'Exit search',
            onPressed: _exitSearch,
          ),
        ],
      );
    }

    return AppBar(
      automaticallyImplyLeading: widget.showBackButton,
      title: Text(widget.title),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Search',
          onPressed: _enterSearch,
        ),
        ...?widget.actions,
      ],
    );
  }
}
