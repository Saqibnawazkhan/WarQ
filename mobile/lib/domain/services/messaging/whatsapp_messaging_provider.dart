import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/phone_number.dart';
import '../../../data/models/enums.dart';
import 'messaging_provider.dart';

/// Delivers absence notices through the WhatsApp app installed on the phone.
///
/// A `wa.me` link opens WhatsApp with the recipient and the message already
/// filled in; the teacher confirms with one tap. This needs no server, no API
/// key and no per-message cost, which is why it is the Phase 1 default.
///
/// It cannot send unattended — WhatsApp requires the user to press send, and
/// only one chat can be opened at a time. That is why [requiresUserAction] is
/// true: the absence pipeline queues the notices and the teacher dispatches
/// them from a list.
///
/// For fully automatic delivery, implement a provider that calls the WhatsApp
/// Cloud API through your own backend (the access token must never ship inside
/// the app) and register it in `AppDependencies` instead of this one. Nothing
/// else in the app changes.
class WhatsAppMessagingProvider extends MessagingProvider {
  const WhatsAppMessagingProvider({
    this.defaultCountryCode,
    this.smsFallback = true,
    this.launcher = _launch,
  });

  /// Dialling code applied to numbers stored in national format
  /// (`03001112222`). Without it such numbers cannot be addressed.
  final String? defaultCountryCode;

  /// Falls back to the SMS composer when WhatsApp cannot handle the link.
  final bool smsFallback;

  /// Injectable so tests can assert on the generated link without opening an
  /// external app.
  final Future<bool> Function(Uri uri) launcher;

  @override
  String get id => 'whatsapp.deeplink';

  @override
  String get displayName => 'WhatsApp';

  @override
  Set<MessageChannel> get supportedChannels => const <MessageChannel>{
        MessageChannel.whatsapp,
        MessageChannel.sms,
      };

  @override
  bool get isConfigured => true;

  @override
  bool get requiresUserAction => true;

  @override
  String get statusDescription =>
      'Opens WhatsApp with the message ready to send. Numbers stored without a '
      'country code need a default dialling code set in Profile.';

  @override
  bool canReach(String phone) => PhoneNumber.isReachable(
        phone,
        defaultCountryCode: defaultCountryCode,
      );

  /// Builds the `wa.me` link for a recipient, or `null` when the number cannot
  /// be normalised to international format.
  Uri? linkFor({required String phone, required String body}) {
    final String? number = PhoneNumber.toWhatsAppNumber(
      phone,
      defaultCountryCode: defaultCountryCode,
    );
    if (number == null) return null;
    return Uri.https('wa.me', '/$number', <String, String>{'text': body});
  }

  Uri? _smsLinkFor({required String phone, required String body}) {
    final String? number = PhoneNumber.toE164(
      phone,
      defaultCountryCode: defaultCountryCode,
    );
    if (number == null) return null;
    return Uri(
      scheme: 'sms',
      path: number,
      queryParameters: <String, String>{'body': body},
    );
  }

  @override
  Future<MessageDispatchResult> send(MessageRequest request) async {
    final Uri? link = linkFor(
      phone: request.recipientPhone,
      body: request.body,
    );
    if (link == null) {
      return const MessageDispatchResult.failed(
        MessageChannel.whatsapp,
        'That number is not in international format. Add a country code, or '
        'set a default dialling code in Profile.',
      );
    }

    try {
      if (await launcher(link)) {
        return const MessageDispatchResult.sent(MessageChannel.whatsapp);
      }
    } catch (error) {
      debugPrint('[whatsapp] launch failed: $error');
    }

    if (smsFallback) {
      final Uri? sms = _smsLinkFor(
        phone: request.recipientPhone,
        body: request.body,
      );
      if (sms != null) {
        try {
          if (await launcher(sms)) {
            return const MessageDispatchResult.sent(MessageChannel.sms);
          }
        } catch (error) {
          debugPrint('[whatsapp] sms fallback failed: $error');
        }
      }
    }

    return const MessageDispatchResult.failed(
      MessageChannel.whatsapp,
      'WhatsApp could not be opened on this device.',
    );
  }

  static Future<bool> _launch(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
}
