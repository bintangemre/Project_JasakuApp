import { AuthService } from "./auth.service";
import { successResponse, errorResponse } from "../../utils/response";
const registerCustomer = async (req, res) => {
    try {
        const { email, password, role, name, phone, gender, birthDate } = req.body;
        const authService = new AuthService();
        const result = await authService.registerCustomer(email, password, name, phone, gender, birthDate);
        return successResponse(res, result, 'Registrasi berhasil', 201);
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const registerProvider = async (req, res) => {
    try {
        const { full_name, nickname, email, password, phone, birthDate, gender, address, domicile, services, certificates, ocr_nik, ocr_full_name, ocr_birth_place, ocr_birth_date, ocr_address, ocr_gender, ocr_blood_type, ocr_religion, liveness_data } = req.body;
        let parsedServices = [];
        if (services) {
            parsedServices = typeof services === 'string' ? JSON.parse(services) : services;
        }
        let parsedCertificates = [];
        if (certificates) {
            parsedCertificates = typeof certificates === 'string' ? JSON.parse(certificates) : certificates;
        }
        const profile_photo = req.files?.['profile_photo']?.[0]?.path || req.body.profile_photo;
        const ktp_photo = req.files?.['ktp_photo']?.[0]?.path || req.body.ktp_photo;
        const selfie_photo = req.files?.['selfie_photo']?.[0]?.path || req.body.selfie_photo;
        const portfolios = req.files?.['portfolios']?.map((file) => file.path) || [];
        // Ijazah & Sertifikat
        const ijazah_photo = req.files?.['ijazah_photo']?.[0]?.path || null;
        const certificateFiles = req.files?.['certificate_files']?.map((file) => file.path) || [];
        const authService = new AuthService();
        let parsedLiveness = null;
        if (liveness_data) {
            parsedLiveness = typeof liveness_data === 'string' ? JSON.parse(liveness_data) : liveness_data;
        }
        const result = await authService.registerProvider(full_name, nickname, email, password, phone, birthDate, gender, address, domicile, profile_photo, ktp_photo, selfie_photo, portfolios, ijazah_photo, certificateFiles, parsedCertificates, parsedServices, ocr_nik, ocr_full_name, ocr_birth_place, ocr_birth_date, ocr_address, ocr_gender, ocr_blood_type, ocr_religion, parsedLiveness);
        return successResponse(res, result, 'Registrasi penyedia layanan berhasil', 201);
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const registerAdmin = async (req, res) => {
    try {
        const { email, password, name, phone } = req.body;
        const authService = new AuthService();
        const result = await authService.registerAdmin(email, password, name, phone);
        return successResponse(res, result, 'Registrasi admin berhasil', 201);
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const login = async (req, res) => {
    try {
        const { email, password } = req.body;
        const authService = new AuthService();
        const result = await authService.login(email, password);
        return successResponse(res, result, 'Login berhasil');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const loginWithGoogle = async (req, res) => {
    try {
        const { idToken } = req.body;
        const authService = new AuthService();
        const result = await authService.loginWithGoogle(idToken);
        return successResponse(res, result, 'Login dengan Google berhasil');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const sendOtp = async (req, res) => {
    try {
        const { email, phone } = req.body;
        if (!email || !phone) {
            return errorResponse(res, 'Email dan nomor HP harus diisi', 400);
        }
        const authService = new AuthService();
        const result = await authService.sendOtp(email, phone);
        return successResponse(res, result, 'OTP berhasil dikirim');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const verifyOtp = async (req, res) => {
    try {
        const { email, phone, otp } = req.body;
        if (!email || !phone || !otp) {
            return errorResponse(res, 'Email, nomor HP, dan OTP harus diisi', 400);
        }
        const authService = new AuthService();
        const result = await authService.verifyOtp(email, phone, otp);
        return successResponse(res, result, 'Verifikasi OTP berhasil');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const getVerificationStatus = async (req, res) => {
    try {
        const authService = new AuthService();
        const result = await authService.getProviderVerificationStatus(req.user.userId);
        return successResponse(res, result);
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const resubmitVerification = async (req, res) => {
    try {
        const authService = new AuthService();
        await authService.resubmitProviderVerification(req.user.userId);
        return successResponse(res, null, 'Pengajuan ulang verifikasi berhasil dikirim');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
export { registerCustomer, registerProvider, registerAdmin, login, loginWithGoogle, sendOtp, verifyOtp, getVerificationStatus, resubmitVerification };
