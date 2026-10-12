import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../config/api_config.dart';

class AppTileLayer extends StatelessWidget {
  const AppTileLayer({super.key});

  @override
  Widget build(BuildContext context) => TileLayer(
        urlTemplate: ApiConfig.mapTileUrl,
        userAgentPackageName: ApiConfig.mapUserAgent,
      );
}