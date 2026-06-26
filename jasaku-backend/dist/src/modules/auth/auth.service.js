import { prisma } from '../../config/prisma';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { OAuth2Client } from 'google-auth-library';
const client = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);
export class AuthService {
    async registerCustomer(email, password, name, phone, gender, birthDate) {
        // Cek email sudah terdaftar
        const existing = await prisma.users.findUnique({ where: { email } });
        if (existing)
            throw new Error('Email sudah terdaftar');
        // Cari role berdasarkan name
        const role = await prisma.roles.findUnique({ where: { name: 'customer' } });
        if (!role)
            throw new Error('Role tidak ditemukan');
        // Hash password
        const hashedPassword = await bcrypt.hash(password, 12);
        // Gunakan transaction agar atomic
        const result = await prisma.$transaction(async (tx) => {
            const newUser = await tx.users.create({
                data: {
                    email,
                    password_hash: hashedPassword,
                    role_id: role.id,
                    phone
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
    async registerProvider(full_name, nickname, email, password, phone, birthDate, gender, address, domicile, profile_photo, ktp_photo, selfie_photo, services) {
        // Cek email sudah terdaftar
        const existing = await prisma.users.findUnique({ where: { email } });
        if (existing)
            throw new Error('Email sudah terdaftar');
        const role = await prisma.roles.findUnique({ where: { name: 'provider' } });
        if (!role)
            throw new Error('Role provider tidak ditemukan');
        const hashedPassword = await bcrypt.hash(password, 12);
        const result = await prisma.$transaction(async (tx) => {
            const newUser = await tx.users.create({
                data: {
                    email,
                    password_hash: hashedPassword,
                    role_id: role.id,
                    phone
                }
            });
            // Gunakan fullName (sesuai parameter)
            const profile = await tx.provider_profiles.create({
                data: {
                    user_id: newUser.id,
                    full_name: full_name,
                    nickname: nickname,
                    birth_date: new Date(birthDate), // Pastikan formatnya Date jika di DB adalah Timestamp
                    gender: gender,
                    address: address,
                    domicile: domicile,
                    profile_photo: profile_photo || null,
                    ktp_photo: ktp_photo || null,
                    selfie_photo: selfie_photo || null
                }
            });
            // Simpan services dan prices jika ada
            if (services && services.length > 0) {
                for (const service of services) {
                    // Ambil master pricing types untuk auto-fill unit
                    const masterPricingTypes = await tx.pricing_types.findMany();
                    // Buat atau update provider service
                    const existingProviderService = await tx.provider_services.findFirst({
                        where: {
                            provider_id: newUser.id,
                            service_id: service.serviceId
                        }
                    });
                    let providerServiceId;
                    if (existingProviderService) {
                        providerServiceId = existingProviderService.id;
                    }
                    else {
                        const newProviderService = await tx.provider_services.create({
                            data: {
                                provider_id: newUser.id,
                                service_id: service.serviceId,
                                description: service.description
                            }
                        });
                        providerServiceId = newProviderService.id;
                    }
                    // Map data harga dengan unit otomatis dari pricing_types
                    const priceData = service.prices.map(p => {
                        const typeInfo = masterPricingTypes.find((t) => t.id === p.pricingTypeId);
                        return {
                            provider_service_id: providerServiceId,
                            pricing_type_id: p.pricingTypeId,
                            price: p.price,
                            unit: typeInfo?.default_unit || null
                        };
                    });
                    await tx.provider_service_prices.createMany({ data: priceData });
                }
            }
            return { newUser, profile };
        });
        const token = this.generateToken(result.newUser.id, role.name);
        return { token, user: { id: result.newUser.id, email: result.newUser.email, role: role.name }, profile: result.profile };
    }
    //register admin langsung masuk ke tabel users tanpa profile karena tidak diperlukan
    async registerAdmin(email, password, name, phone) {
        const existing = await prisma.users.findUnique({ where: { email } });
        if (existing)
            throw new Error('Email sudah terdaftar');
        const role = await prisma.roles.findUnique({ where: { name: 'admin' } });
        if (!role)
            throw new Error('Role admin tidak ditemukan');
        const hashedPassword = await bcrypt.hash(password, 12);
        const user = await prisma.users.create({
            data: {
                email,
                password_hash: hashedPassword,
                role_id: role.id,
                phone
            }
        });
        const token = this.generateToken(user.id, role.name);
        return { token, user: { id: user.id, email: user.email, role: role.name }, profile: null };
    }
    async login(email, password) {
        const user = await prisma.users.findUnique({
            where: { email },
            include: { roles: true, profiles_customer: true, provider_profiles: true }
        });
        if (!user)
            throw new Error('Email atau password salah');
        const isValid = await bcrypt.compare(password, user.password_hash || '');
        if (!isValid)
            throw new Error('Email atau password salah');
        const token = this.generateToken(user.id, user.roles.name);
        return { token, user: { id: user.id, email: user.email, role: user.roles.name }, profile: user.profiles_customer || user.provider_profiles };
    }
    // ==========================================
    // 5. FITUR BARU: LOGIN & REGISTER VIA GOOGLE
    // ==========================================
    async loginWithGoogle(idToken) {
        // 1. Verifikasi token ke Google
        const ticket = await client.verifyIdToken({
            idToken: idToken,
            audience: process.env.GOOGLE_CLIENT_ID,
        });
        const payload = ticket.getPayload();
        if (!payload || !payload.email)
            throw new Error('Gagal mendapatkan payload dari Google');
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
            if (!role)
                throw new Error('Role customer tidak ditemukan');
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
        }
        else {
            roleName = user.roles.name;
        }
        // 4. Generate token internal Jasaku menggunakan function pembantu class
        const token = this.generateToken(user.id, roleName);
        return {
            token,
            user: { id: user.id, email: user.email, role: roleName },
            profile: user.profiles_customer || user.provider_profiles
        };
    }
    generateToken(userId, role) {
        return jwt.sign({ userId, role }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRES_IN });
    }
}
