import { prisma } from '../../config/prisma';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';   

export class AuthService {
  
  async registerCustomer(email: string, password: string, name: string, phone?: string, gender?: string, birthDate?: Date) {
    // Cek email sudah terdaftar
    const existing = await prisma.users.findUnique({ where: { email } });
    if (existing) throw new Error('Email sudah terdaftar');

    // Cari role berdasarkan name
    const role = await prisma.roles.findUnique({ where: { name: 'customer' } });
    if (!role) throw new Error('Role tidak ditemukan');

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 12);

    // Gunakan transaction agar atomic
    const user = await prisma.$transaction(async (tx) => {
      const newUser = await tx.users.create({
        data: {
          email,
          password_hash: hashedPassword,
          role_id: role.id,
          phone
        }
      });

      await tx.profiles_customer.create({
        data: { user_id: newUser.id, full_name: name, gender: gender, birth_date: birthDate }
      });
      
      return newUser;
    });

    return this.generateToken(user.id, role.name);
  }


  //untuk Jasa (provider)
  async registerProvider(full_name: string, nickname: string, email: string, password: string, phone: string, birthDate: Date, gender: string, address: string, domicile: string, profile_photo?: string, ktp_photo?: string, selfie_photo?: string) {
    // Cek email sudah terdaftar
    const existing = await prisma.users.findUnique({ where: { email } });
    if (existing) throw new Error('Email sudah terdaftar');

    const role = await prisma.roles.findUnique({ where: { name: 'provider' } });
    if (!role) throw new Error('Role provider tidak ditemukan');

    const hashedPassword = await bcrypt.hash(password, 12);

    const user = await prisma.$transaction(async (tx) => {
      const newUser = await tx.users.create({
        data: {
          email,
          password_hash: hashedPassword,
          role_id: role.id,
          phone
        }
      });

      // Gunakan fullName (sesuai parameter)
      await tx.provider_profiles.create({
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
      
      return newUser;
    });

    return this.generateToken(user.id, role.name);
  }

  async login(email: string, password: string) {
    const user = await prisma.users.findUnique({
      where: { email },
      include: { roles: true, profiles_customer: true, provider_profiles: true }
    });
    if (!user) throw new Error('Email atau password salah');

    const isValid = await bcrypt.compare(password, user.password_hash || '');
    if (!isValid) throw new Error('Email atau password salah');

    const token = this.generateToken(user.id, user.roles.name);

    return { token, user: { id: user.id, email: user.email, role: user.roles.name }, profile: user.profiles_customer || user.provider_profiles };
  }

  private generateToken(userId: string, role: string) {
    return jwt.sign(
      { userId, role },
      process.env.JWT_SECRET!,
      { expiresIn: process.env.JWT_EXPIRES_IN as any }
    );
  }
}
