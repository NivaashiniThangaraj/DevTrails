import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/chat_service.dart';

enum MessageRole { user, assistant }

class ChatMessage {
  String text;
  final MessageRole role;
  ChatMessage({required this.text, required this.role});
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [
    ChatMessage(role: MessageRole.assistant, text: "Hi! I'm Aegis AI 🤖 Ask me anything about your insurance, claims, coverage or the app!"),
  ];
  final TextEditingController _controller = TextEditingController();
  bool _isTyping = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty || _isTyping) return;
    final text = _controller.text.trim();
    setState(() {
      _messages.add(ChatMessage(role: MessageRole.user, text: text));
      _isTyping = true;
    });
    _controller.clear();
    _scrollToBottom();

    final response = await ChatService.generateResponse(text);
    setState(() {
      _messages.add(ChatMessage(role: MessageRole.assistant, text: response));
      _isTyping = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (!mounted) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    initialChildSize: 0.93,
    minChildSize: 0.6,
    maxChildSize: 0.95,
    builder: (context, _) => Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(color: AppColors.navy.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.blue.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.smart_toy_rounded, color: AppColors.blue, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  'Aegis AI',
                  style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.white),
                ),
                Text(
                  'Your insurance buddy 🤖',
                  style: GoogleFonts.nunito(fontSize: 15, color: AppColors.white.withOpacity(0.9)),
                ),
              ])),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: AppColors.white),
              ),
            ]),
          ]),
        ),
        // Messages List
        Expanded(child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: _messages.length,
          itemBuilder: (context, index) {
            final msg = _messages[index];
            return Align(
              alignment: msg.role == MessageRole.user ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                decoration: BoxDecoration(
                  color: msg.role == MessageRole.user ? AppColors.blue : Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 1)),
                  ],
                ),
                child: Text(msg.text, style: GoogleFonts.nunito(
                  color: msg.role == MessageRole.user ? AppColors.white : AppColors.dark,
                  height: 1.45,
                  fontSize: 15,
                )),
              ),
            );
          },
        )),
        // Input Row
        SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bg,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(children: [
              Expanded(child: TextField(
                controller: _controller,
                maxLines: null,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Type your question...',
                  hintStyle: GoogleFonts.nunito(color: AppColors.muted, fontSize: 15),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: AppColors.border, width: 1.2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: AppColors.blue, width: 2),
                  ),
                  filled: true,
                  fillColor: AppColors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                ),
              )),
              const SizedBox(width: 12),
              FloatingActionButton(
                onPressed: _sendMessage,
                heroTag: 'send_chat',
                backgroundColor: _isTyping ? Colors.grey : AppColors.blue,
                elevation: 2,
                child: _isTyping
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, color: AppColors.white),
              ),
            ]),
          ),
        ),
      ]),
    ),
  );

  Widget _typingIndicator() => const Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: EdgeInsets.only(bottom: 16, left: 16),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        SizedBox(width: 12),
        Text('Aegis is typing...', style: TextStyle(color: Colors.grey)),
      ]),
    ),
  );
}
