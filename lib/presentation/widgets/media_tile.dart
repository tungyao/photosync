import 'package:flutter/material.dart';

import '../../data/models/media_asset.dart';

class MediaTile extends StatelessWidget {
  const MediaTile({
    super.key,
    required this.asset,
    required this.selected,
    required this.onTap,
  });

  final MediaAsset asset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(asset.path.split('\\').last),
      subtitle: Text('${asset.type} • ${asset.size} bytes'),
      trailing: Icon(
        selected ? Icons.check_circle : Icons.radio_button_unchecked,
        color: selected ? Theme.of(context).colorScheme.primary : null,
      ),
      onTap: onTap,
    );
  }
}
