import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/booking.dart';
import '../services/booking_services.dart';

const _kNavy  = Color(0xFF1A237E);
const _kSlate = Color(0xFF546E7A);
const _kBlue  = Color(0xFF1A73E8); // accent only: amounts, discount pill

class BookingListScreen extends StatefulWidget {
  const BookingListScreen({super.key});
  @override
  State<BookingListScreen> createState() => _BookingListScreenState();
}

class _BookingListScreenState extends State<BookingListScreen>
    with TickerProviderStateMixin {
  final _service = BookingService();
  List<Booking> _bookings = [];
  bool _isLoading = false;
  String? _errorMessage;
  final Set<String> _processingIds = {};

  String _filter = 'All';
  List<Booking> get _filtered {
    switch (_filter) {
      case 'Pending':   return _bookings.where((b) => b.status == 'Pending').toList();
      case 'Completed': return _bookings.where((b) => b.status == 'Completed').toList();
      case 'Discount':  return _bookings.where((b) => b.discountApplied).toList();
      default:          return _bookings;
    }
  }

  bool _isGridView = false;
  Key get _viewKey => ValueKey(_isGridView);

  late final AnimationController _fadeCtrl = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 500),
  );
  late final Animation<double> _fadeAnim =
  CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _fadeCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    _fadeCtrl.reset();
    try {
      final data = await _service.fetchBookings();
      setState(() => _bookings = data);
      _fadeCtrl.forward();
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markDone(Booking b, {bool fromSheet = false}) async {
    if (fromSheet) Navigator.pop(context);
    setState(() => _processingIds.add('status_${b.id}'));
    try {
      await _service.updateBookingStatus(b.id, 'Completed');
      setState(() => b.status = 'Completed');
      _toast('Status successfully updated!', ok: true);
    } on ApiException catch (e) {
      _toast(e.message, ok: false);
    } finally {
      setState(() => _processingIds.remove('status_${b.id}'));
    }
  }

  Future<void> _applyDiscount(Booking b, {bool fromSheet = false}) async {
    if (fromSheet) Navigator.pop(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Apply for 10% discount?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _dialogRow('Original price', 'RM ${b.amount.toStringAsFixed(2)}'),
          _dialogRow('After discount', 'RM ${(b.amount * 0.9).toStringAsFixed(2)}', highlight: true),
          _dialogRow('Save', 'RM ${(b.amount * 0.1).toStringAsFixed(2)}', color: Colors.green.shade700),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _processingIds.add('disc_${b.id}'));
    try {
      await _service.applyDiscount(b.id);
      setState(() => b.discountApplied = true);
      _toast('10% discount successfully applied!', ok: true);
    } on ApiException catch (e) {
      _toast(e.message, ok: false);
    } finally {
      setState(() => _processingIds.remove('disc_${b.id}'));
    }
  }

  Widget _dialogRow(String label, String value, {bool highlight = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          Text(value, style: TextStyle(
            fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            color: color ?? (highlight ? _kNavy : null),
            fontSize: 13,
          )),
        ]),
      );

  void _toast(String msg, {required bool ok}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(ok ? Icons.check_circle_outline : Icons.error_outline, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
    ));
  }

  void _showBookingSheet(Booking b) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      backgroundColor: Colors.white,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (_) => _BookingBottomSheet(
        booking: b,
        isStatusBusy: _processingIds.contains('status_${b.id}'),
        isDiscountBusy: _processingIds.contains('disc_${b.id}'),
        onComplete: () => _markDone(b, fromSheet: true),
        onDiscount: () => _applyDiscount(b, fromSheet: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending   = _bookings.where((b) => b.status == 'Pending').length;
    final completed = _bookings.where((b) => b.status == 'Completed').length;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: _buildAppBar(),
      body: _isLoading
          ? _buildShimmer()
          : _errorMessage != null
          ? _buildError()
          : _buildBody(pending, completed, _filtered),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: const Color(0xFFF0F4FF),
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    title: const Text('Booking Management',
        style: TextStyle(color: _kNavy, fontWeight: FontWeight.bold, fontSize: 17)),
    actions: [
      _appBarBtn(
        icon: _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
        onTap: () => setState(() => _isGridView = !_isGridView),
        right: 4,
      ),
      _appBarBtn(icon: Icons.refresh_rounded, onTap: _load, right: 12),
    ],
  );

  Widget _appBarBtn({required IconData icon, required VoidCallback onTap, required double right}) =>
      Padding(
        padding: EdgeInsets.only(right: right),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Icon(icon, color: _kNavy, size: 20),
          ),
        ),
      );

  Widget _buildBody(int pending, int completed, List<Booking> filtered) =>
      Column(children: [
        _buildStatsBar(pending, completed),
        _buildFilterBar(),
        Expanded(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: RefreshIndicator(
              onRefresh: _load,
              color: _kNavy,
              child: filtered.isEmpty
                  ? _buildEmpty()
                  : AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(anim),
                    child: child,
                  ),
                ),
                child: _isGridView
                    ? _buildGrid(key: _viewKey, items: filtered)
                    : _buildListView(key: _viewKey, items: filtered),
              ),
            ),
          ),
        ),
      ]);

  Widget _buildListView({Key? key, required List<Booking> items}) =>
      ListView.builder(
        key: key,
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 30),
        itemCount: items.length,
        itemBuilder: (_, i) => _BookingCard(
          booking: items[i],
          isStatusBusy: _processingIds.contains('status_${items[i].id}'),
          isDiscountBusy: _processingIds.contains('disc_${items[i].id}'),
          onComplete: () => _markDone(items[i]),
          onDiscount: () => _applyDiscount(items[i]),
        ),
      );

  Widget _buildGrid({Key? key, required List<Booking> items}) =>
      GridView.builder(
        key: key,
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 30),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.95,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => _BookingGridCard(
          booking: items[i],
          onTap: () { HapticFeedback.lightImpact(); _showBookingSheet(items[i]); },
        ),
      );

  Widget _buildStatsBar(int pending, int completed) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
    child: Row(children: [
      _dot(Colors.orange),
      const SizedBox(width: 6),
      Text('Pending  $pending',
          style: const TextStyle(color: _kNavy, fontSize: 12, fontWeight: FontWeight.bold)),
      const SizedBox(width: 16),
      _dot(Colors.green),
      const SizedBox(width: 6),
      Text('Completed  $completed',
          style: const TextStyle(color: _kNavy, fontSize: 12, fontWeight: FontWeight.bold)),
      const Spacer(),
      Text('${_bookings.length} booking',
          style: const TextStyle(color: _kSlate, fontSize: 11)),
    ]),
  );

  Widget _dot(Color c) => Container(
    width: 8, height: 8,
    decoration: BoxDecoration(shape: BoxShape.circle, color: c),
  );

  Widget _buildFilterBar() {
    final filters = [
      ('All',       Icons.list_alt_rounded),
      ('Pending',   Icons.hourglass_top_rounded),
      ('Completed', Icons.check_circle_outline_rounded),
      ('Discount',  Icons.local_offer_outlined),
    ];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final label  = filters[i].$1;
          final icon   = filters[i].$2;
          final active = _filter == label;
          return GestureDetector(
            onTap: () => setState(() => _filter = label),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: active ? _kNavy : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: active ? _kNavy : Colors.grey.shade300),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 13, color: active ? Colors.white : _kSlate),
                const SizedBox(width: 5),
                Text(label, style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  color: active ? Colors.white : _kSlate,
                )),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShimmer() => ListView.builder(
    padding: const EdgeInsets.all(14),
    itemCount: 4,
    itemBuilder: (_, __) => const _ShimmerCard(),
  );

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
          child: Icon(Icons.cloud_off_rounded, color: Colors.red.shade400, size: 48),
        ),
        const SizedBox(height: 20),
        const Text('Oops! An error occurred.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(_errorMessage!, textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, height: 1.5)),
        const SizedBox(height: 28),
        ElevatedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Cuba Lagi'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kNavy,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ]),
    ),
  );

  Widget _buildEmpty() => const Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
      SizedBox(height: 12),
      Text('No more bookings.', style: TextStyle(color: Colors.grey)),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════
