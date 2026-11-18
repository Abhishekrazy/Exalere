import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/home_provider_row.dart';
import '../models/media_item.dart';
import 'media_provider_plugin.dart';

/// Builds Home's provider shelves from the rows each provider declares.
///
/// This is the piece Vega gets from `getHomepagedata.ts`: ask every provider for
/// the catalogues it advertises, tolerate a row that fails on its own, and never
/// let one unresponsive site hold the screen. It is a plain service rather than
/// part of [AppProvider] so the planning and failure rules can be tested without
/// a widget tree or the network.
class ProviderHomeRowsService {
  const ProviderHomeRowsService({
    this.timeout = const Duration(seconds: 12),
    this.maxRows = 8,
    this.maxRowsPerProvider = 2,
  });

  /// How long a single row may take before it is dropped.
  final Duration timeout;

  /// Upper bound on rows for the whole screen: enough to show what was
  /// installed, not so many that Home becomes a wall of duplicated posters.
  final int maxRows;

  /// Rows asked per provider before moving to the next one.
  final int maxRowsPerProvider;

  /// Loads the rows [providers] declare, in order.
  ///
  /// [isAllowed] filters individual titles (the adult-content rule lives in the
  /// caller). Providers whose feed throws, times out or comes back empty simply
  /// contribute no row; everything else is returned.
  Future<List<HomeProviderRow>> load(
    List<MediaProviderPlugin> providers, {
    bool Function(MediaItem item)? isAllowed,
  }) async {
    final rows = <HomeProviderRow>[];
    var budget = maxRows;

    for (final provider in providers) {
      if (budget <= 0) break;

      final declared = provider.catalogs
          .take(maxRowsPerProvider)
          .toList(growable: false);
      if (declared.isEmpty) continue;

      // Concurrent per provider (its rows are independent), sequential across
      // providers so one slow site cannot multiply the request fan-out.
      final fetched = await Future.wait(
        declared.map((row) async {
          try {
            return await provider
                .getCatalogFeed(category: row.category)
                .timeout(timeout);
          } catch (e) {
            debugPrint(
              '[ProviderHomeRowsService] ${provider.name} row '
              '"${row.title}" failed: $e',
            );
            return const <MediaItem>[];
          }
        }),
      );

      for (var i = 0; i < declared.length && budget > 0; i++) {
        final filtered = isAllowed == null
            ? fetched[i]
            : fetched[i].where(isAllowed).toList(growable: false);
        final items = _dedupe(filtered);
        if (items.isEmpty) continue;

        rows.add(
          HomeProviderRow(
            providerId: provider.id,
            providerName: provider.name,
            rowId: declared[i].id,
            title: declared[i].title,
            items: items,
          ),
        );
        budget--;
      }
    }

    return rows;
  }

  /// Drops titles a provider returned more than once in the same row.
  static List<MediaItem> _dedupe(List<MediaItem> items) {
    if (items.isEmpty) return const [];
    final seen = <String>{};
    return [
      for (final item in items)
        if (item.id.isNotEmpty && seen.add(item.id)) item,
    ];
  }
}
