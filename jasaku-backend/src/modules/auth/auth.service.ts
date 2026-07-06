import { prisma } from '../../config/prisma';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';   
import { OAuth2Client } from 'google-auth-library';

const client = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

export class AuthService {
  
  async registerCustomer(email: string, password: string, name: string, phone?: string, gender?: string, birthDate?: Date) {
    // Normalisasi: empty string → null (unik constraint aman)
    const normalizedPhone = phone?.trim() || null;

    // Cek email sudah terdaftar
    const existing = await prisma.users.findUnique({ where: { email } });
    if (existing) throw new Error('Email sudah terdaftar');

    // Cek nomor telepon sudah terdaftar
    if (normalizedPhone) {
      const phoneExists = await prisma.users.findUnique({ where: { phone: normalizedPhone } });
      if (phoneExists) throw new Error('Nomor telepon sudah terdaftar');
    }

    // Cari role berdasarkan name
    const role = await prisma.roles.findUnique({ where: { name: 'customer' } });
    if (!role) throw new Error('Role tidak ditemukan');

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 12);

    // Gunakan transaction agar atomic
    const result = await prisma.$transaction(async (tx) => {
      const newUser = await tx.users.create({
        data: {
          email,
          password_hash: hashedPassword,
          role_id: role.id,
          phone: normalizedPhone
        }
      });

      const profile = await tx.profiles_customer.create({
        data: { user_id: newUser.id, full_name: name, gender: gender, birth_date: birthDate }
      });
      
      return { newUser, profile };
    });

    const token = this.generateToken(result.newUser.id, role.name);
    return { token, user: { id: result.newUser.id, email: result.newUser.email, role: role.name }, profile: result.profile };
  }


  //untuk Jasa (provider)
  //untuk Jasa (provider) - Versi Atomik Sekaligus Menyimpan Keahlian & Tarif
