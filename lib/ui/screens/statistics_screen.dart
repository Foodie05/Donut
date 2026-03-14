import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:math' as math;
import '../../data/models/book.dart';
import '../../data/models/reading_session.dart';
import '../../data/repositories/book_repository.dart';
import '../../objectbox.g.dart';
import '../../providers.dart';
import '../../l10n/app_localizations.dart';

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // Localized strings will be handled in build
  List<String> _tabs = []; 

  @override
  void initState() {
    super.initState();
    // Initialize with placeholders, update in didChangeDependencies
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = AppLocalizations.of(context)!;
    _tabs = [l10n.day, l10n.week, l10n.month, l10n.year, l10n.all];
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.statistics),
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
          isScrollable: true,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: ['Day', 'Week', 'Month', 'Year', 'All'].map((range) => _StatsView(range: range)).toList(),
      ),
    );
  }
}

class _StatsView extends ConsumerWidget {
  final String range;

  const _StatsView({required this.range});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<_StatsData>(
      future: _fetchStats(ref, range),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        final data = snapshot.data!;
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Overview Card
              _OverviewCard(totalDuration: data.totalDuration, range: range),
              const Gap(24),
              
              // 2. Frequency Chart
              Text(l10n.readingFrequency, style: Theme.of(context).textTheme.titleLarge),
              const Gap(8), // Reduced gap
              AspectRatio(
                aspectRatio: 6.0, // Reduced height (was 2.0, now 1/3 height means aspect ratio x3)
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0), // Narrower width
                  child: _FrequencyChart(spots: data.chartSpots),
                ),
              ),
              const Gap(24),
              
              // 3. Book Rankings
              Text(l10n.topBooks, style: Theme.of(context).textTheme.titleLarge),
              const Gap(8), // Reduced gap
              _BookRankingList(bookStats: data.bookStats),
            ],
          ),
        );
      },
    );
  }

  Future<_StatsData> _fetchStats(WidgetRef ref, String range) async {
    final store = ref.read(storeProvider);
    final sessionBox = store.box<ReadingSession>();
    
    DateTime now = DateTime.now();
    DateTime start;
    DateTime end = now;

    switch (range) {
      case 'Day':
        start = DateTime(now.year, now.month, now.day);
        break;
      case 'Week':
        // Start of week (Monday)
        start = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        break;
      case 'Month':
        start = DateTime(now.year, now.month, 1);
        break;
      case 'Year':
        start = DateTime(now.year, 1, 1);
        break;
      case 'All':
      default:
        start = DateTime(1970);
        break;
    }

    // Query Sessions
    final query = sessionBox.query(
      ReadingSession_.startTime.greaterOrEqual(start.millisecondsSinceEpoch)
          .and(ReadingSession_.startTime.lessOrEqual(end.millisecondsSinceEpoch))
    ).build();
    
    final sessions = query.find();
    query.close();

    // Aggregation
    int totalSeconds = 0;
    final Map<int, int> bookDurationMap = {}; // bookId -> seconds
    
    // Initialize buckets (0-11 for 24h, 2h each)
    final Map<int, int> timeBuckets = {};
    for (int i = 0; i < 12; i++) timeBuckets[i] = 0;

    for (final session in sessions) {
      totalSeconds += session.duration;
      
      // Book Ranking
      final bookId = session.book.targetId;
      if (bookId != 0) {
        bookDurationMap[bookId] = (bookDurationMap[bookId] ?? 0) + session.duration;
      }

      // Chart Distribution (Time of Day)
      // Logic: Split session duration across time buckets if it spans across them
      DateTime current = session.startTime;
      // Use duration directly or calculate from end time?
      // session.duration is in seconds.
      // If endTime is missing, we assume session.duration is valid from startTime.
      int remainingSeconds = session.duration;
      
      // Safety check: Ignore unrealistically long sessions (e.g., > 24 hours) or future timestamps
      if (remainingSeconds > 86400 || session.startTime.isAfter(DateTime.now())) {
        continue; 
      }

      while (remainingSeconds > 0) {
        // Find which bucket current time falls into
        int hour = current.hour;
        int bucketIndex = (hour / 2).floor(); // 0-11
        
        // Calculate seconds until next bucket
        // Next bucket starts at (bucketIndex + 1) * 2 hours
        int nextBucketHour = (bucketIndex + 1) * 2;
        
        // Time until next bucket boundary from current time
        DateTime nextBoundary = DateTime(current.year, current.month, current.day, nextBucketHour % 24, 0, 0);
        
        // Fix: If nextBucketHour is 24 (or 0 next day), we need to handle day rollover correctly
        if (nextBucketHour >= 24) {
           nextBoundary = DateTime(current.year, current.month, current.day).add(const Duration(days: 1));
        } else if (nextBucketHour <= current.hour) {
           // Handle case where we might have crossed midnight in calculation logic or logic error
           // But here (bucketIndex + 1) * 2 is always > current.hour because bucketIndex = floor(hour/2)
           // e.g. hour=23, bucket=11, next=24. hour=0, bucket=0, next=2.
           // So nextBucketHour is strictly > hour (except if hour is 23, next is 24)
        }
        
        int secondsToBoundary = nextBoundary.difference(current).inSeconds;
        
        // Determine how much time belongs to this bucket
        int secondsInBucket = math.min(remainingSeconds, secondsToBoundary);
        
        // Safety: ensure positive
        if (secondsInBucket <= 0) {
           // Should not happen if logic is correct, but break to avoid infinite loop
           break; 
        }

        timeBuckets[bucketIndex] = (timeBuckets[bucketIndex] ?? 0) + secondsInBucket;
        
        remainingSeconds -= secondsInBucket;
        current = current.add(Duration(seconds: secondsInBucket));
      }
    }

    // Prepare Chart Spots
    final List<FlSpot> chartSpots = [];
    for (int i = 0; i < 12; i++) {
      // Y axis: Minutes
      // Ensure unit is correct: seconds / 60
      double minutes = (timeBuckets[i] ?? 0) / 60.0;
      chartSpots.add(FlSpot(i.toDouble(), minutes));
    }

    // Prepare Book Ranking
    final List<_BookStat> bookStats = [];
    final bookBox = store.box<Book>();
    for (final entry in bookDurationMap.entries) {
      final book = bookBox.get(entry.key);
      if (book != null) {
        bookStats.add(_BookStat(book, entry.value));
      }
    }
    bookStats.sort((a, b) => b.durationSeconds.compareTo(a.durationSeconds)); // Descending

    return _StatsData(
      totalDuration: Duration(seconds: totalSeconds),
      chartSpots: chartSpots,
      bookStats: bookStats,
    );
  }
}

