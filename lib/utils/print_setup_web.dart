import 'dart:convert';
import 'dart:js_interop';

@JS('printKingdomSheet')
external JSBoolean? _printKingdomSheet(JSString sheet);

bool printSetup(Map<String, Object> sheet) {
  try {
    return _printKingdomSheet(jsonEncode(sheet).toJS)?.toDart ?? false;
  } catch (_) {
    return false;
  }
}
