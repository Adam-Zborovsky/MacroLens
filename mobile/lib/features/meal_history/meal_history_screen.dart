import 'package:flutter/material.dart';
import 'package:flutter_haptic_feedback/flutter_haptic_feedback.dart';
import '../../core/models/case_file.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/api_service.dart';
import '../detective_refinement/detective_overlay.dart';

class MealHistoryScreen extends StatefulWidget {
  final ApiService apiService;
  const MealHistoryScreen({super.key, required this.apiService});

  @override
  State<MealHistoryScreen> createState() => _MealHistoryScreenState();
}

class _MealHistoryScreenState extends State<MealHistoryScreen> {
  List<CaseFile> _caseFiles = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  bool _hasMore = true;

  // Search & filter
  final _searchController = TextEditingController();
  String _searchQuery = '';
  DateTime? _filterDate;
  bool _showSearchBar = false;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() { _page = 1; _hasMore = true; _caseFiles = []; _loading = true; _error = null; });
    }

    try {
      final dateStr = _filterDate?.toIso8601String().split('T')[0];
      final results = await widget.apiService.fetchCaseFiles(
        date:  dateStr,
        query: _searchQuery.isNotEmpty ? _searchQuery : null,
        page:  _page,
      );

      setState(() {
        _caseFiles = reset ? results : [..._caseFiles, ...results];
        _hasMore   = results.length >= 20;
        _loading   = false;
        _loadingMore = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; _loadingMore = false; });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_loadingMore && _hasMore && !_loading) {
      setState(() { _page++; _loadingMore = true; });
      _load();
    }
  }

  void _onSearch(String query) {
    _searchQuery = query;
    _load(reset: true);
  }

  Future<void> _deleteCaseFile(CaseFile cf) async {
    try {
      await widget.apiService.deleteCaseFile(cf.id);
      setState(() => _caseFiles.removeWhere((c) => c.id == cf.id));
      await FlutterHapticFeedback.impact(ImpactFeedbackStyle.medium);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Case File archived.', style: MLTextStyles.dataSmall),
            backgroundColor: MLColors.bgCard,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'UNDO',
              textColor: MLColors.accentCyan,
              onPressed: () => _load(reset: true), // Reload to restore
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ERR_DELETE_FAILED: ${e.toString()}',
                style: MLTextStyles.dataSmall.copyWith(color: MLColors.statusError)),
            backgroundColor: MLColors.bgCard,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MLColors.bgDeep,
      body: SafeArea(
        child: Column(
          children: [
            _ArchiveHeader(
              showSearch:       _showSearchBar,
              filterDate:       _filterDate,
              searchController: _searchController,
              onToggleSearch: () {
                setState(() {
                  _showSearchBar = !_showSearchBar;
                  if (!_showSearchBar) {
                    _searchController.clear();
                    _searchQuery = '';
                    _load(reset: true);
                  }
                });
              },
              onSearch:   _onSearch,
              onDateFilter: (date) {
                setState(() => _filterDate = date);
                _load(reset: true);
              },
              onClearDate: () {
                setState(() => _filterDate = null);
                _load(reset: true);
              },
            ),
            Expanded(
              child: _loading
                  ? const _LoadingState()
                  : _error != null
                      ? _ErrorState(error: _error!, onRetry: () => _load(reset: true))
                      : _caseFiles.isEmpty
                          ? const _EmptyState()
                          : RefreshIndicator(
                              color: MLColors.accentCyan,
                              backgroundColor: MLColors.bgCard,
                              onRefresh: () => _load(reset: true),
                              child: ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.fromLTRB(
                                    MLSpacing.md, MLSpacing.sm, MLSpacing.md, 80),
                                itemCount: _caseFiles.length + (_loadingMore ? 1 : 0),
                                itemBuilder: (_, i) {
                                  if (i == _caseFiles.length) {
                                    return const Padding(
                                      padding: EdgeInsets.all(MLSpacing.lg),
                                      child: Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2, color: MLColors.accentCyan),
                                        ),
                                      ),
                                    );
                                  }
                                  return _CaseFileTile(
                                    caseFile:  _caseFiles[i],
                                    onTap:     () => _openCaseFile(_caseFiles[i]),
                                    onDelete:  () => _deleteCaseFile(_caseFiles[i]),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCaseFile(CaseFile cf) async {
    await FlutterHapticFeedback.impact(ImpactFeedbackStyle.light);
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DetectiveOverlay(
        caseFileJson: cf.toJson(),
        apiService: widget.apiService,
      ),
    );
    _load(reset: true);
  }
}

// ─── Header with search + date filter ────────────────────────────────────────

class _ArchiveHeader extends StatelessWidget {
  final bool showSearch;
  final DateTime? filterDate;
  final TextEditingController searchController;
  final VoidCallback onToggleSearch;
  final ValueChanged<String> onSearch;
  final ValueChanged<DateTime> onDateFilter;
  final VoidCallback onClearDate;

  const _ArchiveHeader({
    required this.showSearch,
    required this.filterDate,
    required this.searchController,
    required this.onToggleSearch,
    required this.onSearch,
    required this.onDateFilter,
    required this.onClearDate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(MLSpacing.md, MLSpacing.md, MLSpacing.md, 0),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: MLColors.border)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CASE FILE ARCHIVE', style: MLTextStyles.labelCaps),
                    if (filterDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: GestureDetector(
                          onTap: onClearDate,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${filterDate!.day.toString().padLeft(2, '0')}.${filterDate!.month.toString().padLeft(2, '0')}.${filterDate!.year}',
                                style: MLTextStyles.dataSmall.copyWith(color: MLColors.accentCyan),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.close, size: 12, color: MLColors.accentCyan),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _IconButton(
                icon: showSearch ? Icons.search_off : Icons.search,
                active: showSearch,
                onTap: onToggleSearch,
              ),
              const SizedBox(width: MLSpacing.sm),
              _IconButton(
                icon: Icons.calendar_today_outlined,
                active: filterDate != null,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: filterDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    builder: (ctx, child) => Theme(
                      data: ThemeData.dark().copyWith(
                        colorScheme: const ColorScheme.dark(primary: MLColors.accentCyan),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) onDateFilter(picked);
                },
              ),
            ],
          ),
          if (showSearch)
            Padding(
              padding: const EdgeInsets.only(top: MLSpacing.sm, bottom: MLSpacing.sm),
              child: TextField(
                controller: searchController,
                autofocus: true,
                style: MLTextStyles.bodyRegular,
                onChanged: onSearch,
                decoration: InputDecoration(
                  hintText: 'Search Case Files…',
                  hintStyle: MLTextStyles.bodyMuted,
                  prefixIcon: const Icon(Icons.search, color: MLColors.textMuted, size: 18),
                  filled: true,
                  fillColor: MLColors.surfaceGlass,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(MLRadius.md),
                    borderSide: const BorderSide(color: MLColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(MLRadius.md),
                    borderSide: const BorderSide(color: MLColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(MLRadius.md),
                    borderSide: const BorderSide(color: MLColors.accentCyan),
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: MLSpacing.sm),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _IconButton({required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? MLColors.accentCyanGlow : MLColors.surfaceGlass,
            border: Border.all(color: active ? MLColors.accentCyan : MLColors.border),
          ),
          child: Icon(icon, color: active ? MLColors.accentCyan : MLColors.textMuted, size: 16),
        ),
      );
}

// ─── Case File tile with swipe-to-delete ─────────────────────────────────────

class _CaseFileTile extends StatelessWidget {
  final CaseFile caseFile;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _CaseFileTile({required this.caseFile, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(caseFile.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: MLSpacing.lg),
        margin: const EdgeInsets.only(bottom: MLSpacing.sm),
        decoration: BoxDecoration(
          color: MLColors.statusError.withAlpha(30),
          borderRadius: BorderRadius.circular(MLRadius.md),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.delete_outline, color: MLColors.statusError, size: 20),
            const SizedBox(height: 2),
            Text('SHRED', style: MLTextStyles.dataSmall.copyWith(color: MLColors.statusError)),
          ],
        ),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: MLSpacing.sm),
          padding: const EdgeInsets.all(MLSpacing.md),
          decoration: BoxDecoration(
            color: MLColors.bgCard,
            borderRadius: BorderRadius.circular(MLRadius.md),
            border: Border.all(color: MLColors.border),
          ),
          child: Row(
            children: [
              // Verification stripe
              Container(
                width: 3,
                height: 60,
                margin: const EdgeInsets.only(right: MLSpacing.md),
                decoration: BoxDecoration(
                  color: caseFile.isVerified ? MLColors.statusVerified : MLColors.statusWarning,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Main content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            caseFile.detectedItems.map((i) => i.name).take(3).join(', '),
                            style: MLTextStyles.headingSmall.copyWith(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _ConfidenceDot(caseFile.overallConfidence),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(_formatDateTime(caseFile.loggedAt), style: MLTextStyles.dataSmall),
                        const SizedBox(width: MLSpacing.sm),
                        Text('•', style: MLTextStyles.dataSmall),
                        const SizedBox(width: MLSpacing.sm),
                        Text(
                          caseFile.mealType.name.toUpperCase(),
                          style: MLTextStyles.labelCaps.copyWith(color: MLColors.accentCyan, fontSize: 9),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _MacroChip('${caseFile.mealTotals.calories.round()} kcal', MLColors.textPrimary),
                        const SizedBox(width: 8),
                        _MacroChip('P ${caseFile.mealTotals.proteinGrams.round()}g', MLColors.macroProtein),
                        const SizedBox(width: 8),
                        _MacroChip('C ${caseFile.mealTotals.carbohydratesGrams.round()}g', MLColors.macroCarbs),
                        const SizedBox(width: 8),
                        _MacroChip('F ${caseFile.mealTotals.fatGrams.round()}g', MLColors.macroFat),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: MLColors.textDim, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (isToday) return 'Today $timeStr';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')} $timeStr';
  }
}

class _ConfidenceDot extends StatelessWidget {
  final OverallConfidence confidence;
  const _ConfidenceDot(this.confidence);

  @override
  Widget build(BuildContext context) {
    final color = switch (confidence) {
      OverallConfidence.high   => MLColors.statusVerified,
      OverallConfidence.medium => MLColors.statusWarning,
      OverallConfidence.low    => MLColors.statusError,
    };
    return Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}

class _MacroChip extends StatelessWidget {
  final String text;
  final Color color;
  const _MacroChip(this.text, this.color);

  @override
  Widget build(BuildContext context) =>
      Text(text, style: MLTextStyles.dataSmall.copyWith(color: color, fontSize: 10));
}

// ─── Empty / Loading / Error ──────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(MLSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_open_outlined, color: MLColors.textDim, size: 48),
              const SizedBox(height: MLSpacing.md),
              Text('NO CASE FILES FOUND', style: MLTextStyles.labelCaps),
              const SizedBox(height: 4),
              Text('Capture a meal to begin your analysis log.', style: MLTextStyles.bodyMuted, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) => const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: MLColors.accentCyan),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(MLSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error, style: MLTextStyles.dataSmall.copyWith(color: MLColors.statusError), textAlign: TextAlign.center),
              const SizedBox(height: MLSpacing.lg),
              OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(side: const BorderSide(color: MLColors.accentCyan)),
                child: Text('RETRY', style: MLTextStyles.labelCaps.copyWith(color: MLColors.accentCyan)),
              ),
            ],
          ),
        ),
      );
}
