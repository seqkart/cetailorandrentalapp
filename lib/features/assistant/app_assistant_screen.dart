import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/app_date_format.dart';
import '../../core/session_store.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/language_picker.dart';
import '../../widgets/stitch_loader.dart';
import '../rentals/rental_repository.dart';
import '../tailoring/tailoring_repository.dart';

enum _AssistantAction { createItem, createTailoringOrder, createRentalBooking }

class AppAssistantScreen extends StatefulWidget {
  const AppAssistantScreen({
    required this.session,
    required this.rentalRepository,
    required this.tailoringRepository,
    required this.onClose,
    required this.onStartTailoringOrder,
    required this.onOpenTailoringOrders,
    required this.onOpenRentals,
    required this.onCreateItem,
    this.onLocaleChanged,
    super.key,
  });

  final AuthSession session;
  final RentalRepository rentalRepository;
  final TailoringRepository tailoringRepository;
  final VoidCallback onClose;
  final VoidCallback onStartTailoringOrder;
  final VoidCallback onOpenTailoringOrders;
  final ValueChanged<int> onOpenRentals;
  final VoidCallback onCreateItem;
  final Future<void> Function(Locale locale)? onLocaleChanged;

  @override
  State<AppAssistantScreen> createState() => _AppAssistantScreenState();
}

class _AppAssistantScreenState extends State<AppAssistantScreen> {
  static const _voiceChannel = MethodChannel(
    'com.creativeease.ce_tailor_rentals/text_to_speech',
  );

  final _input = TextEditingController();
  final _scrollController = ScrollController();
  final _speech = SpeechToText();
  final List<_AssistantMessage> _messages = [];
  bool _speechAvailable = false;
  bool _listening = false;
  bool _searching = false;
  bool _voiceReplies = true;
  String? _speechError;

  @override
  void dispose() {
    _input.dispose();
    _scrollController.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }

