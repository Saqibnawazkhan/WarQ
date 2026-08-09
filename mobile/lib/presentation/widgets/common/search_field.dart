import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/debouncer.dart';

/// Debounced search input used by every list screen.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.onChanged,
    this.hintText = 'Search',
    this.initialValue,
    this.autofocus = false,
    this.trailing,
    this.debounce = AppConstants.searchDebounce,
  });

  final ValueChanged<String> onChanged;
  final String hintText;
  final String? initialValue;
  final bool autofocus;
  final Widget? trailing;
  final Duration debounce;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);
  late final Debouncer _debouncer = Debouncer(delay: widget.debounce);
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = _controller.text.isNotEmpty;
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleChanged(String value) {
    final bool hasText = value.isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
    _debouncer.run(() => widget.onChanged(value));
  }

  void _clear() {
    _controller.clear();
    setState(() => _hasText = false);
    _debouncer.cancel();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      autofocus: widget.autofocus,
      textInputAction: TextInputAction.search,
      onChanged: _handleChanged,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        suffixIcon: _hasText
            ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: _clear,
                tooltip: 'Clear search',
              )
            : widget.trailing,
      ),
    );
  }
}

/// Horizontal row of selectable filter chips.
class FilterChipsRow<T> extends StatelessWidget {
  const FilterChipsRow({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    this.padding = EdgeInsets.zero,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final ValueChanged<T> onSelected;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final T value = values[index];
          return ChoiceChip(
            label: Text(labelOf(value)),
            selected: value == selected,
            onSelected: (_) => onSelected(value),
            showCheckmark: false,
          );
        },
      ),
    );
  }
}
