import 'package:flutter/material.dart';

import '../../services/viewing_stats_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/tv_focusable.dart';

/// Viewing Habits & Streaming Insights Screen (Year in Review dashboard).
class ViewingStatsScreen extends StatefulWidget {
  const ViewingStatsScreen({super.key});

  @override
  State<ViewingStatsScreen> createState() => _ViewingStatsScreenState();
}

class _ViewingStatsScreenState extends State<ViewingStatsScreen> {
  final ViewingStatsService _service = ViewingStatsService();
  ViewingStats? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await _service.computeStats();
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isTv = size.width > 900;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: theme.colorScheme.primary,
                ),
              )
            : SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isTv ? 48 : 20,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top App Bar
                    Row(
                      children: [
                        TvFocusable(
                          autofocus: true,
                          scaleFactor: 1.1,
                          shape: tokens.shapePill,
                          borderRadius: tokens.borderRadiusPill,
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: tokens.surfaceElevated,
                              borderRadius: tokens.borderRadiusPill,
                              border: Border.all(color: tokens.borderSubtle),
                            ),
                            child: Icon(
                              Icons.arrow_back_rounded,
                              color: tokens.textPrimary,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Viewing Habits & Insights',
                              style: TextStyle(
                                fontSize: isTv ? 24 : 20,
                                fontWeight: FontWeight.bold,
                                color: tokens.textPrimary,
                              ),
                            ),
                            Text(
                              'Private, local analytics of your cinema & TV journey',
                              style: TextStyle(
                                fontSize: 13,
                                color: tokens.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Hero Banner Card
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isTv ? 32 : 22),
                      decoration: BoxDecoration(
                        gradient: tokens.heroGradient,
                        borderRadius: tokens.borderRadiusLg,
                        border: Border.all(
                          color: tokens.borderFocus.withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: tokens.shadowColor.withValues(alpha: 0.35),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: isTv ? 72 : 56,
                            height: isTv ? 72 : 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.2,
                              ),
                              border: Border.all(
                                color: tokens.primaryAccent,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.emoji_events_rounded,
                              size: isTv ? 38 : 28,
                              color: tokens.primaryAccent,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TOTAL TIME STREAMED',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                    color: tokens.primaryAccent,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _stats?.formattedTotalTime ?? '0 mins',
                                  style: TextStyle(
                                    fontSize: isTv ? 32 : 24,
                                    fontWeight: FontWeight.bold,
                                    color: tokens.textPrimary,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Across ${_stats?.totalUniqueTitles ?? 0} titles watched on Exalere',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: tokens.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 4 Grid Metric Cards
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 700;
                        return GridView.count(
                          crossAxisCount: isWide ? 4 : 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: isWide ? 1.4 : 1.2,
                          children: [
                            _buildStatCard(
                              title: 'Movies Watched',
                              value: '${_stats?.moviesWatchedCount ?? 0}',
                              subtitle: 'Feature films',
                              icon: Icons.movie_rounded,
                            ),
                            _buildStatCard(
                              title: 'Episodes Logged',
                              value: '${_stats?.episodesWatchedCount ?? 0}',
                              subtitle: 'Series chapters',
                              icon: Icons.tv_rounded,
                            ),
                            _buildStatCard(
                              title: 'Completion Rate',
                              value:
                                  '${((_stats?.completionPercentage ?? 0.0) * 100).round()}%',
                              subtitle: 'Finished to credits',
                              icon: Icons.task_alt_rounded,
                            ),
                            _buildStatCard(
                              title: 'Active Days',
                              value: '${_stats?.activeStreakDays ?? 0} days',
                              subtitle: 'Viewing habit',
                              icon: Icons.local_fire_department_rounded,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 32),

                    // Habits Breakdown (Top Day & Peak Hour)
                    Text(
                      'Streaming Habits',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: tokens.surfaceCard,
                              borderRadius: tokens.borderRadiusMd,
                              border: Border.all(color: tokens.borderSubtle),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_month_rounded,
                                  color: tokens.primaryAccent,
                                  size: 28,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'FAVORITE STREAMING DAY',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: tokens.textSecondary,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _stats?.topDayOfWeek ?? 'Weekends',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: tokens.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: tokens.surfaceCard,
                              borderRadius: tokens.borderRadiusMd,
                              border: Border.all(color: tokens.borderSubtle),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.access_time_filled_rounded,
                                  color: tokens.secondaryAccent,
                                  size: 28,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'PEAK VIEWING WINDOW',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: tokens.textSecondary,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _stats?.peakTimeOfDay ??
                                            'Prime Evening',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: tokens.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Top Genres Breakdown
                    if (_stats?.genreBreakdown != null &&
                        _stats!.genreBreakdown.isNotEmpty) ...[
                      Text(
                        'Top Genres Explored',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: tokens.surfaceCard,
                          borderRadius: tokens.borderRadiusMd,
                          border: Border.all(color: tokens.borderSubtle),
                        ),
                        child: Column(
                          children: _stats!.genreBreakdown.entries.take(5).map((
                            entry,
                          ) {
                            final total = _stats!.genreBreakdown.values
                                .fold<int>(0, (sum, count) => sum + count);
                            final pct = total > 0 ? (entry.value / total) : 0.0;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        entry.key,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: tokens.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        '${(pct * 100).round()}% (${entry.value} titles)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: tokens.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: tokens.borderRadiusPill,
                                    child: LinearProgressIndicator(
                                      value: pct,
                                      minHeight: 8,
                                      backgroundColor: tokens.surfaceElevated,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
  }) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surfaceCard,
        borderRadius: tokens.borderRadiusMd,
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: tokens.textSecondary,
                ),
              ),
              Icon(icon, size: 18, color: theme.colorScheme.primary),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: tokens.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: tokens.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
