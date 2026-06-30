import { prisma } from "../../config/prisma";

export class LocationService {
    async updateProviderLocation(providerId: string, lat: number, lng: number, address: string) {
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

    async getProviderLocation(providerUserId: string) {
        const result = await prisma.$queryRaw<Array<{ lat: number; lng: number; address: string; updated_at: Date }>>`
            SELECT 
                ST_Y(location::geometry) as lat,
                ST_X(location::geometry) as lng,
                address,
                COALESCE(updated_at, created_at) as updated_at
            FROM provider_locations
            WHERE provider_id = ${providerUserId}::uuid
        `;
        return result.length > 0 ? result[0] : null;
    }
}