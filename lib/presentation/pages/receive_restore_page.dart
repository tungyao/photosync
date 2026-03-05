import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/smb_config.dart';
import '../../platform/channels/smb_channel.dart';
import '../controllers/app_state_controller.dart';
import '../widgets/receive_progress_dialog.dart';

class ReceiveRestorePage extends ConsumerStatefulWidget {
  const ReceiveRestorePage({super.key});

  @override
  ConsumerState<ReceiveRestorePage> createState() => _ReceiveRestorePageState();
}

class _ReceiveRestorePageState extends ConsumerState<ReceiveRestorePage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (!Platform.isIOS) {
      Future.microtask(
        () => ref.read(remoteBrowserProvider.notifier).loadInitial(''),
      );
    }
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 600) {
      ref.read(remoteBrowserProvider.notifier).loadMore();
    }
  }

  Future<void> _startRestore() async {
    if (Platform.isIOS) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receive/Restore is not supported on iOS yet.'),
        ),
      );
      return;
    }

    final browser = ref.read(remoteBrowserProvider.notifier);
    final selected = browser.selectedMediaEntries();
    if (selected.isEmpty) return;

    final runner = ref.read(receiveRunnerProvider.notifier);
    unawaited(runner.startRestore(selected: selected));
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const ReceiveProgressDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return Scaffold(
        appBar: AppBar(title: const Text('Receive / Restore')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Receive / Restore is not supported on iOS yet.'),
          ),
        ),
      );
    }

    final state = ref.watch(remoteBrowserProvider);
    final smbConfigState = ref.watch(smbConfigProvider);
    final smb = ref.read(smbChannelProvider);
    final browser = ref.read(remoteBrowserProvider.notifier);
    final selectedCount = state.selectedPaths.length;
    final visibleEntries =
        state.entries.where((e) => e.isDir || e.isImage).toList(growable: false);
    final breadcrumb =
        '/${state.currentDir.replaceAll('\\', '/').replaceAll(RegExp(r'^/+'), '')}'
            .replaceAll(RegExp(r'//+'), '/');

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Receive / Remote'),
            Text(
              breadcrumb == '/' ? '/ (root)' : breadcrumb,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        leading: const BackButton(),
        actions: [
          if (state.currentDir.isNotEmpty)
            TextButton(
              onPressed: browser.backToParent,
              child: const Text('Up'),
            ),
          TextButton(
            onPressed: browser.selectAllVisible,
            child: const Text('Select All'),
          ),
          if (state.selectionMode)
            IconButton(
              tooltip: 'Exit Selection',
              onPressed: browser.clearSelectionMode,
              icon: const Icon(Icons.close),
            ),
        ],
      ),
      body: smbConfigState.when(
        data: (config) => state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : state.error != null
                ? Center(child: Text('Load failed: ${state.error}'))
                : RefreshIndicator(
                    onRefresh: () => browser.loadInitial(state.currentDir),
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: visibleEntries.length + (state.hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= visibleEntries.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final entry = visibleEntries[index];
                        if (entry.isDir) {
                          return ListTile(
                            leading: const Icon(Icons.folder),
                            title: Text(entry.name),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => browser.enterDir(entry.path),
                          );
                        }

                        final selected = state.selectedPaths.contains(entry.path);
                        final imported = state.importedKeys.contains(entry.localMatchKey);
                        return ListTile(
                          leading: _RemoteThumb(
                            smb: smb,
                            config: config,
                            remotePath: entry.path,
                            mimeType: entry.mimeType,
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (imported)
                                const Padding(
                                  padding: EdgeInsets.only(left: 6),
                                  child: Icon(
                                    Icons.check_circle,
                                    color: Colors.blue,
                                    size: 18,
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text('${entry.mimeType}  ${entry.size} bytes'),
                          trailing: Icon(
                            selected
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color:
                                selected ? Theme.of(context).colorScheme.primary : null,
                          ),
                          onTap: () {
                            browser.toggleSelect(entry);
                          },
                          onLongPress: () => browser.toggleSelect(entry),
                        );
                      },
                    ),
                  ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('SMB config load failed: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: selectedCount <= 0 ? null : _startRestore,
        child: const Icon(Icons.download),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: selectedCount <= 0 ? null : _startRestore,
            icon: const Icon(Icons.download),
            label: Text('Restore Selected ($selectedCount)'),
          ),
        ),
      ),
    );
  }
}

class _RemoteThumb extends StatefulWidget {
  const _RemoteThumb({
    required this.smb,
    required this.config,
    required this.remotePath,
    required this.mimeType,
  });

  final SmbChannel smb;
  final SmbConfig config;
  final String remotePath;
  final String mimeType;

  @override
  State<_RemoteThumb> createState() => _RemoteThumbState();
}

class _RemoteThumbState extends State<_RemoteThumb> {
  late Future<Uint8List?> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.smb.getRemoteThumbnail(
      config: widget.config,
      remotePath: widget.remotePath,
      width: 120,
      height: 120,
    );
  }

  @override
  void didUpdateWidget(covariant _RemoteThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.remotePath != widget.remotePath) {
      _future = widget.smb.getRemoteThumbnail(
        config: widget.config,
        remotePath: widget.remotePath,
        width: 120,
        height: 120,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 48,
        height: 48,
        child: FutureBuilder<Uint8List?>(
          future: _future,
          builder: (context, snapshot) {
            final bytes = snapshot.data;
            if (bytes != null && bytes.isNotEmpty) {
              return Image.memory(bytes, fit: BoxFit.cover);
            }
            return ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Icon(
                widget.mimeType.startsWith('video/')
                    ? Icons.videocam
                    : Icons.image,
                size: 18,
              ),
            );
          },
        ),
      ),
    );
  }
}
