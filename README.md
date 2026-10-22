# Pulseboard

**Flutter ops dashboard** — live service health, sparklines, KPI cards. Demo telemetry that feels like a real NOC wall.

![Flutter](https://img.shields.io/badge/Flutter-3.24+-02569B?logo=flutter&logoColor=white)
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)

Live web demo: **https://kianpk.github.io/pulseboard/**

## Features

- Animated RPS sparkline (CustomPainter)
- Per-service latency + up/down
- Incident & error-rate KPIs
- Material 3 dark “ops” aesthetic

## Run

```bash
flutter pub get
flutter run -d chrome
```

## Web build

```bash
flutter build web --base-href "/pulseboard/"
```

Pairs well with [gateproxy](https://github.com/kianPk/gateproxy) and [pulsehub](https://github.com/kianPk/pulsehub).

## License

MIT © [kianPk](https://github.com/kianPk)
