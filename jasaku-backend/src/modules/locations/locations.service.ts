import { Prisma } from "../../generated/prisma/client";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { prisma } from "../../config/prisma";

export class LocationService {
    async updateProviderLocation(providerId: string, lat: number, lng: number, address: string) {
        // Upsert (Update jika ada, Insert jika tidak ada) menggunakan SQL mentah
        return await prisma.$executeRaw`
            INSERT INTO provider_locations (id, provider_id, address, location)
            VALUES (
                uuid_generate_v4(), 
                ${providerId}::uuid, 
                ${address}, 
                ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)
            )
            ON CONFLICT (provider_id) DO UPDATE 
            SET 
                address = ${address},
                location = ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326);
        `;
    }
}