// Bottom Sheet
// ═══════════════════════════════════════════════════════════
class _BookingBottomSheet extends StatefulWidget {
  final Booking booking;
  final bool isStatusBusy;
  final bool isDiscountBusy;
  final VoidCallback onComplete;
  final VoidCallback onDiscount;

  const _BookingBottomSheet({
    required this.booking,
    required this.isStatusBusy,
    required this.isDiscountBusy,
    required this.onComplete,
    required this.onDiscount,
  });

  @override
  State<_BookingBottomSheet> createState() => _BookingBottomSheetState();
}

class _BookingBottomSheetState extends State<_BookingBottomSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _handleCtrl = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);
  late final Animation<double> _handleWidth =
  Tween<double>(begin: 32, end: 48).animate(
      CurvedAnimation(parent: _handleCtrl, curve: Curves.easeInOut));

  @override
  void dispose() { _handleCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final isPending = b.status == 'Pending';

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [

        // Animated drag handle
        AnimatedBuilder(
          animation: _handleWidth,
          builder: (_, __) => Container(
            width: _handleWidth.value, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
                color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
        ),

        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(
            child: Text(b.customerName,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _kNavy)),
          ),
          _StatusBadge(status: b.status),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.home_repair_service_outlined, size: 13, color: _kSlate),
          const SizedBox(width: 6),
          Text(b.serviceType, style: const TextStyle(color: _kSlate, fontSize: 13)),
        ]),
        const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Divider(height: 1)),

        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Amount', style: TextStyle(color: _kSlate, fontSize: 11)),
            const SizedBox(height: 2),
            if (b.discountApplied) ...[
              Text('RM ${b.amount.toStringAsFixed(2)}',
                  style: const TextStyle(decoration: TextDecoration.lineThrough, color: _kSlate, fontSize: 12)),
              Row(children: [
                Text('RM ${b.finalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _kBlue)),
                const SizedBox(width: 6),
                _pill10Off(),
              ]),
              Text('Saved RM ${b.discountSaving.toStringAsFixed(2)}',
                  style: TextStyle(color: Colors.green.shade600, fontSize: 11)),
            ] else ...[
              Text('RM ${b.amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _kNavy)),
              if (b.eligibleForDiscount && isPending)
                const Text('Eligible for 10% discount',
                    style: TextStyle(color: _kBlue, fontSize: 11)),
            ],
          ]),
          if (!isPending) Icon(Icons.verified_rounded, color: Colors.green.shade400, size: 28),
        ]),

        if (isPending) ...[
          const SizedBox(height: 20),
          Row(children: [
            if (b.eligibleForDiscount && !b.discountApplied) ...[
              Expanded(
                child: widget.isDiscountBusy
                    ? const _Loader()
                    : OutlinedButton.icon(
                  onPressed: widget.onDiscount,
                  icon: const Icon(Icons.local_offer_outlined, size: 15),
                  label: const Text('Apply Discount'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kNavy,
                    side: const BorderSide(color: _kNavy),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: widget.isStatusBusy
                  ? const _Loader()
                  : ElevatedButton.icon(
                onPressed: widget.onComplete,
                icon: const Icon(Icons.check_circle_outline, size: 15),
                label: const Text('Mark Complete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kNavy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _pill10Off() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: _kBlue.withOpacity(0.1),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: _kBlue.withOpacity(0.25)),
    ),
    child: const Text('10% OFF',
        style: TextStyle(color: _kBlue, fontSize: 10, fontWeight: FontWeight.bold)),
  );
}

// ═══════════════════════════════════════════════════════════
// Shared mini loader
// ═══════════════════════════════════════════════════════════
class _Loader extends StatelessWidget {
  const _Loader();
  @override
  Widget build(BuildContext context) => const Center(
    child: SizedBox(width: 22, height: 22,
        child: CircularProgressIndicator(strokeWidth: 2, color: _kNavy)),
  );
}

// ═══════════════════════════════════════════════════════════
// Grid Card
// ═══════════════════════════════════════════════════════════
class _BookingGridCard extends StatelessWidget {
  final Booking booking;
  final VoidCallback onTap;
  const _BookingGridCard({required this.booking, required this.onTap});

  String _initials(String name) {
    final p = name.trim().split(' ');
    return p.length >= 2
        ? '${p[0][0]}${p[1][0]}'.toUpperCase()
        : name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final isPending = b.status == 'Pending';
    final accentColor = isPending ? const Color(0xFFFF9800) : const Color(0xFF43A047);
    final accentLight = isPending ? const Color(0xFFFFB74D) : const Color(0xFF81C784);
    final avatarBg    = isPending ? const Color(0xFFE8F0FE) : const Color(0xFFE8F5E9);
    final avatarText  = isPending ? _kNavy : const Color(0xFF2E7D32);
    final cardBg      = isPending ? Colors.white : const Color(0xFFF8FBF8);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isPending
              ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))]
              : [],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
                gradient: LinearGradient(colors: [accentColor, accentLight])),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: avatarBg, borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: Text(_initials(b.customerName),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: avatarText)),
              ),
              const SizedBox(height: 8),
              Text(b.customerName,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _kNavy)),
              const SizedBox(height: 3),
              Text(b.serviceType,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: _kSlate)),
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, thickness: 0.5)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (b.discountApplied) ...[
                      Text('RM ${b.amount.toStringAsFixed(2)}',
                          style: const TextStyle(decoration: TextDecoration.lineThrough, color: _kSlate, fontSize: 9)),
                      Text('RM ${b.finalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F4C81))),
                    ] else ...[
                      Text('RM ${b.amount.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _kNavy)),
                    ],
                  ]),
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle, color: accentColor,
                      boxShadow: [BoxShadow(color: accentColor.withOpacity(0.35), blurRadius: 4, spreadRadius: 1)],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.touch_app_outlined, size: 10, color: Colors.grey.shade400),
                const SizedBox(width: 3),
                Text('Tap for details', style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// List Card
// ═══════════════════════════════════════════════════════════
class _BookingCard extends StatefulWidget {
  final Booking booking;
  final bool isStatusBusy;
  final bool isDiscountBusy;
  final VoidCallback onComplete;
  final VoidCallback onDiscount;

  const _BookingCard({
    required this.booking,
    required this.isStatusBusy,
    required this.isDiscountBusy,
    required this.onComplete,
    required this.onDiscount,
  });

  @override
  State<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<_BookingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);
  late final Animation<double> _scale =
  Tween(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final isPending  = b.status == 'Pending';
    final isCompleted = !isPending;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isPending ? 2 : 0,
      color: isCompleted ? Colors.grey.shade50 : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isCompleted ? Colors.green.shade100 : Colors.transparent),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(
              child: Text(b.customerName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _kNavy)),
            ),
            _StatusBadge(status: b.status),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.home_repair_service_outlined, size: 13, color: _kSlate),
            const SizedBox(width: 6),
            Text(b.serviceType, style: const TextStyle(color: _kSlate, fontSize: 13)),
          ]),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (b.discountApplied) ...[
                  Text('RM ${b.amount.toStringAsFixed(2)}',
                      style: const TextStyle(decoration: TextDecoration.lineThrough, color: _kSlate, fontSize: 12)),
                  Row(children: [
                    Text('RM ${b.finalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F4C81))),
                    const SizedBox(width: 6),
                    _pill('10% OFF', Color(0xFF0F4C81)),
                  ]),
                  Text('Saved RM ${b.discountSaving.toStringAsFixed(2)}',
                      style: TextStyle(color: Colors.green.shade600, fontSize: 11)),
                ] else ...[
                  Text('RM ${b.amount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kNavy)),
                  if (b.eligibleForDiscount && isPending)
                    const Text('Eligible for 10% discount',
                        style: TextStyle(color: _kBlue, fontSize: 11)),
                ],
              ]),
              if (isPending)
                Row(children: [
                  if (b.eligibleForDiscount && !b.discountApplied) ...[
                    widget.isDiscountBusy
                        ? const _Loader()
                        : ScaleTransition(
                      scale: _scale,
                      child: _outlineBtn('Discount', Icons.local_offer_outlined, widget.onDiscount),
                    ),
                    const SizedBox(width: 8),
                  ],
                  widget.isStatusBusy
                      ? const _Loader()
                      : _solidBtn('Complete', Icons.check_circle_outline, widget.onComplete),
                ])
              else
                Icon(Icons.verified_rounded, color: Colors.green.shade400, size: 26),
            ],
          ),
        ]),
      ),
    );
  }

  // AFTER
  Widget _pill(String label, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: c.withOpacity(0.1),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: c.withOpacity(0.25)),
    ),
    child: Text(label,
        style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold)),
  );

  Widget _outlineBtn(String label, IconData icon, VoidCallback onTap) =>
      OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 13),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          foregroundColor: _kNavy,
          side: const BorderSide(color: _kNavy),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );

  Widget _solidBtn(String label, IconData icon, VoidCallback onTap) =>
      ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 13),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _kNavy,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
}

// ═══════════════════════════════════════════════════════════
// Status Badge
// ═══════════════════════════════════════════════════════════
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isPending = status == 'Pending';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPending ? Colors.orange.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isPending ? Colors.orange.shade200 : Colors.green.shade200),
      ),
      child: Text(status,
          style: TextStyle(
              color: isPending ? Colors.orange.shade800 : Colors.green.shade800,
              fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Shimmer Card
// ═══════════════════════════════════════════════════════════
class _ShimmerCard extends StatefulWidget {
  const _ShimmerCard();
  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 1400),
  )..repeat();
  late final Animation<double> _anim =
  Tween(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine));

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) {
      final g = LinearGradient(
        begin: Alignment(_anim.value - 1, 0),
        end: Alignment(_anim.value + 1, 0),
        colors: [Colors.grey.shade200, Colors.grey.shade100, Colors.grey.shade200],
      );
      Widget s(double w, double h) => Container(
        width: w, height: h,
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(gradient: g, borderRadius: BorderRadius.circular(4)),
      );
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [s(140, 14), s(60, 22)]),
            const SizedBox(height: 4),
            s(100, 12),
            const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1)),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [s(80, 18), s(90, 32)]),
          ]),
        ),
      );
    },
  );
}