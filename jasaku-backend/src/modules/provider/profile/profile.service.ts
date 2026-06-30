import { prisma } from "../../../config/prisma";

export class ProfileService {
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
}
