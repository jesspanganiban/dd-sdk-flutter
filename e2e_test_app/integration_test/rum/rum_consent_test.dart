// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:datadog_sdk/datadog_sdk.dart';
import 'package:e2e_test_app/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test_utils.dart';

/// ```global
/// $service = com.datadog.flutter.nightly
/// $feature = flutter_rum_consent
/// $monitor_name_prefix = [RUM] [Flutter (${{variant:-global}})] Nightly
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final datadog = DatadogSdk.instance;

  setUp(() {
    app.main();
  });

  tearDown(() async {
    await datadog.flushAndDeinitialize();
  });

  Future<void> sendRandomRumEvent(WidgetTester tester) async {
    final viewKey = randomString();
    final viewName = randomString();

    final rumEvents = [
      () async {
        await datadog.rum!.startView(viewKey, viewName, e2eAttributes(tester));
        await datadog.rum!.stopView(viewKey);
      },
      () async {
        final resourceKey = randomString();
        await datadog.rum!.startView(viewKey, viewName, e2eAttributes(tester));
        await datadog.rum!.startResourceLoading(
            resourceKey, RumHttpMethod.get, randomString());
        await datadog.rum!.stopResourceLoading(
            resourceKey, 200, RumResourceType.values.randomElement());
        await datadog.rum!.stopView(viewKey);
      },
      () async {
        await datadog.rum!.startView(viewKey, viewName, e2eAttributes(tester));
        await datadog.rum!.addErrorInfo(randomString(), RumErrorSource.custom);
        await datadog.rum!.stopView(viewKey);
      },
      () async {
        final actionName = randomString();
        await datadog.rum!.startView(viewKey, viewName, e2eAttributes(tester));
        await datadog.rum!.addUserAction(RumUserActionType.custom, actionName);
        await datadog.rum!.stopView(viewKey);
      }
    ];

    final event = rumEvents.randomElement();
    await event();
  }

  /// - data monitor:
  /// ```rum(ios, android)
  /// $monitor_prefix = ${{feature}}_granted
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} - ${{test_description}}: number of views is below expected value"
  /// $monitor_query = "rum(\"service:${{service}} @context.test_method_name:\\\"${{test_description}}\\\" @type:view @operating_system:${{variant}}\").index(\"*\").rollup(\"count\").last(\"1d\") < 1"
  /// ```
  testWidgets('rum consent - granted', (tester) async {
    await initializeDatadog();

    await sendRandomRumEvent(tester);
  });

  /// - data monitor:
  /// ```rum(ios, android)
  /// $monitor_prefix = ${{feature}}_not_granted
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} - ${{test_description}}: number of views is above expected value"
  /// $monitor_query = "rum(\"service:${{service}} @context.test_method_name:\\\"${{test_description}}\\\" @type:view @operating_system:${{variant}}\").index(\"*\").rollup(\"count\").last(\"1d\") > 0"
  /// $monitor_threshold = 0.0
  /// ```
  testWidgets('rum consent - not granted', (tester) async {
    await initializeDatadog(
        (config) => config.trackingConsent = TrackingConsent.notGranted);

    await sendRandomRumEvent(tester);
  });

  /// - data monitor:
  /// ```rum(ios, android)
  /// $monitor_prefix = ${{feature}}_pending
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} - ${{test_description}}: number of views is above expected value"
  /// $monitor_query = "rum(\"service:${{service}} @context.test_method_name:\\\"${{test_description}}\\\" @type:view @operating_system:${{variant}}\").index(\"*\").rollup(\"count\").last(\"1d\") > 0"
  /// $monitor_threshold = 0.0
  /// ```
  testWidgets('rum consent - pending', (tester) async {
    await initializeDatadog(
        (config) => config.trackingConsent = TrackingConsent.pending);

    await sendRandomRumEvent(tester);
  });

  /// - data monitor:
  /// ```rum(ios, android)
  /// $monitor_prefix = ${{feature}}_pending_to_granted
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} - ${{test_description}}: number of views is below expected value"
  /// $monitor_query = "rum(\"service:${{service}} @context.test_method_name:\\\"${{test_description}}\\\" @type:view @operating_system:${{variant}}\").index(\"*\").rollup(\"count\").last(\"1d\") < 1"
  /// ```
  testWidgets('rum consent - pending to granted', (tester) async {
    await initializeDatadog(
        (config) => config.trackingConsent = TrackingConsent.pending);

    await sendRandomRumEvent(tester);

    await datadog.setTrackingConsent(TrackingConsent.granted);
  });
}