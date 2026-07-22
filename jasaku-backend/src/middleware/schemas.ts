import { z } from 'zod';

export const registerCustomerSchema = z.object({
    email: z.string().email('Email tidak valid'),
    password: z.string().min(6, 'Password minimal 6 karakter'),
    name: z.string().min(1, 'Nama wajib diisi'),
    phone: z.string().nullish(),
    gender: z.string().nullish(),
    birthDate: z.string().nullish(),
});

export const loginSchema = z.object({
    email: z.string().email('Email tidak valid'),
    password: z.string().min(1, 'Password wajib diisi'),
});

export const googleLoginSchema = z.object({
    idToken: z.string().min(1, 'idToken wajib diisi'),
});

export const createOrderSchema = z.object({
    providerId: z.string().uuid('providerId tidak valid'),
    serviceId: z.string().uuid('serviceId tidak valid'),
    pricingUnitId: z.string().uuid('pricingUnitId tidak valid'),
    contractTypeId: z.string().uuid('contractTypeId tidak valid').optional(),
    withMaterial: z.boolean().optional().default(false),
    quantity: z.number().int().positive('Kuantitas harus lebih dari 0'),
    description: z.string().optional(),
    workDate: z.string().min(1, 'Tanggal kerja wajib diisi'),
    address: z.string().min(1, 'Alamat wajib diisi'),
    lat: z.number().min(-90).max(90, 'Latitude tidak valid'),
    lng: z.number().min(-180).max(180, 'Longitude tidak valid'),
    attachments: z.array(z.string()).max(5, 'Maksimal 5 lampiran').optional(),
    paymentMethod: z.string().optional(),
});

export const updateOrderStatusSchema = z.object({
    status: z.enum(['accepted', 'rejected', 'on_the_way', 'arrived', 'in_progress', 'completed'] as const),
});

export const createReviewSchema = z.object({
    orderId: z.string().uuid('orderId tidak valid'),
    providerId: z.string().uuid('providerId tidak valid'),
    rating: z.number().int().min(1, 'Rating minimal 1').max(5, 'Rating maksimal 5'),
    review: z.string().optional(),
});

export const createPaymentSchema = z.object({
    orderId: z.string().uuid('orderId tidak valid'),
    method: z.string().min(1, 'Metode pembayaran wajib diisi'),
    amount: z.number().positive('Amount harus lebih dari 0'),
});

export const updatePaymentStatusSchema = z.object({
    status: z.enum(['paid', 'failed', 'pending'] as const),
});

export const savePaymentMethodSchema = z.object({
    type: z.string().min(1, 'Tipe wajib diisi'),
    accountNumber: z.string().min(1, 'Nomor rekening wajib diisi'),
    accountName: z.string().min(1, 'Nama rekening wajib diisi'),
    providerName: z.string().optional(),
});

export const createCategorySchema = z.object({
    name: z.string().min(1, 'Nama kategori wajib diisi'),
    description: z.string().optional(),
    iconUrl: z.string().optional(),
});

export const createPricingUnitSchema = z.object({
    categoryId: z.string().uuid('categoryId tidak valid').optional(),
    name: z.string().min(1, 'Nama unit harga wajib diisi').max(50, 'Nama maksimal 50 karakter'),
    unit: z.string().optional(),
});

export const updatePricingUnitSchema = z.object({
    name: z.string().min(1, 'Nama unit harga wajib diisi').max(50, 'Nama maksimal 50 karakter').optional(),
    unit: z.string().optional(),
    categoryId: z.string().uuid('categoryId tidak valid').optional(),
});

export const createContractTypeSchema = z.object({
    name: z.string().min(1, 'Nama tipe kontrak wajib diisi').max(50, 'Nama maksimal 50 karakter'),
    description: z.string().optional(),
});

export const updateContractTypeSchema = z.object({
    name: z.string().min(1, 'Nama tipe kontrak wajib diisi').max(50, 'Nama maksimal 50 karakter').optional(),
    description: z.string().optional(),
});

export const createServiceSchema = z.object({
    categoryId: z.string().uuid('categoryId tidak valid'),
    name: z.string().min(1, 'Nama layanan wajib diisi'),
    description: z.string().optional(),
});

export const verifyProviderSchema = z.object({
    status: z.enum(['verified', 'rejected'] as const).optional().default('verified'),
    notes: z.string().optional(),
    checklist: z.array(z.object({
        item: z.string(),
        status: z.enum(['passed', 'failed']),
        note: z.string().optional(),
    })).optional(),
});

export const registerDeviceSchema = z.object({
    fcmToken: z.string().min(1, 'fcmToken wajib diisi'),
    deviceType: z.string().min(1, 'deviceType wajib diisi'),
    deviceName: z.string().optional(),
});

export const createCustomTaskSchema = z.object({
    title: z.string().min(1, 'Judul task wajib diisi').max(150, 'Maksimal 150 karakter'),
    description: z.string().optional().nullable(),
    budget_per_person: z.coerce.number().positive('Budget per orang harus lebih dari 0'),
    required_people: z.coerce.number().int().min(1, 'Minimal 1 orang').default(1),
    address: z.string().optional(),
    location_detail: z.string().optional().nullable(),
    publish_days: z.coerce.number().int().min(1, 'Minimal 1 hari').max(3, 'Maksimal 3 hari').default(1),
    lat: z.coerce.number().min(-90).max(90, 'Latitude tidak valid'),
    lng: z.coerce.number().min(-180).max(180, 'Longitude tidak valid'),
    locations: z.preprocess(
        (val) => {
            if (Array.isArray(val)) return val;
            if (typeof val === 'string') {
                try { return JSON.parse(val); } catch { return []; }
            }
            return [];
        },
        z.array(z.object({
            label: z.string().optional(),
            address: z.string().min(1, 'Alamat titik wajib diisi'),
            lat: z.coerce.number().min(-90).max(90),
            lng: z.coerce.number().min(-180).max(180),
        })).optional().default([])
    ),
});

export const submitBidSchema = z.object({
    offeredPrice: z.number().positive('Harga penawaran harus lebih dari 0'),
    message: z.string().min(1, 'Pesan wajib diisi'),
});

export const getAvailableTasksQuerySchema = z.object({
    lat: z.coerce.number().min(-90).max(90).optional(),
    lng: z.coerce.number().min(-180).max(180).optional(),
    radius: z.coerce.number().positive().optional(),
});
