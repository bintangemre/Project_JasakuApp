import { Response } from "express";
import { AuthService } from "./auth.service";
import { successResponse, errorResponse } from "../../utils/response";

const registerCustomer = async (req: any, res: Response) => {
  try {
    const { email, password, role, name, phone, gender, birthDate } = req.body;   
    const authService = new AuthService();
    const result = await authService.registerCustomer(email, password, name, phone, gender, birthDate);
    return successResponse(res, result, 'Registrasi berhasil', 201);
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const registerProvider = async (req: any, res: Response) => {
  try {
    // 1. Ambil data teks biasa dari req.body
    const { full_name, nickname, email, password, phone, birthDate, gender, address, domicile, services } = req.body;

    // 2. 🟢 KUNCI PERBAIKAN 1: Ubah string JSON services menjadi Array Objek asli kembali
    let parsedServices = [];
    if (services) {
      parsedServices = typeof services === 'string' ? JSON.parse(services) : services;
    }

    // 3. 🟢 KUNCI PERBAIKAN 2: Tangkap file gambar fisik dari req.files (sesuaikan dengan nama field di multer kamu)
    const profile_photo = req.files?.['profile_photo']?.[0]?.path || req.body.profile_photo;
    const ktp_photo = req.files?.['ktp_photo']?.[0]?.path || req.body.ktp_photo;
    const selfie_photo = req.files?.['selfie_photo']?.[0]?.path || req.body.selfie_photo;
    
    // Tangkap array gambar portofolio opsional
    const portfolios = req.files?.['portfolios']?.map((file: any) => file.path) || [];

    const authService = new AuthService();
    
    // 4. Kirim data yang sudah bersih dan matang ke database via service
    const result = await authService.registerProvider(
      full_name, 
      nickname, 
      email, 
      password, 
      phone, 
      birthDate, 
      gender, 
      address, 
      domicile, 
      profile_photo, 
      ktp_photo, 
      selfie_photo, 
      portfolios, // Kirim array string url/path portofolio
      parsedServices // Kirim array objek services yang sudah valid
    );

    return successResponse(res, result, 'Registrasi penyedia layanan berhasil', 201);
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const registerAdmin = async (req: any, res: Response) => {
  try {
    const { email, password, name, phone } = req.body;  
    const authService = new AuthService();
    const result = await authService.registerAdmin(email, password, name, phone);
    return successResponse(res, result, 'Registrasi admin berhasil', 201);
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const login = async (req: any, res: Response) => {
  try {
    const { email, password } = req.body;
    const authService = new AuthService();
    const result = await authService.login(email, password);
    return successResponse(res, result, 'Login berhasil');
  } catch (err: any) {
    return errorResponse(res, err.message);
  }   
};

const loginWithGoogle = async (req: any, res: Response) => {
  try {
    const { idToken } = req.body;
    const authService = new AuthService();
    const result = await authService.loginWithGoogle(idToken);
    return successResponse(res, result, 'Login dengan Google berhasil');
  }
  catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const sendOtp = async (req: any, res: Response) => {
  try {
    const { email, phone } = req.body;
    if (!email || !phone) {
      return errorResponse(res, 'Email dan nomor HP harus diisi', 400);
    }
    const authService = new AuthService();
    const result = await authService.sendOtp(email, phone);
    return successResponse(res, result, 'OTP berhasil dikirim');
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const verifyOtp = async (req: any, res: Response) => {
  try {
    const { email, phone, otp } = req.body;
    if (!email || !phone || !otp) {
      return errorResponse(res, 'Email, nomor HP, dan OTP harus diisi', 400);
    }
    const authService = new AuthService();
    const result = await authService.verifyOtp(email, phone, otp);
    return successResponse(res, result, 'Verifikasi OTP berhasil');
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

export { registerCustomer, registerProvider, registerAdmin, login, loginWithGoogle, sendOtp, verifyOtp };