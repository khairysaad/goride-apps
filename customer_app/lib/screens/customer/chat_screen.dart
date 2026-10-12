import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../providers/settings_provider.dart';
class TripChatScreen extends StatefulWidget {
  const TripChatScreen({
    super.key,
    required this.tripId,
    required this.title,
  });

  final int tripId;
  final String title;

  @override
  State<TripChatScreen> createState() => _TripChatScreenState();
}

class _TripChatScreenState extends State<TripChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<ChatMessageItem> _messages = [];
  bool _loading = true;
  Timer? _pollTimer;

  bool get _isDriver =>
      context.read<AuthProvider>().user?.isDriver == true;

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _tick());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _tick() async {
    try {
      final messages =
          await context.read<TripProvider>().fetchMessages(widget.tripId);
      if (!mounted) return;
      final changed = messages.length != _messages.length ||
          (messages.isNotEmpty &&
              _messages.isNotEmpty &&
              messages.last.createdAt != _messages.last.createdAt);
      if (!changed) return;
      setState(() => _messages = messages);
      if (_nearBottom) _scrollToBottom();
      await context.read<TripProvider>().markMessagesRead(widget.tripId);
    } catch (_) {}
  }

  bool get _nearBottom {
    if (!_scrollController.hasClients) return true;
    return _scrollController.position.maxScrollExtent -
            _scrollController.position.pixels <
        80;
  }

  Future<void> _load() async {
    try {
      final messages =
          await context.read<TripProvider>().fetchMessages(widget.tripId);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _loading = false;
      });
      _scrollToBottom();
      await context.read<TripProvider>().markMessagesRead(widget.tripId);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    setState(() {
      _messages.add(
        ChatMessageItem(
          id: 0,
          senderId: 0,
          senderType: _isDriver ? 1 : 2,
          body: text,
          isRead: false,
          createdAt: DateTime.now(),
        ),
      );
    });
    _scrollToBottom();
    try {
      await context.read<TripProvider>().sendMessage(widget.tripId, text);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          L10n.t('chat_empty'),
                          style: TextStyle(color: context.onSurfaceVariant),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) =>
                            _bubble(_messages[i]),
                      ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 4),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: L10n.t('chat_hint'),
                        hintStyle:
                            const TextStyle(color: AppColors.textSecondary),
                        isDense: true,
                        filled: true,
                        fillColor: AppColors.skyLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _send,
                    icon: Icon(Icons.send,
                        color: Theme.of(context).colorScheme.primary, size: 26),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(ChatMessageItem m) {
    final mine = m.senderType == (_isDriver ? 1 : 2);
    return Align(
      alignment: mine ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: mine ? AppColors.primary : AppColors.skyLight,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 4 : 16),
            bottomRight: Radius.circular(mine ? 16 : 4),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            Text(
              m.body,
              style: TextStyle(
                color: mine ? Colors.white : AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _time(m.createdAt),
              style: TextStyle(
                color: mine ? Colors.white70 : AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _time(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final min = t.minute.toString().padLeft(2, '0');
    return '$h:$min';
  }
}