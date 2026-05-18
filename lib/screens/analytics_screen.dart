import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/analytics_provider.dart';
import '../utils/theme.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(analyticsProvider.notifier).fetchAnalytics();
    });
  }

  @override
  Widget build(BuildContext context) {
    final analytics = ref.watch(analyticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('CAMPAIGN ANALYTICS'),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppTheme.darkBackgroundGradient,
        ),
        child: analytics.isLoading
            ? const Center(
                child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppTheme.secondaryNeon)),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Conversion KPI Header
                    FadeInDown(
                      duration: const Duration(milliseconds: 500),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: AppTheme.glassCardDecoration(
                          borderColor: AppTheme.successGreen.withOpacity(0.2),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Conversion Efficiency',
                                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textWhite),
                                ),
                                const Text(
                                  'Percentage of leads marked "Interested"',
                                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppTheme.successGreen.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.successGreen.withOpacity(0.3)),
                              ),
                              child: Text(
                                '${analytics.conversionRate.toStringAsFixed(1)}%',
                                style: GoogleFonts.outfit(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.successGreen,
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Beautiful fl_chart Daily Calls Performance Curve
                    FadeInUp(
                      duration: const Duration(milliseconds: 500),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'WEEKLY CAMPAIGN TIMELINE',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textMuted,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            height: 250,
                            padding: const EdgeInsets.only(top: 20, bottom: 10, right: 20, left: 10),
                            decoration: AppTheme.glassCardDecoration(),
                            child: LineChart(
                              LineChartData(
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  getDrawingHorizontalLine: (value) => FlLine(
                                    color: AppTheme.borderBlue.withOpacity(0.3),
                                    strokeWidth: 1,
                                  ),
                                ),
                                titlesData: FlTitlesData(
                                  show: true,
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 22,
                                      interval: 1,
                                      getTitlesWidget: (value, meta) {
                                        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
                                        if (value.toInt() >= 0 && value.toInt() < days.length) {
                                          return Text(
                                            days[value.toInt()],
                                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
                                          );
                                        }
                                        return const Text('');
                                      },
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 28,
                                      interval: 10,
                                      getTitlesWidget: (value, meta) {
                                        return Text(
                                          value.toInt().toString(),
                                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                minX: 0,
                                maxX: 5,
                                minY: 0,
                                maxY: 40,
                                lineBarsData: [
                                  // Calls completed line (Indigo Curve)
                                  LineChartBarData(
                                    spots: const [
                                      FlSpot(0, 12),
                                      FlSpot(1, 18),
                                      FlSpot(2, 24),
                                      FlSpot(3, 15),
                                      FlSpot(4, 30),
                                      FlSpot(5, 35),
                                    ],
                                    isCurved: true,
                                    color: AppTheme.primaryNeon,
                                    barWidth: 4,
                                    isStrokeCapRound: true,
                                    dotData: const FlDotData(show: true),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      color: AppTheme.primaryNeon.withOpacity(0.12),
                                    ),
                                  ),
                                  // Conversions line (Teal Curve)
                                  LineChartBarData(
                                    spots: const [
                                      FlSpot(0, 2),
                                      FlSpot(1, 4),
                                      FlSpot(2, 5),
                                      FlSpot(3, 3),
                                      FlSpot(4, 8),
                                      FlSpot(5, 18),
                                    ],
                                    isCurved: true,
                                    color: AppTheme.secondaryNeon,
                                    barWidth: 3,
                                    isStrokeCapRound: true,
                                    dotData: const FlDotData(show: true),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      color: AppTheme.secondaryNeon.withOpacity(0.08),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          
                          // Legend
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildLegendItem('Total Outbound Calls', AppTheme.primaryNeon),
                              const SizedBox(width: 24),
                              _buildLegendItem('Interested Pitch Conversions', AppTheme.secondaryNeon),
                            ],
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Industry Niche Success Leaderboard
                    FadeInUp(
                      duration: const Duration(milliseconds: 500),
                      delay: const Duration(milliseconds: 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BEST BUSINESS NICHES SUCCESS RATE',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textMuted,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: AppTheme.glassCardDecoration(),
                            child: analytics.nichePerformance.isEmpty
                                ? const Center(
                                    child: Text(
                                      'Call campaigns to analyze business niches',
                                      style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: analytics.nichePerformance.length,
                                    itemBuilder: (context, index) {
                                      final item = analytics.nichePerformance[index];
                                      final double percentage = (item['percentage'] as num).toDouble();
                                      
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 16.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  item['niche'] ?? 'Unknown Business',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                ),
                                                Text(
                                                  '${percentage.toStringAsFixed(0)}% success (${item['interested']}/${item['total']})',
                                                  style: TextStyle(
                                                    color: percentage > 49 
                                                        ? AppTheme.successGreen 
                                                        : AppTheme.textMuted,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                )
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(5),
                                              child: LinearProgressIndicator(
                                                value: percentage / 100,
                                                minHeight: 6,
                                                backgroundColor: AppTheme.borderBlue.withOpacity(0.5),
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                  percentage > 49 
                                                      ? AppTheme.successGreen 
                                                      : AppTheme.secondaryNeon,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
      ],
    );
  }
}
