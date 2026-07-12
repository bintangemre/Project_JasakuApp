import { prisma } from "../../config/prisma";
import { NotificationService } from "../notifications/notifications.service";

export class ReviewsService {
    // mengirim review dan rating setelah layanan selesai
    async createReview(customerId: string, orderId: string, providerId: string, rating: number, review?: string) {
        const result = await prisma.reviews.create({
            data: {
                order_id: orderId,
                customer_id: customerId,
                provider_id: providerId,
                rating,
                review
            }
        });

        // update rata-rata rating & total_reviews provider
        const agg = await prisma.reviews.aggregate({
            where: { provider_id: providerId },
            _avg: { rating: true },
            _count: true
        });

        await prisma.provider_profiles.update({
            where: { user_id: providerId },
            data: {
                rating: agg._avg.rating ?? 0,
                total_reviews: agg._count
            }
        });

        NotificationService.sendToUser(
            providerId,
            'Review Baru',
            `Anda mendapat review ${rating} bintang dari customer.`,
            { type: 'NEW_REVIEW', orderId }
        ).catch(() => {});

        return result;
    }

    // mendapatkan daftar review untuk provider tertentu
    async getProviderReviews(providerId: string) {
        return await prisma.reviews.findMany({
            where: { provider_id: providerId },
            select: {
                id: true,
                rating: true,
                review: true,
                created_at: true,
                users_reviews_customer_idTousers: {
                    select: {
                        id: true,
                        profiles_customer: {
                            select: { full_name: true, avatar_url: true }
                        }
                    }
                }
            }
        });
    }

    // cek apakah order sudah pernah direview
    async getReviewByOrder(orderId: string) {
        return await prisma.reviews.findUnique({
            where: { order_id: orderId }
        });
    }
    
}