import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../design_tokens.g.dart';
import '../domain/guest_session.dart';

class DeviceSessionsScreen extends StatefulWidget {
  const DeviceSessionsScreen({super.key, required this.load});

  final Future<List<DeviceSession>> Function() load;

  @override
  State<DeviceSessionsScreen> createState() => _DeviceSessionsScreenState();
}

class _DeviceSessionsScreenState extends State<DeviceSessionsScreen> {
  late Future<List<DeviceSession>> _sessions = widget.load();

  @override
  Widget build(BuildContext context) {
    final copy = AppLocalizations.of(context)!;
    final material = MaterialLocalizations.of(context);
    final style = Theme.of(context).textTheme;
    const space = HastaTokens.spacing;
    const subtitle = HastaTokens.myanmarType;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(space[7]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const BackButton(),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child:
                          Text(copy.securityDevices, style: style.titleLarge),
                    ),
                  ),
                ],
              ),
              SizedBox(height: space[4]),
              Text(copy.activeSessions, style: subtitle['subtitle']),
              SizedBox(height: space[4]),
              FutureBuilder<List<DeviceSession>>(
                future: _sessions,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return LinearProgressIndicator(
                        semanticsLabel: copy.loading);
                  }
                  if (snapshot.hasError) {
                    final error = snapshot.error;
                    final offline = error is AuthFailure && error.offline;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          liveRegion: true,
                          child:
                              Text(offline ? copy.offline : copy.genericError),
                        ),
                        TextButton(
                          onPressed: () {
                            final next = widget.load();
                            setState(() {
                              _sessions = next;
                            });
                          },
                          child: Text(copy.retry),
                        ),
                      ],
                    );
                  }
                  final sessions = snapshot.requireData;
                  if (sessions.isEmpty) return Text(copy.noActiveSessions);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final session in sessions)
                        Padding(
                          padding: EdgeInsets.only(bottom: space[4]),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                switch (session.platform) {
                                  'android' => copy.androidDevice,
                                  'ios' => copy.iosDevice,
                                  _ => copy.unknownDevice,
                                },
                                style: subtitle['subtitle'],
                              ),
                              if (session.current) Text(copy.currentSession),
                              Text(copy.sessionLastActive(
                                  material.formatMediumDate(
                                      session.lastActive.toLocal()))),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
