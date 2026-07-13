const OP_START_HOUR = 8;
const OP_START_MIN = 0;
const OP_END_HOUR = 17;
const OP_END_MIN = 0;
const ORDER_CUTOFF_HOUR = 15;
const ORDER_CUTOFF_MIN = 0;
const WARNING_START_HOUR = 14;
const WARNING_START_MIN = 30;

function getTotalMinutes(h: number, m: number): number {
  return h * 60 + m;
}

export function getCurrentWitaTime(): { hour: number; minute: number } {
  const now = new Date();
  const wita = new Date(now.getTime() + 8 * 60 * 60 * 1000);
  return {
    hour: wita.getUTCHours(),
    minute: wita.getUTCMinutes(),
  };
}

export function getTodayWitaDate(): Date {
  const now = new Date();
  const wita = new Date(now.getTime() + 8 * 60 * 60 * 1000);
  return new Date(wita.getUTCFullYear(), wita.getUTCMonth(), wita.getUTCDate());
}

export function isWithinOperatingHours(): boolean {
  const { hour, minute } = getCurrentWitaTime();
  const nowTotal = getTotalMinutes(hour, minute);
  const startTotal = getTotalMinutes(OP_START_HOUR, OP_START_MIN);
  const endTotal = getTotalMinutes(OP_END_HOUR, OP_END_MIN);
  return nowTotal >= startTotal && nowTotal < endTotal;
}

export function canTransitionWorkflow(): { allowed: boolean; message?: string } {
  const { hour, minute } = getCurrentWitaTime();
  const nowTotal = getTotalMinutes(hour, minute);
  const startTotal = getTotalMinutes(OP_START_HOUR, OP_START_MIN);
  const endTotal = getTotalMinutes(OP_END_HOUR, OP_END_MIN);

  if (nowTotal < startTotal) {
    return { allowed: false, message: `Belum jam operasional (${String(OP_START_HOUR).padStart(2, '0')}:${String(OP_START_MIN).padStart(2, '0')} WITA)` };
  }
  if (nowTotal >= endTotal) {
    return { allowed: false, message: `Sudah lewat jam operasional. Batas konfirmasi pekerjaan pukul ${String(OP_END_HOUR - 1).padStart(2, '0')}:59 WITA` };
  }
  return { allowed: true };
}

export function canCompleteWork(): { allowed: boolean; message?: string } {
  const { hour, minute } = getCurrentWitaTime();
  const nowTotal = getTotalMinutes(hour, minute);
  const startTotal = getTotalMinutes(OP_START_HOUR, OP_START_MIN);
  const endTotal = getTotalMinutes(OP_END_HOUR, OP_END_MIN);

  if (nowTotal < startTotal) {
    return { allowed: false, message: `Belum jam operasional (${String(OP_START_HOUR).padStart(2, '0')}:${String(OP_START_MIN).padStart(2, '0')} WITA)` };
  }
  if (nowTotal >= endTotal) {
    return { allowed: false, message: "Sudah lewat jam operasional. Batas konfirmasi selesai pukul 16:59 WITA" };
  }
  return { allowed: true };
}

export function canOrderNow(): { allowed: boolean; warning?: string } {
  const { hour, minute } = getCurrentWitaTime();
  const nowTotal = getTotalMinutes(hour, minute);
  const startTotal = getTotalMinutes(OP_START_HOUR, OP_START_MIN);
  const cutoffTotal = getTotalMinutes(ORDER_CUTOFF_HOUR, ORDER_CUTOFF_MIN);
  const warningStartTotal = getTotalMinutes(WARNING_START_HOUR, WARNING_START_MIN);

  if (nowTotal < startTotal) {
    return { allowed: false, warning: `Belum jam operasional (${String(OP_START_HOUR).padStart(2, '0')}:${String(OP_START_MIN).padStart(2, '0')} WITA)` };
  }
  if (nowTotal >= cutoffTotal) {
    return { allowed: false, warning: "Sudah lewat jam operasional, silahkan order untuk besok" };
  }
  if (nowTotal >= warningStartTotal) {
    return { allowed: true, warning: "Waktu pemesanan mepet dengan jam operasional berakhir. Sarankan order besok pagi jam 08:00 atau lihat jadwal mitra." };
  }
  return { allowed: true };
}

export function isSameWitaDate(date: Date): boolean {
  const now = new Date();
  const nowWita = new Date(now.getTime() + 8 * 60 * 60 * 1000);
  const dateWita = new Date(date.getTime() + 8 * 60 * 60 * 1000);
  return nowWita.getUTCFullYear() === dateWita.getUTCFullYear() &&
         nowWita.getUTCMonth() === dateWita.getUTCMonth() &&
         nowWita.getUTCDate() === dateWita.getUTCDate();
}
