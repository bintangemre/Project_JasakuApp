import { prisma } from "../../../config/prisma";

export class ProfileService {
  async getFullProfile(userId: string) {
    const profile = await prisma.provider_profiles.findUnique({
      where: { user_id: userId },
    });

    const services = await prisma.provider_services.findMany({
      where: { provider_id: userId },
      include: {
        services: true,
        provider_service_prices: {
          include: { pricing_types: true },
        },
      },
    });

    let payoutMethods: any[] = [];
    if (profile) {
      payoutMethods = await prisma.provider_payout_methods.findMany({
        where: { provider_id: profile.id },
      });
    }

    return { profile, services, payoutMethods };
  }

  async completeOnboarding(
    userId: string,
    data: {
      profile_photo?: string;
      services?: Array<{
        serviceId: string;
        description: string;
        prices: Array<{ pricingTypeId: string; price: number }>;
      }>;
      payoutMethod?: {
        type: string;
        provider_name: string;
        account_number: string;
        account_name: string;
      };
    }
  ) {
    return await prisma.$transaction(async (tx) => {
      if (data.profile_photo) {
        await tx.provider_profiles.update({
          where: { user_id: userId },
          data: { profile_photo: data.profile_photo },
        });
      }

      if (data.services && data.services.length > 0) {
        const masterPricingTypes = await tx.pricing_types.findMany();

        for (const svc of data.services) {
          const existing = await tx.provider_services.findFirst({
            where: { provider_id: userId, service_id: svc.serviceId },
          });
          if (!existing) continue;

          await tx.provider_services.update({
            where: { id: existing.id },
            data: { description: svc.description },
          });

          await tx.provider_service_prices.deleteMany({
            where: { provider_service_id: existing.id },
          });

          if (svc.prices.length > 0) {
            const priceData = svc.prices.map((p) => {
              const typeInfo = masterPricingTypes.find(
                (t: any) => t.id === p.pricingTypeId
              );
              return {
                provider_service_id: existing.id,
                pricing_type_id: p.pricingTypeId,
                price: p.price,
                unit: typeInfo?.default_unit || null,
              };
            });
            await tx.provider_service_prices.createMany({ data: priceData });
          }
        }
      }

      if (data.payoutMethod) {
        const profile = await tx.provider_profiles.findUnique({
          where: { user_id: userId },
          select: { id: true },
        });
        if (profile) {
          await tx.provider_payout_methods.create({
            data: {
              provider_id: profile.id,
              ...data.payoutMethod,
            },
          });
        }
      }

      await tx.provider_profiles.update({
        where: { user_id: userId },
        data: { onboarding_completed: true },
      });
    });
  }

  async updateProfile(
    userId: string,
    data: {
      full_name?: string;
      nickname?: string;
      gender?: string;
      birth_date?: string;
      phone?: string;
      address?: string;
      domicile?: string;
      profile_photo?: string;
      portfolios?: string[];
      ktp_photo?: string;
      selfie_photo?: string;
    }
  ) {
    const profile = await prisma.provider_profiles.findUnique({
      where: { user_id: userId },
      select: { id: true },
    });
    if (!profile) throw new Error('Profil provider tidak ditemukan');

    const updateData: any = {};
    if (data.full_name !== undefined) updateData.full_name = data.full_name;
    if (data.nickname !== undefined) updateData.nickname = data.nickname;
    if (data.gender !== undefined) updateData.gender = data.gender;
    if (data.birth_date !== undefined) updateData.birth_date = new Date(data.birth_date);
    if (data.phone !== undefined) updateData.phone = data.phone?.trim() || null;
    if (data.address !== undefined) updateData.address = data.address;
    if (data.domicile !== undefined) updateData.domicile = data.domicile;
    if (data.profile_photo !== undefined) updateData.profile_photo = data.profile_photo;
    if (data.portfolios !== undefined) updateData.portfolios = data.portfolios;
    if (data.ktp_photo !== undefined) updateData.ktp_photo = data.ktp_photo;
    if (data.selfie_photo !== undefined) updateData.selfie_photo = data.selfie_photo;

    if (Object.keys(updateData).length > 0) {
      await prisma.provider_profiles.update({
        where: { user_id: userId },
        data: updateData,
      });
    }

    if (data.ktp_photo && data.selfie_photo) {
      const { runFaceMatchAsync } = await import("../../../config/face_client");
      runFaceMatchAsync(profile.id, data.ktp_photo, data.selfie_photo).catch((e: any) =>
        console.warn("Face match non-blocking error:", e.message),
      );
    }
  }

  async deleteProviderDocuments(providerUserId: string, documentIds: string[]) {
    const profile = await prisma.provider_profiles.findUnique({
      where: { user_id: providerUserId },
      select: { id: true },
    });
    if (!profile) throw new Error('Profil provider tidak ditemukan');
    await prisma.provider_documents.deleteMany({
      where: {
        id: { in: documentIds },
        provider_id: profile.id,
      },
    });
  }
}
