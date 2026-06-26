import { Prisma } from "../../generated/prisma/client";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { prisma } from "../../config/prisma";

export class ReviewsService {
    // mengirim review dan rating atau ulasan setelah layanan selesai

   

    // mendapatkan daftar review untuk provider tertentu
    async getProviderReviews(providerId: string) {
        return await prisma.reviews.findMany({
            where: { provider_id: providerId },
            select: {
                customers: {
                    select: { id: true, name: true }
                }
            }
        });
    }
    
}