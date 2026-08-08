import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pad_providers.dart';

class PadSearchBarWidget extends ConsumerStatefulWidget {
  const PadSearchBarWidget({super.key});

  @override
  ConsumerState<PadSearchBarWidget> createState() => _PadSearchBarWidgetState();
}

class _PadSearchBarWidgetState extends ConsumerState<PadSearchBarWidget> {
  bool _isSearching = false;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _closeSearch() {
    _controller.clear();
    ref.read(searchQueryProvider.notifier).state = '';
    setState(() {
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    var query = ref.watch(searchQueryProvider);
    var isSearching = _isSearching || query.isNotEmpty;

    if (!isSearching) {
      return IconButton(
        icon: const Icon(
          Icons.search_rounded,
          color: Colors.cyanAccent,
          size: 20,
        ),
        tooltip: 'Buscar pads (Ctrl+F)',
        onPressed: () {
          setState(() {
            _isSearching = true;
          });
          _focusNode.requestFocus();
        },
      );
    }

    final maxWidth = MediaQuery.sizeOf(context).width < 400 ? 140.0 : 200.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: maxWidth,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF161A26),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: Colors.cyanAccent.withValues(alpha: 0.7),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.cyanAccent.withValues(alpha: 0.2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.search_rounded,
                color: Colors.cyanAccent,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Buscar sample...',
                    hintStyle: TextStyle(color: Colors.white38, fontSize: 11),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (val) {
                    ref.read(searchQueryProvider.notifier).state = val;
                  },
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: _closeSearch,
                child: const Padding(
                  padding: EdgeInsets.all(2.0),
                  child: Icon(
                    Icons.close_rounded,
                    color: Colors.white60,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
