import { z } from 'zod';

export const registerCustomerSchema = z.object({
    email: z.string().email('Email tidak valid'),
    password: z.string().min(6, 'Password minimal 6 karakter'),
    name: z.string().min(1, 'Nama wajib diisi'),
    phone: z.string().optional(),
    gender: z.string().optional(),
    birthDate: z.string().optional(),
});

export const loginSchema = z.object({
    email: z.string().email('Email tidak valid'),
    password: z.string().min(1, 'Password wajib diisi'),
});

export const googleLoginSchema = z.object({
    idToken: z.string().min(1, 'idToken wajib diisi'),
});

export const sendOtpSchema = z.object({
    email: z.string().email('Email tidak valid'),
    phone: z.string().min(1, 'Nomor HP wajib diisi'),
});

export const verifyOtpSchema = z.object({
    email: z.string().email('Email tidak valid'),
    phone: z.string().min(1, 'Nomor HP wajib diisi'),
    otp: z.string().length(6, 'OTP harus 6 digit'),
});

export const createOrderSchema = z.object({
    providerId: z.string().uuid('providerId tidak valid'),
    serviceId: z.string().uuid('serviceId tidak valid'),
    pricingTypeId: z.string().uuid('pricingTypeId tidak valid'),
    quantity: z.number().int().positive('Kuantitas harus lebih dari 0'),
    description: z.string().optional(),
    workDate: z.string().min(1, 'Tanggal kerja wajib diisi'),
    address: z.string().min(1, 'Alamat wajib diisi'),
    lat: z.number().min(-90).max(90, 'Latitude tidak valid'),
    lng: z.number().min(-180).max(180, 'Longitude tidak valid'),
    attachments: z.array(z.string()).max(5, 'Maksimal 5 lampiran').optional(),
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

export const createServiceSchema = z.object({
    categoryId: z.string().uuid('categoryId tidak valid'),
    name: z.string().min(1, 'Nama layanan wajib diisi'),
    description: z.string().optional(),
});

export const verifyProviderSchema = z.object({
    status: z.enum(['verified', 'rejected'] as const).optional().default('verified'),
});

export const registerDeviceSchema = z.object({
    fcmToken: z.string().min(1, 'fcmToken wajib diisi'),
    deviceType: z.string().min(1, 'deviceType wajib diisi'),
    deviceName: z.string().optional(),
});