    final strings = appStrings(context);
    final languageCode = Localizations.localeOf(context).languageCode;
    _speechError = null;
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          setState(() => _listening = status == 'listening');
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _listening = false;
            _speechError = error.errorMsg;
          });
        },
      );
      if (!_speechAvailable) {
        setState(() {
          _listening = false;
          _speechError = strings.speechUnavailable;
        });
        return;
      }
      final availableLocales = await _speech.locales();
      final speechLocale = availableLocales
          .where(
            (entry) =>
                entry.localeId
                    .toLowerCase()
                    .replaceAll('-', '_')
                    .split('_')
                    .first ==
                languageCode,
          )
          .firstOrNull;
      if (speechLocale == null) {
        final language = switch (languageCode) {
          'hi' => strings.hindi,
          'pa' => strings.punjabi,
          _ => strings.english,
        };
        setState(() {
          _listening = false;
          _speechError = strings.voiceSearchLanguageUnavailable(language);
        });
        return;
      }
      await _speech.listen(
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
          cancelOnError: true,
          localeId: speechLocale.localeId,
        ),
        onResult: (result) {
          if (!mounted) return;
          setState(() => _input.text = result.recognizedWords);
          if (result.finalResult) {
            _speech.stop();
            setState(() => _listening = false);
            _submit(result.recognizedWords);
          }
        },
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _listening = false;
        _speechError = strings.couldNotStartSpeech(error.toString());
      });
    }
  }

  Future<void> _submit([String? value]) async {
    final query = (value ?? _input.text).trim();
    if (query.isEmpty || _searching) return;
    _input.clear();
    setState(() {
      _messages.add(_AssistantMessage.user(query));
      _searching = true;
    });
    _scrollToBottom();

    final strings = appStrings(context);
    final action = _parseAction(query);
    if (action != null) {
      setState(() {
        _searching = false;
        _messages.add(
          _AssistantMessage.action(action, _actionResponse(action, strings)),
        );
      });
      _speak(_messages.last.text);
      _scrollToBottom();
      return;
    }

    final unavailable = _unavailableAction(query);
    if (unavailable != null) {
      setState(() {
        _searching = false;
        _messages.add(_AssistantMessage.text(unavailable));
      });
      _speak(unavailable);
      _scrollToBottom();
      return;
    }

    if (_isHelpRequest(query)) {
      setState(() {
        _searching = false;
        _messages.add(_AssistantMessage.text(strings.helpText));
      });
      _speak(strings.helpText);
      _scrollToBottom();
      return;
    }

    if (_isItemCreateRequest(query)) {
      setState(() {
        _searching = false;
        _messages.add(
          _AssistantMessage.action(
            _AssistantAction.createItem,
            strings.createItemResponse,
          ),
        );
      });
      _speak(_messages.last.text);
      _scrollToBottom();
      return;
    }

    await _searchRecords(query);
  }

  bool _isItemCreateRequest(String query) {
    final text = query.toLowerCase();
    final create =
        RegExp(r'\b(new|create|add|make)\b').hasMatch(text) ||
        RegExp(r'(नया|नई|बनाओ|बनाएं|जोड़ें|जोड़ें|ਨਵਾਂ|ਨਵੀਂ|ਬਣਾਓ|ਜੋੜੋ)')
            .hasMatch(text);
    final item =
        RegExp(r'\b(item|items|product|products)\b').hasMatch(text) ||
        RegExp(r'(आइटम|वस्तु|उत्पाद|ਆਈਟਮ|ਚੀਜ਼)').hasMatch(text);
    return create && item;
  }

  _AssistantAction? _parseAction(String query) {
    final text = query.toLowerCase();
    final create =
        RegExp(r'\b(new|create|add|make|start|book|booking)\b')
            .hasMatch(text) ||
        RegExp(
          r'(नया|नई|बनाओ|बनाएं|शुरू|बुक|करो|ਕਰੋ|ਨਵਾਂ|ਨਵੀਂ|ਬਣਾਓ|ਸ਼ੁਰੂ|ਬੁੱਕ)',
        ).hasMatch(text);
    if (!create) return null;

    final rental =
        RegExp(r'\b(rental|rentals|rent|booking|bookings)\b').hasMatch(text) ||
        RegExp(r'(किराया|किराये|बुकिंग|ਭਾੜਾ|ਕਿਰਾਇਆ|ਬੁਕਿੰਗ)').hasMatch(text);
    final tailoringEnglish = RegExp(
      r'\b(tailor|tailoring|stitch|stitching|order|orders)\b',
    ).hasMatch(text);
    final tailoring =
        tailoringEnglish ||
        RegExp(r'(सिलाई|दर्जी|ऑर्डर|ਆਰਡਰ|ਸਿਲਾਈ|ਦਰਜ਼ੀ)').hasMatch(text);
    final item =
        RegExp(r'\b(item|items|product|products)\b').hasMatch(text) ||
        RegExp(r'(आइटम|वस्तु|उत्पाद|ਆਈਟਮ|ਚੀਜ਼)').hasMatch(text);
    if (item) return _AssistantAction.createItem;
    if (rental && widget.session.canViewRentals) {
      return _AssistantAction.createRentalBooking;
    }
    if (tailoring && widget.session.canViewTailoring) {
      return _AssistantAction.createTailoringOrder;
    }
    return null;
  }

  String? _unavailableAction(String query) {
    final text = query.toLowerCase();
    final create =
        RegExp(r'\b(new|create|add|make|start|book|booking)\b')
            .hasMatch(text) ||
        RegExp(
          r'(नया|नई|बनाओ|बनाएं|शुरू|बुक|करो|ਨਵਾਂ|ਨਵੀਂ|ਬਣਾਓ|ਸ਼ੁਰੂ|ਬੁੱਕ|ਕਰੋ)',
        ).hasMatch(text);
    if (!create) return null;
    if ((RegExp(r'\b(rental|rentals|rent|booking|bookings)\b').hasMatch(text) ||
            RegExp(r'(किराया|किराये|बुकिंग|ਭਾੜਾ|ਕਿਰਾਇਆ|ਬੁਕਿੰਗ)')
                .hasMatch(text)) &&
        !widget.session.canViewRentals) {
      return appStrings(context).rentalAccessDenied;
    }
    if ((RegExp(r'\b(tailor|tailoring|stitch|stitching|order|orders)\b')
                .hasMatch(text) ||
            RegExp(r'(सिलाई|दर्जी|ऑर्डर|ਆਰਡਰ|ਸਿਲਾਈ|ਦਰਜ਼ੀ)').hasMatch(text)) &&
        !widget.session.canViewTailoring) {
      return appStrings(context).tailoringAccessDenied;
    }
    return null;
  }

  bool _isHelpRequest(String query) {
    final text = query.toLowerCase().trim();
    return text == 'help' ||
        text.contains('what can you do') ||
        text.contains('how do i use') ||
        RegExp(r'(मदद|सहायता|क्या कर सकते|ਮਦਦ|ਸਹਾਇਤਾ|ਕੀ ਕਰ ਸਕਦੇ)')
            .hasMatch(text);
  }

  String _actionResponse(_AssistantAction action, AppLocalizations strings) =>
      switch (action) {
        _AssistantAction.createItem => strings.createItemResponse,
        _AssistantAction.createTailoringOrder =>
          strings.createTailoringResponse,
        _AssistantAction.createRentalBooking => strings.createRentalResponse,
      };

  Future<void> _searchRecords(String query) async {
    final records = <_AssistantRecord>[];
    final errors = <String>[];
    final tasks = <Future<void>>[];

    Future<void> load(
      String label,
      String kind,
      Future<List<Map<String, dynamic>>> Function() request,
    ) async {
      try {
        final rows = await request();
        for (final row in rows) {
          if (_matches(row, query)) {
            records.add(_AssistantRecord.fromMap(kind, row));
          }
        }
      } catch (error) {
        errors.add('$label: $error');
      }
    }

    if (widget.session.canViewTailoring) {
      tasks.add(
        load(
          'Tailoring orders',
          'Tailoring order',
          () => widget.tailoringRepository.loadOrdersByType(
            widget.session,
            status: 'All',
          ),
        ),
      );
    }
    if (widget.session.canViewRentals) {
      final today = DateUtils.dateOnly(DateTime.now());
      tasks.add(
        load(
          'Rental bookings',
          'Rental booking',
          () => widget.rentalRepository.loadBookings(widget.session),
        ),
      );
      tasks.add(
        load(
          'Rental catalogue',
          'Rental item',
          () => widget.rentalRepository.loadCatalog(
            widget.session,
            fromDate: today,
            toDate: today.add(const Duration(days: 365)),
          ),
        ),
      );
      tasks.add(
        load(
          'Customers',
          'Customer',
          () => widget.rentalRepository.loadCustomers(widget.session),
        ),
      );
      tasks.add(
        load(
          'Item Master',
          'Item',
          () => widget.rentalRepository.loadItems(widget.session),
        ),
      );
    } else if (widget.session.canViewTailoring) {
      tasks.add(
        load(
          'Customers',
          'Customer',
          () => widget.tailoringRepository.loadCustomers(widget.session),
        ),
      );
      tasks.add(
        load(
          'Item Master',
          'Item',
          () => widget.tailoringRepository.loadItems(widget.session),
        ),
      );
    }

    await Future.wait(tasks);
    if (!mounted) return;
    final uniqueRecords = <String, _AssistantRecord>{};
    for (final record in records) {
      uniqueRecords.putIfAbsent(record.key, () => record);
    }
    final results = uniqueRecords.values.take(25).toList();
    setState(() {
      _searching = false;
      _messages.add(
        _AssistantMessage.searchResults(
          results,
          errors,
          query: query,
          strings: appStrings(context),
        ),
      );
    });
    _speak(_messages.last.text);
    _scrollToBottom();
  }

  bool _matches(Map<String, dynamic> record, String query) {
    final searchable = <String>[];
    void visit(Object? value, [String key = '']) {
      if (key.toLowerCase().contains('photo') ||
          key.toLowerCase().contains('base64')) {
        return;
      }
      if (value is Map) {
        for (final entry in value.entries) {
          visit(entry.value, entry.key.toString());
        }
      } else if (value is Iterable) {
        for (final item in value) {
          visit(item, key);
        }
      } else if (value != null) {
        searchable.add(value.toString().toLowerCase());
      }
    }

    visit(record);
    final normalized = query.toLowerCase().trim();
    final term = normalized.replaceFirst(
      RegExp(
        r'^(please\s+)?(search|find|show|look up)\s+(for\s+)?(a\s+)?(customer|order|rental|booking|item|catalogue|catalog)?\s*|^(कृपया\s*)?(खोजो|दिखाओ|खोजें|दिखाएं)\s*(ग्राहक|ऑर्डर|बुकिंग|आइटम)?\s*|^(ਕਿਰਪਾ ਕਰਕੇ\s*)?(ਖੋਜੋ|ਦਿਖਾਓ)\s*(ਗਾਹਕ|ਆਰਡਰ|ਬੁਕਿੰਗ|ਆਈਟਮ)?\s*',
        caseSensitive: false,
      ),
      '',
    );
    return term.isEmpty ||
        searchable.any((field) => field.contains(term)) ||
        (normalized.length >= 3 &&
            searchable.any((field) => field.contains(normalized)));
  }

  void _openRecord(_AssistantRecord record) {
    switch (record.kind) {
      case 'Tailoring order':
        widget.onOpenTailoringOrders();
      case 'Rental booking':
      case 'Rental item':
        widget.onOpenRentals(record.kind == 'Rental booking' ? 1 : 0);
      case 'Customer':
      case 'Item':
        if (widget.session.canViewTailoring) {
          widget.onOpenTailoringOrders();
        } else {
          widget.onOpenRentals(0);
        }
    }
  }

  void _openAction(_AssistantAction action) {
    switch (action) {
      case _AssistantAction.createItem:
        widget.onCreateItem();
      case _AssistantAction.createTailoringOrder:
        widget.onStartTailoringOrder();
      case _AssistantAction.createRentalBooking:
        widget.onOpenRentals(0);
    }
  }

  Future<void> _speak(String text) async {
    if (!_voiceReplies || text.trim().isEmpty) return;
    try {
      final languageCode = Localizations.localeOf(context).languageCode;
      final languageTag = switch (languageCode) {
        'hi' => 'hi-IN',
        'pa' => 'pa-IN',
        _ => 'en-US',
      };
      await _voiceChannel.invokeMethod<void>('speak', {
        'text': text,
        'locale': languageTag,
      });
      if (mounted && _speechError != null) {
        setState(() => _speechError = null);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _speechError = 'Could not speak the reply: $error');
    }
  }

  Future<void> _toggleVoiceReplies() async {
    final enabled = !_voiceReplies;
    setState(() => _voiceReplies = enabled);
    try {
      if (enabled && _messages.isNotEmpty) {
        await _speak(_messages.last.text);
      } else {
        await _voiceChannel.invokeMethod<void>('stop');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _speechError = 'Could not update voice replies: $error');
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = appStrings(context);
    final locale = Localizations.localeOf(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: strings.assistantName,
          onPressed: widget.onClose,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: Color(0xFF1688E8)),
            const SizedBox(width: 9),
            Text(strings.assistantName),
          ],
        ),
        actions: [
          if (widget.onLocaleChanged != null)
            LanguagePicker(locale: locale, onChanged: widget.onLocaleChanged!),
          IconButton(
            tooltip: _voiceReplies
                ? 'Turn off voice replies'
                : 'Turn on voice replies',
            onPressed: _toggleVoiceReplies,
            icon: Icon(
              _voiceReplies
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFE9F4FF),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0xFFD2E8FB)),
              ),
              child: Text(
                strings.askByTypingOrSpeak,
                style: TextStyle(color: Color(0xFF365472), fontSize: 12),
              ),
            ),
            Expanded(
              child: _messages.isEmpty
                  ? _welcome()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: _messages.length + (_searching ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_searching && index == _messages.length) {
                          return const Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: StitchLoader(
                                size: 40,
                                showMonogram: false,
                              ),
                            ),
                          );
                        }
                        return _messageCard(_messages[index]);
                      },
                    ),
            ),
            if (_speechError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  _speechError!,
                  style: const TextStyle(
                    color: Color(0xFFB42336),
                    fontSize: 12,
                  ),
                ),
              ),
            _inputBar(),
          ],
        ),
      ),
    );
  }

  Widget _welcome() {
    final strings = appStrings(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 34,
              backgroundColor: Color(0xFFE5F2FF),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 32,
                color: Color(0xFF1688E8),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              strings.howCanIHelp,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              strings.assistantWelcome,
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF718198)),
            ),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (widget.session.canViewTailoring)
                  _suggestion(strings.suggestCreateTailoring),
                if (widget.session.canViewRentals)
                  _suggestion(strings.suggestRental),
                _suggestion(strings.suggestCreateItem),
                _suggestion(strings.suggestHelp),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _suggestion(String text) => ActionChip(
    avatar: const Icon(Icons.arrow_outward_rounded, size: 16),
    label: Text(text),
    onPressed: () => _submit(text),
  );

  Widget _inputBar() {
    final strings = appStrings(context);
    return Material(
      color: Colors.white,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton.filledTonal(
                tooltip: _listening
                    ? strings.stopListening
                    : strings.speakRequest,
                onPressed: _searching ? null : _toggleListening,
                icon: Icon(
                  _listening ? Icons.stop_rounded : Icons.mic_none_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  selectAllOnFocus: true,
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: strings.typeRequest,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: strings.sendRequest,
                onPressed: _searching ? null : _submit,
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _messageCard(_AssistantMessage message) {
    final isUser = message.isUser;
    final strings = appStrings(context);
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF1688E8) : Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: isUser ? null : Border.all(color: const Color(0xFFDCEAF8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.text.isNotEmpty)
              Text(
                message.text,
                style: TextStyle(
                  color: isUser ? Colors.white : const Color(0xFF26374A),
                ),
              ),
            if (message.action != null) ...[
              const SizedBox(height: 11),
              FilledButton.icon(
                onPressed: () => _openAction(message.action!),
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(switch (message.action!) {
                  _AssistantAction.createItem => strings.openItemMaster,
                  _AssistantAction.createTailoringOrder => strings.openNewOrder,
                  _AssistantAction.createRentalBooking =>
                    strings.openRentalBooking,
                }),
              ),
            ],
            if (message.results.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final record in message.results)
                Material(
                  type: MaterialType.transparency,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFE9F4FF),
                      child: Icon(
                        record.icon,
                        size: 19,
                        color: const Color(0xFF1688E8),
                      ),
                    ),
                    title: Text(record.title, maxLines: 1),
                    subtitle: Text(
                      '${record.kind}${record.subtitle.isEmpty ? '' : ' · ${record.subtitle}'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _openRecord(record),
                  ),
                ),
            ],
            if (message.errors.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Some app data could not be searched:\n${message.errors.join('\n')}',
                style: const TextStyle(color: Color(0xFF9A5B00), fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AssistantMessage {
  const _AssistantMessage({
    this.text = '',
    this.isUser = false,
    this.action,
    this.results = const [],
    this.errors = const [],
  });

  factory _AssistantMessage.user(String text) =>
      _AssistantMessage(text: text, isUser: true);

  factory _AssistantMessage.text(String text) => _AssistantMessage(text: text);

  factory _AssistantMessage.action(_AssistantAction action, String text) =>
      _AssistantMessage(text: text, action: action);

  factory _AssistantMessage.searchResults(
    List<_AssistantRecord> results,
    List<String> errors, {
    required String query,
    required AppLocalizations strings,
  }) => _AssistantMessage(
    text: results.isEmpty
        ? strings.noSearchMatch(query)
        : strings.searchMatchCount(results.length, query),
    results: results,
    errors: errors,
  );

  final String text;
  final bool isUser;
  final _AssistantAction? action;
  final List<_AssistantRecord> results;
  final List<String> errors;
}

class _AssistantRecord {
  const _AssistantRecord({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.key,
    required this.icon,
  });

  factory _AssistantRecord.fromMap(String kind, Map<String, dynamic> map) {
    String firstValue(List<String> keys) {
      for (final key in keys) {
        final value = map[key]?.toString().trim() ?? '';
        if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
      }
      return '';
    }

    final title = firstValue([
      'orderNo',
      'bookingNo',
      'rentNo',
      'fullName',
      'customerName',
      'itemName',
      'groupName',
      'name',
    ]);
    final id = firstValue([
      'orderID',
      'bookingID',
      'rentID',
      'customerID',
      'itemId',
      'itemID',
    ]);
    final dateValue = firstValue(['orderDate', 'bookingDate', 'rentDate']);
    final displayDate = formatDateValue(dateValue) ?? dateValue;
    final subtitle = [
      firstValue(['mobileNo', 'itemCode']),
      firstValue(['status', 'orderStatus']),
      displayDate,
    ].where((part) => part.isNotEmpty).join(' · ');
    return _AssistantRecord(
      kind: kind,
      title: title.isEmpty ? '$kind ${id.isEmpty ? '' : id}' : title,
      subtitle: subtitle,
      key: '$kind:${id.isEmpty ? title : id}',
      icon: switch (kind) {
        'Tailoring order' => Icons.content_cut_rounded,
        'Rental booking' => Icons.event_note_outlined,
        'Rental item' || 'Item' => Icons.checkroom_outlined,
        _ => Icons.person_outline_rounded,
      },
    );
  }

  final String kind;
  final String title;
  final String subtitle;
  final String key;
  final IconData icon;
}
