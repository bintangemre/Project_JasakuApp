class OperatingHours {
  static const int startHour = 8;
  static const int startMinute = 0;
  static const int endHour = 16;
  static const int endMinute = 0;
  static const int orderCutoffHour = 15;
  static const int orderCutoffMinute = 59;
  static const int warningStartHour = 15;
  static const int warningStartMinute = 30;

  static int _totalMinutes(int h, int m) => h * 60 + m;

  static DateTime _nowWita() {
    final utc = DateTime.now().toUtc();
    return utc.add(const Duration(hours: 8));
  }

  static bool isWithinOperatingHours() {
    final now = _nowWita();
    final total = _totalMinutes(now.hour, now.minute);
    return total >= _totalMinutes(startHour, startMinute) &&
           total < _totalMinutes(endHour, endMinute);
  }

  static ({bool allowed, String? warning}) canOrderNow() {
    final now = _nowWita();
    final total = _totalMinutes(now.hour, now.minute);
    final start = _totalMinutes(startHour, startMinute);
    final cutoff = _totalMinutes(orderCutoffHour, orderCutoffMinute);
    final warningStart = _totalMinutes(warningStartHour, warningStartMinute);

    if (total < start) {
      return (allowed: false, warning: 'Belum jam operasional (08:00-16:00 WITA)');
    }
    if (total >= cutoff) {
      return (allowed: false, warning: 'Sudah lewat jam operasional, silahkan order untuk besok');
    }
    if (total >= warningStart) {
      return (
        allowed: true,
        warning: 'Jam operasional berakhir pukul 16:00 WITA. Pilih hari lain atau pesan 2 hari kerja. Jika tetap pesan, provider bisa minta extensi jika pekerjaan belum selesai.',
      );
    }
    return (allowed: true, warning: null);
  }

  static bool isToday(DateTime date) {
    final now = _nowWita();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }
}