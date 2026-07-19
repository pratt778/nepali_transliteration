import 'package:flutter/material.dart';
import 'package:nepali_transliteration/src/logic/nepali_dictionary.dart';

/// Builds the ready UI once [NepaliDictionary.load] completes.
typedef NepaliDictionaryWidgetBuilder =
    Widget Function(BuildContext context, NepaliDictionary dictionary);

/// Builds a fallback UI for a load failure (e.g. a missing/corrupt asset).
typedef NepaliDictionaryErrorBuilder =
    Widget Function(BuildContext context, Object error);

/// Convenience wrapper around [NepaliDictionary.load] so callers don't have
/// to hand-roll `isLoading`/error `State` fields themselves. Drop this in
/// wherever the dictionary-backed UI (suggestion bar, sentence translation)
/// would otherwise go:
///
/// ```dart
/// NepaliDictionaryLoader(
///   builder: (context, dictionary) => MySuggestionBar(dictionary),
/// )
/// ```
///
/// [NepaliKeyboard] and [convertToNepali] need no loading at all and can be
/// used directly without this widget — it's only needed for the
/// dictionary-backed suggestion/sentence APIs.
///
/// Safe to mount more than once, or to unmount and remount later: repeat
/// calls to [NepaliDictionary.load] return the already-loaded singleton
/// instantly rather than re-reading the asset.
class NepaliDictionaryLoader extends StatefulWidget {
  const NepaliDictionaryLoader({
    super.key,
    required this.builder,
    this.loadingBuilder,
    this.errorBuilder,
    this.onReady,
  });

  /// Called with the ready [NepaliDictionary] once loading completes.
  final NepaliDictionaryWidgetBuilder builder;

  /// Shown while the dictionary asset is being read and indexed. Defaults to
  /// a centered [CircularProgressIndicator].
  final WidgetBuilder? loadingBuilder;

  /// Shown if [NepaliDictionary.load] throws. Defaults to a centered error
  /// icon and the error's `toString()`.
  final NepaliDictionaryErrorBuilder? errorBuilder;

  /// Fires exactly once, right after loading completes and before [builder]
  /// is first used — handy for one-off setup like restoring a previously
  /// [NepaliDictionary.loadLearned] snapshot.
  final void Function(NepaliDictionary dictionary)? onReady;

  @override
  State<NepaliDictionaryLoader> createState() => _NepaliDictionaryLoaderState();
}

class _NepaliDictionaryLoaderState extends State<NepaliDictionaryLoader> {
  late final Future<NepaliDictionary> _future = NepaliDictionary.load().then((
    dictionary,
  ) {
    widget.onReady?.call(dictionary);
    return dictionary;
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NepaliDictionary>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return widget.errorBuilder?.call(context, snapshot.error!) ??
              _DefaultError(error: snapshot.error!);
        }
        if (!snapshot.hasData) {
          return widget.loadingBuilder?.call(context) ??
              const _DefaultLoading();
        }
        return widget.builder(context, snapshot.data!);
      },
    );
  }
}

class _DefaultLoading extends StatelessWidget {
  const _DefaultLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _DefaultError extends StatelessWidget {
  const _DefaultError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: cs.error, size: 48),
            const SizedBox(height: 12),
            Text(
              'Failed to load Nepali dictionary asset',
              style: TextStyle(color: cs.error, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text('$error', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
