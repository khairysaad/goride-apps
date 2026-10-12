import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/models.dart';
import '../../providers/complaint_provider.dart';
import '../../providers/trip_provider.dart';
import '../../providers/settings_provider.dart';
class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({super.key});

  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> {
  int _category = 1;
  final _subject = TextEditingController();
  final _description = TextEditingController();
  bool _busy = false;
  int? _tripId;
  List<Trip> _trips = [];

  static List<String> get _categories => [
    L10n.t('other'),
    L10n.t('cat_driver_behavior'),
    L10n.t('cat_route'),
    L10n.t('cat_pricing'),
    L10n.t('cat_safety'),
    L10n.t('cat_app_issue'),
    L10n.t('cat_support'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ComplaintProvider>().load();
      _loadTrips();
    });
  }

  Future<void> _loadTrips() async {
    try {
      final trips = await context.read<TripProvider>().history();
      if (!mounted || trips.isEmpty) return;
      setState(() => _trips = trips.take(15).toList());
    } catch (_) {}
  }

  Future<void> _submit() async {
    final desc = _description.text.trim();
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.t('complaint_desc_hint'))),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<ComplaintProvider>().submit(
            category: _category,
            subject: _subject.text.trim().isEmpty ? null : _subject.text.trim(),
            description: desc,
            tripId: _tripId,
          );
      if (!mounted) return;
      _subject.clear();
      _description.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.t('complaint_sent'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ComplaintProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(L10n.t('complaints_support'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(L10n.t('new_complaint'),
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(L10n.t('category')),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(_categories.length, (i) {
                      return ChoiceChip(
                        label: Text(_categories[i]),
                        selected: _category == i,
                        onSelected: (_) => setState(() => _category = i),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  if (_trips.isNotEmpty) ...[
                    DropdownButtonFormField<int>(
                      value: _tripId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: L10n.t('related_trip_optional'),
                        prefixIcon: const Icon(Icons.history, size: 20),
                      ),
                      items: [
                        DropdownMenuItem(
                            value: null,
                            child: Text(L10n.t('no_related_trip'))),
                        ..._trips.map((t) => DropdownMenuItem(
                              value: t.id,
                              child: Text(
                                t.tripNumber,
                                overflow: TextOverflow.ellipsis,
                              ),
                            )),
                      ],
                      onChanged: (v) => setState(() => _tripId = v),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _subject,
                    decoration: InputDecoration(labelText: L10n.t('subject_optional')),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _description,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: L10n.t('complaint_desc'),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(L10n.t('submit_complaint')),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(L10n.t('past_complaints'),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (provider.loading)
            const Center(child: CircularProgressIndicator())
          else if (provider.list.isEmpty)
            Text(L10n.t('no_complaints'),
                style: TextStyle(color: context.onSurfaceVariant))
          else
            ...provider.list.map((c) => _complaintTile(c)),
        ],
      ),
    );
  }

  Widget _complaintTile(Complaint c) {
    return Card(
      child: ListTile(
        title: Text(c.subject ?? c.categoryLabel),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(c.description, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
        trailing: Chip(
          label: Text(c.statusLabel),
          backgroundColor: c.status == 2 || c.status == 3
              ? Colors.green.withValues(alpha: 0.15)
              : AppColors.warning.withValues(alpha: 0.15),
          labelStyle: TextStyle(
            color: c.status == 2 || c.status == 3 ? Colors.green : AppColors.warning,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}