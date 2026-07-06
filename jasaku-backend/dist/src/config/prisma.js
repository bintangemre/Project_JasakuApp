import { PrismaClient } from '../generated/prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';
const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const globalForPrisma = globalThis;
export const prisma = globalForPrisma.prisma || new PrismaClient({
    adapter,
    transactionOptions: {
        maxWait: 5000,
        timeout: 15000,
    },
});
if (process.env.NODE_ENV !== 'production')
    globalForPrisma.prisma = prisma;
