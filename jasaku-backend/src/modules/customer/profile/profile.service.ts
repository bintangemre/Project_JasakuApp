import { prisma } from "../../../config/prisma";

export const getCustomerProfile = async (userId: string) => {
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
                    avatar_url: true,
                }
            }
        }
    });
    if (!user) throw new Error("User tidak ditemukan");
    return user;
};

export const updateCustomerProfile = async (
    userId: string,
    data: { full_name?: string; nickname?: string },
    avatarPath?: string
) => {
    const profile = await prisma.profiles_customer.findUnique({
        where: { user_id: userId }
    });
    if (!profile) throw new Error("Profil customer tidak ditemukan");

    const updateData: any = {};
    if (data.full_name !== undefined) updateData.full_name = data.full_name;
    if (data.nickname !== undefined) updateData.nickname = data.nickname;
    if (avatarPath !== undefined) updateData.avatar_url = avatarPath;

    const updated = await prisma.profiles_customer.update({
        where: { user_id: userId },
        data: updateData,
        select: {
            id: true,
            full_name: true,
            nickname: true,
            birth_date: true,
            gender: true,
            avatar_url: true,
        }
    });
    return updated;
};
