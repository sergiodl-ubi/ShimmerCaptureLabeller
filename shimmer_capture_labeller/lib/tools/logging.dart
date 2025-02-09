import 'package:flutter/foundation.dart';
import 'globals.dart' as globals;

DebugPrintCallback customDebugPrint(String contextID, bool enabled) =>
    (String? message, {int? wrapWidth}) {
      if (enabled && !globals.showDebugMessages) {
        return;
      }
      debugPrintThrottled("DEBUG $contextID: ${message ?? ''}",
          wrapWidth: wrapWidth);
    };
