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
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF5A6B5C),
          onPrimary: Color(0xFFF4F6F8),
          surface: Color(0xFFF4F6F8),
          onSurface: Color(0xFF12161C),
        ),
        scaffoldBackgroundColor: const Color(0xFFE8EBEE),
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
  final List<double> history = [];
}

class Incident {
  Incident(this.at, this.service, this.detail);
  final DateTime at;
  final String service;
  final String detail;
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
  final List<Incident> _incidentsLog = [];
  Timer? _timer;
  int _incidents = 0;
  double _errorRate = 0.4;
  bool _paused = false;
  ServiceStatus? _selected;
  double _alertLatency = 100;

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
    for (final s in _services) {
      s.history.addAll(List.generate(20, (_) => s.latency + _rng.nextDouble() * 20 - 10));
    }
    _rpsHistory = List.generate(30, (i) => 40 + _rng.nextDouble() * 80);
    _incidentsLog.add(Incident(DateTime.now().subtract(const Duration(minutes: 12)), 'billing', 'elevated latency'));
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _tick());
  }

  void _tick() {
    if (_paused) return;
    setState(() {
      for (final s in _services) {
        final prev = s.ok;
        s.latency = (s.latency + (_rng.nextDouble() * 20 - 8)).clamp(12, 220);
        if (_rng.nextDouble() < 0.08) s.ok = !s.ok || s.name != 'billing';
        if (s.name == 'billing') s.ok = _rng.nextDouble() > 0.35;
        s.history
          ..removeAt(0)
          ..add(s.latency);
        if (prev && !s.ok) {
          _incidentsLog.insert(0, Incident(DateTime.now(), s.name, 'health check failed'));
        } else if (s.latency > _alertLatency && _rng.nextDouble() < 0.15) {
          _incidentsLog.insert(0, Incident(DateTime.now(), s.name, 'latency > ${_alertLatency.toInt()}ms'));
        }
      }
      if (_incidentsLog.length > 40) {
        _incidentsLog.removeRange(40, _incidentsLog.length);
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
        title: const Text('Pulseboard', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.4)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: _paused ? 'Resume' : 'Pause',
            onPressed: () => setState(() => _paused = !_paused),
            icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              label: Text(_paused ? 'PAUSED' : 'LIVE'),
              avatar: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _paused ? const Color(0xFF8B7355) : const Color(0xFF5A6B5C),
                  shape: BoxShape.circle,
                ),
              ),
              side: BorderSide(color: Colors.black.withOpacity(0.08)),
              backgroundColor: Colors.white.withOpacity(0.8),
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
              _kpi('Services up', '$up/${_services.length}', const Color(0xFF5A6B5C)),
              _kpi('Incidents', '$_incidents', const Color(0xFF8B3A3A)),
              _kpi('Error rate', '${_errorRate.toStringAsFixed(2)}%', const Color(0xFF8B7355)),
              _kpi('RPS', _rpsHistory.last.toStringAsFixed(0), const Color(0xFF2A3038)),
            ],
          ),
          const SizedBox(height: 16),
          _card(
            title: 'Alert threshold',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Latency alert at ${_alertLatency.toInt()} ms', style: TextStyle(color: Colors.black.withOpacity(0.55))),
                Slider(
                  value: _alertLatency,
                  min: 40,
                  max: 180,
                  divisions: 14,
                  activeColor: const Color(0xFF5A6B5C),
                  onChanged: (v) => setState(() => _alertLatency = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _card(
            title: 'Traffic (RPS)',
            child: SizedBox(height: 140, child: CustomPaint(painter: SparkPainter(_rpsHistory, const Color(0xFF5A6B5C)), child: Container())),
          ),
          const SizedBox(height: 14),
          _card(
            title: 'Services',
            child: Column(
              children: _services.map((s) {
                final hot = s.latency > _alertLatency;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () => setState(() => _selected = s),
                  leading: Icon(Icons.circle, size: 12, color: s.ok ? const Color(0xFF5A6B5C) : const Color(0xFF8B3A3A)),
                  title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${s.region.toUpperCase()}${hot ? ' · alert' : ''}'),
                  trailing: Text(
                    '${s.latency.toStringAsFixed(0)} ms',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: hot ? const Color(0xFF8B7355) : Colors.black54,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (_selected != null) ...[
            const SizedBox(height: 14),
            _card(
              title: '${_selected!.name} detail',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Region ${_selected!.region.toUpperCase()} · ${_selected!.ok ? 'healthy' : 'degraded'}'),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 90,
                    child: CustomPaint(
                      painter: SparkPainter(_selected!.history, _selected!.ok ? const Color(0xFF5A6B5C) : const Color(0xFF8B3A3A)),
                      child: Container(),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          _card(
            title: 'Incident timeline',
            child: Column(
              children: _incidentsLog.take(8).map((i) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(i.service, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(i.detail),
                  trailing: Text(
                    '${i.at.hour.toString().padLeft(2, '0')}:${i.at.minute.toString().padLeft(2, '0')}:${i.at.second.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.black45),
                  ),
                );
              }).toList(),
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
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: accent)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black45)),
        ],
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
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
  SparkPainter(this.values, this.color);
  final List<double> values;
  final Color color;

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
          colors: [color.withOpacity(0.28), color.withOpacity(0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant SparkPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}