class _StatsData {
  final Duration totalDuration;
  final List<FlSpot> chartSpots;
  final List<_BookStat> bookStats;

  _StatsData({
    required this.totalDuration,
    required this.chartSpots,
    required this.bookStats,
  });
}

class _BookStat {
  final Book book;
  final int durationSeconds;

  _BookStat(this.book, this.durationSeconds);
}

class _OverviewCard extends StatelessWidget {
  final Duration totalDuration;
  final String range;

  const _OverviewCard({required this.totalDuration, required this.range});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final hours = totalDuration.inHours;
    final minutes = totalDuration.inMinutes % 60;
    
    // Convert range key to localized string
    String localizedRange;
    switch(range) {
      case 'Day': localizedRange = l10n.day; break;
      case 'Week': localizedRange = l10n.week; break;
      case 'Month': localizedRange = l10n.month; break;
      case 'Year': localizedRange = l10n.year; break;
      case 'All': localizedRange = l10n.all; break;
      default: localizedRange = range;
    }

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${l10n.readingTime} ($localizedRange)',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Gap(24),
              // Semi-circle Progress Arc
              SizedBox(
                width: 200,
                height: 100, // Half of width
                child: CustomPaint(
                  painter: _ArcPainter(
                    color: theme.colorScheme.primary,
                    trackColor: theme.colorScheme.surfaceContainerHighest,
                    // Example goal logic: Day=1h, Week=7h, etc.
                    percent: (totalDuration.inMinutes / 60.0).clamp(0.0, 1.0), 
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${hours}${l10n.hourShort} ${minutes}${l10n.minuteShort}',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const Gap(4),
                          Text(
                            '${l10n.goal} 60${l10n.minuteShort}', // Example hardcoded goal
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final Color color;
  final Color trackColor;
  final double percent;

  _ArcPainter({required this.color, required this.trackColor, required this.percent});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2;
    final strokeWidth = 20.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Draw Track (Full semi-circle)
    paint.color = trackColor;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      math.pi, // Start from 180 degrees (left)
      math.pi, // Sweep 180 degrees
      false,
      paint,
    );

    // Draw Progress
    paint.color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      math.pi,
      math.pi * percent,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) {
    return oldDelegate.percent != percent || oldDelegate.color != color;
  }
}

class _FrequencyChart extends StatelessWidget {
  final List<FlSpot> spots;

  const _FrequencyChart({required this.spots});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    
    // Calculate Y axis max to avoid top clipping
    double maxY = 0;
    for (final spot in spots) {
      if (spot.y > maxY) maxY = spot.y;
    }
    
    // Minimal dynamic padding (10%) to prevent touching top, but keep it tight
    // If maxY is very small (e.g. < 5), give it a bit more room to look normal
    if (maxY < 5) {
      maxY = 5;
    } else {
      maxY = maxY * 1.05; // Reduced buffer from 1.1 to 1.05 (5%)
    }

    return LineChart(
      LineChartData(
        minY: 0, // Force Y-axis start at 0
        maxY: maxY, // Tighter dynamic max
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                // 0 -> 00:00, 1 -> 02:00, ... 11 -> 22:00
                final hour = (value * 2).toInt();
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text('$hour:00', style: theme.textTheme.labelSmall),
                );
              },
              interval: 2, // Show every 4 hours (interval 2 * 2h buckets = 4h)
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            preventCurveOverShooting: true, // Prevent curves dipping below 0
            color: theme.colorScheme.primary,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.3),
                  theme.colorScheme.primary.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => theme.colorScheme.surfaceContainerHighest,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final minutes = spot.y.toInt();
                final hourStart = (spot.x * 2).toInt();
                final hourEnd = hourStart + 2;
                return LineTooltipItem(
                  '$hourStart:00 - $hourEnd:00\n$minutes${l10n.minuteShort}',
                  TextStyle(color: theme.colorScheme.onSurface),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}

class _BookRankingList extends StatelessWidget {
  final List<_BookStat> bookStats;

  const _BookRankingList({required this.bookStats});

  @override
  Widget build(BuildContext context) {
    if (bookStats.isEmpty) {
      return const Center(child: Text('No reading data yet.'));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: bookStats.length,
      itemBuilder: (context, index) {
        final stat = bookStats[index];
        final duration = Duration(seconds: stat.durationSeconds);
        final hours = duration.inHours;
        final minutes = duration.inMinutes % 60;

        return ListTile(
          leading: Container(
            width: 40,
            height: 60,
            color: Colors.grey.shade300,
            child: stat.book.coverPath != null
                ? Image.file(
                    File(stat.book.coverPath!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.book),
                  )
                : const Icon(Icons.book),
          ),
          title: Text(stat.book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${hours}h ${minutes}m'),
          trailing: index < 3 
              ? Icon(Icons.emoji_events, color: index == 0 ? Colors.amber : (index == 1 ? Colors.grey : Colors.brown))
              : Text('#${index + 1}'),
        );
      },
    );
  }
}
