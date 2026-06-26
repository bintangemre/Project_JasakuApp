import { prisma } from "../../../config/prisma";

export class LocationService {
    async updateProviderLocation(providerId: string, lat: number, lng: number, address: string) {
        // Flutter mengirim lat & lng, API bertugas melakukan Upsert ke PostGIS
        return await prisma.$executeRaw`
            INSERT INTO provider_locations (id, provider_id, address, location)
            VALUES (
                gen_random_uuid(), 
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