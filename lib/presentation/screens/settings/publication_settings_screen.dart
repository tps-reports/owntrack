import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:owntrack/core/utils/app_logger.dart';
import 'package:owntrack/data/services/tracking_publication_policy.dart';
import 'package:owntrack/domain/providers/app_providers.dart';

class PublicationSettingsScreen extends ConsumerStatefulWidget {
  const PublicationSettingsScreen({super.key});

  @override
  ConsumerState<PublicationSettingsScreen> createState() =>
      _PublicationSettingsScreenState();
}

class _PublicationSettingsScreenState
    extends ConsumerState<PublicationSettingsScreen> {
  final _form = GlobalKey<FormState>();
  final _interval = TextEditingController();
  final _distance = TextEditingController();
  final _heartbeat = TextEditingController();
  final _heading = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    try {
      _load(ref.read(settingsRepositoryProvider).getPublicationPolicy());
    } catch (_) {
      _load(TrackingPublicationPolicy());
      _error =
          'Saved publication settings could not be read. Review these defaults and save to repair them.';
      AppLogger.e('Unable to read publication settings.');
    }
  }

  void _load(TrackingPublicationPolicy policy) {
    _interval.text = policy.minimumInterval.inSeconds.toString();
    _distance.text = policy.minimumDistanceMeters.toString();
    _heartbeat.text = policy.heartbeatInterval.inSeconds.toString();
    _heading.text = policy.minimumHeadingChangeDegrees?.toString() ?? '';
  }

  @override
  void dispose() {
    _interval.dispose();
    _distance.dispose();
    _heartbeat.dispose();
    _heading.dispose();
    super.dispose();
  }

  String? _wholeSeconds(String? text, int minimum, int maximum) {
    final value = int.tryParse(text ?? '');
    return value == null || value < minimum || value > maximum
        ? 'Enter whole seconds from $minimum to $maximum'
        : null;
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(settingsRepositoryProvider)
          .setPublicationPolicy(
            TrackingPublicationPolicy(
              minimumInterval: Duration(seconds: int.parse(_interval.text)),
              minimumDistanceMeters: double.parse(_distance.text),
              heartbeatInterval: Duration(seconds: int.parse(_heartbeat.text)),
              minimumHeadingChangeDegrees: _heading.text.trim().isEmpty
                  ? null
                  : double.parse(_heading.text),
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Publication settings saved')),
        );
      }
    } catch (_) {
      AppLogger.e('Unable to save publication settings.');
      if (mounted) {
        setState(
          () => _error = 'Unable to save publication settings. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Publication settings')),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Automatic sharing waits for the minimum interval, then sends after enough movement, a qualifying heading change, or the heartbeat interval. Changes apply to the next location fix.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Heartbeat requires a fresh GPS fix; the operating system controls when fixes arrive. Quiet and Manual modes do not share automatically.',
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Semantics(liveRegion: true, child: Text(_error!)),
            ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('publication-interval'),
            controller: _interval,
            enabled: !_saving,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Minimum interval (seconds)',
            ),
            validator: (text) => _wholeSeconds(text, 5, 3600),
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('publication-distance'),
            controller: _distance,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Minimum movement (metres)',
            ),
            validator: (text) {
              final value = double.tryParse(text ?? '');
              return value == null ||
                      !value.isFinite ||
                      value < 1 ||
                      value > 10000
                  ? 'Enter metres from 1 to 10000'
                  : null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('publication-heartbeat'),
            controller: _heartbeat,
            enabled: !_saving,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Heartbeat interval (seconds)',
            ),
            validator: (text) {
              final rangeError = _wholeSeconds(text, 5, 86400);
              if (rangeError != null) return rangeError;
              return int.parse(text!) < (int.tryParse(_interval.text) ?? 0)
                  ? 'Heartbeat must be at least the minimum interval'
                  : null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('publication-heading'),
            controller: _heading,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Heading change (degrees, optional)',
              helperText:
                  'Leave blank to disable. Requires movement beyond GPS uncertainty.',
              helperMaxLines: 3,
            ),
            validator: (text) {
              if (text == null || text.trim().isEmpty) return null;
              final value = double.tryParse(text);
              return value == null ||
                      !value.isFinite ||
                      value < 1 ||
                      value > 180
                  ? 'Enter degrees from 1 to 180, or leave blank'
                  : null;
            },
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save publication settings'),
          ),
        ],
      ),
    ),
  );
}
