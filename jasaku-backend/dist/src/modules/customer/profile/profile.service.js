import { prisma } from "../../../config/prisma";
export const getCustomerProfile = async (userId) => {
    const user = await prisma.users.findUnique({
        where: { id: userId },
        select: {
            id: true,
            email: true,
            phone: true,
            profiles_customer: {
                select: {
                    id: true,
                    full_name: true,
                    nickname: true,
                    birth_date: true,
                    gender: true,
                    address: true,
                    avatar_url: true,
                }
            }
        }
    });
    if (!user)
        throw new Error("User tidak ditemukan");
    return user;
};
export const updateCustomerProfile = async (userId, data, avatarPath) => {
    const profile = await prisma.profiles_customer.findUnique({
        where: { user_id: userId }
    });
    if (!profile)
        throw new Error("Profil customer tidak ditemukan");
    const profileData = {};
    if (data.full_name !== undefined)
        profileData.full_name = data.full_name;
    if (data.nickname !== undefined)
        profileData.nickname = data.nickname;
    if (data.birth_date !== undefined)
        profileData.birth_date = data.birth_date;
    if (data.gender !== undefined)
        profileData.gender = data.gender;
    if (data.address !== undefined)
        profileData.address = data.address;
    if (avatarPath !== undefined)
        profileData.avatar_url = avatarPath;
    if (data.phone !== undefined) {
        const normalizedPhone = data.phone?.trim() || null;
        if (normalizedPhone) {
            const existing = await prisma.users.findUnique({ where: { phone: normalizedPhone } });
            if (existing && existing.id !== userId) {
                throw new Error("Nomor telepon sudah terdaftar");
            }
        }
        await prisma.users.update({
            where: { id: userId },
            data: { phone: normalizedPhone }
        });
    }
    const updated = await prisma.profiles_customer.update({
        where: { user_id: userId },
        data: profileData,
        select: {
            id: true,
            full_name: true,
            nickname: true,
            birth_date: true,
            gender: true,
            address: true,
            avatar_url: true,
        }
    });
    return updated;
};