async registerProvider(
  full_name: string, 
  nickname: string, 
  email: string, 
  password: string, 
  phone: string, 
  birthDate: Date, 
  gender: string, 
  address: string, 
  domicile: string, 
  profile_photo?: string, 
  ktp_photo?: string, 
  selfie_photo?: string, 
  portfolios?: string[],
  ijazah_photo?: string | null,
  certificate_files?: string[],
  certificates?: Array<{ categoryId: string; description: string }>,
  services?: Array<{ 
    serviceId: string; 
    description: string; 
    prices: Array<{ pricingTypeId: string; price: number }> 
  }>,
  ocr_nik?: string,
  ocr_full_name?: string,
  ocr_birth_place?: string,
  ocr_birth_date?: string,
  ocr_address?: string,
  liveness_data?: any
) {
  // Normalisasi: empty string → null
  const normalizedPhone = phone?.trim() || null;

  // 1. Cek apakah email sudah terdaftar di sistem Jasaku
  const existing = await prisma.users.findUnique({ where: { email } });
  if (existing) throw new Error('Email sudah terdaftar');

  // 1b. Cek apakah nomor telepon sudah terdaftar
  if (normalizedPhone) {
    const phoneExists = await prisma.users.findUnique({ where: { phone: normalizedPhone } });
    if (phoneExists) throw new Error('Nomor telepon sudah terdaftar');
  }

  // 2. Ambil master role khusus provider
  const role = await prisma.roles.findUnique({ where: { name: 'provider' } });
  if (!role) throw new Error('Role provider tidak ditemukan');

  // 3. Hash password secara aman
  const hashedPassword = await bcrypt.hash(password, 12);

  // 4. JALANKAN SATU TRANSAKSI UTUH (ATOMIK)
  const result = await prisma.$transaction(async (tx) => {
    
    // A. Buat Akun Utama di tabel users
    const newUser = await tx.users.create({
      data: {
        email,
        password_hash: hashedPassword,
        role_id: role.id,
        phone: normalizedPhone
      }
    });

    // B. Buat Data Profil Lengkap beserta Foto Dokumen & Portofolio
    const profile = await tx.provider_profiles.create({
      data: { 
        user_id: newUser.id, 
        full_name: full_name,
        nickname: nickname,
        birth_date: new Date(birthDate),
        gender: gender,
        phone: normalizedPhone,
        address: address,
        domicile: domicile,
        profile_photo: profile_photo || null,
        ktp_photo: ktp_photo || null,
        selfie_photo: selfie_photo || null,
        portfolios: portfolios || [],
      }
    });

    // C. Buat identity_verifications (untuk OCR & face match)
    const identityData: any = { provider_id: profile.id };
    if (ocr_nik) identityData.nik = ocr_nik;
    if (ocr_full_name) identityData.ocr_full_name = ocr_full_name;
    if (ocr_birth_place) identityData.ocr_birth_place = ocr_birth_place;
    if (ocr_birth_date) identityData.ocr_birth_date = ocr_birth_date;
    if (ocr_address) identityData.ocr_address = ocr_address;
    if (liveness_data) {
      identityData.liveness_data = liveness_data;
      identityData.liveness_status = liveness_data?.completed >= 3 ? 'passed' : 'failed';
    }
    await tx.identity_verifications.create({ data: identityData });

    // D. Simpan Ijazah
    if (ijazah_photo) {
      await tx.provider_documents.create({
        data: {
          provider_id: profile.id,
          type: 'ijazah',
          file_url: ijazah_photo,
          description: 'Ijazah',
        }
      });
    }

    // E. Simpan Sertifikat Penunjang
    if (certificate_files && certificate_files.length > 0 && certificates) {
      for (let i = 0; i < certificate_files.length; i++) {
        const certInfo = certificates[i] || { categoryId: '', description: '' };
        await tx.provider_documents.create({
          data: {
            provider_id: profile.id,
            type: 'certificate',
            file_url: certificate_files[i],
            category_id: certInfo.categoryId || null,
            description: certInfo.description || 'Sertifikat',
          }
        });
      }
    }

    // F. SIMPAN KEAHLIAN & TARIF SEKALIGUS (Jika dikirim dari Flutter)
    if (services && services.length > 0) {
      // Ambil seluruh master tipe harga untuk auto-fill data unit di DB
      const masterPricingTypes = await tx.pricing_types.findMany();

      for (const service of services) {
        // Buat baris baru di tabel penghubung provider_services
        const newProviderService = await tx.provider_services.create({
          data: {
            provider_id: profile.id,
            service_id: service.serviceId,
            description: service.description
          }
        });

        // Map data harga dengan unit otomatis dari tabel master pricing_types
        const priceData = service.prices.map(p => {
          const typeInfo = masterPricingTypes.find((t: any) => t.id === p.pricingTypeId);
          return {
            provider_service_id: newProviderService.id,
            pricing_type_id: p.pricingTypeId,
            price: p.price,
            unit: typeInfo?.default_unit || null // Isi unit otomatis (misal: 'hari', 'jam', 'meter')
          };
        });

        // Masukkan semua rincian tarif harga ke tabel harga provider
        await tx.provider_service_prices.createMany({ data: priceData });
      }
    }
    
    return { newUser, profile };
  });

  // 5. Panggil face matching async (jika KTP & selfie tersedia)
  if (ktp_photo && selfie_photo) {
    const { runFaceMatchAsync } = await import("../../config/face_client");
    runFaceMatchAsync(result.profile.id, ktp_photo, selfie_photo).catch((e) =>
      console.warn("Face match non-blocking error:", e.message),
    );
  }

  // 6. Generate token internal Jasaku untuk auto-login setelah register sukses
  const token = this.generateToken(result.newUser.id, role.name);
  return { 
    token, 
    user: { id: result.newUser.id, email: result.newUser.email, role: role.name }, 
    profile: result.profile 
  };
}

  //register admin langsung masuk ke tabel users tanpa profile karena tidak diperlukan
  async registerAdmin(email: string, password: string, name: string, phone?: string) {
    const normalizedPhone = phone?.trim() || null;

    const existing = await prisma.users.findUnique({ where: { email } });
    if (existing) throw new Error('Email sudah terdaftar');
    if (normalizedPhone) {
      const phoneExists = await prisma.users.findUnique({ where: { phone: normalizedPhone } });
      if (phoneExists) throw new Error('Nomor telepon sudah terdaftar');
    }
    const role = await prisma.roles.findUnique({ where: { name: 'admin' } });
    if (!role) throw new Error('Role admin tidak ditemukan');
    const hashedPassword = await bcrypt.hash(password, 12);
    const user = await prisma.users.create({
      data: {
        email,
        password_hash: hashedPassword,
        role_id: role.id,
        phone: normalizedPhone
      }    
  });
    const token = this.generateToken(user.id, role.name);
    return { token, user: { id: user.id, email: user.email, role: role.name }, profile: null };
  }

  async login(email: string, password: string) {
    const user = await prisma.users.findUnique({
      where: { email },
      include: { roles: true, profiles_customer: true, provider_profiles: true }
    });
    if (!user) throw new Error('Email atau password salah');

    const isValid = await bcrypt.compare(password, user.password_hash || '');
    if (!isValid) throw new Error('Email atau password salah');

      // Cek verifikasi untuk role provider
      if (user.roles.name === 'provider') {
        const profile = user.provider_profiles;
        if (profile) {
          if (profile.verification_status === 'pending') {
            throw new Error('Akun Anda belum diverifikasi oleh admin. Silakan tunggu konfirmasi.');
          }
          if (profile.verification_status === 'rejected') {
            const notes = profile.verification_notes ? ` Alasan: ${profile.verification_notes}` : '';
            throw new Error(`Akun Anda ditolak. Silakan perbaiki sesuai saran admin.${notes}`);
          }
          // Auto-set onboarding_completed untuk provider LAMA (sudah punya tarif, bukan baru daftar 5-step)
          if (profile.verification_status === 'verified' && !profile.onboarding_completed) {
            const hasPricing = await prisma.provider_service_prices.count({
              where: {
                provider_services: { provider_id: user.id }
              }
            }) > 0;
            if (hasPricing) {
              await prisma.provider_profiles.update({
                where: { user_id: user.id },
                data: { onboarding_completed: true }
              });
              profile.onboarding_completed = true;
            }
          }
        }
      }

      const token = this.generateToken(user.id, user.roles.name);

    const profile = user.profiles_customer || user.provider_profiles;
    const extra = profile && 'verification_status' in profile
      ? {
          verification_status: (profile as any).verification_status,
          verification_notes: (profile as any).verification_notes,
          onboarding_completed: (profile as any).onboarding_completed ?? true
        }
      : {};

    return {
      token,
      user: { id: user.id, email: user.email, role: user.roles.name },
      profile: { ...profile, ...extra }
    };
  }

  // ==========================================
  // 5. FITUR BARU: LOGIN & REGISTER VIA GOOGLE
  // ==========================================
  async loginWithGoogle(idToken: string) {
    // 1. Verifikasi token ke Google
    const ticket = await client.verifyIdToken({
      idToken: idToken,
      audience: process.env.GOOGLE_CLIENT_ID,
    });

    const payload = ticket.getPayload();
    if (!payload || !payload.email) throw new Error('Gagal mendapatkan payload dari Google');
    
    const { email, name } = payload;

    // 2. Cari apakah user dengan email tersebut sudah terdaftar di database Jasaku
    let user = await prisma.users.findUnique({
      where: { email },
      include: { roles: true, profiles_customer: true, provider_profiles: true }
    });

    let roleName = 'customer'; // Default role jika membuat akun baru via Google

    if (!user) {
      // 3. Jika belum terdaftar, daftarkan otomatis sebagai CUSTOMER via Prisma Transaction
      const role = await prisma.roles.findUnique({ where: { name: 'customer' } });
      if (!role) throw new Error('Role customer tidak ditemukan');

      user = await prisma.$transaction(async (tx) => {
        const newUser = await tx.users.create({
          data: {
            email,
            password_hash: null, // Kosongkan password karena login menggunakan Google OAuth
            role_id: role.id,
          },
          include: { roles: true, profiles_customer: true, provider_profiles: true }
        });

        const newProfile = await tx.profiles_customer.create({
          data: {
            user_id: newUser.id,
            full_name: name || 'Google User',
          }
        });

        // Masukkan kembali profil yang baru dibuat ke objek user agar strukturnya konsisten saat dikembalikan
        newUser.profiles_customer = newProfile;
        return newUser;
      });

      roleName = role.name;
    } else {
      roleName = user.roles.name;

      // Cek verifikasi untuk role provider yang sudah terdaftar
      if (roleName === 'provider' && user.provider_profiles) {
        const profile = user.provider_profiles;
        if (profile.verification_status === 'pending') {
          throw new Error('Akun Anda belum diverifikasi oleh admin. Silakan tunggu konfirmasi.');
        }
        if (profile.verification_status === 'rejected') {
          const notes = profile.verification_notes ? ` Alasan: ${profile.verification_notes}` : '';
          throw new Error(`Akun Anda ditolak. Silakan perbaiki sesuai saran admin.${notes}`);
        }
        // Auto-set onboarding_completed untuk provider LAMA (sudah punya tarif, bukan baru daftar 5-step)
        if (profile.verification_status === 'verified' && !profile.onboarding_completed) {
          const hasPricing = await prisma.provider_service_prices.count({
            where: {
              provider_services: { provider_id: user.id }
            }
          }) > 0;
          if (hasPricing) {
            await prisma.provider_profiles.update({
              where: { user_id: user.id },
              data: { onboarding_completed: true }
            });
            profile.onboarding_completed = true;
          }
        }
      }
    }

    // 4. Generate token internal Jasaku menggunakan function pembantu class
    const token = this.generateToken(user.id, roleName);

    const profile = user.profiles_customer || user.provider_profiles;
    const extra = profile && 'verification_status' in profile
      ? {
          verification_status: (profile as any).verification_status,
          verification_notes: (profile as any).verification_notes,
          onboarding_completed: (profile as any).onboarding_completed ?? true
        }
      : {};

    return { 
      token, 
      user: { id: user.id, email: user.email, role: roleName }, 
      profile: { ...profile, ...extra }
    };
  }

  private generateToken(userId: string, role: string) {
    return jwt.sign(
      { userId, role },
      process.env.JWT_SECRET!,
      { expiresIn: process.env.JWT_EXPIRES_IN as any }
    );
  }

  // ==========================================
  // OTP Sederhana (in-memory, untuk development)
  // ==========================================
  private otpStore = new Map<string, { otp: string; email: string; phone: string; expiresAt: Date }>();

  async sendOtp(email: string, phone: string) {
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000); // 5 menit

    this.otpStore.set(email, { otp, email, phone, expiresAt });

    // Untuk development, log OTP ke console
    console.log(`[OTP] Email: ${email}, OTP: ${otp}, berlaku hingga: ${expiresAt}`);

    return { message: 'OTP berhasil dikirim' };
  }

  async verifyOtp(email: string, phone: string, otp: string) {
    const stored = this.otpStore.get(email);
    if (!stored) throw new Error('OTP tidak ditemukan. Kirim ulang OTP.');

    if (new Date() > stored.expiresAt) {
      this.otpStore.delete(email);
      throw new Error('OTP sudah kadaluwarsa. Kirim ulang OTP.');
    }

    if (stored.otp !== otp) throw new Error('OTP salah.');

    // Tandai user sebagai terverifikasi
    await prisma.users.updateMany({
      where: { email },
      data: { is_phone_verified: true, is_email_verified: true }
    });

    this.otpStore.delete(email);
    return { message: 'Verifikasi berhasil' };
  }

  async getProviderVerificationStatus(userId: string) {
    const profile = await prisma.provider_profiles.findUnique({
      where: { user_id: userId },
      select: {
        id: true,
        verification_status: true,
        verification_notes: true,
        is_verified: true,
      }
    });
    if (!profile) throw new Error('Profil provider tidak ditemukan');
    return profile;
  }

  async resubmitProviderVerification(userId: string) {
    const profile = await prisma.provider_profiles.findUnique({
      where: { user_id: userId }
    });
    if (!profile) throw new Error('Profil provider tidak ditemukan');
    if (profile.verification_status !== 'rejected') {
      throw new Error('Status verifikasi saat ini tidak dapat diajukan ulang');
    }
    return await prisma.provider_profiles.update({
      where: { user_id: userId },
      data: {
        verification_status: 'pending',
        verification_notes: null,
      }
    });
  }
}
