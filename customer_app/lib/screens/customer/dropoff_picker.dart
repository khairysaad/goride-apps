import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../config/app_theme.dart';
import '../../core/network/geocode_service.dart';
import '../../core/widgets/app_tile_layer.dart';
import '../../providers/settings_provider.dart';

class DropoffSelection {
  final LatLng position;
  final String address;

  const DropoffSelection({required this.position, required this.address});
}

class DropoffPicker extends StatefulWidget {
  const DropoffPicker({super.key, required this.initial});

  final LatLng initial;

  @override
  State<DropoffPicker> createState() => _DropoffPickerState();
}

class _DropoffPickerState extends State<DropoffPicker> {
  final _mapController = MapController();
  final _searchController = TextEditingController();
  LatLng? _picked;
  String? _pickedAddress;
  bool _searching = false;
  bool _resolving = false;
  List<GeocodeResult> _results = const [];

  @override
  void initState() {
    super.initState();
    _picked = widget.initial;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    FocusScope.of(context).unfocus();
    if (query.trim().isEmpty) return;
    setState(() {
      _searching = true;
      _results = const [];
    });
    final r = await GeocodeService.search(query.trim(), near: widget.initial);
    if (!mounted) return;
    setState(() {
      _searching = false;
      _results = r;
    });
  }

  Future<void> _pickPoint(LatLng? point, {String? address}) async {
    if (point == null) return;
    _mapController.move(point, 16);
    setState(() {
      _picked = point;
      _results = const [];
      _pickedAddress = address;
    });
    if (address != null) return;
    setState(() => _resolving = true);
    final addr = await GeocodeService.reverse(point.latitude, point.longitude);
    if (!mounted) return;
    setState(() {
      _resolving = false;
      _pickedAddress = addr;
    });
  }

  void _confirm() {
    if (_picked == null) return;
    Navigator.of(context).pop(DropoffSelection(
      position: _picked!,
      address: (_pickedAddress ?? '').isNotEmpty
          ? _pickedAddress!
          : '${_picked!.latitude.toStringAsFixed(5)}, ${_picked!.longitude.toStringAsFixed(5)}',
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.t('choose_dropoff_title')),
        actions: [
          TextButton(
            onPressed: _picked != null ? _confirm : null,
            child: Text(L10n.t('done')),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.initial,
              initialZoom: 14,
              onTap: (_, point) => _pickPoint(point),
            ),
            children: [
              const AppTileLayer(),
              if (_picked != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _picked!,
                      width: 48,
                      height: 48,
                      child: Icon(
                        Icons.location_on,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Column(
              children: [
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(28),
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _search,
                    decoration: InputDecoration(
                      hintText: L10n.t('search_destination_hint'),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        onPressed: _searching
                            ? null
                            : () => _search(_searchController.text),
                        icon: _searching
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.arrow_forward_rounded),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (_results.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 8)
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final r in _results)
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.place_outlined,
                                color: AppColors.secondary),
                            title: Text(r.shortName,
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            onTap: () async {
                              _searchController.text = r.shortName;
                              await _pickPoint(r.position,
                                  address: r.displayName);
                            },
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 8)
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        _resolving ? Icons.hourglass_top : Icons.location_on,
                        color: _pickedAddress != null
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _pickedAddress ??
                              (_resolving
                                  ? L10n.t('geocoding')
                                  : L10n.t('tap_map_dropoff')),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _picked != null ? _confirm : null,
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(L10n.t('use_this_location')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}