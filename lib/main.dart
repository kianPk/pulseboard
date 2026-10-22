import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

void main() => runApp(const PulseboardApp());

class PulseboardApp extends StatelessWidget {
  const PulseboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pulseboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3DFFA8), brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF060910),
      ),
      home: const DashboardPage(),
    );
  }
}

class ServiceStatus {
  ServiceStatus(this.name, this.region, this.latency, this.ok);
  final String name;
  final String region;
  double latency;
  bool ok;
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _rng = Random();
  late List<ServiceStatus> _services;
  late List<double> _rpsHistory;
  Timer? _timer;
  int _incidents = 2;
  double _errorRate = 0.4;

  @override
  void initState() {
    super.initState();
    _services = [
      ServiceStatus('api-core', 'fra', 42, true),
      ServiceStatus('edge-gw', 'ams', 18, true),
      ServiceStatus('auth', 'fra', 55, true),
      ServiceStatus('workers', 'hel', 90, true),
      ServiceStatus('realtime', 'fra', 28, true),
      ServiceStatus('billing', 'iad', 120, false),
    ];
    _rpsHistory = List.generate(24, (i) => 40 + _rng.nextDouble() * 80);
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _tick());
  }

  void _tick() {
    setState(() {
      for (final s in _services) {
        s.latency = (s.latency + (_rng.nextDouble() * 20 - 8)).clamp(12, 220);
        if (_rng.nextDouble() < 0.08) s.ok = !s.ok || s.name != 'billing';
        if (s.name == 'billing') s.ok = _rng.nextDouble() > 0.35;
      }
      _rpsHistory
        ..removeAt(0)
        ..add(30 + _rng.nextDouble() * 100);
      _errorRate = (_errorRate + (_rng.nextDouble() * 0.4 - 0.2)).clamp(0.05, 3.5);
      _incidents = _services.where((s) => !s.ok).length;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final up = _services.where((s) => s.ok).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pulseboard', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        backgroundColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Chip(
              label: const Text('LIVE'),
              avatar: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: Color(0xFF3DFFA8), shape: BoxShape.circle),
              ),
              side: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _kpi('Services up', '$up/${_services.length}', const Color(0xFF3DFFA8)),
              _kpi('Incidents', '$_incidents', const Color(0xFFFF6B6B)),
              _kpi('Error rate', '${_errorRate.toStringAsFixed(2)}%', const Color(0xFFFFC857)),
              _kpi('RPS', _rpsHistory.last.toStringAsFixed(0), const Color(0xFF7EC8FF)),
            ],
          ),
          const SizedBox(height: 18),
          _card(
            title: 'Traffic (RPS)',
            child: SizedBox(height: 140, child: CustomPaint(painter: SparkPainter(_rpsHistory), child: Container())),
          ),
          const SizedBox(height: 14),
          _card(
            title: 'Services',
            child: Column(
              children: _services.map((s) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.circle, size: 12, color: s.ok ? const Color(0xFF3DFFA8) : const Color(0xFFFF6B6B)),
                  title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(s.region.toUpperCase()),
                  trailing: Text('${s.latency.toStringAsFixed(0)} ms',
                      style: TextStyle(fontFamily: 'monospace', color: s.latency > 100 ? const Color(0xFFFFC857) : Colors.white70)),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          _card(
            title: 'About',
            child: Text(
              'Pulseboard is a Flutter ops dashboard demo — animated telemetry, service health, and sparklines. '
              'Pair it with Gateproxy / Pulsehub backends for a full stack story.',
              style: TextStyle(color: Colors.white.withOpacity(0.7), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value, Color accent) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1420),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: accent)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white54)),
        ],
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1420),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class SparkPainter extends CustomPainter {
  SparkPainter(this.values);
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final minV = values.reduce(min);
    final maxV = values.reduce(max);
    final range = (maxV - minV).clamp(1, 9999);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - ((values[i] - minV) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFF3DFFA8).withOpacity(0.35), const Color(0xFF3DFFA8).withOpacity(0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF3DFFA8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant SparkPainter oldDelegate) => oldDelegate.values != values;
}
